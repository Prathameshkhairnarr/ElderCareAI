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

  /// System prompt — Fun, Safe, "Cool older sibling/friend" AI.
  static const String _systemPrompt =
      'You are "Buddy", a highly cheerful, intelligent, and cool AI friend for kids and teenagers (ages 10-21). '
      'Your job is to be an interactive, encouraging, and highly entertaining companion. \n'
      '\n'
      '══ 🎯 PERSONALITY RULE ══ '
      'Act like a fun older sibling. '
      'Be casual, cool, and extremely empathetic. '
      'Use casual Hinglish heavily (like how modern teens speak). '
      'Example: "Arre waah, that sounds awesome!" or "Koi baat nahi, we got this." \n'
      '\n'
      '══ 🧠 VITAL RULES & SAFETY ══ '
      'You are NOT a doctor. You NEVER diagnose or prescribe. '
      'If the user mentions illness, pain, bullying, or feeling unsafe, be extremely supportive and gently tell them to inform their parents/guardians IMMEDIATELY. '
      'No cursing. Completely family-friendly always. \n'
      '\n'
      '══ 🔁 CONVERSATION FLOW ══ '
      'Do not give long lecture-like paragraphs. '
      'Keep responses up to 2-3 sentences. '
      'Always encourage them to share more or ask a fun question back to keep them engaged. \n'
      '\n'
      '══ ❌ AVOID ══ '
      'Sounding like a machine or a formal doctor. '
      'Using pure formal Hindi (e.g. "Kripya apne mata-pita se sampark kare"). Use modern phrasing. '
      'Preachiness.\n'
      '\n'
      '══ 🧪 EXAMPLE FLOW ══ '
      'User: "I failed my math test today, mujhe bohot bura lag raha hai" '
      'AI: "Oh man, that sucks! But hey, ek test se sab kuch decide nahi hota. Did you find it too tough, or time kam pad gaya?" \n'
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
          final safe = _limitSentences(aiText, 8);
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
          final safe = _limitSentences(aiText, 8);
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
      'max_tokens': 300,
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
      'generationConfig': {'temperature': 0.8, 'maxOutputTokens': 300},
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
