/// Text normalization layer for Hindi/English voice input.
///
/// Pipeline: trim → lowercase → Devanagari transliteration → synonym
/// replacement → filler removal → punctuation strip → space collapse.
///
/// Zero external dependencies — pure Dart.
class TextNormalizer {
  TextNormalizer._();

  // ── Devanagari → Romanized/English word map ──
  // Covers common health, risk, emergency, and general terms.
  static const Map<String, String> _devanagariMap = {
    // Health
    'हेल्थ': 'health',
    'स्कोर': 'score',
    'सेहत': 'sehat',
    'तबीयत': 'tabiyat',
    'बीमारी': 'bimaari',
    'दवाई': 'dawai',
    'दवा': 'dawa',
    'गोली': 'goli',
    'डॉक्टर': 'doctor',

    // Risk
    'खतरा': 'risk',
    'खतरे': 'risk',
    'ख़तरा': 'risk',
    'सुरक्षा': 'suraksha',
    'सुरक्षित': 'surakshit',

    // SMS / Messages
    'संदेश': 'sms',
    'मैसेज': 'message',
    'मेसेज': 'message',
    'धोखा': 'dhokha',
    'ठगी': 'thagee',
    'फ्रॉड': 'fraud',

    // Emergency
    'आपातकाल': 'emergency',
    'एम्बुलेंस': 'ambulance',
    'अस्पताल': 'hospital',
    'बचाओ': 'bachao',
    'जल्दी': 'jaldi',
    'मदद': 'madad',

    // Greeting
    'नमस्ते': 'namaste',
    'नमस्कार': 'namaskar',
    'प्रणाम': 'pranam',
    'शुभ': 'shubh',
    'हेलो': 'hello',
    'हाय': 'hi',
    'हैलो': 'hello',

    // Thanks
    'शुक्रिया': 'shukriya',
    'धन्यवाद': 'dhanyawad',

    // General
    'बताओ': 'batao',
    'बताइए': 'bataiye',
    'बताये': 'bataye',
    'कितना': 'kitna',
    'कितनी': 'kitni',
    'कितने': 'kitne',
    'देखो': 'dekho',
    'चेक': 'check',
    'करो': 'karo',
    'करें': 'karein',
    'कीजिये': 'kijiye',
  };

  // ── Romanized Hindi synonyms → canonical English ──
  static const Map<String, String> _synonyms = {
    // Health
    'sehat': 'health',
    'tabiyat': 'health',
    'bimaari': 'health',
    'dawai': 'medicine',
    'dawa': 'medicine',
    'goli': 'medicine',

    // Risk
    'khatara': 'risk',
    'khatraa': 'risk',
    'khatra': 'risk',
    'suraksha': 'safe',
    'surakshit': 'safe',

    // SMS
    'sandesh': 'sms',
    'dhokha': 'fraud',
    'thagee': 'fraud',

    // Emergency
    'bachao': 'emergency',
    'jaldi': 'emergency',

    // Help
    'sahayata': 'help',
    'sahayak': 'help',
  };

  // ── Filler / stop words to remove ──
  static const Set<String> _fillerWords = {
    'mera',
    'meri',
    'mere',
    'mujhe',
    'mujhko',
    'yeh',
    'ye',
    'woh',
    'wo',
    'uska',
    'uski',
    'ka',
    'ke',
    'ki',
    'ko',
    'se',
    'mein',
    'par',
    'hai',
    'hain',
    'tha',
    'thi',
    'the',
    'aur',
    'ya',
    'bhi',
    'toh',
    'to',
    'na',
    'kya',
    'kaise',
    'kaisa',
    'kaisi',
    'please',
    'zara',
    'thoda',
    'aap',
    'aapka',
    'aapki',
    'aapke',
    'hume',
    'humein',
    'humko',
    'abhi',
    'bas',
  };

  /// Normalize voice input for intent matching.
  ///
  /// Returns a cleaned, synonym-resolved, filler-free string.
  /// Example:
  /// ```
  /// "मेरा हेल्थ स्कोर बताओ" → "health score batao"
  /// "risk kitna hai"        → "risk kitna"
  /// ```
  static String normalize(String input) {
    if (input.trim().isEmpty) return '';

    var text = input.trim().toLowerCase();

    // 1. Transliterate Devanagari words (known words only)
    text = _transliterateDevanagari(text);

    // 2. Remove punctuation but PRESERVE Unicode letters (Devanagari, etc.)
    //    Keep: letters (\p{L}), marks/matras (\p{M}), numbers (\p{N}), spaces.
    text = text.replaceAll(RegExp(r'[^\p{L}\p{M}\p{N}\s]', unicode: true), ' ');

    // 3. Split into words, apply synonyms, remove fillers
    final words = text
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => _synonyms[w] ?? w) // synonym replacement
        .where((w) => !_fillerWords.contains(w)) // filler removal
        .toList();

    // 4. Collapse and return
    return words.join(' ').trim();
  }

  /// Replace Devanagari tokens with their romanized equivalents.
  static String _transliterateDevanagari(String text) {
    // Split on whitespace, replace known Devanagari words
    final words = text.split(RegExp(r'\s+'));
    final result = words.map((word) {
      // Try exact match first
      if (_devanagariMap.containsKey(word)) {
        return _devanagariMap[word]!;
      }
      // Try after stripping trailing matras / punctuation
      final cleaned = word.replaceAll(RegExp(r'[।,!?]'), '');
      if (_devanagariMap.containsKey(cleaned)) {
        return _devanagariMap[cleaned]!;
      }
      return word;
    });
    return result.join(' ');
  }

  /// Expose synonym map for testing / debugging.
  static Map<String, String> get synonyms => Map.unmodifiable(_synonyms);

  /// Expose Devanagari map for testing / debugging.
  static Map<String, String> get devanagariMap =>
      Map.unmodifiable(_devanagariMap);
}
