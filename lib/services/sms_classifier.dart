/// On-device SMS scam classifier — zero network, instant results.
/// Ports the backend's keyword-based heuristic to Dart.
///
/// HARDENED: Never crashes on any input — null, empty, oversized all handled.
library;

class SmsClassification {
  final bool isScam;
  final int riskScore; // 0–100
  final String scamType;
  final String explanation;
  final String label;

  const SmsClassification({
    required this.isScam,
    required this.riskScore,
    required this.scamType,
    required this.explanation,
    required this.label,
  });

  @override
  String toString() =>
      'SmsClassification(label=$label, risk=$riskScore, type=$scamType)';
}

/// Safe default for any error or empty input
const _safeDefault = SmsClassification(
  isScam: false,
  riskScore: 0,
  scamType: 'safe',
  explanation: 'No suspicious patterns',
  label: 'SAFE',
);

class SmsClassifier {
  SmsClassifier._();

  // ── Keyword Sets (mirrored from backend analysis_service.py) ──

  static const _urgencyWords = <String>{
    'urgent',
    'immediately',
    'act now',
    'expire',
    'suspended',
    'last chance',
    'hurry',
    'deadline',
    'limited time',
    'warning',
    'final notice',
    'right away',
    "don't delay",
    'asap',
  };

  static const _financialWords = <String>{
    'bank',
    'account',
    'transfer',
    'upi',
    'otp',
    'pin',
    'credit card',
    'debit card',
    'loan',
    'emi',
    'payment',
    'refund',
    'kyc',
    'aadhar',
    'pan card',
    'blocked',
    'verify',
    'transaction',
    'wallet',
    'paytm',
    'phonepe',
    'gpay',
    'prize',
    'lottery',
    'reward',
    'cashback',
    'rupees',
    'lakh',
    'crore',
    'won',
    'winner',
  };

  static const _impersonationWords = <String>{
    'rbi',
    'reserve bank',
    'sbi',
    'government',
    'police',
    'court',
    'income tax',
    'customs',
    'cbi',
    'ministry',
    'official',
    'department',
    'authority',
    'officer',
    'inspector',
    'magistrate',
  };

  static const _threatWords = <String>{
    'arrest',
    'jail',
    'legal action',
    'case filed',
    'warrant',
    'fine',
    'penalty',
    'blacklisted',
    'terminate',
    'seize',
    'freeze',
    'suspend',
    'cancel',
  };

  static final _linkPattern = RegExp(
    r'https?://[^\s]+|www\.[^\s]+|bit\.ly/[^\s]+|t\.co/[^\s]+'
    r'|[a-zA-Z0-9.-]+\.(tk|ml|ga|cf|gq|xyz|top|buzz|click|link)/[^\s]*',
    caseSensitive: false,
  );

  // ── Classifier ──

  /// Classify an SMS message. Runs synchronously, no I/O.
  /// NEVER throws — returns safe default on any error.
  static SmsClassification classify(String? message) {
    // Defensive: handle null, empty, oversized
    if (message == null || message.trim().isEmpty) return _safeDefault;

    try {
      // Truncate very long messages to prevent regex DoS
      final safeMessage = message.length > 2000
          ? message.substring(0, 2000)
          : message;

      final textLower = safeMessage.toLowerCase();
      final words = textLower.split(RegExp(r'\s+'));
      final wordSet = words.toSet();

      // Match single-word and multi-word keywords
      final urgencyHits = _matchKeywords(wordSet, textLower, _urgencyWords);
      final financialHits = _matchKeywords(wordSet, textLower, _financialWords);
      final impersonationHits = _matchKeywords(
        wordSet,
        textLower,
        _impersonationWords,
      );
      final threatHits = _matchKeywords(wordSet, textLower, _threatWords);
      final hasLinks = _linkPattern.hasMatch(safeMessage);

      // Score calculation (same weights as backend)
      int score = 0;
      final reasons = <String>[];

      if (urgencyHits.isNotEmpty) {
        score += (urgencyHits.length * 12).clamp(0, 25);
        reasons.add('Urgency: ${urgencyHits.take(3).join(", ")}');
      }
      if (financialHits.isNotEmpty) {
        score += (financialHits.length * 15).clamp(0, 30);
        reasons.add('Financial: ${financialHits.take(3).join(", ")}');
      }
      if (impersonationHits.isNotEmpty) {
        score += (impersonationHits.length * 18).clamp(0, 25);
        reasons.add('Impersonation: ${impersonationHits.take(3).join(", ")}');
      }
      if (threatHits.isNotEmpty) {
        score += (threatHits.length * 15).clamp(0, 20);
        reasons.add('Threat: ${threatHits.take(3).join(", ")}');
      }
      if (hasLinks) {
        score += 20;
        reasons.add('Suspicious link detected');
      }

      score = score.clamp(0, 100);

      // Category
      String scamType;
      if (financialHits.isNotEmpty && impersonationHits.isNotEmpty) {
        scamType = 'financial_impersonation';
      } else if (financialHits.isNotEmpty) {
        scamType = 'financial_scam';
      } else if (impersonationHits.isNotEmpty) {
        scamType = 'impersonation';
      } else if (threatHits.isNotEmpty) {
        scamType = 'threat_scam';
      } else if (hasLinks && urgencyHits.isNotEmpty) {
        scamType = 'phishing';
      } else if (hasLinks) {
        scamType = 'suspicious_link';
      } else if (urgencyHits.isNotEmpty) {
        scamType = 'social_engineering';
      } else {
        scamType = 'safe';
      }

      final isScam = score >= 40;

      String label = 'SAFE';
      if (scamType == 'phishing' || (hasLinks && score >= 40)) {
        label = 'PHISHING_LINK';
      } else if (isScam) {
        label = 'SCAM';
      }

      return SmsClassification(
        isScam: isScam,
        riskScore: score,
        scamType: scamType,
        explanation: reasons.isEmpty
            ? 'No suspicious patterns'
            : reasons.join(' | '),
        label: label,
      );
    } catch (_) {
      // Any exception → return safe default to never crash
      return _safeDefault;
    }
  }

  /// Match both single-word and multi-word phrases from a keyword set.
  static Set<String> _matchKeywords(
    Set<String> wordSet,
    String fullText,
    Set<String> keywords,
  ) {
    final hits = <String>{};
    for (final kw in keywords) {
      if (kw.contains(' ')) {
        // Multi-word phrase
        if (fullText.contains(kw)) hits.add(kw);
      } else {
        // Single word
        if (wordSet.contains(kw)) hits.add(kw);
      }
    }
    return hits;
  }
}
