class Medicine {
  final int id;
  final String name;
  final String? composition;
  final String? manufacturer;
  final double? price;
  final String? type;
  final String? packSize;

  Medicine({
    required this.id,
    required this.name,
    this.composition,
    this.manufacturer,
    this.price,
    this.type,
    this.packSize,
  });

  factory Medicine.fromJson(Map<String, dynamic> json) {
    return Medicine(
      id: json['id'],
      name: json['name'] ?? '',
      composition: json['composition'],
      manufacturer: json['manufacturer'],
      price: json['price'] != null ? (json['price'] as num).toDouble() : null,
      type: json['type'],
      packSize: json['pack_size'],
    );
  }
}

class UserMedication {
  final int id;
  final int userId;
  final Medicine medicine;
  final double? dosageValue;
  final String? dosageUnit;
  final int frequencyPerDay;
  final String? timeOfDay;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? notes;

  UserMedication({
    required this.id,
    required this.userId,
    required this.medicine,
    this.dosageValue,
    this.dosageUnit,
    required this.frequencyPerDay,
    this.timeOfDay,
    this.startDate,
    this.endDate,
    this.notes,
  });

  factory UserMedication.fromJson(Map<String, dynamic> json) {
    return UserMedication(
      id: json['id'],
      userId: json['user_id'] ?? 0,
      medicine: Medicine.fromJson(json['medicine']),
      dosageValue: json['dosage_value'] != null ? (json['dosage_value'] as num).toDouble() : null,
      dosageUnit: json['dosage_unit'],
      frequencyPerDay: json['frequency_per_day'] ?? 1,
      timeOfDay: json['time_of_day'],
      startDate: json['start_date'] != null ? DateTime.parse(json['start_date']) : null,
      endDate: json['end_date'] != null ? DateTime.parse(json['end_date']) : null,
      notes: json['notes'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'medicine_id': medicine.id,
      'dosage_value': dosageValue,
      'dosage_unit': dosageUnit,
      'frequency_per_day': frequencyPerDay,
      'time_of_day': timeOfDay,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'notes': notes,
    };
  }
}
