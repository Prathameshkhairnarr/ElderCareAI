import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Represents the currently logged-in user.
class UserProfile {
  final int id;
  final String name;
  final String phone;
  final UserRole role;

  UserProfile({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
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
    );
  }
}

enum UserRole { elder, caregiver, admin }

class AuthService {
  // ── Singleton ────────────────────────────────────────
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static const _baseUrl = 'http://10.0.2.2:8000'; // Android emulator
  // Use 'http://localhost:8000' for web / desktop

  static const _tokenKey = 'jwt_token';
  static const _userKey = 'user_data';

  String? _token;
  UserProfile? _currentUser;

  UserProfile? get currentUser => _currentUser;
  String? get token => _token;
  bool get isLoggedIn => _token != null;

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
    String? firebaseToken,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'phone': phone,
          'password': pin,
          'role': role,
          'firebase_token': firebaseToken,
        }),
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
        // You might want to throw specific errors here based on response body
        // print('Register failed: ${response.body}');
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  // ── Login ────────────────────────────────────────────
  Future<UserProfile?> login(String phone, String pin) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'username': phone, 'password': pin},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _token = data['access_token'] as String;
        _currentUser = UserProfile.fromJson(data['user']);

        // Persist
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey, _token!);
        await prefs.setString(_userKey, jsonEncode(data['user']));

        return _currentUser;
      }
      return null;
    } catch (e) {
      return null;
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
