class AlertModel {
  final int id;
  final String type;
  final String title;
  final String details;
  final String severity;
  bool isRead;
  final DateTime createdAt;

  AlertModel({
    required this.id,
    required this.type,
    required this.title,
    required this.details,
    required this.severity,
    required this.isRead,
    required this.createdAt,
  });

  factory AlertModel.fromJson(Map<String, dynamic> json) {
    return AlertModel(
      id: json['id'],
      type: json['alert_type'],
      title: json['title'],
      details: json['details'] ?? '',
      severity: json['severity'] ?? 'medium',
      isRead: json['is_read'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class ElderStatsModel {
  final int id; // Elder's User ID
  final String elderName;
  final String elderPhone;
  final int riskScore;
  final DateTime? lastSosAt;
  final int unreadAlertsCount;
  final List<AlertModel> recentAlerts;

  ElderStatsModel({
    required this.id,
    required this.elderName,
    required this.elderPhone,
    required this.riskScore,
    this.lastSosAt,
    required this.unreadAlertsCount,
    required this.recentAlerts,
  });

  factory ElderStatsModel.fromJson(Map<String, dynamic> json) {
    return ElderStatsModel(
      id:
          json['elder_id'] ??
          0, // Default to 0 if missing (should not happen with new backend)
      elderName: json['elder_name'],
      elderPhone: json['elder_phone'],
      riskScore: json['risk_score'],
      lastSosAt: json['last_sos_at'] != null
          ? DateTime.parse(json['last_sos_at'])
          : null,
      unreadAlertsCount: json['unread_alerts_count'],
      recentAlerts: (json['recent_alerts'] as List)
          .map((e) => AlertModel.fromJson(e))
          .toList(),
    );
  }
}
