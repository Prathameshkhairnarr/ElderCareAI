import '../services/health_profile_service.dart';
import '../services/risk_score_provider.dart';
import '../services/system_status_manager.dart';
import '../services/medicine_reminder_service.dart';
import '../services/app_logger.dart';
import 'language_detector.dart';
import 'text_normalizer.dart';

/// Result of matching user input against intent keyword buckets.
class _MatchResult {
  final String intent;
  final double confidence;
  final List<String> matchedKeywords;

  const _MatchResult(this.intent, this.confidence, this.matchedKeywords);

  static const none = _MatchResult('none', 0.0, []);
}

/// Intent keyword bucket definition.
class _IntentBucket {
  final String name;
  final Set<String> keywords;

  const _IntentBucket(this.name, this.keywords);
}

/// Lightweight keyword-based intent router — bilingual (Hindi/English).
/// Reads live data from existing services for dynamic responses.
///
/// Pipeline: raw input → TextNormalizer → fuzzy keyword match with
/// confidence scoring → intent response (or friendly clarification).
class IntentRouter {
  final _healthService = HealthProfileService();
  final _riskProvider = RiskScoreProvider();

  // ══════════════════════════════════════════════
  //  INTENT KEYWORD BUCKETS
  // ══════════════════════════════════════════════

  static final List<_IntentBucket> _buckets = [
    // ── Greeting ──
    _IntentBucket('greeting', {
      'hello',
      'hi',
      'hey',
      'helo',
      'hllo',
      'namaste',
      'namaskar',
      'pranam',
      'good morning',
      'good evening',
      'good afternoon',
      'good night',
      'suprabhat',
      'shubh',
      // Devanagari variants
      'हेलो',
      'हाय',
      'हैलो',
      'नमस्ते',
      'नमस्कार',
      'प्रणाम',
    }),

    // ── Health Score ──
    _IntentBucket('health_score', {
      'health',
      'score',
      'status',
      'sehat',
      'tabiyat',
      'batao',
      'check',
      'bmi',
      'weight',
      'age',
    }),

    // ── Risk Level ──
    _IntentBucket('risk_level', {
      'risk',
      'level',
      'danger',
      'safe',
      'surakshit',
      'suraksha',
      'kitna',
      'kitni',
      'kitne',
    }),

    // ── SMS Check ──
    _IntentBucket('sms_check', {
      'sms',
      'message',
      'text',
      'scam',
      'fraud',
      'scan',
      'dekho',
    }),

    // ── Help ──
    _IntentBucket('help', {
      'help',
      'features',
      'assist',
      'sahayata',
      'kar sakti',
      'kar sakte',
    }),

    // ── Emergency ──
    _IntentBucket('emergency', {
      'emergency',
      'sos',
      'help me',
      'ambulance',
      'hospital',
      'doctor',
      'bachao',
      'jaldi',
      // Devanagari
      'बचाओ',
      'मदद',
      'एम्बुलेंस',
      'अस्पताल',
      'डॉक्टर',
    }),

    // ── Thank You ──
    _IntentBucket('thanks', {
      'thank',
      'thanks',
      'shukriya',
      'dhanyawad',
      'bahut achha',
      'bohot achha',
      'theek',
      // Devanagari
      'शुक्रिया',
      'धन्यवाद',
    }),

    // ── How Are You ──
    _IntentBucket('casual', {
      'how are you',
      'kaise ho',
      'kaisi ho',
      'kya haal',
      'sab theek',
      'aap kaisi',
      'kya chal raha',
    }),

    // ── Medicine ──
    _IntentBucket('medicine', {
      'medicine',
      'dawai',
      'dawa',
      'tablet',
      'goli',
      'medicine time',
      'dawai time',
      'dawai kab',
      'reminder',
      'yaad',
      'le li',
      'kha li',
      'taken',
    }),

    // ── System Status ──
    _IntentBucket('system_status', {
      'status',
      'system',
      'module',
      'active',
      'chal raha',
      'chal rahi',
      'console',
      'listener',
      'service',
      'kya kya chal',
      'running',
      'band hai',
      'chalu hai',
      'on hai',
      'off hai',
    }),
  ];

  /// Match user speech to an intent and return a spoken response.
  /// Response language matches the [language] detected from user input.
  ///
  /// Some handlers are async (medicine, system status) so this returns Future.
  Future<String> getResponse(
    String input, {
    DetectedLanguage language = DetectedLanguage.hindi,
  }) async {
    final hi = language != DetectedLanguage.english;

    if (input.trim().isEmpty) {
      return hi
          ? "Mujhe kuch samajh nahi aaya. Kya aap dobara bol sakte hain?"
          : "I didn't catch that. Could you please say that again?";
    }

    // ── Step 1: Normalize input ──
    final rawText = input.toLowerCase().trim();
    final normalized = TextNormalizer.normalize(input);

    AppLogger.info(
      LogCategory.lifecycle,
      '[TEXT] Before normalize: "$rawText"',
    );
    AppLogger.info(
      LogCategory.lifecycle,
      '[TEXT] After normalize: "$normalized"',
    );

    // ── Step 2: Fuzzy match against all intent buckets ──
    final match = _findBestMatch(rawText, normalized);

    // ── Step 3: Log detailed diagnostics ──
    AppLogger.info(
      LogCategory.lifecycle,
      '[INTENT] raw="$rawText" | normalized="$normalized" '
      '| intent=${match.intent} | confidence=${match.confidence.toStringAsFixed(2)} '
      '| keywords=${match.matchedKeywords}',
    );

    // ── Step 4: Route to intent handler or fallback ──
    if (match.intent == 'none') {
      return _friendlyFallback(rawText, hi);
    }

    return await _handleIntent(match.intent, hi, rawText);
  }

  // ══════════════════════════════════════════════
  //  FUZZY MATCHING ENGINE
  // ══════════════════════════════════════════════

  /// Find the best matching intent bucket.
  ///
  /// Checks BOTH raw + normalized text against each bucket.
  /// Scores by number of keyword hits. Picks highest-scoring bucket
  /// with at least 1 keyword match.
  _MatchResult _findBestMatch(String rawText, String normalizedText) {
    String bestIntent = 'none';
    double bestConfidence = 0.0;
    List<String> bestKeywords = [];

    for (final bucket in _buckets) {
      final matched = <String>[];

      for (final keyword in bucket.keywords) {
        // Check both raw and normalized text for maximum tolerance
        if (rawText.contains(keyword) || normalizedText.contains(keyword)) {
          matched.add(keyword);
        }
      }

      if (matched.isEmpty) continue;

      // Confidence = matched keywords / total keywords in bucket (clamped)
      // Weighted: more matches = higher confidence
      final confidence = matched.length / bucket.keywords.length;

      if (confidence > bestConfidence ||
          (confidence == bestConfidence &&
              matched.length > bestKeywords.length)) {
        bestIntent = bucket.name;
        bestConfidence = confidence;
        bestKeywords = matched;
      }
    }

    if (bestKeywords.isEmpty) return _MatchResult.none;

    return _MatchResult(bestIntent, bestConfidence, bestKeywords);
  }

  // ══════════════════════════════════════════════
  //  INTENT HANDLERS
  // ══════════════════════════════════════════════

  Future<String> _handleIntent(String intent, bool hi, String rawText) async {
    switch (intent) {
      case 'greeting':
        return hi
            ? "Namaste, main aapki ElderCare sahayak hoon, batayiye kaise madad karoon?"
            : "Hello, I'm your ElderCare assistant, how can I help you?";

      case 'health_score':
        return _getHealthResponse(hi);

      case 'risk_level':
        return _getRiskResponse(hi);

      case 'sms_check':
        return hi
            ? "Aap apne messages SMS Scan tab mein dekh sakte hain, "
                  "main kisi bhi sandehjanik message ko check kar lungi."
            : "You can check messages in SMS Scan tab, "
                  "I'll analyze any suspicious messages for scams.";

      case 'help':
        return hi
            ? "Main health check, risk level, SMS scan, dawai reminder, "
                  "system status aur emergency mein madad kar sakti hoon."
            : "I can help with health check, risk level, SMS scan, "
                  "medicine reminders, system status and emergency.";

      case 'emergency':
        return hi
            ? "Emergency ke liye SOS button dabayein, aapke contacts ko turant alert hoga."
            : "For emergency, tap the SOS button, it will alert your contacts immediately.";

      case 'thanks':
        return hi
            ? "Koi baat nahi! Main hamesha aapki seva mein hoon."
            : "You're welcome! I'm always here to help.";

      case 'casual':
        return hi
            ? "Main bilkul theek hoon! Aapki seva mein hamesha tayyar. Batayiye kaise madad karoon?"
            : "I'm doing great, thank you! Always ready to help. What can I do for you?";

      case 'medicine':
        return await _getMedicineResponse(hi);

      case 'system_status':
        return _getSystemStatusResponse(hi, rawText);

      default:
        return _friendlyFallback('', hi);
    }
  }

  // ── Warm Conversation Fallback (elder-friendly, NOT robotic) ──

  /// Counter for rotating warm responses.
  int _fallbackIndex = 0;

  /// Warm, rotating conversation responses for when no intent matches.
  static const _hindiFallbacks = [
    "Ji, main sun rahi hoon. Aap mujhse health, dawai, ya kisi aur cheez ke baare mein pooch sakte hain.",
    "Aapke saath baat karke achha lagta hai! Batayiye, kya madad karoon?",
    "Main aapki seva mein hoon. Health check, SMS scan, ya dawai reminder, jo chahein poochiye.",
    "Bilkul, main yahan hoon. Aapko kisi bhi cheez ki zaroorat ho toh boliye.",
    "Ji haan, aapki baat sun rahi hoon. Koi bhi sawal ho, befikar hokar poochiye.",
    "Aapki chinta meri chinta hai. Batayiye kaise madad kar sakti hoon.",
  ];

  static const _englishFallbacks = [
    "I'm listening! You can ask me about health, medicine reminders, or anything else.",
    "It's lovely talking to you! How can I help you today?",
    "I'm here for you. Ask about health check, SMS scan, medicine reminders, or anything.",
    "Of course, I'm right here. Feel free to ask me anything.",
    "I'm always happy to chat. What would you like to know?",
    "Your wellbeing matters to me. Tell me how I can help.",
  ];

  String _friendlyFallback(String text, bool hi) {
    AppLogger.info(
      LogCategory.lifecycle,
      '[INTENT] Warm fallback triggered for: "$text"',
    );

    final responses = hi ? _hindiFallbacks : _englishFallbacks;
    final response = responses[_fallbackIndex % responses.length];
    _fallbackIndex++;
    return response;
  }

  // ══════════════════════════════════════════════
  //  DATA RESPONSES
  // ══════════════════════════════════════════════

  String _getHealthResponse(bool hindi) {
    final profile = _healthService.profile;
    if (profile.isEmpty) {
      return hindi
          ? "Aapne abhi tak apna health profile set nahi kiya hai. "
                "Health tab mein jaake apni umar, blood group, "
                "height aur weight add karein."
          : "You haven't set up your health profile yet. "
                "Go to the Health tab to add your details like age, blood group, "
                "height and weight.";
    }

    if (hindi) {
      final parts = <String>[];
      if (profile.age != null) parts.add('Umar ${profile.age} saal');
      if (profile.bloodGroup != null) {
        parts.add('blood group ${profile.bloodGroup}');
      }
      if (profile.bmi != null) {
        parts.add(
          'BMI ${profile.bmi!.toStringAsFixed(1)}, jo ${profile.bmiCategory} hai',
        );
      }
      parts.add('profile ${profile.completeness} percent complete hai');

      return "Aapki health ki jaankari yeh rahi: ${parts.join(', ')}. "
          "Zyada details ke liye Health tab dekhein.";
    } else {
      final parts = <String>[];
      if (profile.age != null) parts.add('Age ${profile.age}');
      if (profile.bloodGroup != null) {
        parts.add('blood group ${profile.bloodGroup}');
      }
      if (profile.bmi != null) {
        parts.add(
          'BMI ${profile.bmi!.toStringAsFixed(1)}, which is ${profile.bmiCategory}',
        );
      }
      parts.add('profile is ${profile.completeness}% complete');

      return "Here's your health summary: ${parts.join(', ')}. "
          "Visit the Health tab for more details.";
    }
  }

  String _getRiskResponse(bool hindi) {
    final score = _riskProvider.riskScore;
    final level = _riskProvider.level;

    if (score == 0) {
      return hindi
          ? "Aapka risk score zero hai. Sab kuch surakshit hai! "
                "Haal mein koi khatraa nahi mila."
          : "Your risk score is zero. Everything looks safe! "
                "No threats detected recently.";
    }

    if (hindi) {
      return "Aapka abhi ka risk score $score hai, 100 mein se. "
          "Level: $level. "
          "${score > 50 ? 'Kripya savdhaan rahein aur apne alerts check karein.' : 'Haalat zyaadatar safe hain.'}";
    } else {
      return "Your current risk score is $score out of 100. "
          "Level: $level. "
          "${score > 50 ? 'Please be cautious and check your recent alerts.' : 'Things look mostly safe.'}";
    }
  }

  // ══════════════════════════════════════════════
  //  MEDICINE RESPONSE
  // ══════════════════════════════════════════════

  Future<String> _getMedicineResponse(bool hindi) async {
    final medService = MedicineReminderService.instance;
    return await medService.getStatusReport(hindi);
  }

  // ══════════════════════════════════════════════
  //  SYSTEM STATUS RESPONSE
  // ══════════════════════════════════════════════

  String _getSystemStatusResponse(bool hindi, String query) {
    final statusMgr = SystemStatusManager.instance;

    // Check if asking about a specific module
    final specificModules = [
      'sms',
      'call',
      'sos',
      'health',
      'notification',
      'background',
      'voice',
      'azure',
    ];
    for (final module in specificModules) {
      if (query.contains(module)) {
        return statusMgr.answerModuleQuery(module, hindi);
      }
    }

    // General status report
    return statusMgr.getStatusReport(hindi);
  }
}
