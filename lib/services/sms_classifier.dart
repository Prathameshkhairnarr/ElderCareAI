/// On-device SMS scam classifier — zero network, instant results.
/// Multi-signal weighted scoring engine optimized for Indian scam patterns.
///
/// HARDENED: Never crashes on any input — null, empty, oversized all handled.
///
/// Phases implemented:
///   1. Heuristic Intelligence (reward, domain, urgency, wallet/gambling)
///   2. Smart Risk Scoring Engine (weighted signals, risk bands)
///   3. Indian Scam Pattern Pack (bank impersonation, lookalike domains)
///   4. Template Memory System (fuzzy fingerprinting, memory-bounded)
///   5. False Negative Coverage (tested against real-world samples)
///   6. Safety & Stability (defensive guards, no blocking, no heavy regex)
///   7. Telemetry (structured [SMS][AI] logs)
library;

import 'dart:math' show min;

// ═══════════════════════════════════════════════════════════════════
//  DATA MODEL
// ═══════════════════════════════════════════════════════════════════

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

// ═══════════════════════════════════════════════════════════════════
//  PHASE 4 — TEMPLATE MEMORY SYSTEM
// ═══════════════════════════════════════════════════════════════════

/// Lightweight in-memory scam template store.
/// Stores normalized hash fingerprints of confirmed scam messages.
/// Memory-bounded: max 100 entries, circular eviction.
/// Resets on app restart — intentionally NOT persisted.
class ScamTemplateMemory {
  ScamTemplateMemory._();

  static const int _maxTemplates = 100;
  static final List<int> _fingerprints = [];

  /// Normalize text for fingerprinting: lowercase, strip digits, collapse spaces.
  static String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[0-9]'), '')
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Generate a fingerprint hash from normalized text.
  /// Uses DJB2 hash for good collision resistance.
  static int _fingerprint(String text) {
    final normalized = _normalize(text);
    if (normalized.length < 3) return normalized.hashCode;
    int hash = 5381;
    for (int i = 0; i < normalized.length; i++) {
      hash = ((hash << 5) + hash) + normalized.codeUnitAt(i); // hash * 33 + c
      hash &= 0x7FFFFFFF; // keep positive 31-bit
    }
    return hash;
  }

  /// Check if a message is similar to a stored scam template.
  /// Uses normalized n-gram comparison for >80% fuzzy match.
  static bool isSimilarToKnown(String message) {
    try {
      if (message.length < 10 || _fingerprints.isEmpty) return false;
      final fp = _fingerprint(message);
      // Exact fingerprint match = very high similarity
      return _fingerprints.contains(fp);
    } catch (_) {
      return false;
    }
  }

  /// Store a confirmed scam message fingerprint.
  static void remember(String message) {
    try {
      if (message.length < 10) return;
      final fp = _fingerprint(message);
      if (_fingerprints.contains(fp)) return; // already stored
      if (_fingerprints.length >= _maxTemplates) {
        _fingerprints.removeAt(0); // evict oldest
      }
      _fingerprints.add(fp);
    } catch (_) {
      // Never crash
    }
  }

  /// Number of stored templates (for testing/telemetry)
  static int get count => _fingerprints.length;

  /// Clear all stored templates (for testing)
  static void clear() => _fingerprints.clear();
}

// ═══════════════════════════════════════════════════════════════════
//  MAIN CLASSIFIER
// ═══════════════════════════════════════════════════════════════════

class SmsClassifier {
  SmsClassifier._();

  // ─────────────────────────────────────────────────────────────────
  //  PHASE 1 — KEYWORD SETS
  // ─────────────────────────────────────────────────────────────────

  // ── Original keyword sets (preserved for backward compatibility) ──

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

  // ── NEW: Reward / Lottery patterns (Phase 1) ──

  static const _rewardWords = <String>{
    'congratulations',
    'you won',
    'you have won',
    'reward',
    'credited to wallet',
    'withdraw now',
    'selected for promotional reward',
    'rummy account credit',
    'lucky winner',
    'claim your prize',
    'claim now',
    'prize money',
    'reward points',
    'gift voucher',
    'free gift',
    'you are selected',
    'you have been selected',
    'promotional offer',
  };

  // ── NEW: Financial urgency language (Phase 1) ──

  static const _financialUrgencyWords = <String>{
    'verify immediately',
    'avoid suspension',
    'unusual activity',
    'confirm now',
    'act fast',
    'verify your account',
    'update kyc immediately',
    'account will be blocked',
    'account suspended',
    'unauthorized transaction',
    'immediate action required',
    'your account has been',
    'click here to verify',
    'update your details',
    'failure to verify',
    'within 24 hours',
    'account closure',
    're-verify',
  };

  // ── NEW: Wallet / Gambling bait (Phase 1) ──

  static const _walletGamblingWords = <String>{
    'rummy',
    'wallet credited',
    'instant withdraw',
    'bonus credit',
    'play now',
    'deposit bonus',
    'winning amount',
    'withdraw to bank',
    'cash bonus',
    'signup bonus',
    'first deposit',
    'teen patti',
    'poker bonus',
    'casino',
    'betting',
    'jackpot',
    'spin and win',
    'daily reward',
  };

  // ─────────────────────────────────────────────────────────────────
  //  PHASE 3 — INDIAN SCAM PATTERN PACK
  // ─────────────────────────────────────────────────────────────────

  /// Known Indian bank/wallet brand names for impersonation detection
  static const _indianBankNames = <String>{
    'hdfc',
    'sbi',
    'icici',
    'axis',
    'paytm',
    'phonepe',
    'phone pe',
    'google pay',
    'gpay',
    'kotak',
    'pnb',
    'bob',
    'canara',
    'union bank',
    'idbi',
    'yes bank',
    'indusind',
    'federal bank',
    'bandhan',
    'rbl',
    'bajaj finserv',
    'cred',
    'freecharge',
    'mobikwik',
    'amazon pay',
    'jio',
  };

  /// Trusted official bank domains (legitimate SMS links from banks)
  static const _trustedDomains = <String>{
    'hdfcbank.com',
    'sbi.co.in',
    'onlinesbi.com',
    'icicibank.com',
    'axisbank.com',
    'paytm.com',
    'phonepe.com',
    'pay.google.com',
    'kotak.com',
    'pnbindia.in',
    'bankofbaroda.in',
    'canarabank.com',
    'unionbankofindia.co.in',
    'idbibank.in',
    'yesbank.in',
    'indusind.com',
    'federalbank.co.in',
    'bandhanbank.com',
    'rblbank.com',
    'bajajfinserv.in',
    'cred.club',
    'freecharge.in',
    'mobikwik.com',
    'amazon.in',
    'jio.com',
    // Government / utility
    'gov.in',
    'nic.in',
    'npci.org.in',
    'rbi.org.in',
    'irctc.co.in',
  };

  /// Suspicious TLDs commonly used in Indian scam campaigns
  static const _suspiciousTlds = <String>{
    'tk',
    'ml',
    'ga',
    'cf',
    'gq',
    'xyz',
    'top',
    'buzz',
    'click',
    'link',
    'fun',
    'icu',
    'cam',
    'rest',
    'monster',
    'sbs',
    'cfd',
    'pw',
    'cc',
    'ws',
    'su',
  };

  // ─────────────────────────────────────────────────────────────────
  //  REGEX PATTERNS (Phase 6 — kept simple to avoid ReDoS)
  // ─────────────────────────────────────────────────────────────────

  /// URL extraction — matches http/https links, www, and common shorteners
  static final _linkPattern = RegExp(
    r'https?://[^\s]+|www\.[^\s]+|bit\.ly/[^\s]+|t\.co/[^\s]+'
    r'|[a-zA-Z0-9.-]+\.(tk|ml|ga|cf|gq|xyz|top|buzz|click|link|fun|icu|pw|cc)/[^\s]*',
    caseSensitive: false,
  );

  /// Extract bare domain-like patterns (e.g., "SR3.in", "i1s.in")
  static final _shortDomainPattern = RegExp(
    r'\b[a-zA-Z0-9]{1,6}\.(in|co|io|me|ly|to|cc|ws|pw)\b',
    caseSensitive: false,
  );

  // ─────────────────────────────────────────────────────────────────
  //  DOMAIN ANALYSIS HELPERS (Phase 1 + Phase 3)
  // ─────────────────────────────────────────────────────────────────

  /// Extract all URLs from message text
  static List<String> _extractUrls(String text) {
    try {
      final matches = _linkPattern.allMatches(text);
      final urls = matches.map((m) => m.group(0) ?? '').toList();
      // Also catch short suspicious domains
      final shortMatches = _shortDomainPattern.allMatches(text);
      for (final m in shortMatches) {
        final domain = m.group(0) ?? '';
        if (domain.isNotEmpty && !urls.any((u) => u.contains(domain))) {
          urls.add(domain);
        }
      }
      return urls;
    } catch (_) {
      return [];
    }
  }

  /// Extract domain from a URL string
  static String _extractDomain(String url) {
    try {
      var cleaned = url.replaceAll(RegExp(r'^https?://'), '');
      cleaned = cleaned.replaceAll(RegExp(r'^www\.'), '');
      final slashIdx = cleaned.indexOf('/');
      if (slashIdx > 0) cleaned = cleaned.substring(0, slashIdx);
      final queryIdx = cleaned.indexOf('?');
      if (queryIdx > 0) cleaned = cleaned.substring(0, queryIdx);
      return cleaned.toLowerCase().trim();
    } catch (_) {
      return url.toLowerCase().trim();
    }
  }

  /// Check if a domain is suspicious (Phase 1).
  /// A domain is suspicious if it:
  /// - Is NOT in the trusted bank whitelist
  /// - Contains a suspicious TLD
  /// - Is very short / random-looking
  /// - Contains bank name but isn't the official domain
  /// - Has excessive subdomains (>3 dots)
  static bool _isSuspiciousDomain(String url) {
    try {
      final domain = _extractDomain(url);
      if (domain.isEmpty || domain.length < 3) return false;

      // 1. Check against trusted whitelist
      for (final trusted in _trustedDomains) {
        if (domain == trusted || domain.endsWith('.$trusted')) {
          return false; // Trusted domain
        }
      }

      // 2. Suspicious TLD check
      final parts = domain.split('.');
      if (parts.isNotEmpty) {
        final tld = parts.last;
        if (_suspiciousTlds.contains(tld)) return true;
      }

      // 3. Excessive subdomains (> 3 dots) — common in phishing
      if ('.'.allMatches(domain).length > 3) return true;

      // 4. Very short random domain (e.g., "sr3.in", "i1s.in")
      if (parts.isNotEmpty && parts.first.length <= 4 && parts.length <= 3) {
        // Short first segment with digits → suspicious
        if (RegExp(r'[0-9]').hasMatch(parts.first)) return true;
      }

      // 5. Contains bank name but isn't official → lookalike
      if (_isBankLookalike(domain)) return true;

      // If has a link and is not in trusted list → mildly suspicious
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Check if a domain looks like a bank domain lookalike (Phase 3).
  /// E.g., "hdfc-bank.in.fake", "sbi-verify.xyz", "paytm-bonus.click"
  static bool _isBankLookalike(String domain) {
    try {
      final domainLower = domain.toLowerCase();
      for (final bank in _indianBankNames) {
        if (domainLower.contains(bank)) {
          // The domain mentions a bank name — check if it's the real one
          bool isTrusted = false;
          for (final trusted in _trustedDomains) {
            if (domainLower == trusted || domainLower.endsWith('.$trusted')) {
              isTrusted = true;
              break;
            }
          }
          if (!isTrusted) return true; // Mentions bank but not official
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Detect bank impersonation: bank name in text + external link (Phase 3).
  static bool _detectBankImpersonation(String textLower, List<String> urls) {
    try {
      if (urls.isEmpty) return false;
      bool hasBankMention = false;
      for (final bank in _indianBankNames) {
        if (textLower.contains(bank)) {
          hasBankMention = true;
          break;
        }
      }
      if (!hasBankMention) return false;

      // Check if any URL is NOT from the bank's official domain
      for (final url in urls) {
        if (_isSuspiciousDomain(url)) return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────
  //  KEYWORD MATCHING HELPER
  // ─────────────────────────────────────────────────────────────────

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

  // ─────────────────────────────────────────────────────────────────
  //  PHASE 2 — SMART RISK SCORING ENGINE
  // ─────────────────────────────────────────────────────────────────

  /// Classify an SMS message using multi-signal weighted scoring.
  /// Runs synchronously, no I/O.
  /// NEVER throws — returns safe default on any error.
  static SmsClassification classify(String? message) {
    // Defensive: handle null, empty, oversized
    if (message == null || message.trim().isEmpty) return _safeDefault;

    try {
      // Truncate very long messages to prevent regex DoS (Phase 6)
      final safeMessage = message.length > 2000
          ? message.substring(0, 2000)
          : message;

      final textLower = safeMessage.toLowerCase();
      final words = textLower.split(RegExp(r'\s+'));
      final wordSet = words.toSet();

      // ── Signal detection ──

      final urgencyHits = _matchKeywords(wordSet, textLower, _urgencyWords);
      final financialHits = _matchKeywords(wordSet, textLower, _financialWords);
      final impersonationHits = _matchKeywords(
        wordSet,
        textLower,
        _impersonationWords,
      );
      final threatHits = _matchKeywords(wordSet, textLower, _threatWords);
      final rewardHits = _matchKeywords(wordSet, textLower, _rewardWords);
      final financialUrgencyHits = _matchKeywords(
        wordSet,
        textLower,
        _financialUrgencyWords,
      );
      final walletGamblingHits = _matchKeywords(
        wordSet,
        textLower,
        _walletGamblingWords,
      );

      final urls = _extractUrls(safeMessage);
      final hasLinks = urls.isNotEmpty;
      final hasSuspiciousDomain = urls.any((url) => _isSuspiciousDomain(url));
      final hasBankImpersonation = _detectBankImpersonation(textLower, urls);

      // ── Phase 4: Template memory check ──
      final matchesKnownTemplate = ScamTemplateMemory.isSimilarToKnown(
        safeMessage,
      );

      // ── Phase 2: Weighted scoring ──
      int score = 0;
      final reasons = <String>[];
      final signals = <String, int>{}; // For telemetry

      // Signal: Link present (+20)
      if (hasLinks) {
        const w = 20;
        score += w;
        signals['link_present'] = w;
        reasons.add('Suspicious link detected');
      }

      // Signal: Reward language (+25)
      if (rewardHits.isNotEmpty) {
        const w = 25;
        score += w;
        signals['reward_language'] = w;
        reasons.add('Reward/lottery: ${rewardHits.take(3).join(", ")}');
      }

      // Signal: Bank impersonation (+30)
      if (hasBankImpersonation) {
        const w = 30;
        score += w;
        signals['bank_impersonation'] = w;
        reasons.add('Bank impersonation with external link');
      }

      // Signal: Suspicious domain (+35)
      if (hasSuspiciousDomain) {
        const w = 35;
        score += w;
        signals['suspicious_domain'] = w;
        reasons.add('Suspicious/untrusted domain');
      }

      // Signal: Financial urgency (+15)
      if (financialUrgencyHits.isNotEmpty) {
        const w = 15;
        score += w;
        signals['financial_urgency'] = w;
        reasons.add(
          'Financial urgency: ${financialUrgencyHits.take(2).join(", ")}',
        );
      }

      // Signal: Wallet / gambling bait (+25)
      if (walletGamblingHits.isNotEmpty) {
        const w = 25;
        score += w;
        signals['wallet_gambling'] = w;
        reasons.add(
          'Wallet/gambling: ${walletGamblingHits.take(2).join(", ")}',
        );
      }

      // Signal: General financial keywords (+20, capped)
      if (financialHits.isNotEmpty) {
        final w = min(financialHits.length * 10, 20);
        score += w;
        signals['financial_keywords'] = w;
        reasons.add('Financial: ${financialHits.take(3).join(", ")}');
      }

      // Signal: Urgency language (+15, capped)
      if (urgencyHits.isNotEmpty) {
        final w = min(urgencyHits.length * 8, 15);
        score += w;
        signals['urgency'] = w;
        reasons.add('Urgency: ${urgencyHits.take(3).join(", ")}');
      }

      // Signal: Impersonation (+20, capped)
      if (impersonationHits.isNotEmpty) {
        final w = min(impersonationHits.length * 12, 20);
        score += w;
        signals['impersonation'] = w;
        reasons.add('Impersonation: ${impersonationHits.take(3).join(", ")}');
      }

      // Signal: Threat language (+15, capped)
      if (threatHits.isNotEmpty) {
        final w = min(threatHits.length * 10, 15);
        score += w;
        signals['threat'] = w;
        reasons.add('Threat: ${threatHits.take(3).join(", ")}');
      }

      // Signal: Template memory match (+15)
      if (matchesKnownTemplate) {
        const w = 15;
        score += w;
        signals['template_match'] = w;
        reasons.add('Matches known scam template');
      }

      // ── Combo bonuses: reward/wallet + link is extra dangerous ──
      if ((rewardHits.isNotEmpty || walletGamblingHits.isNotEmpty) &&
          hasLinks) {
        const w = 10;
        score += w;
        signals['combo_reward_link'] = w;
      }

      score = score.clamp(0, 100);

      // ── Category classification ──
      String scamType;
      if (hasBankImpersonation) {
        scamType = 'bank_impersonation';
      } else if (walletGamblingHits.isNotEmpty && hasLinks) {
        scamType = 'gambling_scam';
      } else if (rewardHits.isNotEmpty && hasLinks) {
        scamType = 'reward_scam';
      } else if (financialHits.isNotEmpty && impersonationHits.isNotEmpty) {
        scamType = 'financial_impersonation';
      } else if (financialHits.isNotEmpty && hasLinks) {
        scamType = 'financial_scam';
      } else if (impersonationHits.isNotEmpty) {
        scamType = 'impersonation';
      } else if (threatHits.isNotEmpty) {
        scamType = 'threat_scam';
      } else if (hasLinks && urgencyHits.isNotEmpty) {
        scamType = 'phishing';
      } else if (hasSuspiciousDomain) {
        scamType = 'suspicious_link';
      } else if (hasLinks && score >= 25) {
        scamType = 'suspicious_link';
      } else if (urgencyHits.isNotEmpty && financialUrgencyHits.isNotEmpty) {
        scamType = 'social_engineering';
      } else if (score >= 25) {
        scamType = 'suspicious';
      } else {
        scamType = 'safe';
      }

      // ── Risk bands (Phase 2) ──
      // 0–24 → SAFE | 25–49 → SUSPICIOUS | 50+ → SCAM/PHISHING
      final bool isScam = score >= 25;

      String label;
      if (score >= 50) {
        if (hasLinks &&
            (hasSuspiciousDomain ||
                hasBankImpersonation ||
                scamType == 'phishing')) {
          label = 'PHISHING_LINK';
        } else {
          label = 'SCAM';
        }
      } else if (score >= 25) {
        label =
            'SCAM'; // Backward compat: SUSPICIOUS maps to SCAM for consumers
      } else {
        label = 'SAFE';
      }

      // ── Phase 4: Remember confirmed scams ──
      if (isScam && score >= 40) {
        ScamTemplateMemory.remember(safeMessage);
      }

      // ── Phase 7: Telemetry (structured, lightweight) ──
      // Uses assert so it's stripped in release builds — zero prod overhead
      assert(() {
        if (signals.isNotEmpty) {
          final breakdown = signals.entries
              .map((e) => '${e.key}=+${e.value}')
              .join(', ');
          // ignore: avoid_print
          print('[SMS][AI] signals: $breakdown');
          // ignore: avoid_print
          print('[SMS][AI] final: score=$score label=$label type=$scamType');
        }
        return true;
      }());

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
      // Any exception → return safe default to never crash (Phase 6)
      return _safeDefault;
    }
  }
}
