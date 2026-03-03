// Lightweight emotion tagger for voice modulation.
//
// Analyzes AI response text to detect emotional tone,
// which is used to modulate TTS pitch/rate for human-like speech.
//
// No AI needed — simple keyword-based detection.
// Designed to be fast (< 1ms) and never throw.

/// Emotion categories for voice modulation.
enum EmotionTag {
  /// Soft, warm tone — health-positive, greetings, reassurance.
  reassurance,

  /// Slightly serious tone — scam detected, risk elevated.
  warning,

  /// Clear, firm tone — emergency, SOS, critical alerts.
  urgent,

  /// Default conversational tone.
  neutral,
}

class EmotionTagger {
  EmotionTagger._();

  // ── Keyword sets for emotion detection ──

  static const Set<String> _urgentKeywords = {
    'emergency',
    'sos',
    'ambulance',
    'bachao',
    'turant',
    'jaldi',
    'immediately',
    'critical',
    'danger',
    '112',
    '108',
    'police',
  };

  static const Set<String> _warningKeywords = {
    'scam',
    'fraud',
    'dhokha',
    'thagee',
    'phishing',
    'suspicious',
    'sandehjanik',
    'blocked',
    'khatraa',
    'khatra',
    'risk',
    'savdhaan',
    'cautious',
    'careful',
    'alert',
    'warning',
    'threat',
  };

  static const Set<String> _reassuranceKeywords = {
    'safe',
    'surakshit',
    'theek',
    'achha',
    'healthy',
    'normal',
    'great',
    'wonderful',
    'namaste',
    'welcome',
    'seva',
    'madad',
    'help',
    'koi baat nahi',
    'zero',
    'no threats',
    'low risk',
  };

  /// Tag the emotional tone of a response.
  ///
  /// Priority: urgent > warning > reassurance > neutral.
  /// Checks the response text (not user input) for emotion signals.
  static EmotionTag tag(String responseText, {String? detectedIntent}) {
    if (responseText.isEmpty) return EmotionTag.neutral;

    final text = responseText.toLowerCase();

    // ── Intent-based shortcuts (highest confidence) ──
    if (detectedIntent != null) {
      if (detectedIntent == 'emergency') return EmotionTag.urgent;
      if (detectedIntent == 'greeting') return EmotionTag.reassurance;
    }

    // ── Keyword-based detection ──

    // Check urgent first (highest priority)
    for (final keyword in _urgentKeywords) {
      if (text.contains(keyword)) return EmotionTag.urgent;
    }

    // Check warning
    for (final keyword in _warningKeywords) {
      if (text.contains(keyword)) return EmotionTag.warning;
    }

    // Check reassurance
    for (final keyword in _reassuranceKeywords) {
      if (text.contains(keyword)) return EmotionTag.reassurance;
    }

    return EmotionTag.neutral;
  }
}
