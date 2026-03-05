import '../services/app_logger.dart';

/// Emergency detection result.
class EmergencyDetection {
  final bool isEmergency;
  final double confidence; // 0.0 - 1.0
  final String? matchedPhrase;

  const EmergencyDetection({
    required this.isEmergency,
    this.confidence = 0.0,
    this.matchedPhrase,
  });

  static const none = EmergencyDetection(isEmergency: false);
}

/// Detects health emergency phrases in Hindi and English user speech.
///
/// Emergency triggers:
///   - Distress: "mujhe chakkar", "I'm falling", "help chahiye"
///   - Pain: "bahut dard", "chest pain", "seene mein dard"
///   - Breathing: "saans nahi", "can't breathe"
///   - General: "bachao", "emergency", "ambulance bulao"
///
/// Returns an [EmergencyDetection] with confidence score.
/// The voice controller should ask for confirmation before triggering SOS.
class EmergencyDetector {
  EmergencyDetector._();

  /// High-confidence emergency phrases (immediate concern).
  static const _highPhrases = [
    'bachao',
    'help me',
    'help chahiye',
    'emergency',
    'ambulance',
    'ambulance bulao',
    'mujhe bachao',
    'mar jaunga',
    'mar jaungi',
    'behosh',
    'gir gaya',
    'gir gayi',
    'gir raha',
    'gir rahi',
    'heart attack',
    'dil ka daura',
  ];

  /// Medium-confidence phrases (need confirmation).
  static const _mediumPhrases = [
    'chakkar',
    'chakkar aa rahe',
    'chakkar aa raha',
    'bahut dard',
    'dard ho raha',
    'seene mein dard',
    'chest pain',
    'saans nahi',
    'saans lene mein',
    'breathing problem',
    'cant breathe',
    'tabiyat kharab',
    'bahut bura',
    'accha nahi lag raha',
    'mujhe help',
    'i need help',
    'sos bhejo',
    'sos send',
    'please help',
    'madad karo',
    'madad chahiye',
    'mujhe dard',
    'i am falling',
    'i fell down',
    'blood aa raha',
    'bleeding',
    'bukhar hai',
    'high fever',
  ];

  /// Check user input for emergency phrases.
  static EmergencyDetection detect(String input) {
    final text = input.toLowerCase().trim();

    // Check high-confidence phrases first
    for (final phrase in _highPhrases) {
      if (text.contains(phrase)) {
        AppLogger.info(
          LogCategory.lifecycle,
          '[EMERGENCY] HIGH confidence match: "$phrase"',
        );
        return EmergencyDetection(
          isEmergency: true,
          confidence: 0.9,
          matchedPhrase: phrase,
        );
      }
    }

    // Check medium-confidence phrases
    for (final phrase in _mediumPhrases) {
      if (text.contains(phrase)) {
        AppLogger.info(
          LogCategory.lifecycle,
          '[EMERGENCY] MEDIUM confidence match: "$phrase"',
        );
        return EmergencyDetection(
          isEmergency: true,
          confidence: 0.6,
          matchedPhrase: phrase,
        );
      }
    }

    return EmergencyDetection.none;
  }

  /// Get the confirmation prompt based on language.
  static String getConfirmationPrompt(
    EmergencyDetection detection,
    bool hindi,
  ) {
    if (hindi) {
      return 'Lagta hai aapko madad chahiye. Kya main SOS bhejoon? '
          'Haan boliye ya mic dabaaiye.';
    } else {
      return 'It sounds like you need help. Should I send an SOS? '
          'Say yes or tap the mic.';
    }
  }
}
