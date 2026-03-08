import 'dart:convert';

/// Strongly-typed health profile model — null-safe, serializable,
/// survives JSON round-trips with backward compatibility.
class HealthProfile {
  final String profileId;
  final String? name;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? bloodGroup;
  final double? heightCm;
  final double? weightKg;
  final String? medicalConditions;
  final String? emergencyPhone;
  final DateTime? lastUpdated;
  final String? city;
  final String? homeAddress;

  const HealthProfile({
    this.profileId = 'default',
    this.name,
    this.dateOfBirth,
    this.gender,
    this.bloodGroup,
    this.heightCm,
    this.weightKg,
    this.medicalConditions,
    this.emergencyPhone,
    this.lastUpdated,
    this.city,
    this.homeAddress,
  });

  /// Empty default state
  static const empty = HealthProfile();

  /// Compute age from dateOfBirth. Returns null if DOB not set.
  int? get age {
    if (dateOfBirth == null) return null;
    final now = DateTime.now();
    int years = now.year - dateOfBirth!.year;
    if (now.month < dateOfBirth!.month ||
        (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) {
      years--;
    }
    return years;
  }

  bool get isEmpty =>
      dateOfBirth == null &&
      gender == null &&
      bloodGroup == null &&
      heightCm == null &&
      weightKg == null &&
      (medicalConditions == null || medicalConditions!.isEmpty) &&
      (emergencyPhone == null || emergencyPhone!.isEmpty) &&
      (city == null || city!.isEmpty) &&
      (homeAddress == null || homeAddress!.isEmpty);

  /// Completeness score 0–100 (percentage of filled fields)
  int get completeness {
    int filled = 0;
    const total = 9;
    if (dateOfBirth != null) filled++;
    if (gender != null && gender!.isNotEmpty) filled++;
    if (bloodGroup != null && bloodGroup!.isNotEmpty) filled++;
    if (heightCm != null) filled++;
    if (weightKg != null) filled++;
    if (medicalConditions != null && medicalConditions!.isNotEmpty) filled++;
    if (emergencyPhone != null && emergencyPhone!.isNotEmpty) filled++;
    if (city != null && city!.isNotEmpty) filled++;
    if (homeAddress != null && homeAddress!.isNotEmpty) filled++;
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
    // Backward compat: if old 'age' field exists but no DOB, estimate DOB
    DateTime? dob;
    if (json['date_of_birth'] != null) {
      dob = DateTime.tryParse(json['date_of_birth'] as String);
    } else if (json['age'] != null) {
      final age = json['age'] as int;
      dob = DateTime(DateTime.now().year - age, 1, 1);
    }

    return HealthProfile(
      profileId: json['profile_id'] as String? ?? 'default',
      name: json['name'] as String?,
      dateOfBirth: dob,
      gender: json['gender'] as String?,
      bloodGroup: json['blood_group'] as String?,
      heightCm: (json['height_cm'] as num?)?.toDouble(),
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
      medicalConditions: json['medical_conditions'] as String?,
      emergencyPhone: json['emergency_contact'] as String?,
      lastUpdated: json['last_updated'] != null
          ? DateTime.tryParse(json['last_updated'] as String)
          : null,
      city: json['city'] as String?,
      homeAddress: json['home_address'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'profile_id': profileId,
      if (name != null) 'name': name,
      if (dateOfBirth != null) 'date_of_birth': dateOfBirth!.toIso8601String(),
      if (age != null) 'age': age, // Keep for backward compat with API
      if (gender != null) 'gender': gender,
      if (bloodGroup != null) 'blood_group': bloodGroup,
      if (heightCm != null) 'height_cm': heightCm,
      if (weightKg != null) 'weight_kg': weightKg,
      if (medicalConditions != null) 'medical_conditions': medicalConditions,
      if (emergencyPhone != null) 'emergency_contact': emergencyPhone,
      if (lastUpdated != null) 'last_updated': lastUpdated!.toIso8601String(),
      if (city != null) 'city': city,
      if (homeAddress != null) 'home_address': homeAddress,
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
    DateTime? dateOfBirth,
    String? gender,
    String? bloodGroup,
    double? heightCm,
    double? weightKg,
    String? medicalConditions,
    String? emergencyPhone,
    DateTime? lastUpdated,
    String? city,
    String? homeAddress,
  }) {
    return HealthProfile(
      profileId: profileId ?? this.profileId,
      name: name ?? this.name,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      medicalConditions: medicalConditions ?? this.medicalConditions,
      emergencyPhone: emergencyPhone ?? this.emergencyPhone,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      city: city ?? this.city,
      homeAddress: homeAddress ?? this.homeAddress,
    );
  }

  @override
  String toString() =>
      'HealthProfile(id=$profileId, name=$name, age=$age, completeness=$completeness%)';
}
