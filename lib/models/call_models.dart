/// Call reputation model for scam detection.
class CallReputation {
  final int riskScore; // 0-100
  final String riskLevel; // SAFE, UNKNOWN, SUSPICIOUS, HIGH
  final String? category; // loan_scam, bank_fraud, etc.
  final int reportCount;
  final String warningMessage;
  final String recommendedAction; // allow, warn_only, warn_and_silence, block
  final double confidence; // 0-1

  CallReputation({
    required this.riskScore,
    required this.riskLevel,
    this.category,
    required this.reportCount,
    required this.warningMessage,
    required this.recommendedAction,
    required this.confidence,
  });

  factory CallReputation.fromJson(Map<String, dynamic> json) {
    return CallReputation(
      riskScore: json['risk_score'] as int,
      riskLevel: json['risk_level'] as String,
      category: json['category'] as String?,
      reportCount: json['report_count'] as int,
      warningMessage: json['warning_message'] as String,
      recommendedAction: json['recommended_action'] as String,
      confidence: (json['confidence'] as num).toDouble(),
    );
  }

  bool get isHighRisk => riskLevel == 'HIGH';
  bool get isSuspicious => riskLevel == 'SUSPICIOUS' || riskLevel == 'HIGH';
  bool get shouldBlock => recommendedAction == 'block';
  bool get shouldWarn => recommendedAction != 'allow';
}

/// Scam category enum
enum ScamCategory {
  loanScam('loan_scam', 'Loan Scam'),
  bankFraud('bank_fraud', 'Bank Fraud'),
  otpScam('otp_scam', 'OTP Scam'),
  investmentFraud('investment_fraud', 'Investment Fraud'),
  impersonation('impersonation', 'Impersonation'),
  prizeScam('prize_scam', 'Prize/Lottery Scam'),
  techSupport('tech_support', 'Tech Support Scam'),
  other('other', 'Other Scam');

  final String value;
  final String label;

  const ScamCategory(this.value, this.label);

  static ScamCategory fromValue(String value) {
    return ScamCategory.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ScamCategory.other,
    );
  }
}

/// Caller information model
class CallerInfo {
  final String phoneNumber;
  final String displayNumber;
  final bool isContact;
  final String? contactName;

  CallerInfo({
    required this.phoneNumber,
    required this.displayNumber,
    this.isContact = false,
    this.contactName,
  });
}
