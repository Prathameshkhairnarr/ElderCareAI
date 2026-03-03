import 'dart:convert';

/// Strongly-typed health profile model — null-safe, serializable,
/// survives JSON round-trips with backward compatibility.
class HealthProfile {
  final String profileId;
  final String? name;
  final int? age;
  final String? gender;
  final String? bloodGroup;
  final double? heightCm;
  final double? weightKg;
  final String? medicalConditions;
  final String? emergencyPhone;
  final DateTime? lastUpdated;

  const HealthProfile({
    this.profileId = 'default',
    this.name,
    this.age,
    this.gender,
    this.bloodGroup,
    this.heightCm,
    this.weightKg,
    this.medicalConditions,
    this.emergencyPhone,
    this.lastUpdated,
  });

  /// Empty default state
  static const empty = HealthProfile();

  bool get isEmpty =>
      age == null &&
      gender == null &&
      bloodGroup == null &&
      heightCm == null &&
      weightKg == null &&
      (medicalConditions == null || medicalConditions!.isEmpty) &&
      (emergencyPhone == null || emergencyPhone!.isEmpty);

  /// Completeness score 0–100 (percentage of filled fields)
  int get completeness {
    int filled = 0;
    const total = 7;
    if (age != null) filled++;
    if (gender != null && gender!.isNotEmpty) filled++;
    if (bloodGroup != null && bloodGroup!.isNotEmpty) filled++;
    if (heightCm != null) filled++;
    if (weightKg != null) filled++;
    if (medicalConditions != null && medicalConditions!.isNotEmpty) filled++;
    if (emergencyPhone != null && emergencyPhone!.isNotEmpty) filled++;
    return ((filled / total) * 100).round();
  }

  /// Auto-calculated BMI from height & weight.
  double? get bmi {
    if (heightCm == null || weightKg == null || heightCm! <= 0) return null;
    final heightM = heightCm! / 100;
    return weightKg! / (heightM * heightM);
  }

  /// Human-readable BMI category.
  String get bmiCategory {
    if (bmi == null) return 'N/A';
    if (bmi! < 18.5) return 'Underweight';
    if (bmi! < 25) return 'Normal';
    if (bmi! < 30) return 'Overweight';
    return 'Obese';
  }

  // ── Serialization ────────────────────────────

  factory HealthProfile.fromJson(Map<String, dynamic> json) {
    return HealthProfile(
      profileId: json['profile_id'] as String? ?? 'default',
      name: json['name'] as String?,
      age: json['age'] as int?,
      gender: json['gender'] as String?,
      bloodGroup: json['blood_group'] as String?,
      heightCm: (json['height_cm'] as num?)?.toDouble(),
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
      medicalConditions: json['medical_conditions'] as String?,
      emergencyPhone: json['emergency_contact'] as String?,
      lastUpdated: json['last_updated'] != null
          ? DateTime.tryParse(json['last_updated'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'profile_id': profileId,
      if (name != null) 'name': name,
      if (age != null) 'age': age,
      if (gender != null) 'gender': gender,
      if (bloodGroup != null) 'blood_group': bloodGroup,
      if (heightCm != null) 'height_cm': heightCm,
      if (weightKg != null) 'weight_kg': weightKg,
      if (medicalConditions != null) 'medical_conditions': medicalConditions,
      if (emergencyPhone != null) 'emergency_contact': emergencyPhone,
      if (lastUpdated != null) 'last_updated': lastUpdated!.toIso8601String(),
    };
  }

  /// Serialize for SharedPreferences storage
  String toJsonString() => jsonEncode(toJson());

  /// Deserialize from SharedPreferences string
  factory HealthProfile.fromJsonString(String source) {
    try {
      final map = jsonDecode(source) as Map<String, dynamic>;
      return HealthProfile.fromJson(map);
    } catch (_) {
      return HealthProfile.empty;
    }
  }

  // ── Copy with ────────────────────────────────

  HealthProfile copyWith({
    String? profileId,
    String? name,
    int? age,
    String? gender,
    String? bloodGroup,
    double? heightCm,
    double? weightKg,
    String? medicalConditions,
    String? emergencyPhone,
    DateTime? lastUpdated,
  }) {
    return HealthProfile(
      profileId: profileId ?? this.profileId,
      name: name ?? this.name,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      medicalConditions: medicalConditions ?? this.medicalConditions,
      emergencyPhone: emergencyPhone ?? this.emergencyPhone,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  String toString() =>
      'HealthProfile(id=$profileId, name=$name, completeness=$completeness%)';
}
