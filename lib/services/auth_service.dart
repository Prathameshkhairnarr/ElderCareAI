import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import 'app_logger.dart';

/// Represents the currently logged-in user.
class UserProfile {
  final int id;
  final String name;
  final String phone;
  final UserRole role;
  final bool isActive;
  final bool isPhoneVerified;
  final String? createdAt;
  final String? lastLoginAt;

  UserProfile({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    this.isActive = true,
    this.isPhoneVerified = true,
    this.createdAt,
    this.lastLoginAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as int,
      name: json['name'] as String,
      phone: json['phone'] as String,
      role: UserRole.values.firstWhere(
        (r) => r.name == (json['role'] as String),
        orElse: () => UserRole.elder,
      ),
      isActive: json['is_active'] as bool? ?? true,
      isPhoneVerified: json['is_phone_verified'] as bool? ?? true,
      createdAt: json['created_at'] as String?,
      lastLoginAt: json['last_login_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'role': role.name,
    'is_active': isActive,
    'is_phone_verified': isPhoneVerified,
    'created_at': createdAt,
    'last_login_at': lastLoginAt,
  };
}

enum UserRole { elder, guardian, admin }

class AuthService {
  // ── Singleton ────────────────────────────────────────
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // 🔴 PHYSICAL DEVICE: Your Phone & PC must be on SAME Wi-Fi. Turn off Mobile Data (5G).
  // Run 'ipconfig' to find PC IP. If fails, use Emulator.
  // 🔴 EMULATOR CONFIG: Use 10.0.2.2 for Android Emulator
  static const _baseUrl = ApiConfig.baseUrl;

  static const _tokenKey = 'jwt_token';
  static const _userKey = 'user_data';

  String? _token;
  UserProfile? _currentUser;

  UserProfile? get currentUser => _currentUser;
  String? get token => _token;
  bool get isLoggedIn => _token != null;

  static String normalizePhone(String phone) {
    // Remove all non-digits
    final digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    // Take last 10 digits if longer (e.g. 919876543210 -> 9876543210)
    if (digits.length > 10) {
      return digits.substring(digits.length - 10);
    }
    return digits;
  }

  // ── Init (call on app start to restore session) ──────
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    final userData = prefs.getString(_userKey);
    if (userData != null) {
      _currentUser = UserProfile.fromJson(jsonDecode(userData));
    }
  }

  // ── Register ─────────────────────────────────────────
  Future<bool> register({
    required String name,
    required String phone,
    required String pin,
    required String role,
  }) async {
    try {
      final normalizedPhone = AuthService.normalizePhone(phone);
      AppLogger.info(
        LogCategory.auth,
        'Attempting registration for: $name ($normalizedPhone)',
      );

      final response = await http
          .post(
            Uri.parse('$_baseUrl/auth/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'name': name,
              'phone': normalizedPhone,
              'password': pin,
              'role': role,
            }),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              AppLogger.error(
                LogCategory.auth,
                'Registration request timed out after 30 seconds',
              );
              throw Exception(
                'Connection timed out. If on real device, check IP in auth_service.dart.',
              );
            },
          );

      AppLogger.info(
        LogCategory.auth,
        'Registration response status: ${response.statusCode}',
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        _token = data['access_token'] as String;
        _currentUser = UserProfile.fromJson(data['user']);

        // Persist
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey, _token!);
        await prefs.setString(_userKey, jsonEncode(data['user']));

        return true;
      } else {
        // Extract the actual error from backend
        try {
          final errBody = jsonDecode(response.body);
          final detail = errBody['detail'] ?? 'Unknown error';
          throw Exception('$detail');
        } catch (e) {
          if (e is Exception && e.toString().contains('Exception:')) rethrow;
          throw Exception('Server error (${response.statusCode})');
        }
      }
    } on http.ClientException catch (_) {
      throw Exception(
        'Cannot reach server. Please check your internet connection.',
      );
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Network error: $e');
    }
  }

  // ── Login ────────────────────────────────────────────
  Future<UserProfile> login(String phone, String pin) async {
    try {
      final normalizedPhone = AuthService.normalizePhone(phone);
      AppLogger.info(
        LogCategory.auth,
        'Attempting login for: $normalizedPhone',
      );

      final response = await http
          .post(
            Uri.parse('$_baseUrl/auth/login'),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {'username': normalizedPhone, 'password': pin},
          )
          .timeout(
            const Duration(seconds: 10), // Reduced timeout for faster feedback
            onTimeout: () {
              throw Exception(
                'Connection timed out. Check IP & ensure Phone/PC are on same Wi-Fi.',
              );
            },
          );

      AppLogger.info(
        LogCategory.auth,
        'Login response status: ${response.statusCode}',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _token = data['access_token'] as String;
        _currentUser = UserProfile.fromJson(data['user']);

        // Persist
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey, _token!);
        await prefs.setString(_userKey, jsonEncode(data['user']));

        return _currentUser!;
      } else if (response.statusCode == 401) {
        throw Exception('Invalid phone number or PIN');
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } on http.ClientException catch (_) {
      throw Exception(
        'Cannot reach server. Check IP in auth_service.dart or Firewall.',
      );
    } catch (e) {
      if (e.toString().contains('Exception:')) rethrow;
      throw Exception('Login failed: $e');
    }
  }

  // ── Logout ───────────────────────────────────────────
  Future<void> logout() async {
    _token = null;
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }
}
