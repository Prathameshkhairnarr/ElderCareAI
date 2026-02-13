class RiskModel {
  final double score;
  final String level;
  final String details;

  RiskModel({required this.score, required this.level, required this.details});

  factory RiskModel.fromJson(Map<String, dynamic> json) {
    return RiskModel(
      score: (json['score'] as num).toDouble(),
      level: json['level'] as String,
      details: json['details'] as String,
    );
  }
}
