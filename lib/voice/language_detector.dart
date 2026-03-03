/// Lightweight Hindi/English language detection from user input.
///
/// Detection strategies:
///   1. Devanagari Unicode range check (U+0900–U+097F)
///   2. Common Hindi word/romanized keyword matching
///
/// Zero external dependencies — pure Dart.
enum DetectedLanguage { hindi, english, mixed }

class LanguageDetector {
  LanguageDetector._();

  /// Common romanized Hindi words that indicate Hindi input.
  static const _hindiKeywords = {
    'kya', 'hai', 'hain', 'mera', 'meri', 'mere',
    'batao', 'bataiye', 'bataye', 'karo', 'kariye',
    'kaise', 'kaisa', 'kaisi', 'kahan', 'kab',
    'mujhe', 'hume', 'humein', 'humko',
    'aap', 'aapka', 'aapki', 'aapke',
    'theek', 'thik', 'achha', 'accha',
    'nahi', 'nahin', 'mat', 'haan', 'ji',
    'chahiye', 'chahie', 'dijiye', 'dijie',
    'namaste', 'namaskar', 'dhanyawad', 'shukriya',
    'dawai', 'dawa', 'sehat', 'tabiyat', 'bimaari',
    'suraksha', 'madad', 'bachao', 'khatara',
    'paisa', 'paise', 'rupaye', 'rupay',
    'khana', 'peena', 'sona', 'chalna',
    'doctor', 'hospital', 'ambulance', // shared but common in Hindi context
    'kitna', 'kitni', 'kitne', 'koi', 'kuch',
    'abhi', 'aaj', 'kal', 'parso',
    'dekho', 'suno', 'bolo', 'jao', 'aao',
    'ghar', 'phone', 'call', 'number',
    'check', 'kijiye', 'karein',
  };

  /// Devanagari Unicode range: U+0900 to U+097F
  static final _devanagariRegex = RegExp(r'[\u0900-\u097F]');

  /// Detect the language of the given text.
  ///
  /// Rules:
  ///   - If Devanagari characters present → Hindi
  ///   - If ≥30% of words are Hindi keywords → Hindi
  ///   - If some Hindi keywords but <30% → Mixed (defaults to Hindi for ElderCare)
  ///   - Otherwise → English
  static DetectedLanguage detect(String text) {
    if (text.trim().isEmpty) return DetectedLanguage.english;

    // Check for Devanagari script first (most reliable)
    if (_devanagariRegex.hasMatch(text)) {
      return DetectedLanguage.hindi;
    }

    // Romanized Hindi detection via keyword matching
    final words = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    if (words.isEmpty) return DetectedLanguage.english;

    final hindiWordCount = words
        .where((w) => _hindiKeywords.contains(w))
        .length;
    final ratio = hindiWordCount / words.length;

    if (ratio >= 0.3) return DetectedLanguage.hindi;
    if (hindiWordCount > 0) return DetectedLanguage.mixed;

    return DetectedLanguage.english;
  }

  /// Get the TTS locale string for a detected language.
  static String ttsLocale(DetectedLanguage lang) {
    switch (lang) {
      case DetectedLanguage.hindi:
      case DetectedLanguage.mixed: // ElderCare default: prefer Hindi
        return 'hi-IN';
      case DetectedLanguage.english:
        return 'en-IN';
    }
  }

  /// Get the STT locale string for a detected language.
  static String sttLocale(DetectedLanguage lang) {
    switch (lang) {
      case DetectedLanguage.hindi:
      case DetectedLanguage.mixed:
        return 'hi_IN';
      case DetectedLanguage.english:
        return 'en_IN';
    }
  }

  /// Get the Azure SSML xml:lang for a detected language.
  static String azureSsmlLang(DetectedLanguage lang) {
    switch (lang) {
      case DetectedLanguage.hindi:
      case DetectedLanguage.mixed:
        return 'hi-IN';
      case DetectedLanguage.english:
        return 'en-IN';
    }
  }

  /// Get the best Azure Neural voice name for a detected language.
  static String azureVoiceName(DetectedLanguage lang) {
    switch (lang) {
      case DetectedLanguage.hindi:
      case DetectedLanguage.mixed:
        return 'hi-IN-SwaraNeural';
      case DetectedLanguage.english:
        return 'en-IN-NeerjaNeural';
    }
  }
}
