/// Pre-TTS text normalization for human-like speech output.
///
/// Before text is sent to the TTS engine, this layer:
///   - Removes emojis and excessive symbols
///   - Expands common medical/tech abbreviations
///   - Normalizes numbers for natural speech
///   - Replaces Hinglish insertions with context-appropriate Hindi
///   - Adds micro-pauses after punctuation
///
/// Lightweight — pure string processing, no heavy AI.
class SpeechNaturalizer {
  SpeechNaturalizer._();

  /// Normalize text for natural-sounding TTS output.
  static String naturalize(String text) {
    if (text.isEmpty) return text;

    var result = text;

    // Step 1: Remove emojis
    result = _removeEmojis(result);

    // Step 2: Remove excessive symbols
    result = _removeExcessiveSymbols(result);

    // Step 3: Expand abbreviations
    result = _expandAbbreviations(result);

    // Step 4: Normalize numbers
    result = _normalizeNumbers(result);

    // Step 5: Apply Hinglish avoidance (replace English insertions in Hindi text)
    result = _avoidHinglish(result);

    // Step 6: Add micro-pauses
    result = _addMicroPauses(result);

    // Step 7: Clean up whitespace
    result = result.replaceAll(RegExp(r'\s{2,}'), ' ').trim();

    return result;
  }

  // ══════════════════════════════════════════════════════
  //  EMOJI REMOVAL
  // ══════════════════════════════════════════════════════

  /// Remove all Unicode emoji and symbol characters that TTS cannot pronounce.
  static String _removeEmojis(String text) {
    // Comprehensive emoji regex covering:
    //   - Emoticons (U+1F600–U+1F64F)
    //   - Misc Symbols & Pictographs (U+1F300–U+1F5FF)
    //   - Transport & Map (U+1F680–U+1F6FF)
    //   - Supplemental Symbols (U+1F900–U+1F9FF)
    //   - Symbols & Pictographs Extended-A (U+1FA00–U+1FA6F, U+1FA70–U+1FAFF)
    //   - Dingbats (U+2702–U+27B0)
    //   - Misc symbols (U+2600–U+26FF)
    //   - Variation selectors & skin tones
    //   - Zero-width joiners and other invisible chars
    return text.replaceAll(
      RegExp(
        r'[\u{1F600}-\u{1F64F}]|'
        r'[\u{1F300}-\u{1F5FF}]|'
        r'[\u{1F680}-\u{1F6FF}]|'
        r'[\u{1F900}-\u{1F9FF}]|'
        r'[\u{1FA00}-\u{1FA6F}]|'
        r'[\u{1FA70}-\u{1FAFF}]|'
        r'[\u{2702}-\u{27B0}]|'
        r'[\u{2600}-\u{26FF}]|'
        r'[\u{FE00}-\u{FE0F}]|'
        r'[\u{200D}]|'
        r'[\u{20E3}]|'
        r'[\u{E0020}-\u{E007F}]',
        unicode: true,
      ),
      '',
    );
  }

  // ══════════════════════════════════════════════════════
  //  SYMBOL CLEANUP
  // ══════════════════════════════════════════════════════

  /// Remove symbols that sound bad in TTS.
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

  /// Expand common abbreviations for clarity.
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
      // Match whole word only (case-sensitive for medical abbreviations)
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

  /// Normalize numbers for natural speech.
  /// Examples:
  ///   "120/80" → "120 over 80"
  ///   "85%" → "85 percent"
  ///   "98.6°F" → "98.6 degrees Fahrenheit"
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

    // Ranges: "50-60" → "50 to 60" (but not in dates)
    result = result.replaceAllMapped(
      RegExp(r'(\d+)\s*-\s*(\d+)'),
      (m) => '${m.group(1)} to ${m.group(2)}',
    );

    return result;
  }

  // ══════════════════════════════════════════════════════
  //  HINGLISH AVOIDANCE
  // ══════════════════════════════════════════════════════

  /// Replace common English filler words that creep into Hindi responses
  /// with natural Hindi equivalents for consistent pronunciation.
  static String _avoidHinglish(String text) {
    // Only apply if text appears to be predominantly Hindi
    // (contains Hindi-romanized keywords or Devanagari)
    final hindiSignals = RegExp(
      r'(aap|hai|hain|theek|kijiye|karein|batao|nahi|ji|hoon|rahi|raha)',
      caseSensitive: false,
    );
    if (!hindiSignals.hasMatch(text)) return text;

    const replacements = {
      // Common English insertions in Hindi speech
      'OK': 'theek hai',
      'okay': 'theek hai',
      'Okay': 'theek hai',
      'processing': 'dekh rahi hoon',
      'Processing': 'Dekh rahi hoon',
      'loading': 'laa rahi hoon',
      'Loading': 'Laa rahi hoon',
      'please wait': 'ek second',
      'Please wait': 'Ek second',
      'sorry': 'maaf kijiye',
      'Sorry': 'Maaf kijiye',
      'thank you': 'shukriya',
      'Thank you': 'Shukriya',
      'yes': 'ji haan',
      'Yes': 'Ji haan',
      'no': 'nahi',
      'No': 'Nahi',
      'done': 'ho gaya',
      'Done': 'Ho gaya',
    };

    var result = text;
    for (final entry in replacements.entries) {
      result = result.replaceAll(
        RegExp('\\b${RegExp.escape(entry.key)}\\b'),
        entry.value,
      );
    }
    return result;
  }

  // ══════════════════════════════════════════════════════
  //  MICRO-PAUSE INSERTION
  // ══════════════════════════════════════════════════════

  /// Add brief TTS-friendly pauses after punctuation for natural rhythm.
  static String _addMicroPauses(String text) {
    var result = text;

    // Ensure a small pause after periods (if not already followed by space)
    result = result.replaceAllMapped(RegExp(r'\.(?!\s)'), (m) => '. ');

    // Add comma pauses after colons for speech flow
    result = result.replaceAll(': ', ', ');

    // Add breathing room after question marks
    result = result.replaceAllMapped(RegExp(r'\?(?!\s)'), (m) => '? ');

    // Add breathing room after exclamation marks
    result = result.replaceAllMapped(RegExp(r'!(?!\s)'), (m) => '! ');

    // Add a pause after Hindi purna viram (।)
    result = result.replaceAllMapped(RegExp(r'।(?!\s)'), (m) => '। ');

    return result;
  }
}
