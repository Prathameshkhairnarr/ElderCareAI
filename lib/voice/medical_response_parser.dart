/// Medical Response Parser — AI Doctor Mode
///
/// Parses structured 5-section AI doctor responses into a typed model.
/// Handles both labeled format ("Condition: ...") and plain-text fallback.
///
/// Used by the AI Doctor Screen to display a rich, formatted medical card.
///
/// Safety: Never throws. Returns best-effort parse.
class MedicalResponseParser {
  MedicalResponseParser._();

  // ══════════════════════════════════════════════════════
  //  PUBLIC API
  // ══════════════════════════════════════════════════════

  /// Parse an AI doctor response into a [MedicalResponse].
  ///
  /// Returns null if the response is clearly not a medical response
  /// (e.g., it's a JSON action or a very short system reply).
  static MedicalResponse? parse(String text) {
    if (text.trim().isEmpty) return null;
    if (text.trim().startsWith('{')) return null; // JSON action — skip
    if (text.trim().length < 30) return null; // Too short to be a medical response

    // Try structured format first (labeled sections)
    final structured = _parseStructured(text);
    if (structured != null) return structured;

    // Try heuristic plain-text parse
    return _parsePlainText(text);
  }

  /// Strip all medical section labels from text for clean TTS speech.
  ///
  /// Converts:
  ///   "Condition: viral infection. Explanation: ..."
  /// to:
  ///   "Viral infection. ..."
  static String stripLabelsForTts(String text) {
    var result = text;
    for (final label in _allSectionLabels) {
      result = result.replaceAll(RegExp('$label\\s*', caseSensitive: false), '');
    }
    // Clean up any resulting double spaces or leading newlines
    result = result.replaceAll(RegExp(r'\n{2,}'), '\n');
    result = result.replaceAll(RegExp(r' {2,}'), ' ');
    return result.trim();
  }

  // ══════════════════════════════════════════════════════
  //  SECTION LABEL PATTERNS
  // ══════════════════════════════════════════════════════

  // English labels
  static const _labelCondition = r'Condition\s*:';
  static const _labelExplanation = r'Explanation\s*:';
  static const _labelSymptoms = r'Symptoms?\s*:';
  static const _labelCare = r'Care\s*:';
  static const _labelDoctorWarning = r'Doctor\s*Warning\s*:';

  // Hindi labels (transliterated)
  static const _labelStheeti = r'Stheeti\s*:';
  static const _labelSamasyaSambhavit = r'(Sambhavit\s*)?Sthiti\s*:';
  static const _labelDekhabahal = r'Dekhbhal\s*:';

  static const _allSectionLabels = [
    _labelCondition,
    _labelExplanation,
    _labelSymptoms,
    _labelCare,
    _labelDoctorWarning,
    _labelStheeti,
    _labelSamasyaSambhavit,
    _labelDekhabahal,
  ];

  // ══════════════════════════════════════════════════════
  //  STRUCTURED PARSE — for labeled format
  // ══════════════════════════════════════════════════════

  static MedicalResponse? _parseStructured(String text) {
    final conditionMatch = _extractSection(text, _labelCondition);
    final explanationMatch = _extractSection(text, _labelExplanation);
    final symptomsMatch = _extractSection(text, _labelSymptoms);
    final careMatch = _extractSection(text, _labelCare);
    final doctorWarningMatch = _extractSection(text, _labelDoctorWarning);

    // Need at least condition + one other section to qualify as structured
    if (conditionMatch == null && explanationMatch == null) return null;

    final symptoms = symptomsMatch != null ? _parseBulletList(symptomsMatch) : <String>[];
    final isEmergency = _isEmergencyResponse(doctorWarningMatch ?? text);

    return MedicalResponse(
      condition: conditionMatch ?? '',
      explanation: explanationMatch ?? '',
      symptoms: symptoms,
      care: careMatch ?? '',
      doctorWarning: doctorWarningMatch ?? '',
      rawText: text,
      isEmergency: isEmergency,
    );
  }

  /// Extract text that follows a section label until the next label or end.
  static String? _extractSection(String text, String labelPattern) {
    // Build all-labels alternation for "stop-at" boundary
    const allLabels =
        r'(?:Condition|Explanation|Symptoms?|Care|Doctor\s*Warning)';

    final pattern = RegExp(
      '$labelPattern'
      r'\s*'           // optional whitespace after colon
      r'([\s\S]+?)'    // lazy capture — stop at...
      r'(?='           // lookahead for next label OR end
        '$allLabels'
        r'\s*:|$)',
      caseSensitive: false,
    );

    final match = pattern.firstMatch(text);
    if (match == null) return null;

    final extracted = match.group(1)?.trim();
    if (extracted == null || extracted.isEmpty) return null;
    return extracted;
  }

  // ══════════════════════════════════════════════════════
  //  PLAIN TEXT PARSE — heuristic fallback
  // ══════════════════════════════════════════════════════

  static MedicalResponse? _parsePlainText(String text) {
    // Check if this looks like a medical response at all
    if (!_looksLikeMedicalResponse(text)) return null;

    final isEmergency = _isEmergencyResponse(text);

    // Split into sentences for rough assignment
    final sentences = text
        .split(RegExp(r'(?<=[.।!?])\s+'))
        .where((s) => s.trim().isNotEmpty)
        .toList();

    if (sentences.isEmpty) return null;

    // Heuristic: first sentence = condition clue, last sentence = doctor warning
    final condition = sentences.length >= 1 ? sentences.first : '';
    final explanation = sentences.length >= 2 ? sentences[1] : '';
    final doctorWarning = isEmergency
        ? sentences.last
        : _extractDoctorWarning(text);

    return MedicalResponse(
      condition: condition,
      explanation: explanation,
      symptoms: [],
      care: '',
      doctorWarning: doctorWarning,
      rawText: text,
      isEmergency: isEmergency,
    );
  }

  // ══════════════════════════════════════════════════════
  //  HELPERS
  // ══════════════════════════════════════════════════════

  static bool _looksLikeMedicalResponse(String text) {
    final lower = text.toLowerCase();
    const medicalKeywords = [
      'lagta hai', 'could be', 'symptoms', 'lakshan', 'dawai', 'doctor',
      'paracetamol', 'rest', 'relief', 'infection', 'viral', 'chest',
      'bukhaar', 'khansi', 'dard', 'pain', 'fever', 'cough', 'blood',
      'aaram', 'doctor se milein', 'hospital', 'emergency', 'seek',
    ];
    return medicalKeywords.any((kw) => lower.contains(kw));
  }

  static bool _isEmergencyResponse(String text) {
    final lower = text.toLowerCase();
    const emergencyKeywords = [
      'turant', 'abhi', 'immediately', 'emergency', 'ambulance', '112',
      'heart attack', 'stroke', 'bleeding', 'unconscious', 'hospital',
      'sos', 'critical', 'serious', 'urgent', 'chest pain',
    ];
    return emergencyKeywords.any((kw) => lower.contains(kw));
  }

  static String _extractDoctorWarning(String text) {
    final lower = text.toLowerCase();
    final sentences = text.split(RegExp(r'(?<=[.।!?])\s+'));

    for (final sentence in sentences) {
      final s = sentence.toLowerCase();
      if (s.contains('doctor') ||
          s.contains('milein') ||
          s.contains('hospital') ||
          s.contains('dekhayein') ||
          s.contains('consult') ||
          s.contains('visit')) {
        return sentence.trim();
      }
    }

    // Fallback: if any warning-related phrasing
    if (lower.contains('zyada') || lower.contains('severe') || lower.contains('worsen')) {
      return sentences.last;
    }

    return '';
  }

  /// Parse a text block into a bullet list.
  /// Handles: "- item", "• item", "* item", or comma/newline-separated items.
  static List<String> _parseBulletList(String text) {
    final lines = text.split(RegExp(r'\n|•|-|\*'));
    final results = <String>[];

    for (final line in lines) {
      final trimmed = line.replaceAll(RegExp(r'^[\s\-•*]+'), '').trim();
      if (trimmed.isNotEmpty && trimmed.length > 2) {
        results.add(trimmed);
      }
    }

    // If no bullets found, treat comma-separated as list items (for Hindi responses)
    if (results.isEmpty) {
      final commaItems = text.split(RegExp(r',\s*'));
      for (final item in commaItems) {
        final trimmed = item.trim();
        if (trimmed.isNotEmpty && trimmed.length > 2) {
          results.add(trimmed);
        }
      }
    }

    return results;
  }
}

// ══════════════════════════════════════════════════════
//  MEDICAL RESPONSE MODEL
// ══════════════════════════════════════════════════════

/// Typed model for a structured AI doctor medical response.
///
/// All fields may be empty if the AI did not include that section.
/// Use [isEmergency] to decide if the Doctor Warning should be shown prominently.
class MedicalResponse {
  /// Short description of the possible condition (non-final).
  final String condition;

  /// 1–2 line explanation of what is happening.
  final String explanation;

  /// Common matching symptoms (as a list for chip display).
  final List<String> symptoms;

  /// Basic safe remedies (home / OTC).
  final String care;

  /// When to see a doctor — shown prominently if [isEmergency].
  final String doctorWarning;

  /// Full raw AI text — used for TTS.
  final String rawText;

  /// Whether this response indicates an urgent/emergency situation.
  final bool isEmergency;

  const MedicalResponse({
    required this.condition,
    required this.explanation,
    required this.symptoms,
    required this.care,
    required this.doctorWarning,
    required this.rawText,
    this.isEmergency = false,
  });

  /// True if this response has at least one non-empty section to display.
  bool get hasContent =>
      condition.isNotEmpty ||
      explanation.isNotEmpty ||
      symptoms.isNotEmpty ||
      care.isNotEmpty ||
      doctorWarning.isNotEmpty;
}
