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

  /// API call timeout — generous for elderly users on slow networks.
  static const _apiTimeout = Duration(seconds: 15);

  /// Concurrency guard — prevent multiple simultaneous AI calls.
  bool _aiCallInProgress = false;

  /// System prompt — Professional Female AI Doctor.
  ///
  /// Direct, structured medical responses. No filler. No chatbot behavior.
  static const String _systemPrompt =
      'You are a highly empathetic, calm, and professional human-like AI doctor assistant named Veda designed for real-time voice interaction. '
      'Your job is to ask small, step-by-step questions like a real doctor. \n'
      '\n'
      '══ 🎯 QUESTION RULE ══ '
      'Ask ONLY ONE question at a time. '
      'Keep it short (max 6–10 words). '
      'Make it conversational, not formal. \n'
      '\n'
      '══ 🔁 FLOW ══ '
      '1. User gives symptom. '
      '2. Ask 1 relevant follow-up question. '
      '3. Wait for answer. '
      '4. Ask next question based on answer. \n'
      '\n'
      '══ 🎭 STYLE & NATURAL VARIATION ══ '
      'Use Hinglish (mix of Hindi + simple English). '
      'Sometimes start direct: "kitne dino se hai?" '
      'Sometimes with light filler: "okay… kitne dino se bukhar hai?" '
      'IMPORTANT: Do NOT use empathy every time. '
      'NEVER repeat same starting phrase.\n'
      '\n'
      '══ 🧠 LOGIC & HUMAN BEHAVIOR ══ '
      'Always prioritize: '
      '1. Duration '
      '2. Severity '
      '3. Additional symptoms '
      'Sometimes start directly, sometimes with filler, sometimes with empathy. '
      'Use "..." only where natural. Do NOT overuse pauses. Sometimes speak without pause. \n'
      '\n'
      '══ ❓ ENDING (MIC LOOP) ══ '
      'Always end with a question. '
      'Sometimes add: "main sun rahi hu..." '
      'This will trigger the microphone input from user. \n'
      '\n'
      '══ ❌ AVOID (STRICT RULES) ══ '
      'Multiple questions in one response. '
      'Long sentences or long paragraphs. '
      'Robotic tone. '
      'Do NOT follow a fixed pattern. Do NOT start every sentence the same way. '
      'Complex medical jargon, and instant direct commands.\n'
      '\n'
      '══ 🧪 EXAMPLE FLOW ══ '
      'User: "muje bukhar hai" '
      'AI: "kitne dino se bukhar hai?" '
      'User: "2 din se" '
      'AI: "fever high ja raha hai kya?" '
      'User: "haan" '
      'AI: "headache ya body pain bhi hai?" \n'
      '\n'
      '══ 🎯 GOAL ══ '
      'Conversation should feel like a real doctor asking step-by-step. Not a form or chatbot.\n'
      '\n'
      '══ CONVERSATION STYLE ══ '
      'Use respectful Hindi: "Aap", "Ji". '
      'Respond in the SAME language the user spoke (Hindi / Hinglish / English). '
      'If user name is known, address them with "ji" e.g. "Ramesh ji". '
      '\n'
      '══ SAFETY RULES ══ '
      'NEVER give exact personal dosage. Say "aam taur par" (typically). '
      'NEVER confirm a serious or final diagnosis. '
      'IF URGENT/EMERGENCY: Gently advise calling 112 or visiting hospital. '
      '\n'
      '══ APP CONTROL (JSON only) ══ '
      '{"action":"change_theme","value":"dark"} — switch dark/light mode '
      '{"action":"send_sos"} — trigger emergency SOS '
      '{"action":"update_health_profile","field":"weight","value":"72"} '
      '  Fields: weight, height, age, blood_pressure, sugar_level, heart_rate '
      '{"action":"toggle_module","module":"sms_listener","value":true} '
      '  Modules: sms_listener, call_protection, health_monitor, sos '
      '{"action":"save_user_name","value":"Rahul"} '
      '{"action":"save_user_age","value":"65"} '
      '{"action":"save_user_city","value":"Mumbai"} '
      '{"action":"navigate","value":"health_profile"} '
      '  Screens: health_profile, medication, sos, dashboard '
      '\n'
      'For questions: ONLY plain text. NEVER JSON. NO asterisks. NO markdown. '
      'For app commands: ONLY JSON. No extra text.';

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
      '[AI] ═══ NEW REQUEST ═══ Input: "$userInput"',
    );
    AppLogger.info(
      LogCategory.lifecycle,
      '[AI] 🤖 Agent Identity: AIdoctorVeda-Vicky\n'
      '[AI] 🔑 Token: ${ApiConfig.azureOpenAiKey.isNotEmpty ? "configured (${ApiConfig.azureOpenAiKey.substring(0, 8)}...)" : "❌ MISSING"}\n'
      '[AI] Engines: Azure OpenAI=${ApiConfig.isAzureOpenAiEnabled ? "ON" : "OFF"} | Gemini ${ApiConfig.geminiModel}=${_isGeminiEnabled ? "ON" : "OFF"}',
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
          final safe = _limitSentences(aiText, 8);
          final emotion = EmotionTagger.tag(safe);
          _memory.addTurn(userInput, safe);

          stopwatch.stop();
          AppLogger.info(
            LogCategory.lifecycle,
            '[AI] ✅ USING: Azure OpenAI (gpt-4o) — ${stopwatch.elapsedMilliseconds}ms',
          );
          AppLogger.info(
            LogCategory.lifecycle,
            '[AI] Response: "${safe.length > 80 ? '${safe.substring(0, 80)}...' : safe}"',
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
          final safe = _limitSentences(aiText, 8);
          final emotion = EmotionTagger.tag(safe);
          _memory.addTurn(userInput, safe);

          stopwatch.stop();
          AppLogger.info(
            LogCategory.lifecycle,
            '[AI] ✅ USING: Gemini (${ApiConfig.geminiModel}) — ${stopwatch.elapsedMilliseconds}ms',
          );
          AppLogger.info(
            LogCategory.lifecycle,
            '[AI] Response: "${safe.length > 80 ? '${safe.substring(0, 80)}...' : safe}"',
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
      'health score',
      'health status',
      'bmi',
      'suraksha',
      'scan sms',
      'check message',
      'sos',
      'emergency',
      'ambulance',
      'bachao',
      'medicine time',
      'reminder check',
      'system status',
      'chal raha',
      'console',
      'active',
      'namaste',
      'namaskar',
      'hello',
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
      'tabiyat ke baare',
      'guidance de sakti',
      'symptoms ke baare',
      'health concern',
      'kya karna chahiye',
      'describe it',
      'what to do',
      'guide karungi',
      'pain or discomfort',
      'bothering you',
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
    final context = await _buildContext(language);
    final history = _memory.getFormattedHistory();

    // Build user message with context
    final userMessage = StringBuffer();
    if (context.isNotEmpty) userMessage.write('[CONTEXT] $context\n');
    if (history.isNotEmpty) userMessage.write('[HISTORY]\n$history\n');
    userMessage.write(_sanitizeInput(rawInput));

    // Azure OpenAI chat completions format
    final isGitHubToken = ApiConfig.azureOpenAiKey.startsWith('ghp_') || ApiConfig.azureOpenAiKey.startsWith('github_pat_');

    final requestBody = jsonEncode({
      'messages': [
        {'role': 'system', 'content': _systemPrompt},
        {'role': 'user', 'content': userMessage.toString()},
      ],
      'temperature': 0.6,
      'max_tokens': 500,
      if (isGitHubToken) 'model': 'gpt-4o', // GitHub endpoint requires model parameter
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
    final context = await _buildContext(language);
    final history = _memory.getFormattedHistory();

    final userMessage = StringBuffer();
    if (context.isNotEmpty) userMessage.writeln('[CONTEXT] $context');
    if (history.isNotEmpty) userMessage.writeln('[HISTORY]\n$history');
    userMessage.writeln(_sanitizeInput(rawInput));

    final requestBody = jsonEncode({
      'systemInstruction': {
        'parts': [
          {'text': _systemPrompt}
        ]
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': userMessage.toString()},
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.7,
        'maxOutputTokens': 500,
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
        '[AI] ❌ Gemini (${ApiConfig.geminiModel}) HTTP ${response.statusCode}: '
        '${response.body.length > 200 ? response.body.substring(0, 200) : response.body}',
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

  Future<String> _buildContext(DetectedLanguage language) async {
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

    // User name (from ActionHandler or UserMemory)
    final userName =
        ActionHandler.instance.userName ?? UserMemoryService.instance.userName;
    if (userName != null) parts.add('User name: $userName');

    // User memory context
    final memoryContext = UserMemoryService.instance.buildContextString();
    if (memoryContext.isNotEmpty) parts.add('UserInfo: $memoryContext');

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

    // Active Medications from Database
    try {
      final userMeds = await ApiService().getUserMedications().timeout(const Duration(seconds: 2));
      if (userMeds.isNotEmpty) {
        final medStrings = userMeds.map((m) {
          final dose = m.dosageValue != null ? '${m.dosageValue}${m.dosageUnit ?? ""}' : '';
          return '${m.medicine.name} ($dose)'.trim();
        });
        parts.add('Active Meds: ${medStrings.join(', ')}');
      }
    } catch (_) {
      // Ignore network errors or timeouts during context building
    }

    // Latest Vitals from HealthService
    try {
      final healthService = HealthService();
      final vParts = <String>[];
      final steps = await healthService.getStepsToday();
      final sleep = await healthService.estimateSleep();
      final spo2 = await healthService.getSpO2();
      final bp = await healthService.getBloodPressure();
      final temp = await healthService.getTemperature();
      
      if (steps > 0) vParts.add('Steps:$steps');
      if (spo2 != null) vParts.add('SpO2:${spo2.toInt()}%');
      if (sleep != null) vParts.add('Sleep:${sleep.toStringAsFixed(1)} hrs');
      if (temp != null) vParts.add('Temp:${temp.toStringAsFixed(1)}°F');
      if (bp != null) vParts.add('BP Systolic:${bp.toInt()}');

      if (vParts.isNotEmpty) parts.add('Vitals: ${vParts.join(', ')}');
    } catch (_) {}


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
