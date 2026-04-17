class GuardianModel {
  final int id;
  final int userId;
  final String name;
  final String phone;
  final String? email;
  final bool isPrimary;
  final DateTime? createdAt;
  
  // Privacy & Access settings
  final bool canViewLocation;
  final bool canViewHealth;
  final bool receivesSOS;

  GuardianModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.phone,
    this.email,
    required this.isPrimary,
    this.createdAt,
    this.canViewLocation = false,
    this.canViewHealth = false,
    this.receivesSOS = true,
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
      canViewLocation: json['can_view_location'] ?? false,
      canViewHealth: json['can_view_health'] ?? false,
      receivesSOS: json['receives_sos'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone': phone,
      'email': email,
      'is_primary': isPrimary,
      'can_view_location': canViewLocation,
      'can_view_health': canViewHealth,
      'receives_sos': receivesSOS,
    };
  }
}
