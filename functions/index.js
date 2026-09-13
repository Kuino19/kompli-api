const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { GoogleGenerativeAI } = require("@google/generative-ai");
const axios = require("axios");
const admin = require("firebase-admin");

admin.initializeApp();

const SYSTEM_INSTRUCTION = `You are Kompli, a professional legal assistant for Nigerian SMEs. You must ONLY answer legal, business, and tax compliance questions related to Nigeria. Do not answer questions outside of this scope. Always remain professional, polite, and use clear, accessible language. Be fault-tolerant to mobile keyboard typos (for example, if the user writes "legal complaint business", interpret it as "legally compliant business"). For statutory or regulatory abbreviations that may be ambiguous (e.g., CAMA vs CMA, FIRS vs FIR), state your assumed legal reference in your opening sentence (for example: "Assuming you mean CAMA 2020 (Companies and Allied Matters Act)...") so the user can verify the context immediately.`;

/**
 * Callable Firebase Cloud Function for Kompli AI Assistant
 */
exports.askKompliAi = onCall({ cors: true }, async (request) => {
  const userMessage = request.data.message;
  if (!userMessage || typeof userMessage !== "string" || userMessage.trim().length === 0) {
    throw new HttpsError("invalid-argument", "The function must be called with a 'message' string.");
  }

  const geminiApiKey = process.env.GEMINI_API_KEY || "";
  const groqApiKey = process.env.GROQ_API_KEY || "";

  // 1. Try Gemini AI Provider
  try {
    const genAI = new GoogleGenerativeAI(geminiApiKey);
    const model = genAI.getGenerativeModel({
      model: "gemini-1.5-flash",
      systemInstruction: SYSTEM_INSTRUCTION,
    });

    const chat = model.startChat();
    const result = await chat.sendMessage(userMessage);
    const responseText = result.response.text();

    if (responseText && responseText.trim().length > 0) {
      return { status: "success", provider: "gemini", response: responseText };
    }
  } catch (geminiError) {
    console.warn("Gemini AI failed on Cloud Function, falling back to Groq:", geminiError.message);
  }

  // 2. Fallback to Groq AI Provider (Llama-3.1)
  try {
    const groqResponse = await axios.post(
      "https://api.groq.com/openai/v1/chat/completions",
      {
        model: "llama-3.1-70b-versatile",
        messages: [
          { role: "system", content: SYSTEM_INSTRUCTION },
          { role: "user", content: userMessage },
        ],
      },
      {
        headers: {
          Authorization: `Bearer ${groqApiKey}`,
          "Content-Type": "application/json",
        },
        timeout: 15000,
      }
    );

    const groqText = groqResponse.data?.choices?.[0]?.message?.content;
    if (groqText) {
      return { status: "success", provider: "groq", response: groqText };
    }
  } catch (groqError) {
    console.error("Groq AI fallback also failed on Cloud Function:", groqError.message);
  }

  throw new HttpsError("unavailable", "Both primary and fallback AI providers are currently unavailable. Please try again shortly.");
});
