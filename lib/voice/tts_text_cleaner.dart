/// Azure-specific text cleanup pipeline for SSML embedding.
///
/// Unlike [SpeechNaturalizer] which is for flutter_tts, this cleaner
/// is tuned for Azure Neural TTS:
///   - Removes emojis
///   - Normalizes numbers for speech
///   - Expands medical abbreviations
///   - Preserves Hindi Unicode (Devanagari)
///   - Keeps Hinglish intact (Azure handles mixed text well)
///   - Splits long paragraphs into short sentences
///   - Escapes XML special characters for SSML safety
///
/// Pure Dart — zero external dependencies.
class TtsTextCleaner {
  TtsTextCleaner._();

  // ══════════════════════════════════════════════════════
  //  PUBLIC API
  // ══════════════════════════════════════════════════════

  /// Clean text for Azure SSML embedding.
  ///
  /// Returns a list of short sentences ready to be inserted into SSML.
  /// Each sentence is XML-safe, emoji-free, and abbreviation-expanded.
  static List<String> cleanForAzure(String text) {
    if (text.trim().isEmpty) return [];

    var result = text;

    // 1. Remove emojis
    result = _removeEmojis(result);

    // 2. Remove excessive symbols (markdown, dashes, etc.)
    result = _removeExcessiveSymbols(result);

    // 3. Expand medical/tech abbreviations
    result = _expandAbbreviations(result);

    // 4. Normalize numbers for speech
    result = _normalizeNumbers(result);

    // 5. Clean up whitespace
    result = result.replaceAll(RegExp(r'\s{2,}'), ' ').trim();

    // 6. Split into short sentences
    final sentences = _splitIntoShortSentences(result);

    // 7. XML-escape each sentence for SSML safety
    return sentences
        .map((s) => _escapeXml(s))
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// Clean text lightly for Azure — only emoji removal + XML escape.
  /// Use when text is already natural (e.g., AI-generated responses).
  static String lightClean(String text) {
    var clean = _removeEmojis(text);
    clean = clean.replaceAll(RegExp(r'\s+'), ' ').trim();
    return _escapeXml(clean);
  }

  // ══════════════════════════════════════════════════════
  //  EMOJI REMOVAL
  // ══════════════════════════════════════════════════════

  static String _removeEmojis(String text) {
    return text.replaceAll(
      RegExp(
        r'[\u{1F600}-\u{1F64F}]|[\u{1F300}-\u{1F5FF}]|[\u{1F680}-\u{1F6FF}]|'
        r'[\u{1F1E0}-\u{1F1FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]|'
        r'[\u{FE00}-\u{FE0F}]|[\u{1F900}-\u{1F9FF}]|[\u{1FA00}-\u{1FA6F}]|'
        r'[\u{1FA70}-\u{1FAFF}]|[\u{200D}]|[\u{20E3}]|'
        r'[\u{E0020}-\u{E007F}]',
        unicode: true,
      ),
      '',
    );
  }

  // ══════════════════════════════════════════════════════
  //  SYMBOL CLEANUP
  // ══════════════════════════════════════════════════════

  static String _removeExcessiveSymbols(String text) {
    return text
        .replaceAll(RegExp(r'[*#@~`|\\{}\[\]<>^]'), '')
        .replaceAll('...', ', ')
        .replaceAll('–', ', ')
        .replaceAll('—', ', ')
        .replaceAll('_', ' ');
  }

  // ══════════════════════════════════════════════════════
  //  ABBREVIATION EXPANSION
  // ══════════════════════════════════════════════════════

  static String _expandAbbreviations(String text) {
    const abbreviations = {
      // Vitals & diagnostics
      'BP': 'Blood Pressure',
      'BMI': 'Body Mass Index',
      'HR': 'Heart Rate',
      'SpO2': 'Oxygen Level',
      'ECG': 'E C G',
      'EKG': 'E K G',
      'CT': 'C T',
      'MRI': 'M R I',
      'RBC': 'R B C',
      'WBC': 'W B C',
      'HB': 'Hemoglobin',
      'CBC': 'C B C',
      'LFT': 'Liver Function Test',
      'KFT': 'Kidney Function Test',
      'TSH': 'Thyroid',

      // Communication & tech
      'OTP': 'O T P',
      'SMS': 'S M S',
      'SOS': 'S O S',
      'UPI': 'U P I',
      'KYC': 'K Y C',
      'ATM': 'A T M',
      'PIN': 'P I N',
      'ID': 'I D',
      'OPD': 'O P D',
      'ICU': 'I C U',

      // Units
      'mg': 'milligram',
      'ml': 'milliliter',
      'kg': 'kilogram',
      'cm': 'centimeter',
      'mmHg': 'millimeters of mercury',
      'bpm': 'beats per minute',
    };

    var result = text;
    for (final entry in abbreviations.entries) {
      result = result.replaceAll(
        RegExp('\\b${RegExp.escape(entry.key)}\\b'),
        entry.value,
      );
    }
    return result;
  }

  // ══════════════════════════════════════════════════════
  //  NUMBER NORMALIZATION
  // ══════════════════════════════════════════════════════

  static String _normalizeNumbers(String text) {
    var result = text;

    // BP-style fractions: "120/80" → "120 over 80"
    result = result.replaceAllMapped(
      RegExp(r'(\d+)\s*/\s*(\d+)'),
      (m) => '${m.group(1)} over ${m.group(2)}',
    );

    // Percentage: "85%" → "85 percent"
    result = result.replaceAllMapped(
      RegExp(r'(\d+)\s*%'),
      (m) => '${m.group(1)} percent',
    );

    // Temperature Fahrenheit: "98.6°F" → "98.6 degrees Fahrenheit"
    result = result.replaceAllMapped(
      RegExp(r'(\d+\.?\d*)\s*°\s*F', caseSensitive: false),
      (m) => '${m.group(1)} degrees Fahrenheit',
    );

    // Temperature Celsius: "37°C" → "37 degrees Celsius"
    result = result.replaceAllMapped(
      RegExp(r'(\d+\.?\d*)\s*°\s*C', caseSensitive: false),
      (m) => '${m.group(1)} degrees Celsius',
    );

    // Ranges: "50-60" → "50 to 60"
    result = result.replaceAllMapped(
      RegExp(r'(\d+)\s*-\s*(\d+)'),
      (m) => '${m.group(1)} to ${m.group(2)}',
    );

    return result;
  }

  // ══════════════════════════════════════════════════════
  //  SENTENCE SPLITTING
  // ══════════════════════════════════════════════════════

  /// Split text into short sentences (≤ 20 words each).
  ///
  /// First splits on natural sentence boundaries (.।!?),
  /// then breaks any remaining long segments at conjunctions/commas.
  static List<String> _splitIntoShortSentences(String text) {
    // Split on sentence-ending punctuation
    final rawSentences = text.split(RegExp(r'(?<=[.।!?])\s+'));
    final results = <String>[];

    for (final sentence in rawSentences) {
      final trimmed = sentence.trim();
      if (trimmed.isEmpty) continue;

      final words = trimmed.split(RegExp(r'\s+'));
      if (words.length <= 20) {
        results.add(trimmed);
        continue;
      }

      // Break long sentences at natural points
      final buffer = StringBuffer();
      int wordCount = 0;

      for (final word in words) {
        buffer.write('${wordCount > 0 ? ' ' : ''}$word');
        wordCount++;

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
            results.add(buffer.toString().trim());
            buffer.clear();
            wordCount = 0;
          }
        }

        if (wordCount >= 20) {
          results.add('${buffer.toString().trim()}.');
          buffer.clear();
          wordCount = 0;
        }
      }

      if (buffer.isNotEmpty) {
        results.add(buffer.toString().trim());
      }
    }

    return results.where((s) => s.trim().isNotEmpty).toList();
  }

  // ══════════════════════════════════════════════════════
  //  XML ESCAPE
  // ══════════════════════════════════════════════════════

  /// Escape XML special characters for safe SSML embedding.
  static String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
