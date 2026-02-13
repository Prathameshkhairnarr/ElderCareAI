class SmsModel {
  final String sender;
  final String body;
  final double riskScore;
  final String category;
  final bool isFraud;
  final String explanation;

  SmsModel({
    required this.sender,
    required this.body,
    required this.riskScore,
    required this.category,
    required this.isFraud,
    this.explanation = '',
  });

  factory SmsModel.fromJson(Map<String, dynamic> json) {
    return SmsModel(
      sender: json['sender'] ?? 'Unknown',
      body: json['message'] ?? json['body'] ?? '',
      riskScore: (json['confidence'] as num?)?.toDouble() ?? 0,
      category: json['category'] as String? ?? 'unknown',
      isFraud: json['is_scam'] as bool? ?? false,
      explanation: json['explanation'] as String? ?? '',
    );
  }

  /// Create from the backend /sms/analyze-sms response
  factory SmsModel.fromAnalysis(
    Map<String, dynamic> json,
    String originalMessage,
  ) {
    return SmsModel(
      sender: 'You',
      body: originalMessage,
      riskScore: (json['confidence'] as num?)?.toDouble() ?? 0,
      category: json['category'] as String? ?? 'unknown',
      isFraud: json['is_scam'] as bool? ?? false,
      explanation: json['explanation'] as String? ?? '',
    );
  }
}
