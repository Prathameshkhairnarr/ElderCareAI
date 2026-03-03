class RiskModel {
  final double score;
  final String level;
  final String details;
  final int activeThreats;
  final DateTime? lastScamAt;
  final bool isVulnerable;

  RiskModel({
    required this.score,
    required this.level,
    required this.details,
    this.activeThreats = 0,
    this.lastScamAt,
    this.isVulnerable = false,
  });

  factory RiskModel.fromJson(Map<String, dynamic> json) {
    return RiskModel(
      score: (json['score'] as num).toDouble(),
      level: json['level'] as String,
      details: json['details'] as String,
      activeThreats: json['active_threats'] as int? ?? 0,
      lastScamAt: json['last_scam_at'] != null
          ? DateTime.tryParse(json['last_scam_at'])
          : null,
      isVulnerable: json['is_vulnerable'] as bool? ?? false,
    );
  }

  /// A "safe" default for when the backend is unreachable.
  static RiskModel get empty =>
      RiskModel(score: 0, level: 'Safe', details: 'Unable to load risk data.');
}
