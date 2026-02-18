class GuardianModel {
  final int id;
  final int userId;
  final String name;
  final String phone;
  final String? email;
  final bool isPrimary;
  final DateTime? createdAt;

  GuardianModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.phone,
    this.email,
    required this.isPrimary,
    this.createdAt,
  });

  factory GuardianModel.fromJson(Map<String, dynamic> json) {
    return GuardianModel(
      id: json['id'],
      userId: json['user_id'],
      name: json['name'],
      phone: json['phone'],
      email: json['email'],
      isPrimary: json['is_primary'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone': phone,
      'email': email,
      'is_primary': isPrimary,
    };
  }
}
