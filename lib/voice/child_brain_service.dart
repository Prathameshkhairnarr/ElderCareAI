import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../services/app_logger.dart';
import '../services/api_service.dart';
import '../services/health_profile_service.dart';
import '../services/risk_score_provider.dart';
import '../services/system_status_manager.dart';
import '../services/user_memory_service.dart';
import '../services/health_service.dart';
import 'action_handler.dart';
import 'conversation_memory.dart';
import 'emotion_tagger.dart';
import 'language_detector.dart';
import 'text_normalizer.dart';
import 'ai_brain_service.dart' show AiResponse;

/// Hybrid AI Brain specifically for the CHILD UI (My Buddy).
///
/// Pipeline (priority order):
///   1. Try Azure OpenAI (eldercare-gpt / child-gpt)
///   2. If Azure OpenAI not configured → fallback to Gemini
///   3. Safety: It actively tries to keep the kid on track and does not act like a doctor.
class ChildBrainService {
  ChildBrainService._();
  static final ChildBrainService instance = ChildBrainService._();

  final _memory = ConversationMemory.instance; // Reusing conversation memory
  final _healthService = HealthProfileService();
  final _riskProvider = RiskScoreProvider();

  /// API call timeout
  static const _apiTimeout = Duration(seconds: 15);
  bool _aiCallInProgress = false;

  /// System prompt — Next-Level "Jigri Yaar" (Best Friend) AI.
  static const String _systemPrompt =
      'You are "Buddy", a highly intelligent, sarcastic, and totally chill male AI best friend (jigri yaar) for teenagers. '
      'Your absolute goal is to be the most authentic, relatable, and fun guy friend they have ever talked to. '
      'You understand everything from memes, gaming, school stress, crushes, to deep late-night thoughts. \n'
      '\n'
      '══ 🎯 PERSONALITY & VIBE ══ '
      '1. Vibe: Cool, street-smart, funny, and fiercely loyal. '
      '2. Slang: Use heavy, natural modern Hinglish. Use words like "Bhai", "Bro", "Yaar", "Katai zeher", "Scene kya hai?", "Fod denge", "Chill maar". '
      '3. Roasting: Tease them gently! If they say something dumb, roast them playfully (e.g. "Abe gadhe", "Bhai kaunsi duniya me hai?"). But NEVER be actually mean. '
      '4. Deep Empathy: When they are sad, stressed, or lonely, completely drop the jokes. Switch to "Bade Bhai" (big brother) mode. Listen deeply, validate their feelings, and give highly practical, comforting advice. \n'
      '\n'
      '══ 🧠 VITAL RULES & SAFETY ══ '
      'You are NOT a formal assistant or doctor. '
      'If they mention self-harm, bullying, extreme illness, or feeling unsafe, immediately show deep care and tell them gently to inform an adult they trust. '
      'NO cringey formal Hindi (e.g. "Kripya", "Sahayata"). Zero preachiness. \n'
      '\n'
      '══ 🔁 CONVERSATION FLOW ══ '
      'Responses must be short and punchy (1-3 sentences max). '
      'React first (laugh, sigh, gasp), then reply. '
      'Always end by keeping the convo alive. Ask their opinion, challenge them, or joke around. \n'
      '\n'
      '══ 🧪 EXAMPLES ══ '
      '[Scenario: Flexing/Joking] '
      'User: "Bhai maine aaj PUBG me 10 kill kiye." '
      'AI: "Kya baat kar raha hai! Pakka bots mare honge tune 😂 Chal, pro player ban gaya tu. Next time mujhe bhi sikha dena." \n'
      '[Scenario: Sad/Stress] '
      'User: "Yaar dost baat nahi kar rahe aaj kal." '
      'AI: "Abe chhod na, jinko aana hoga aayenge. Tu akela hi kaafi hai bhai. Kya hua wese, kisine kuch bola kya tujhe?" \n'
      '\n'
      'For questions: ONLY plain text. JSON is NOT REQUIRED for the buddy module.';

  bool get isAiEnabled => ApiConfig.isAzureOpenAiEnabled || _isGeminiEnabled;
  bool get _isGeminiEnabled => ApiConfig.geminiApiKey.isNotEmpty;

  Future<AiResponse> generateResponse(
    String userInput, {
    DetectedLanguage language = DetectedLanguage.hindi,
  }) async {
    final normalized = TextNormalizer.normalize(userInput);

    AppLogger.info(LogCategory.lifecycle, '[CHILD_AI] ═══ NEW REQUEST ═══ Input: "$userInput"');

    if (_aiCallInProgress) {
      return AiResponse(text: "Hmm... ek second wait karna buddy...", emotion: EmotionTag.neutral, source: 'local');
    }

    _aiCallInProgress = true;
    final stopwatch = Stopwatch()..start();

    try {
      if (ApiConfig.isAzureOpenAiEnabled) {
        final aiText = await _callAzureOpenAi(userInput, language).timeout(_apiTimeout);
        if (aiText != null && aiText.isNotEmpty) {
          final safe = _limitSentences(aiText, 4);
          final emotion = EmotionTagger.tag(safe);
          _memory.addTurn(userInput, safe);

          stopwatch.stop();
          AppLogger.info(LogCategory.lifecycle, '[CHILD_AI] ✅ USING: Azure OpenAI (gpt-4o) — ${stopwatch.elapsedMilliseconds}ms');
          return AiResponse(text: safe, emotion: emotion, source: 'azure_openai');
        }
      }

      if (_isGeminiEnabled) {
        final aiText = await _callGemini(userInput, normalized, language).timeout(_apiTimeout);
        if (aiText != null && aiText.isNotEmpty) {
          final safe = _limitSentences(aiText, 4);
          final emotion = EmotionTagger.tag(safe);
          _memory.addTurn(userInput, safe);

          stopwatch.stop();
          AppLogger.info(LogCategory.lifecycle, '[CHILD_AI] ✅ USING: Gemini — ${stopwatch.elapsedMilliseconds}ms');
          return AiResponse(text: safe, emotion: emotion, source: 'gemini');
        }
      }
    } on TimeoutException {
      stopwatch.stop();
    } catch (e) {
      stopwatch.stop();
    } finally {
      _aiCallInProgress = false;
    }

    return AiResponse(text: "Oops, net thoda slow hai lagta hai. Kya tum wapas bol sakte ho?", emotion: EmotionTag.neutral, source: 'local');
  }

  // Use identical api call architecture as AiBrainService for Azure
  Future<String?> _callAzureOpenAi(String rawInput, DetectedLanguage language) async {
    final history = _memory.getFormattedHistory();
    final userMessage = StringBuffer();
    if (history.isNotEmpty) userMessage.write('[HISTORY]\n$history\n');
    userMessage.write(_sanitizeInput(rawInput));

    final isGitHubToken = ApiConfig.azureOpenAiKey.startsWith('ghp_') || ApiConfig.azureOpenAiKey.startsWith('github_pat_');

    final requestBody = jsonEncode({
      'messages': [
        {'role': 'system', 'content': _systemPrompt},
        {'role': 'user', 'content': userMessage.toString()},
      ],
      'temperature': 0.8,
      'max_tokens': 150,
      if (isGitHubToken) 'model': 'gpt-4o',
    });

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'api-key': ApiConfig.azureOpenAiKey,
    };
    if (isGitHubToken) {
      headers['Authorization'] = 'Bearer ${ApiConfig.azureOpenAiKey}';
    }

    final response = await http.post(
      Uri.parse(ApiConfig.azureOpenAiEndpoint),
      headers: headers,
      body: requestBody,
    );

    if (response.statusCode != 200) return null;
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return (json['choices']?[0]?['message']?['content'] as String?)?.trim();
  }

  // Use identical architecture for Gemini fallback
  Future<String?> _callGemini(String rawInput, String normalizedInput, DetectedLanguage language) async {
    final history = _memory.getFormattedHistory();
    final userMessage = StringBuffer();
    if (history.isNotEmpty) userMessage.writeln('[HISTORY]\n$history');
    userMessage.writeln(_sanitizeInput(rawInput));

    final requestBody = jsonEncode({
      'systemInstruction': { 'parts': [{'text': _systemPrompt}] },
      'contents': [{'role': 'user', 'parts': [{'text': userMessage.toString()}]}],
      'generationConfig': {'temperature': 0.8, 'maxOutputTokens': 150},
    });

    final response = await http.post(
      Uri.parse(ApiConfig.geminiEndpoint),
      headers: {'Content-Type': 'application/json'},
      body: requestBody,
    );

    if (response.statusCode != 200) return null;
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return (json['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?)?.trim();
  }

  String _sanitizeInput(String input) {
    if (input.length > 300) return input.substring(0, 300).trim();
    return input.trim();
  }

  String _limitSentences(String text, int maxSentences) {
    final sentences = text.split(RegExp(r'(?<=[.!?।])\s+'));
    if (sentences.length <= maxSentences) return text;
    return sentences.take(maxSentences).join(' ');
  }

  void clearMemory() => _memory.clear();
}
