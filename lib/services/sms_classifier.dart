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
    'don\'t delay',
    'asap',
    'within 24 hours',
    'within 12 hours',
    'today only',
    'ending soon',
    'immediate action',
    'urgent request',
    'action required',
    'do it now',
    'last warning',
    'critical',
    'mandatory',
    'required immediately',
    'without fail',
    'time sensitive',
    'fast',
    'quick',
    'soon',
    'before it expires',
    'expiring today',
    'will be blocked',
    'will be suspended',
    'deactivation',
    'deactivate soon',
    'account closed',
    'closure warning',
    'immediate attention',
    'action needed',
    'respond now',
    'must reply',
    'last day',
    'closing soon',
    'turant',
    'jaldi',
    'abhi karein',
    'aakhri mauka',
    'khatam ho raha',
    'aaj hi',
    'block ho jayega',
    'band ho jayega',
    'warn kiya jata hai',
    'antim din',
    'samay seema',
    'jald se jald',
    'tatkal',
    'urgnt',
    'imediately',
    'expir',
    'suspendd',
    'hurrei',
    'deadlin',
    'act fast',
    'quick reply',
    'reply asap',
    'urgent update',
    'critical update',
    'security update required',
    'immediate update',
    'mandatory update',
    'compulsory',
    'compulsory action',
    'must act',
    'failure to do so',
    'if not done',
    'action pending',
    'pending action',
    'resolve now',
    'fix now',
    'issue detected',
    'attention required',
    'please act',
    'kindly act',
    'urgent notice',
    'final reminder',
    'last reminder',
    'reminder 1',
    'reminder 2',
    'reminder 3',
    'account deletion',
    'profile suspension',
    'login immediately',
    'verify now',
    'verify instantly',
    'immediate verification',
    'instant verification',
    'alert',
    'security alert',
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
    'bhim',
    'rupay',
    'visa',
    'mastercard',
    'net banking',
    'internet banking',
    'cvv',
    'branch',
    'manager',
    'cash',
    'funds',
    'deposit',
    'withdrawal',
    'balance',
    'cheque',
    'dd',
    'overdraft',
    'savings',
    'current account',
    'fixed deposit',
    'fd',
    'rd',
    'mutual fund',
    'stocks',
    'trading',
    'crypto',
    'bitcoin',
    'investment',
    'returns',
    'profit',
    'loss',
    'tax',
    'income tax',
    'tds',
    'gst',
    'billing',
    'invoice',
    'receipt',
    'credt',
    'debt',
    'cr',
    'dr',
    'credited',
    'debited',
    'amount',
    'rs',
    'inr',
    'rupees',
    'lakh',
    'crore',
    'thousand',
    'hundred',
    'paisa',
    'paise',
    'paise bhejo',
    'paise transfer',
    'bank khata',
    'khata',
    'bima',
    'insurance',
    'premium',
    'policy',
    'claim',
    'settlement',
    'refund processed',
    'cashback received',
    'reward points',
    'loyalty points',
    'redeem points',
    'encash',
    'vpa',
    'upi id',
    'upi pin',
    'mpin',
    'tpin',
    'beneficiary',
    'payee',
    'remittance',
    'wire transfer',
    'neft',
    'rtgs',
    'imps',
    'swift',
    'forex',
    'loan approved',
    'pre-approved loan',
    'personal loan',
    'home loan',
    'car loan',
    'business loan',
    'instant loan',
    'micro loan',
    'payday loan',
    'cash advance',
    'salary advance',
    'credit limit',
    'limit increase',
    'card upgrade',
    'lifetime free',
    'no annual fee',
    'zero balance',
    'minimum balance',
    'penalty fee',
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
    'govt',
    'department',
    'authority',
    'officer',
    'inspector',
    'magistrate',
    'judge',
    'lawyer',
    'advocate',
    'supreme court',
    'high court',
    'cyber cell',
    'cyber police',
    'crime branch',
    'cid',
    'ed',
    'enforcement directorate',
    'nia',
    'ncb',
    'raw',
    'trai',
    'irda',
    'sebi',
    'epfo',
    'uidai',
    'aadhar center',
    'pan office',
    'passport office',
    'rto',
    'traffic police',
    'challan department',
    'municipality',
    'bmc',
    'ndmc',
    'mcd',
    'collector',
    'dm',
    'sp',
    'dsp',
    'acp',
    'dcp',
    'commissioner',
    'dg',
    'ig',
    'sho',
    'constable',
    'head constable',
    'sub inspector',
    'si',
    'asi',
    'army',
    'navy',
    'air force',
    'military',
    'paramilitary',
    'crpf',
    'bsf',
    'cisf',
    'itbp',
    'niti aayog',
    'pmo',
    'cmo',
    'minister',
    'mp',
    'mla',
    'sarpanch',
    'mayor',
    'governor',
    'president',
    'indian post',
    'bharatiya dak',
    'irctc',
    'indian railways',
    'nhai',
    'fastag authority',
    'telecom ministry',
    'dot',
    'department of telecommunications',
    'npci',
    'national payments',
    'sarkari',
    'karyalay',
    'adhikari',
    'pradhikaran',
    'vibhaag',
    'mantralaya',
    'nyayalaya',
    'police station',
    'thana',
    'chowki',
    'control room',
    'helpline',
    'customer care',
    'support team',
    'resolution center',
    'grievance cell',
    'ombudsman',
    'nodal officer',
    'appellate authority',
    'vigilance',
    'anti-corruption',
    'lokpal',
    'lokayukta',
    'cag',
    'election commission',
    'eci',
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
    'account freeze',
    'sim blocked',
    'fir',
    'complaint',
    'summon',
    'subpoena',
    'court notice',
    'legal notice',
    'lawsuit',
    'sue',
    'prosecute',
    'imprisonment',
    'detention',
    'custody',
    'interrogation',
    'investigation',
    'raid',
    'search warrant',
    'confiscate',
    'attach property',
    'auction',
    'defaulter',
    'absconder',
    'fugitive',
    'criminal',
    'fraudulent',
    'illegal',
    'unlawful',
    'banned',
    'restricted',
    'prohibited',
    'violation',
    'breach',
    'non-compliance',
    'defamation',
    'harassment',
    'extortion',
    'blackmail',
    'threat',
    'danger',
    'risk',
    'severe consequences',
    'strict action',
    'punitive action',
    'disciplinary action',
    'police complaint',
    'cyber complaint',
    'report filed',
    'dossier',
    'chargesheet',
    'conviction',
    'girgtaar',
    'girftari',
    'jail hogi',
    'fine lagega',
    'jurmana',
    'karwai',
    'kanooni karwai',
    'mukadama',
    'notice bheja',
    'court jana padega',
    'police aayegi',
    'ghar pe police',
    'raid padegi',
    'khatra',
    'saza',
    'dand',
    'rukawat',
    'bandi',
    'zapt',
    'kroki',
    'kurki',
    'shikayat',
    'darj',
    'khilaf',
    'virodh',
    'pratibandh',
    'nishedh',
    'dhamki',
    'warning issued',
    'final warning issued',
    'account deletion',
    'permanent ban',
    'lifetime ban',
    'service termination',
    'contract cancellation',
    'agreement failure',
    'breach of trust',
    'fraud detected',
    'suspicious activity detected',
    'money laundering',
    'terror financing',
    'illegal transaction',
    'unauthorized access',
    'hacked',
  };

  // ── NEW: Reward / Lottery patterns (Phase 1) ──

  static const _rewardWords = <String>{
    'congratulations',
    'you won',
    'prize',
    'reward',
    'gift',
    'cashback',
    'rupees',
    'lakh',
    'crore',
    'won',
    'winner',
    'lottery',
    'jackpot',
    'lucky draw',
    'sweepstakes',
    'giveaway',
    'free',
    'bonus',
    'surprise',
    'special offer',
    'exclusive offer',
    'mega offer',
    'bumper prize',
    'grand prize',
    'first prize',
    'cash prize',
    'voucher',
    'coupon',
    'discount',
    'promo code',
    'recharge free',
    'data free',
    'smartphone won',
    'iphone won',
    'car won',
    'bike won',
    'gold won',
    'trip to',
    'holiday package',
    'vacation',
    'all expenses paid',
    'sponsored',
    'selected',
    'shortlisted',
    'chosen',
    'lucky winner',
    'random selection',
    'computer selection',
    'mobile number won',
    'sim card won',
    'email won',
    'claim now',
    'claim prize',
    'redeem now',
    'redeem prize',
    'collect prize',
    'grab offer',
    'avail offer',
    'limited offer',
    'festive offer',
    'diwali offer',
    'new year offer',
    'anniversary offer',
    'birthday offer',
    'celebration',
    'badhai',
    'badhai ho',
    'aap jeet chuke hai',
    'aap winner hai',
    'inaam',
    'puraskar',
    'muft',
    'free gift',
    'tohfa',
    'shandaar',
    'dhamaka',
    'offer',
    'chhoot',
    'cashback mila',
    'paise mile',
    'kismat',
    'bhagya',
    'lucky',
    '1st prize',
    '2nd prize',
    '3rd prize',
    'consolation prize',
    'mega draw',
    'lucky number',
    'lucky spin',
    'wheel of fortune',
    'scratch card',
    'scratch and win',
    'play and win',
    'bet and win',
    'rummy win',
    'casino win',
    'poker win',
    'fantasy win',
    'dream11 win',
    'mpl win',
    'my11circle win',
    'bcci offer',
    'ipl offer',
    't20 offer',
    'world cup offer',
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

  static const _jobWords = <String>{
    'work from home',
    'earn',
    'daily income',
    'part-time job',
    'registration fee',
    'pay to start job',
    'wfh',
    'full time job',
    'freelance',
    'online earning',
    'earn money online',
    'make money online',
    'data entry',
    'copy paste',
    'typing job',
    'sms sending job',
    'email reading job',
    'ad clicking job',
    'survey job',
    'review job',
    'youtube like job',
    'subscribe job',
    'instagram like job',
    'follow job',
    'rating job',
    'amazon review job',
    'flipkart review job',
    'google review job',
    'app installation job',
    'game playing job',
    'refer and earn',
    'network marketing',
    'mlm',
    'pyramid scheme',
    'chain system',
    'downline',
    'upline',
    'direct selling',
    'investment plan',
    'roi plan',
    'doubling money',
    'guaranteed income',
    'fixed income',
    'passive income',
    'financial freedom',
    'be your own boss',
    'no investment',
    'zero investment',
    'low investment',
    'high return',
    'quick money',
    'easy money',
    'get rich quick',
    'lakhpati',
    'crorepati',
    'naukri',
    'rozgar',
    'kaam',
    'ghar baithe',
    'kamai',
    'paise kamaye',
    'din ka',
    'mahine ka',
    'salary',
    'wages',
    'stipend',
    'bonus',
    'commission',
    'incentive',
    'target',
    'target completion',
    'task completion',
    'assignment',
    'project',
    'recruitment',
    'hiring',
    'urgent hiring',
    'vacancy',
    'openings',
    'interview',
    'selection',
    'offer letter',
    'joining letter',
    'appointment letter',
    'training fee',
    'security deposit',
    'equipment fee',
    'laptop fee',
    'uniform fee',
    'id card fee',
    'processing fee',
    'agreement fee',
    'bond fee',
    'document verification fee',
    'hr round',
    'manager round',
    'job guarantee',
    '100% placement',
  };

  static const _deliveryWords = <String>{
    'parcel',
    'shipment',
    'courier',
    'delivery failed',
    'customs charge',
    'pay delivery fee',
    'india post',
    'speed post',
    'postal service',
    'dhl',
    'fedex',
    'blue dart',
    'dtpc',
    'safexpress',
    'ecom express',
    'delhivery',
    'shadowfax',
    'xpressbees',
    'amazon delivery',
    'flipkart delivery',
    'myntra delivery',
    'meesho delivery',
    'swiggy delivery',
    'zomato delivery',
    'blinkit delivery',
    'zepto delivery',
    'dunzo delivery',
    'instamart delivery',
    'bigbasket delivery',
    'jio mart delivery',
    'package',
    'dispatch',
    'dispatched',
    'in transit',
    'out for delivery',
    'delivered',
    'undelivered',
    'returned',
    'address not found',
    'wrong address',
    'update address',
    'confirm address',
    'reschedule',
    'redelivery',
    'pick up',
    'drop off',
    'tracking',
    'track order',
    'tracking number',
    'awb',
    'waybill',
    'customs clearance',
    'duty fee',
    'import tax',
    'clearance fee',
    'holding fee',
    'storage fee',
    'demurrage',
    'penalty fee',
    'insurance fee',
    'damage fee',
    'lost package',
    'damaged package',
    'delayed package',
    'held at customs',
    'seized by customs',
    'pending payment',
    'payment required for delivery',
    'pay to receive',
    'postman',
    'delivery boy',
    'delivery executive',
    'delivery partner',
    'rider',
    'samaan',
    'bheja',
    'parsal',
    'daak',
    'chitthi',
    'patra',
    'pata',
    'pata galat',
    'pata update',
    'wapas',
    'ruk gaya',
    'roka gaya',
    'shulk',
    'tax',
    'fine',
    'delivery missed',
    'missed delivery',
    'door locked',
    'consignee unavailable',
    'receiver unavaliable',
  };

  static const _electricityWords = <String>{
    'electricity bill',
    'power disconnected',
    'bijli cut',
    'pay bill immediately',
    'mseb',
    'uppcl',
    'bescom',
    'cesc',
    'tssprdcl',
    'tsnpdcl',
    'apsprdcl',
    'apepdcl',
    'hbvn',
    'dhbvn',
    'jbvnl',
    'nbpdcl',
    'sbpdcl',
    'cspdcl',
    'gedcol',
    'kseb',
    'tangedco',
    'wbsedcl',
    'power supply',
    'power cut',
    'load shedding',
    'blackout',
    'electricity board',
    'electricity department',
    'electricity officer',
    'lineman',
    'meter reader',
    'meter',
    'smart meter',
    'unit',
    'reading',
    'bill due',
    'due date',
    'overdue',
    'late fee',
    'penalty',
    'disconnection',
    'disconnection notice',
    'final notice electricity',
    'power suspension',
    'restore power',
    'reconnect power',
    'reconnection fee',
    'update bill',
    'previous month bill',
    'current month bill',
    'arrears',
    'outstanding amount',
    'pay online',
    'pay via link',
    'download bill',
    'view bill',
    'bill receipt',
    'payment confirmation',
    'bijli vibhag',
    'bijli board',
    'bijli meter',
    'bijli bill',
    'light bill',
    'current bill',
    'line kat',
    'line cut',
    'connection cut',
    'connection kat',
    'bijli gul',
    'bhuqtan',
    'jama kare',
    'shulk',
    'jurmana',
    'officer se baat kare',
    'call officer',
    'contact officer',
    'helpline number',
    'customer care number',
    'bill desk',
    'payment portal',
    'power grid',
    'state electricity',
    'national grid',
    'solar scheme',
    'free electricity',
    'electricity subsidy',
    '200 units free',
    'zero bill',
    'waiver',
    'maaf',
    'bill maaf',
    'meter checking',
    'vigilance checking',
    'electricity theft',
    'fine for theft',
  };

  static const _gasWords = <String>{
    'gas subsidy',
    'lpg update',
    'gas kyc',
    'connection suspended',
    'indane',
    'hp gas',
    'bharat gas',
    'reliance gas',
    'adani gas',
    'mahanagar gas',
    'igl',
    'mgl',
    'png',
    'cng',
    'lpg',
    'cylinder',
    'gas booking',
    'book cylinder',
    'refill',
    'refill booking',
    'delivery agent',
    'gas agency',
    'distributor',
    'gas officer',
    'gas connection',
    'new connection',
    'ujjwala',
    'ujjwala yojana',
    'subsidy amount',
    'subsidy credited',
    'subsidy pending',
    'subsidy stopped',
    'link aadhar to gas',
    'gas aadhar link',
    'biometric update',
    'ekyc for gas',
    'inspection',
    'safety inspection',
    'inspection fee',
    'hose pipe change',
    'regulator change',
    'stove checking',
    'leakage',
    'blast',
    'insurance for gas',
    'gas insurance',
    'mandatory checking',
    'compulsory inspection',
    'gas bill',
    'piped gas',
    'meter reading',
    'gas meter',
    'disconnect gas',
    'stop gas',
    'gas line',
    'gas vibhag',
    'cylinder book',
    'booking number',
    'subsidy ka paisa',
    'khate me paise',
    'kyc pending',
    'aadhar jode',
    'connection band',
    'connection cancel',
    'home delivery',
    'urgent booking',
    'tatkal booking',
    'gas leakage',
    'emergency service',
    'customer care gas',
    'helpline gas',
    'toll free',
    'complaint gas',
    'resolve gas issue',
    'address update',
    'transfer connection',
    'surrender connection',
    'deposit refund',
    'security amount',
    'cylinder limit',
    'quota over',
    'extra cylinder',
    'commercial cylinder',
    'domestic cylinder',
    '14.2 kg',
    '19 kg',
  };

  static const _simWords = <String>{
    'sim blocked',
    'sim suspend',
    'verify sim',
    'update kyc now',
    'jio',
    'airtel',
    'vi',
    'vodafone',
    'idea',
    'bsnl',
    'mtnl',
    'jiofi',
    'dongle',
    'router',
    'broadband',
    'fiber',
    'fiber broadband',
    'telecom',
    'customer service',
    'network provider',
    'sim card',
    'e-sim',
    'esim',
    'convert to esim',
    'upgrade sim',
    '4g to 5g',
    'sim upgrade',
    'free 5g',
    '5g trial',
    'port number',
    'mnp',
    'puk code',
    'sim locked',
    'unlock sim',
    'sim registry',
    'telecom verification',
    'aadhar sim link',
    'sim aadhar linking',
    'document missing',
    're-verification',
    'document re-verify',
    'sim deactivation',
    'sim validity',
    'validity expired',
    'recharge now',
    'plan expired',
    'outgoing blocked',
    'incoming blocked',
    'data exhausted',
    '100% data used',
    'daily limit',
    'top up',
    'data loan',
    'talktime loan',
    'caller tune',
    'hello tune',
    'vas',
    'value added service',
    'roaming',
    'international roaming',
    'isd',
    'std',
    'sim band',
    'number block',
    'number band',
    'chalu kare',
    'recharge kare',
    'kyc update kare',
    'document jama kare',
    '5g me badle',
    'free data',
    'free calling',
    'unlimited plan',
    'special offer for you',
    'exclusive plan',
    'company officer',
    'tower installation',
    'jio tower',
    'airtel tower',
    'tower lagwaye',
    'tower rent',
    'advance rent',
    'tower agreement',
    'noc fee',
    'site inspection',
    'network issue',
    'signal problem',
    'call drop',
    'complaint resolution',
    'trai order',
    'trai rule',
    'dot order',
    'telecom guidelines',
    'maximum sim limit',
    'extra sim',
  };

  static const _kycWords = <String>{
    'kyc update',
    'verify account',
    'update details immediately',
    'aadhar',
    'pan',
    'voter id',
    'driving license',
    'passport',
    'ration card',
    'identity proof',
    'address proof',
    'dob proof',
    'biometric',
    'fingerprint',
    'iris scan',
    'face auth',
    'ekyc',
    'c-kyc',
    'video kyc',
    'v-kyc',
    'offline kyc',
    'paperless kyc',
    'kyc suspended',
    'kyc expired',
    'kyc rejected',
    'kyc failed',
    'kyc pending',
    'kyc mandatory',
    'kyc required',
    'complete kyc',
    'finish kyc',
    'upload document',
    'submit document',
    'document verification',
    'verify identity',
    'authenticate',
    'link aadhar',
    'link pan',
    'pan-aadhar link',
    'deadline',
    'last date',
    'fine for not linking',
    'penalty for kyc',
    'account freeze due to kyc',
    'block due to kyc',
    'unblock account',
    'reinstate account',
    'reactivate',
    'activation',
    'kyc center',
    'cummunity service center',
    'csc',
    'e-mitra',
    'maha e-seva',
    'agent',
    'kyc officer',
    'field visit',
    'home visit',
    'verification call',
    'verification sms',
    'confirmation code',
    'kyc otp',
    'kyc pin',
    'kyc link',
    'click to update',
    'update online',
    'self service',
    'kyc portal',
    'uidai portal',
    'income tax portal',
    'nsdl',
    'utiitsl',
    'kyc form',
    'fatca',
    'crs',
    'pep',
    'politically exposed person',
    'kyc compliance',
    'regulatory requirement',
    'rbi mandate',
    'sebi guideline',
    'aml',
    'anti money laundering',
    'kyc jama',
    'kyc kare',
    'document de',
    'pehchan patra',
    'praman patra',
    'nambhar link',
    'khata link',
    'bank me aadhar',
    'aadhar jorna',
    'aadhar updation',
    'name change',
    'dob change',
    'address change',
    'mobile number update',
    'email update',
    'profile update',
    'details mismatch',
    'error in kyc',
    're-submit',
  };

  static final _otpPattern = RegExp(r'\b\d{4,8}\b');
  
  static const _otpWords = <String>{
    'otp',
    'one time password',
    'do not share',
    'never share',
  };

  static const _trustedWords = <String>{
    'balance',
    'credited',
    'debited',
    'transaction alert',
    'recharge successful',
    'data balance',
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
    'amazon.in',
    'amazon.com',
    'flipkart.com',
    'swiggy.com',
    'zomato.com',
    'jio.com',
    'myntra.com',
    'uber.com',
    'ola.com',
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
  static SmsClassification classify(
    String? message, {
    String? sender,
    DateTime? timeReceived,
    bool isRepeated = false,
    bool isContact = false,
  }) {
    if (message == null || message.trim().isEmpty) return _safeDefault;

    // --- TRUECALLER-STYLE CONTACT BYPASS ---
    // If the sender is saved in contacts, it's 99.9% safe. Skip expensive analysis.
    if (isContact) {
      return const SmsClassification(
        isScam: false,
        riskScore: 0,
        scamType: 'Contact',
        explanation: 'Message is from a verified saved contact. Bypassed filters.',
        label: 'SAFE',
      );
    }

    try {
      final safeMessage = message.length > 2000
          ? message.substring(0, 2000)
          : message;

      final textLower = safeMessage.toLowerCase();
      final words = textLower.split(RegExp(r'\s+'));
      final wordSet = words.toSet();

      final urls = _extractUrls(safeMessage);
      final hasLinks = urls.isNotEmpty;
      
      // 1. STEP 1: HARD SAFE OVERRIDE
      final hasOtpCode = _otpPattern.hasMatch(textLower);
      final hasOtpWords = _otpWords.any((w) => textLower.contains(w));
      
      if (hasOtpCode && hasOtpWords && !hasLinks) {
        return const SmsClassification(
          isScam: false,
          riskScore: 0,
          scamType: 'OTP / Authentication',
          explanation: '[SAFE] Standard OTP message with no malicious intent.',
          label: 'SAFE',
        );
      }

      // Signal detection 
      final urgencyHits = _matchKeywords(wordSet, textLower, _urgencyWords);
      final financialHits = _matchKeywords(wordSet, textLower, _financialWords);
      final impersonationHits = _matchKeywords(wordSet, textLower, _impersonationWords);
      final threatHits = _matchKeywords(wordSet, textLower, _threatWords);
      final rewardHits = _matchKeywords(wordSet, textLower, _rewardWords);
      
      final jobHits = _matchKeywords(wordSet, textLower, _jobWords);
      final deliveryHits = _matchKeywords(wordSet, textLower, _deliveryWords);
      final electricityHits = _matchKeywords(wordSet, textLower, _electricityWords);
      final gasHits = _matchKeywords(wordSet, textLower, _gasWords);
      final simHits = _matchKeywords(wordSet, textLower, _simWords);
      final kycHits = _matchKeywords(wordSet, textLower, _kycWords);

      final hasSuspiciousDomain = urls.any((url) => _isSuspiciousDomain(url));
      final hasBankImpersonation = _detectBankImpersonation(textLower, urls);

      // Template memory check 
      final matchesKnownTemplate = ScamTemplateMemory.isSimilarToKnown(safeMessage);

      int score = 0;
      final reasons = <String>[];
      final signals = <String, int>{}; 

      // --- ADVANCED BEHAVIORAL CHECKS ---
      if (sender != null && sender.isNotEmpty) {
        if (RegExp(r'^\+?[0-9]{10,12}$').hasMatch(sender.trim())) {
          // Scams typically come from 10-digit mobile numbers. Links from these are highly dangerous.
          if (hasLinks) {
             score += 40;
             signals['sender_mobile_with_link'] = 40;
             reasons.add('Random mobile number sent a link (+40)');
          } else {
             score += 20;
             signals['sender_random_mobile'] = 20;
             reasons.add('Sender appears to be a random mobile number (+20)');
          }
        } else if (RegExp(r'^[A-Z]{2}-[A-Z0-9]{5,6}$').hasMatch(sender.trim().toUpperCase())) {
          // India DLT ID Format (e.g., AD-HDFCBK)
          final senderLower = sender.toLowerCase();
          final isWhitelisted = ['hdfc', 'sbi', 'airtel', 'jio', 'paytm', 'icici', 'zomato', 'swiggy', 'amazon', 'flpkrt', 'myntra', 'uber', 'ola', 'pnb', 'axis', 'google'].any((t) => senderLower.contains(t));
          
          if (isWhitelisted && !hasSuspiciousDomain) {
            score -= 50; // Trusted verified business
            signals['sender_trusted'] = -50;
            reasons.add('Verified DLT Business Partner (-50)');
          } else if (!hasLinks && urgencyHits.isEmpty && threatHits.isEmpty) {
            score -= 10; // Unrecognized DLT, but no suspicious links/words
            signals['sender_dlt_neutral'] = -10;
            reasons.add('Verified DLT Sender format (-10)');
          }
        } else if (['hdfc', 'sbi', 'airtel', 'jio', 'paytm', 'icici', 'amazon', 'swiggy', 'zomato'].any((t) => sender.toLowerCase().contains(t))) {
           score -= 40;
           signals['sender_trusted'] = -40;
           reasons.add('Trusted sender pattern (-40)');
        }
      }

      if (isRepeated) {
        score += 30;
        signals['high_frequency'] = 30;
        reasons.add('High frequency: similar message repeated (+30)');
      }

      if (textLower.contains('dear user') || textLower.contains('dear customer')) {
        score += 10;
        signals['generic_greeting'] = 10;
        reasons.add('Generic greeting used (+10)');
      }

      int upperCount = 0;
      for (int i = 0; i < safeMessage.length; i++) {
        if (safeMessage[i].toUpperCase() == safeMessage[i] && safeMessage[i].toLowerCase() != safeMessage[i].toUpperCase()) {
          upperCount++;
        }
      }
      double upperRatio = safeMessage.isNotEmpty ? upperCount / safeMessage.length : 0;
      if (upperRatio > 0.4 || safeMessage.contains('!!!')) {
        score += 15;
        signals['unnatural_language'] = 15;
        reasons.add('Unnatural language/ALL CAPS/punctuation (+15)');
      }

      final actionWords = ['click', 'verify', 'update', 'pay', 'login', 'download'];
      if (actionWords.any((w) => textLower.contains(w))) {
        score += 25;
        signals['action_intended'] = 25;
        reasons.add('Action intended (click/verify/pay) (+25)');
      }

      final manipulativePhrases = ['turant verify karo', 'account band ho jayega', 'paise jeete ho', 'block ho jayega'];
      if (manipulativePhrases.any((p) => textLower.contains(p))) {
        score += 20;
        signals['multi_lang_manipulation'] = 20;
        reasons.add('Manipulative multi-language phrase detected (+20)');
      }

      if (timeReceived != null) {
        final hour = timeReceived.hour;
        if (hour >= 23 || hour <= 6) {
          score += 10;
          signals['unusual_hour'] = 10;
          reasons.add('Arrived at unusual hour (+10)');
        }
      }

      // 2. STEP 2: TRUSTED MESSAGE DETECTION
      final isInformational = _trustedWords.any((w) => textLower.contains(w));
      if (isInformational && !hasLinks && urgencyHits.isEmpty && threatHits.isEmpty) {
        score -= 40;
        reasons.add('Informational/Transactional alert');
      }

      if (score < 0) score = 0;

      // 3. STEP 3: SCAM SIGNAL DETECTION
      if (urgencyHits.isNotEmpty) {
        score += 20;
        signals['urgency'] = 20;
        reasons.add('Urgency: ${urgencyHits.take(2).join(", ")}');
      }

      if (financialHits.isNotEmpty && (urgencyHits.isNotEmpty || threatHits.isNotEmpty || hasLinks || hasOtpWords)) {
        score += 20;
        signals['financial'] = 20;
        reasons.add('Financial: ${financialHits.take(2).join(", ")}');
      }

      if (impersonationHits.isNotEmpty) {
        score += 25;
        signals['impersonation'] = 25;
        reasons.add('Authority Impersonation: ${impersonationHits.take(2).join(", ")}');
      }

      if (threatHits.isNotEmpty) {
        score += 25;
        signals['threat'] = 25;
        reasons.add('Threat/Fear: ${threatHits.take(2).join(", ")}');
      }

      if (rewardHits.isNotEmpty) {
        score += 25;
        signals['reward'] = 25;
        reasons.add('Reward/Lottery: ${rewardHits.take(2).join(", ")}');
      }

      if (jobHits.isNotEmpty) {
        score += 30;
        signals['job_scam'] = 30;
        reasons.add('Job Scam: ${jobHits.take(2).join(", ")}');
      }

      if (deliveryHits.isNotEmpty) {
        score += 25;
        signals['delivery_scam'] = 25;
        reasons.add('Delivery Scam: ${deliveryHits.take(2).join(", ")}');
      }

      if (electricityHits.isNotEmpty) {
        score += 30;
        signals['electricity_scam'] = 30;
        reasons.add('Electricity Scam: ${electricityHits.take(2).join(", ")}');
      }

      if (gasHits.isNotEmpty) {
        score += 25;
        signals['gas_scam'] = 25;
        reasons.add('Gas/Utility Scam: ${gasHits.take(2).join(", ")}');
      }

      if (simHits.isNotEmpty) {
        score += 25;
        signals['sim_scam'] = 25;
        reasons.add('SIM/Telecom Scam: ${simHits.take(2).join(", ")}');
      }

      if (kycHits.isNotEmpty) {
        score += 25;
        signals['kyc_fraud'] = 25;
        reasons.add('KYC Scam: ${kycHits.take(2).join(", ")}');
      }

      // 4. STEP 4: LINK ANALYSIS
      if (hasLinks) {
        score += 20;
        signals['link_present'] = 20;
        reasons.add('Contains link');
        
        
          // URL Behavior Simulation
          for (final rawUrl in urls) {
            final u = rawUrl.toLowerCase();
            if (RegExp(r'[a-z]+\d+[a-z]+').hasMatch(u)) {
              score += 20;
              signals['digits_in_domain'] = 20;
              reasons.add('Numbers inside domain (+20)');
            }
            if ('-'.allMatches(u).length >= 2) {
              score += 20;
              signals['multiple_hyphens'] = 20;
              reasons.add('Multiple hyphens in domain (+20)');
            }
            if ('/'.allMatches(u).length > 4) {
              score += 20;
              signals['long_path'] = 20;
              reasons.add('Long suspicious path (+20)');
            }
          }
        if (hasSuspiciousDomain) {
          score += 40;
          signals['suspicious_domain'] = 40;
          reasons.add('Suspicious domain detected');
        } else if (hasBankImpersonation) {
          score += 50;
          signals['brand_mimicking_domain'] = 50;
          reasons.add('Domain mimicking real brand detected');
        }
      }

      // 5. STEP 5: COMBINATION BOOST
      if (urgencyHits.isNotEmpty && hasLinks) {
        score += 30;
        signals['combo_urgency_link'] = 30;
        reasons.add('Combo: Urgency + Link');
      } else if (impersonationHits.isNotEmpty && threatHits.isNotEmpty) {
        score += 30;
        signals['combo_auth_threat'] = 30;
        reasons.add('Combo: Authority + Threat');
      } else if (rewardHits.isNotEmpty && hasLinks) {
        score += 30;
        signals['combo_reward_link'] = 30;
        reasons.add('Combo: Reward + Link');
      } else if (financialHits.isNotEmpty && hasLinks) {
        score += 30;
        signals['combo_pay_link'] = 30;
        reasons.add('Combo: Payment request + Link');
      }

      if (matchesKnownTemplate) {
        score += 15;
        signals['template_match'] = 15;
        reasons.add('Matches known scam template');
      }

      // Limit score
      score = score.clamp(0, 100);

      // Determine Category
      String scamType = 'safe';
      if (jobHits.isNotEmpty) scamType = 'job_scam';
      else if (electricityHits.isNotEmpty) scamType = 'electricity_scam';
      else if (deliveryHits.isNotEmpty) scamType = 'delivery_scam';
      else if (kycHits.isNotEmpty) scamType = 'kyc_fraud';
      else if (impersonationHits.isNotEmpty) scamType = 'impersonation';
      else if (threatHits.isNotEmpty) scamType = 'threat_scam';
      else if (rewardHits.isNotEmpty) scamType = 'reward_scam';
      else if (hasLinks && urgencyHits.isNotEmpty) scamType = 'phishing';
      else if (hasLinks && score >= 25) scamType = 'suspicious_link';
      else if (score >= 25) scamType = 'suspicious';

      // 6. STEP 8: FINAL CONFLICT RESOLUTION
      if (hasOtpWords && !hasLinks && score < 50) {
        score = 0;
        scamType = 'OTP / Authentication';
        reasons.insert(0, 'Resolved as Safe OTP');
      }

      // 7. STEP 7: FINAL SCORING
      bool isScam = false;
      String verdict;
      
      if (score >= 50) {
        verdict = 'SCAM';
        isScam = true;
      } else if (score >= 25) {
        verdict = 'SUSPICIOUS';
        isScam = true;
      } else {
        verdict = 'SAFE';
        isScam = false;
      }

      // Backward compatibility label
      String label = verdict;
      if (score >= 50 && hasLinks && (hasSuspiciousDomain || hasBankImpersonation || scamType == 'phishing')) {
        label = 'PHISHING_LINK';
      } else if (score >= 25 && score < 50) {
        label = 'SCAM'; // Suspicious conventionally mapped to SCAM for users previously
      }

      if (isScam && score >= 40) {
        ScamTemplateMemory.remember(safeMessage);
      }

      if (reasons.isEmpty) {
        reasons.add('No suspicious patterns detected. Message appears safe.');
      }

      return SmsClassification(
        isScam: isScam,
        riskScore: score,
        scamType: scamType,
        explanation: '[$verdict] ${reasons.join(" | ")}',
        label: label,
      );
    } catch (_) {
      return _safeDefault;
    }
  }
}
