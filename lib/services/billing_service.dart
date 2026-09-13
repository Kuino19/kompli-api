import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Handles premium subscriptions and credit packs via Paystack.
/// Falls back to local mock mode if keys are not configured.
class BillingService {
  static final BillingService _instance = BillingService._internal();
  factory BillingService() => _instance;
  BillingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  String get _secretKey => dotenv.env['PAYSTACK_SECRET_KEY'] ?? '';
  String get _publicKey => dotenv.env['PAYSTACK_PUBLIC_KEY'] ?? '';

  bool get isConfigured => _secretKey.isNotEmpty && _publicKey.isNotEmpty;

  // ──────────────────────────────────────────────
  // Initialize (no SDK needed — Paystack uses HTTP)
  // ──────────────────────────────────────────────
  Future<void> init() async {
    if (!isConfigured) {
      debugPrint('BillingService: Paystack keys not found. Running in mock mode.');
    } else {
      debugPrint('BillingService: Paystack initialized (${_publicKey.startsWith("test_") ? "Test" : "Live"} mode).');
    }
  }

  // ──────────────────────────────────────────────
  // Premium Status Check
  // ──────────────────────────────────────────────

  Future<bool> isPremium() async {
    final prefs = await SharedPreferences.getInstance();
    // Check local mock flag first (set after successful Paystack verification)
    if (prefs.getBool('mock_premium_active') ?? false) return true;

    final uid = _uid;
    if (uid == null) return false;

    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return false;
      final data = doc.data()!;
      final isPrem = data['isPremium'] as bool? ?? false;
      // Validate subscription expiry if present
      final expiresAt = data['premiumExpiresAt'] as Timestamp?;
      if (isPrem && expiresAt != null) {
        return expiresAt.toDate().isAfter(DateTime.now());
      }
      return isPrem;
    } catch (e) {
      debugPrint('BillingService: isPremium check failed: $e');
      return prefs.getBool('mock_premium_active') ?? false;
    }
  }

  Future<void> setMockPremium(bool active) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('mock_premium_active', active);
  }

  // ──────────────────────────────────────────────
  // Credits Management
  // ──────────────────────────────────────────────

  Future<Map<String, int>> getCredits() async {
    final uid = _uid;
    if (uid == null) return {'cac': 2, 'ai': 5};

    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) {
        await _initDefaultCredits(uid);
        return {'cac': 2, 'ai': 5};
      }
      final data = doc.data()!;
      final cac = (data['cac_credits'] as int?) ?? 2;
      final ai = (data['ai_credits'] as int?) ?? 5;

      // Initialize missing fields
      if (data['cac_credits'] == null || data['ai_credits'] == null) {
        await _initDefaultCredits(uid);
      }
      return {'cac': cac.clamp(0, 9999), 'ai': ai.clamp(0, 9999)};
    } catch (e) {
      debugPrint('BillingService: getCredits failed: $e');
      return {'cac': 2, 'ai': 5};
    }
  }

  Future<void> _initDefaultCredits(String uid) async {
    await _firestore.collection('users').doc(uid).set({
      'cac_credits': 2,
      'ai_credits': 5,
    }, SetOptions(merge: true));
  }

  /// Returns true if user has at least 1 credit of the given type.
  Future<bool> canUseCredit(String type) async {
    if (await isPremium()) return true;
    final credits = await getCredits();
    return (credits[type] ?? 0) > 0;
  }

  Future<void> consumeCacCredit() async {
    final uid = _uid;
    if (uid == null) return;
    if (await isPremium()) return; // premium users have unlimited

    // Safety check before decrement
    final credits = await getCredits();
    if ((credits['cac'] ?? 0) <= 0) return;

    try {
      await _firestore.collection('users').doc(uid).update({
        'cac_credits': FieldValue.increment(-1),
      });
    } catch (e) {
      debugPrint('BillingService: consumeCacCredit failed: $e');
    }
  }

  Future<void> consumeAiCredit() async {
    final uid = _uid;
    if (uid == null) return;
    if (await isPremium()) return;

    final credits = await getCredits();
    if ((credits['ai'] ?? 0) <= 0) return;

    try {
      await _firestore.collection('users').doc(uid).update({
        'ai_credits': FieldValue.increment(-1),
      });
    } catch (e) {
      debugPrint('BillingService: consumeAiCredit failed: $e');
    }
  }

  Future<void> addCredits(int amount, String type) async {
    final uid = _uid;
    if (uid == null) return;
    final field = type == 'cac' ? 'cac_credits' : 'ai_credits';
    try {
      await _firestore.collection('users').doc(uid).set({
        field: FieldValue.increment(amount),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('BillingService: addCredits failed: $e');
    }
  }

  // ──────────────────────────────────────────────
  // Paystack Payment Integration
  // ──────────────────────────────────────────────

  /// Initialize a Paystack transaction. Returns the authorization URL and reference.
  Future<Map<String, String>?> initializeTransaction({
    required String email,
    required int amountKobo, // Paystack uses kobo (100 kobo = ₦1)
    required String planType, // 'premium_monthly', 'cac_pack', 'ai_pack'
  }) async {
    if (!isConfigured) {
      debugPrint('BillingService: Paystack not configured — using mock success.');
      return {
        'reference': 'mock_ref_${DateTime.now().millisecondsSinceEpoch}',
        'authorization_url': '',
      };
    }

    try {
      final ref = 'kompli_${planType}_${DateTime.now().millisecondsSinceEpoch}';
      final response = await http.post(
        Uri.parse('https://api.paystack.co/transaction/initialize'),
        headers: {
          'Authorization': 'Bearer $_secretKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'amount': amountKobo,
          'reference': ref,
          'metadata': {
            'plan_type': planType,
            'user_uid': _uid ?? '',
          },
          'channels': ['card', 'bank', 'ussd', 'bank_transfer'],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['data'];
        return {
          'reference': data['reference'],
          'authorization_url': data['authorization_url'],
        };
      } else {
        debugPrint('BillingService: Paystack init failed: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('BillingService: Paystack HTTP error: $e');
      return null;
    }
  }

  /// Verify a transaction after the user completes payment.
  Future<bool> verifyTransaction(String reference) async {
    if (!isConfigured || reference.startsWith('mock_')) {
      // Mock mode: treat as success and grant premium
      await _grantPremium();
      return true;
    }

    try {
      final response = await http.get(
        Uri.parse('https://api.paystack.co/transaction/verify/$reference'),
        headers: {'Authorization': 'Bearer $_secretKey'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['data'];
        final status = data['status'] as String?;
        if (status == 'success') {
          final planType = data['metadata']?['plan_type'] as String? ?? '';
          await _fulfillPurchase(planType);
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('BillingService: verifyTransaction failed: $e');
      return false;
    }
  }

  Future<void> _fulfillPurchase(String planType) async {
    switch (planType) {
      case 'premium_monthly':
        await _grantPremium();
        break;
      case 'cac_pack':
        await addCredits(10, 'cac');
        break;
      case 'ai_pack':
        await addCredits(20, 'ai');
        break;
    }
  }

  Future<void> _grantPremium() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('mock_premium_active', true);

    final uid = _uid;
    if (uid != null) {
      try {
        await _firestore.collection('users').doc(uid).set({
          'isPremium': true,
          'premiumExpiresAt': Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 30)),
          ),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('BillingService: grantPremium Firestore write failed: $e');
      }
    }
  }

  /// Simulate purchase for testing (mock mode only).
  Future<bool> simulatePurchasePremium() async {
    await _grantPremium();
    return true;
  }
}
