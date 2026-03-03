class SmsModel {
  final int? id;
  final String sender;
  final String body;
  final double riskScore;
  final String category;
  final bool isFraud;
  final String explanation;
  final int? riskEntryId;
  bool isResolved;

  SmsModel({
    this.id,
    required this.sender,
    required this.body,
    required this.riskScore,
    required this.category,
    required this.isFraud,
    this.explanation = '',
    this.riskEntryId,
    this.isResolved = false,
  });

  factory SmsModel.fromJson(Map<String, dynamic> json) {
    return SmsModel(
      id: json['id'] as int?,
      sender: json['sender'] ?? 'Unknown',
      body: json['message'] ?? json['body'] ?? '',
      riskScore: (json['confidence'] as num?)?.toDouble() ?? 0,
      category: json['category'] as String? ?? 'unknown',
      isFraud: json['is_scam'] as bool? ?? false,
      explanation: json['explanation'] as String? ?? '',
      riskEntryId: json['risk_entry_id'] as int?,
      isResolved: json['is_resolved'] as bool? ?? false,
    );
  }

  /// Create from the backend /sms/analyze-sms response
  factory SmsModel.fromAnalysis(
    Map<String, dynamic> json,
    String originalMessage,
  ) {
    return SmsModel(
      id: json['id'] as int?,
      sender: 'You',
      body: originalMessage,
      riskScore: (json['confidence'] as num?)?.toDouble() ?? 0,
      category: json['category'] as String? ?? 'unknown',
      isFraud: json['is_scam'] as bool? ?? false,
      explanation: json['explanation'] as String? ?? '',
    );
  }

  /// Create from the /sms/sms-history endpoint
  factory SmsModel.fromHistory(Map<String, dynamic> json) {
    return SmsModel(
      id: json['id'] as int?,
      sender: 'Analyzed',
      body: json['message'] ?? '',
      riskScore: (json['confidence'] as num?)?.toDouble() ?? 0,
      category: json['category'] as String? ?? 'unknown',
      isFraud: json['is_scam'] as bool? ?? false,
      explanation: json['explanation'] as String? ?? '',
      riskEntryId: json['risk_entry_id'] as int?,
      isResolved: json['is_resolved'] as bool? ?? false,
    );
  }
}
