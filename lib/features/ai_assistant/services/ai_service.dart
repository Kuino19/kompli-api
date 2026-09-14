import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

final aiServiceProvider = Provider<AiService>((ref) => AiService());

class AiService {
  GenerativeModel? _localModel;
  ChatSession? _localChatSession;
  final String _systemInstruction =
      'You are Kompli, a professional legal assistant for Nigerian SMEs. You must ONLY answer legal, business, and tax compliance questions related to Nigeria. Do not answer questions outside of this scope. Always remain professional, polite, and use clear, accessible language. Be fault-tolerant to mobile keyboard typos (for example, if the user writes "legal complaint business", interpret it as "legally compliant business"). For statutory or regulatory abbreviations that may be ambiguous (e.g., CAMA vs CMA, FIRS vs FIR), state your assumed legal reference in your opening sentence (for example: "Assuming you mean CAMA 2020 (Companies and Allied Matters Act)...") so the user can verify the context immediately. When assisting with AML or NFIU Suspicious Transaction Reports (STR) under TPPA 2022, explain that businesses must first register an institutional account on the NFIU goAML portal (portal.nfiu.gov.ng) before filing, and remind users to consult certified legal counsel.';
  
  final List<Map<String, String>> _groqHistory = [];
  final List<DateTime> _requestTimestamps = [];

  AiService() {
    _initLocalFallback();
  }

  void _initLocalFallback() {
    try {
      final geminiApiKey = dotenv.env['GEMINI_API_KEY'];
      if (geminiApiKey != null && geminiApiKey.isNotEmpty) {
        _localModel = GenerativeModel(
          model: 'gemini-flash-latest',
          apiKey: geminiApiKey,
          systemInstruction: Content.system(_systemInstruction),
        );
        _localChatSession = _localModel!.startChat();
      }
    } catch (e) {
      debugPrint('AiService: Local Gemini model fallback init error: $e');
    }
    _groqHistory.add({"role": "system", "content": _systemInstruction});
  }

  Future<String> sendMessage(String userMessage) async {
    // Rate limiting: 5 requests per minute
    final now = DateTime.now();
    _requestTimestamps.removeWhere((t) => now.difference(t).inSeconds > 60);

    if (_requestTimestamps.length >= 5) {
      final oldestRequest = _requestTimestamps.first;
      final secondsPassed = now.difference(oldestRequest).inSeconds;
      final secondsRemaining = 60 - secondsPassed;
      return "⚠️ **AI Rate Limit Exceeded**\n\nYou are on the free plan tier. Please wait **$secondsRemaining seconds** before making another request.";
    }

    _requestTimestamps.add(now);
    _groqHistory.add({"role": "user", "content": userMessage});

    // 1. Primary Strategy: Call Firebase Cloud Function (Secure Backend Proxy)
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('askKompliAi');
      final result = await callable.call({'message': userMessage});
      if (result.data != null && result.data['response'] != null) {
        final text = result.data['response'].toString();
        _groqHistory.add({"role": "assistant", "content": text});
        return text;
      }
    } catch (cfError) {
      debugPrint('Firebase Cloud Function askKompliAi error/unreachable: $cfError. Falling back to local AI pipeline...');
    }

    // 2. Fallback Strategy A: Direct Local Gemini SDK
    if (_localChatSession != null) {
      try {
        final response = await _localChatSession!.sendMessage(Content.text(userMessage));
        final text = response.text ?? "I'm sorry, I could not generate a response.";
        _groqHistory.add({"role": "assistant", "content": text});
        return text;
      } catch (e) {
        debugPrint('Local Gemini failed: $e. Falling back to Groq...');
      }
    }

    // 3. Fallback Strategy B: Direct Local Groq HTTP API
    return await _fallbackToGroq(userMessage);
  }

  Future<String> _fallbackToGroq(String userMessage) async {
    final groqApiKey = dotenv.env['GROQ_API_KEY'];
    if (groqApiKey == null || groqApiKey.isEmpty) {
      return "An error occurred, and the Groq fallback API key was not found.";
    }

    final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $groqApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "model": "llama-3.1-70b-versatile",
          "messages": _groqHistory,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['choices'][0]['message']['content'].toString();
        _groqHistory.add({"role": "assistant", "content": text});
        return text;
      } else {
        return "AI response error: ${response.body}";
      }
    } catch (e) {
      return "Network error connecting to AI providers: $e";
    }
  }
}
