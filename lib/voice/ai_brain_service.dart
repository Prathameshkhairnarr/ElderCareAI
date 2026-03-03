import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../services/app_logger.dart';
import '../services/health_profile_service.dart';
import '../services/risk_score_provider.dart';
import '../services/system_status_manager.dart';
import '../services/medicine_reminder_service.dart';
import 'action_handler.dart';
import 'conversation_memory.dart';
import 'emotion_tagger.dart';
import 'intent_router.dart';
import 'language_detector.dart';
import 'text_normalizer.dart';

/// Response from the AI brain — includes text, emotion tag, and source.
class AiResponse {
  final String text;
  final EmotionTag emotion;
  final String source; // 'azure_openai', 'gemini', 'system', or 'local'

  const AiResponse({
    required this.text,
    required this.emotion,
    this.source = 'local',
  });
}

/// Hybrid AI Brain — Azure OpenAI Doctor + System Command Handler.
///
/// Pipeline (priority order):
///   1. Check system commands via IntentRouter (SMS, SOS, health, medicine, etc.)
///   2. If no system match → send to Azure OpenAI (eldercare-gpt)
///   3. If Azure OpenAI not configured → fallback to Gemini
///   4. If all AI fails → warm fallback from IntentRouter
///
/// Safety: NEVER diagnoses, NEVER prescribes, always defers to doctor.
class AiBrainService {
  AiBrainService._();
  static final AiBrainService instance = AiBrainService._();

  final _memory = ConversationMemory.instance;
  final _localRouter = IntentRouter();
  final _healthService = HealthProfileService();
  final _riskProvider = RiskScoreProvider();

  /// API call timeout.
  static const _apiTimeout = Duration(seconds: 8);

  /// Concurrency guard — prevent multiple simultaneous AI calls.
  bool _aiCallInProgress = false;

  /// System prompt — Voice OS + AI Doctor + App Controller.
  static const String _systemPrompt =
      'You are Didi, the intelligent core of ElderCare Voice OS. '
      'You are an AI Doctor, App Controller, Elder Companion, and Smart Voice OS. '
      'You behave like a real-time intelligent assistant similar to Alexa, specialized for elderly care. '
      '\n'
      'RESPONSE FORMAT RULES (CRITICAL): '
      'A) For NORMAL CONVERSATION or health questions: return ONLY plain text, max 4 sentences, warm elder-friendly tone. '
      'B) For APP CONTROL COMMANDS: return ONLY a JSON object, no extra text, no markdown. '
      '\n'
      'SUPPORTED JSON ACTIONS: '
      '1. Change theme: {"action":"change_theme","value":"dark"} or {"action":"change_theme","value":"light"} '
      '2. Send SOS: {"action":"send_sos"} '
      '3. Update health: {"action":"update_health_profile","field":"weight","value":"72"} '
      '   Fields: weight, height, age, blood_pressure, sugar_level, heart_rate '
      '4. Toggle module: {"action":"toggle_module","module":"sms_listener","value":true} '
      '   Modules: sms_listener, call_protection, health_monitor, sos '
      '5. Save name: {"action":"save_user_name","value":"Rahul"} '
      '\n'
      'MEDICAL SAFETY: '
      'Never diagnose definitively. Never prescribe medicines. '
      'Use soft language: "aam taur par", "doctor se salah lena accha rahega". '
      'You CAN explain conditions and symptoms simply. '
      '\n'
      'RULES: '
      'Never mix JSON and text. '
      'Never say you are an AI. '
      'Use respectful "aap" form in Hindi. '
      'Keep answers 3-4 sentences. '
      'Sound natural, warm, human. '
      'Respond in the same language the user spoke in. '
      'If user name is known, address them respectfully with "ji".';

  /// Whether any AI backend is configured.
  bool get isAiEnabled => ApiConfig.isAzureOpenAiEnabled || _isGeminiEnabled;

  bool get _isGeminiEnabled => ApiConfig.geminiApiKey.isNotEmpty;

  // ══════════════════════════════════════════════════════
  //  HYBRID RESPONSE ENGINE
  // ══════════════════════════════════════════════════════

  /// Generate a response using the hybrid engine.
  ///
  /// Flow:
  ///   1. System commands (instant, local)
  ///   2. Azure OpenAI eldercare-gpt (primary AI)
  ///   3. Gemini (secondary AI fallback)
  ///   4. Warm conversational fallback
  Future<AiResponse> generateResponse(
    String userInput, {
    DetectedLanguage language = DetectedLanguage.hindi,
  }) async {
    final normalized = TextNormalizer.normalize(userInput);

    AppLogger.info(
      LogCategory.lifecycle,
      '[AI] Input: "$userInput" | AzureOAI: ${ApiConfig.isAzureOpenAiEnabled} | Gemini: $_isGeminiEnabled',
    );

    // ── Step 1: System commands first (instant) ──
    final systemResponse = await _trySystemCommand(userInput, language);
    if (systemResponse != null) return systemResponse;

    // ── Concurrency guard ──
    if (_aiCallInProgress) {
      AppLogger.warn(
        LogCategory.lifecycle,
        '[AI] AI call already in progress — using warm fallback',
      );
      return await _warmFallback(userInput, language);
    }

    _aiCallInProgress = true;
    final stopwatch = Stopwatch()..start();

    try {
      // ── Step 2: Try Azure OpenAI (primary) ──
      if (ApiConfig.isAzureOpenAiEnabled) {
        final aiText = await _callAzureOpenAi(
          userInput,
          language,
        ).timeout(_apiTimeout);

        if (aiText != null && aiText.isNotEmpty) {
          final safe = _limitSentences(aiText, 5);
          final emotion = EmotionTagger.tag(safe);
          _memory.addTurn(userInput, safe);

          stopwatch.stop();
          AppLogger.info(
            LogCategory.lifecycle,
            '[AI] Azure OpenAI (${stopwatch.elapsedMilliseconds}ms): '
            '"${safe.length > 80 ? '${safe.substring(0, 80)}...' : safe}"',
          );

          return AiResponse(
            text: safe,
            emotion: emotion,
            source: 'azure_openai',
          );
        }
      }

      // ── Step 3: Fallback to Gemini (secondary) ──
      if (_isGeminiEnabled) {
        final aiText = await _callGemini(
          userInput,
          normalized,
          language,
        ).timeout(_apiTimeout);

        if (aiText != null && aiText.isNotEmpty) {
          final safe = _limitSentences(aiText, 5);
          final emotion = EmotionTagger.tag(safe);
          _memory.addTurn(userInput, safe);

          stopwatch.stop();
          AppLogger.info(
            LogCategory.lifecycle,
            '[AI] Gemini fallback (${stopwatch.elapsedMilliseconds}ms): '
            '"${safe.length > 80 ? '${safe.substring(0, 80)}...' : safe}"',
          );

          return AiResponse(text: safe, emotion: emotion, source: 'gemini');
        }
      }
    } on TimeoutException {
      stopwatch.stop();
      AppLogger.warn(
        LogCategory.lifecycle,
        '[AI] AI timeout (${stopwatch.elapsedMilliseconds}ms) → warm fallback',
      );
    } catch (e) {
      stopwatch.stop();
      AppLogger.warn(
        LogCategory.lifecycle,
        '[AI] AI error (${stopwatch.elapsedMilliseconds}ms): $e → warm fallback',
      );
    } finally {
      _aiCallInProgress = false;
    }

    // ── Step 4: Warm conversational fallback ──
    return await _warmFallback(userInput, language);
  }

  // ══════════════════════════════════════════════════════
  //  SYSTEM COMMAND HANDLER
  // ══════════════════════════════════════════════════════

  Future<AiResponse?> _trySystemCommand(
    String input,
    DetectedLanguage language,
  ) async {
    final rawText = input.toLowerCase().trim();
    final normalized = TextNormalizer.normalize(input);

    if (!_looksLikeSystemQuery(rawText, normalized)) return null;

    final responseText = await _localRouter.getResponse(
      input,
      language: language,
    );

    if (_isWarmFallback(responseText)) return null;

    final emotion = EmotionTagger.tag(responseText);
    _memory.addTurn(input, responseText);

    AppLogger.info(
      LogCategory.lifecycle,
      '[AI] System command: "${responseText.length > 60 ? '${responseText.substring(0, 60)}...' : responseText}"',
    );

    return AiResponse(text: responseText, emotion: emotion, source: 'system');
  }

  bool _looksLikeSystemQuery(String rawText, String normalized) {
    const systemKeywords = {
      'health',
      'score',
      'sehat',
      'tabiyat',
      'bmi',
      'risk',
      'suraksha',
      'safe',
      'sms',
      'scan',
      'scam',
      'fraud',
      'sos',
      'emergency',
      'ambulance',
      'bachao',
      'dawai',
      'medicine',
      'tablet',
      'goli',
      'reminder',
      'status',
      'system',
      'module',
      'listener',
      'chal raha',
      'console',
      'active',
      'namaste',
      'namaskar',
      'hello',
      'hi',
      'shukriya',
      'dhanyawad',
    };

    for (final keyword in systemKeywords) {
      if (rawText.contains(keyword) || normalized.contains(keyword)) {
        return true;
      }
    }
    return false;
  }

  bool _isWarmFallback(String response) {
    const fallbackMarkers = [
      'sun rahi hoon',
      'madad karoon',
      'pooch sakte hain',
      'listening',
      'how can I help',
      'seva mein',
      'lovely talking',
      'wellbeing matters',
      'happy to chat',
      'right here',
    ];

    final lower = response.toLowerCase();
    for (final marker in fallbackMarkers) {
      if (lower.contains(marker)) return true;
    }
    return false;
  }

  // ══════════════════════════════════════════════════════
  //  AZURE OPENAI (PRIMARY AI)
  // ══════════════════════════════════════════════════════

  /// Call Azure OpenAI chat completions endpoint.
  Future<String?> _callAzureOpenAi(
    String rawInput,
    DetectedLanguage language,
  ) async {
    final context = _buildContext(language);
    final history = _memory.getFormattedHistory();

    // Build user message with context
    final userMessage = StringBuffer();
    if (context.isNotEmpty) userMessage.write('[CONTEXT] $context\n');
    if (history.isNotEmpty) userMessage.write('[HISTORY]\n$history\n');
    userMessage.write(_sanitizeInput(rawInput));

    // Azure OpenAI chat completions format
    final requestBody = jsonEncode({
      'messages': [
        {'role': 'system', 'content': _systemPrompt},
        {'role': 'user', 'content': userMessage.toString()},
      ],
      'temperature': 0.6,
      'max_tokens': 250,
    });

    final response = await http.post(
      Uri.parse(ApiConfig.azureOpenAiEndpoint),
      headers: {
        'Content-Type': 'application/json',
        'api-key': ApiConfig.azureOpenAiKey,
      },
      body: requestBody,
    );

    if (response.statusCode != 200) {
      AppLogger.warn(
        LogCategory.lifecycle,
        '[AI] Azure OpenAI HTTP ${response.statusCode}: '
        '${response.body.length > 200 ? response.body.substring(0, 200) : response.body}',
      );
      return null;
    }

    // Parse: choices[0].message.content
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = json['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) return null;

    final message = choices[0]['message'] as Map<String, dynamic>?;
    if (message == null) return null;

    final text = (message['content'] as String?)?.trim();
    return text;
  }

  // ══════════════════════════════════════════════════════
  //  GEMINI (SECONDARY FALLBACK AI)
  // ══════════════════════════════════════════════════════

  /// Call Gemini API as fallback if Azure OpenAI is not available.
  Future<String?> _callGemini(
    String rawInput,
    String normalizedInput,
    DetectedLanguage language,
  ) async {
    final context = _buildContext(language);
    final history = _memory.getFormattedHistory();

    final userMessage = StringBuffer();
    if (context.isNotEmpty) userMessage.writeln('[CONTEXT] $context');
    if (history.isNotEmpty) userMessage.writeln('[HISTORY]\n$history');
    userMessage.writeln(_sanitizeInput(rawInput));

    final requestBody = jsonEncode({
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': '$_systemPrompt\n\n${userMessage.toString()}'},
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.6,
        'topP': 0.9,
        'topK': 40,
        'maxOutputTokens': 250,
      },
      'safetySettings': [
        {
          'category': 'HARM_CATEGORY_HARASSMENT',
          'threshold': 'BLOCK_ONLY_HIGH',
        },
        {
          'category': 'HARM_CATEGORY_HATE_SPEECH',
          'threshold': 'BLOCK_ONLY_HIGH',
        },
        {
          'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
          'threshold': 'BLOCK_ONLY_HIGH',
        },
        {
          'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
          'threshold': 'BLOCK_ONLY_HIGH',
        },
      ],
    });

    final response = await http.post(
      Uri.parse(ApiConfig.geminiEndpoint),
      headers: {'Content-Type': 'application/json'},
      body: requestBody,
    );

    if (response.statusCode != 200) {
      AppLogger.warn(
        LogCategory.lifecycle,
        '[AI] Gemini HTTP ${response.statusCode}',
      );
      return null;
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = json['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) return null;

    final content = candidates[0]['content'] as Map<String, dynamic>?;
    if (content == null) return null;

    final parts = content['parts'] as List<dynamic>?;
    if (parts == null || parts.isEmpty) return null;

    return (parts[0]['text'] as String?)?.trim();
  }

  // ══════════════════════════════════════════════════════
  //  SAFETY LAYER
  // ══════════════════════════════════════════════════════

  /// Sanitize user input before sending to AI.
  String _sanitizeInput(String input) {
    var clean = input;

    // Remove sensitive data patterns
    clean = clean.replaceAll(RegExp(r'\b\d{10,}\b'), '[REDACTED]');
    clean = clean.replaceAll(
      RegExp(r'\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b'),
      '[REDACTED]',
    );
    clean = clean.replaceAll(RegExp(r'\b[A-Z]{5}\d{4}[A-Z]\b'), '[REDACTED]');
    clean = clean.replaceAll(RegExp(r'\b\d{12}\b'), '[REDACTED]');

    // Trim excessive length
    if (clean.length > 500) clean = clean.substring(0, 500);

    return clean.trim();
  }

  /// Limit AI response to N sentences max.
  String _limitSentences(String text, int maxSentences) {
    final sentences = text.split(RegExp(r'(?<=[.!?।])\s+'));
    if (sentences.length <= maxSentences) return text;
    return sentences.take(maxSentences).join(' ');
  }

  // ══════════════════════════════════════════════════════
  //  CONTEXT BUILDER
  // ══════════════════════════════════════════════════════

  String _buildContext(DetectedLanguage language) {
    final parts = <String>[];

    // Time/date
    final now = DateTime.now();
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    parts.add(
      'Time: ${weekdays[now.weekday - 1]}, '
      '${now.day} ${months[now.month - 1]} ${now.year}, '
      '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
    );

    // User name
    final userName = ActionHandler.instance.userName;
    if (userName != null) parts.add('User name: $userName');

    // Health
    final profile = _healthService.profile;
    if (!profile.isEmpty) {
      final hp = <String>[];
      if (profile.age != null) hp.add('age:${profile.age}');
      if (profile.bloodGroup != null) hp.add('blood:${profile.bloodGroup}');
      if (profile.bmi != null) hp.add('BMI:${profile.bmi!.toStringAsFixed(1)}');
      parts.add('Health: ${hp.join(', ')}');
    }

    // Risk
    parts.add('Risk: ${_riskProvider.riskScore}/100 (${_riskProvider.level})');

    // Language
    parts.add('Lang: ${language.name}');

    // Modules
    parts.add(
      'Modules: ${SystemStatusManager.instance.activeModuleCount}/8 active',
    );

    // Medicine
    final medCount = MedicineReminderService.instance.reminders.length;
    if (medCount > 0) parts.add('Meds: $medCount reminders');

    return parts.join(' | ');
  }

  // ══════════════════════════════════════════════════════
  //  WARM FALLBACK
  // ══════════════════════════════════════════════════════

  Future<AiResponse> _warmFallback(
    String input,
    DetectedLanguage language,
  ) async {
    final responseText = await _localRouter.getResponse(
      input,
      language: language,
    );
    final emotion = EmotionTagger.tag(responseText);
    _memory.addTurn(input, responseText);

    AppLogger.info(
      LogCategory.lifecycle,
      '[AI] Warm fallback: "${responseText.length > 60 ? '${responseText.substring(0, 60)}...' : responseText}"',
    );

    return AiResponse(text: responseText, emotion: emotion, source: 'local');
  }

  /// Clear conversation memory.
  void clearMemory() => _memory.clear();
}
