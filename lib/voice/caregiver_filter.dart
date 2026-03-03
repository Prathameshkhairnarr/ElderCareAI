/// Caregiver personality filter for voice assistant responses.
///
/// Ensures all spoken output sounds like a warm, caring human helper:
///   - Replaces robotic/technical phrases with warm Hindi equivalents
///   - Breaks overly long sentences into shorter, elder-friendly chunks
///   - Adds warmth cue if response feels cold
///   - Replaces technical jargon with simple words
///
/// Applied AFTER AI response generation, BEFORE TTS.
/// Pure string processing — zero dependencies.
class CaregiverFilter {
  CaregiverFilter._();

  /// Apply all caregiver filters to a response.
  static String filter(String text) {
    if (text.trim().isEmpty) return text;

    var result = text;

    // Step 1: Replace robotic phrases
    result = _replaceRoboticPhrases(result);

    // Step 2: Replace technical jargon
    result = _simplifyJargon(result);

    // Step 3: Break long sentences
    result = _breakLongSentences(result);

    // Step 4: Inject warmth if response feels cold
    result = _ensureWarmth(result);

    return result.trim();
  }

  // ══════════════════════════════════════════════════════
  //  ROBOTIC PHRASE REPLACEMENT
  // ══════════════════════════════════════════════════════

  /// Replace common robotic/system-like phrases with warm conversational Hindi.
  static String _replaceRoboticPhrases(String text) {
    const replacements = {
      'Processing your request': 'Ek second, main dekh rahi hoon',
      'processing your request': 'ek second, main dekh rahi hoon',
      'Please wait while I': 'Bas ek pal, main',
      'please wait while I': 'bas ek pal, main',
      'I am unable to': 'Abhi yeh thoda mushkil hai, lekin',
      'Error occurred': 'Kuch gadbad ho gayi',
      'error occurred': 'kuch gadbad ho gayi',
      'Request failed': 'Yeh abhi nahi ho paaya',
      'request failed': 'yeh abhi nahi ho paaya',
      'Invalid input': 'Mujhe theek se samajh nahi aaya',
      'invalid input': 'mujhe theek se samajh nahi aaya',
      'No data available': 'Abhi yeh jaankari nahi mil rahi',
      'no data available': 'abhi yeh jaankari nahi mil rahi',
      'Feature not supported': 'Yeh abhi available nahi hai',
      'feature not supported': 'yeh abhi available nahi hai',
      'Operation completed': 'Ho gaya',
      'operation completed': 'ho gaya',
      'Successfully': 'Achhe se',
      'successfully': 'achhe se',
      'Data retrieved': 'Jaankari mil gayi',
      'data retrieved': 'jaankari mil gayi',
    };

    var result = text;
    for (final entry in replacements.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }
    return result;
  }

  // ══════════════════════════════════════════════════════
  //  TECHNICAL JARGON SIMPLIFICATION
  // ══════════════════════════════════════════════════════

  /// Replace technical terms with simple, elder-friendly equivalents.
  static String _simplifyJargon(String text) {
    const jargon = {
      'database': 'record',
      'server': 'system',
      'network error': 'connection ki dikkat',
      'timeout': 'der ho gayi',
      'authentication': 'pehchaan',
      'authorization': 'permission',
      'configured': 'set',
      'initialized': 'tayyar',
      'algorithm': 'tarika',
      'parameter': 'setting',
      'interface': 'screen',
      'notification': 'soochna',
      'update available': 'naya version aaya hai',
      'download': 'lena',
      'upload': 'bhejna',
      'sync': 'milaan',
      'cache': 'yaad',
      'bandwidth': 'speed',
    };

    var result = text;
    for (final entry in jargon.entries) {
      result = result.replaceAll(
        RegExp('\\b${RegExp.escape(entry.key)}\\b', caseSensitive: false),
        entry.value,
      );
    }
    return result;
  }

  // ══════════════════════════════════════════════════════
  //  LONG SENTENCE BREAKER
  // ══════════════════════════════════════════════════════

  /// Break sentences longer than ~20 words into shorter sub-sentences.
  /// Elders process shorter phrases much better.
  static String _breakLongSentences(String text) {
    // Split into sentences first
    final sentences = text.split(RegExp(r'(?<=[.!?।])\s+'));
    final result = <String>[];

    for (final sentence in sentences) {
      final words = sentence.split(RegExp(r'\s+'));
      if (words.length <= 20) {
        result.add(sentence);
        continue;
      }

      // Try to break at natural points (commas, conjunctions)
      final buffer = StringBuffer();
      int wordCount = 0;

      for (final word in words) {
        buffer.write('${wordCount > 0 ? ' ' : ''}$word');
        wordCount++;

        // Break at commas or conjunctions near the 15-word mark
        if (wordCount >= 12) {
          final w = word.toLowerCase();
          if (word.endsWith(',') ||
              w == 'aur' ||
              w == 'lekin' ||
              w == 'ya' ||
              w == 'and' ||
              w == 'but' ||
              w == 'or' ||
              w == 'then' ||
              w == 'phir' ||
              w == 'toh') {
            result.add(buffer.toString().trim());
            buffer.clear();
            wordCount = 0;
          }
        }

        // Force break at 20 words
        if (wordCount >= 20) {
          result.add('${buffer.toString().trim()}.');
          buffer.clear();
          wordCount = 0;
        }
      }

      if (buffer.isNotEmpty) {
        result.add(buffer.toString().trim());
      }
    }

    return result.join(' ');
  }

  // ══════════════════════════════════════════════════════
  //  WARMTH INJECTION
  // ══════════════════════════════════════════════════════

  /// Warmth keywords that signal the response already feels caring.
  static const _warmKeywords = {
    'theek',
    'achha',
    'bilkul',
    'fikar',
    'madad',
    'seva',
    'dhyaan',
    'hoon',
    'karoon',
    'dekhti',
    'sure',
    'welcome',
    'happy',
    'glad',
    'help',
    'care',
    'namaste',
    'shukriya',
    'zaroor',
    'koi baat nahi',
  };

  /// If the response has no warm words, append a reassuring closing.
  static String _ensureWarmth(String text) {
    final lower = text.toLowerCase();
    final hasWarmth = _warmKeywords.any((w) => lower.contains(w));

    if (!hasWarmth && text.length > 10) {
      // Only add warmth to substantive responses
      return '$text Aur koi madad chahiye toh zaroor boliyega.';
    }

    return text;
  }
}
