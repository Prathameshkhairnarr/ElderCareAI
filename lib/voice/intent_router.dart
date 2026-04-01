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
      'health score',
      'health status',
      'mera score',
      'bmi',
      'weight batao',
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
      'scan sms',
      'check message',
      'sms fraud',
      'message scan',
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
      'medicine time',
      'dawai time',
      'dawai kab',
      'reminder check',
      'le li',
      'kha li',
      'taken medicine',
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
            ? "Namaste! Main Didi hoon, aapki AI Doctor. Agar koi tabiyat ki pareshani ho toh bataiye."
            : "Hello! I'm Didi, your AI Doctor. Tell me if you have any health concerns.";

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
            ? "Dhanyawad! Apna khayal rakhiye, aur koi bhi samasya ho toh turant batayiye."
            : "You're welcome! Take care, and don't hesitate to reach out if anything comes up.";

      case 'casual':
        return hi
            ? "Main theek hoon, shukriya! Aapki tabiyat kaisi hai? Koi takleef ho toh bataiye."
            : "I'm doing well, thank you! How are you feeling? Let me know if anything is bothering you.";

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
  /// Doctor-like warm responses — no filler, always useful.
  static const _hindiFallbacks = [
    "Aap mujhe apni tabiyat ke baare mein bataiye, main aapko sahi guidance de sakti hoon.",
    "Agar koi dard ya takleef hai toh bataiye, main aapko samjhati hoon kya karna chahiye.",
    "Aap mujhse health, dawai, ya symptoms ke baare mein pooch sakte hain.",
    "Aapko koi bhi health concern ho toh bataiye, main doctor ki tarah guide karungi.",
    "Agar bukhar, dard, ya koi bhi pareshani ho toh mujhe bataiye.",
    "Apni tabiyat ki koi bhi baat bataiye, main aapki madad karungi.",
  ];

  static const _englishFallbacks = [
    "Tell me about your symptoms, and I'll guide you on what to do.",
    "If you're experiencing any pain or discomfort, describe it and I'll help.",
    "You can ask me about any health concern, medication, or symptom.",
    "Let me know what's bothering you, and I'll give you proper guidance.",
    "Whether it's fever, pain, or any other issue — just describe it to me.",
    "Share your health concern and I'll explain what it could be and what to do.",
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
