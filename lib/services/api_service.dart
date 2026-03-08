import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/risk_model.dart';
import '../models/sms_model.dart';
import '../models/guardian_model.dart';
import '../models/alert_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import 'auth_service.dart';
import 'resilient_http.dart';
import 'app_logger.dart';
import 'network_manager.dart';

class ApiService {
  // ── Singleton ────────────────────────────────────────
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  static const _baseUrl = ApiConfig.baseUrl;
  final _auth = AuthService();
  final _http = ResilientHttp();

  /// Local cache of analyzed SMS — bounded to 100 entries max.
  final List<SmsModel> _smsHistory = [];
  static const int _maxSmsHistory = 100;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_auth.token != null) 'Authorization': 'Bearer ${_auth.token}',
  };

  // ── Health Check ──────────────────────────────────────
  Future<bool> checkHealth() async {
    final result = await _http.get(
      Uri.parse('$_baseUrl/'),
      timeout: const Duration(seconds: 5),
      retries: 1,
    );
    if (!result.isSuccess) {
      AppLogger.warn(
        LogCategory.network,
        'Health check failed: ${result.errorMessage}',
      );
    }
    return result.isSuccess;
  }

  // ── Risk Score ───────────────────────────────────────
  Future<RiskModel?> getRiskScore() async {
    const cacheKey = 'cache_risk_score';
    try {
      if (!await NetworkManager.isOnline()) {
        AppLogger.info(
          LogCategory.network,
          'Offline: Loading /risk from cache',
        );
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString(cacheKey);
        if (cached != null) {
          return RiskModel.fromJson(
            await compute<String, dynamic>(jsonDecode, cached),
          );
        }
        return null;
      }

      final result = await _http.get(
        Uri.parse('$_baseUrl/risk'),
        headers: _headers,
      );
      if (result.isSuccess) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(cacheKey, result.body);
        return RiskModel.fromJson(
          await compute<String, dynamic>(jsonDecode, result.body),
        );
      }
      return null;
    } catch (e) {
      AppLogger.error(LogCategory.risk, 'getRiskScore error: $e');
      return null;
    }
  }

  /// Fetch an elder's risk score (guardian use).
  Future<RiskModel?> getElderRiskScore(int elderId) async {
    try {
      final result = await _http.get(
        Uri.parse('$_baseUrl/elder/risk-score?elder_id=$elderId'),
        headers: _headers,
      );
      if (result.isSuccess) {
        return RiskModel.fromJson(
          await compute<String, dynamic>(jsonDecode, result.body),
        );
      }
      return null;
    } catch (e) {
      AppLogger.error(LogCategory.risk, 'getElderRiskScore error: $e');
      return null;
    }
  }

  Future<bool> resolveRisk(int riskEntryId) async {
    try {
      final result = await _http.post(
        Uri.parse('$_baseUrl/risk/resolve/$riskEntryId'),
        headers: _headers,
      );
      return result.isSuccess;
    } catch (e) {
      AppLogger.error(LogCategory.risk, 'resolveRisk error: $e');
      return false;
    }
  }

  // ── SMS Analysis ─────────────────────────────────────
  Future<SmsModel?> analyzeSms(String message) async {
    try {
      final result = await _http.post(
        Uri.parse('$_baseUrl/sms/analyze-sms'),
        headers: _headers,
        body: jsonEncode({'message': message}),
      );
      if (result.isSuccess) {
        final data = await compute<String, dynamic>(jsonDecode, result.body);
        final sms = SmsModel.fromAnalysis(data, message);
        // Deduplicate
        _smsHistory.removeWhere(
          (s) => s.body.trim().toLowerCase() == message.trim().toLowerCase(),
        );
        _smsHistory.insert(0, sms);
        // Bound memory
        while (_smsHistory.length > _maxSmsHistory) {
          _smsHistory.removeLast();
        }
        return sms;
      }
      return null;
    } catch (e) {
      AppLogger.error(LogCategory.sms, 'analyzeSms error: $e');
      return null;
    }
  }

  // ── SMS History (from backend) ────────────────────────
  Future<List<SmsModel>> getSmsHistory() async {
    try {
      final result = await _http.get(
        Uri.parse('$_baseUrl/sms/sms-history'),
        headers: _headers,
      );
      if (result.isSuccess) {
        final List<dynamic> data = await compute<String, dynamic>(
          jsonDecode,
          result.body,
        );
        return data
            .map((item) => SmsModel.fromHistory(item as Map<String, dynamic>))
            .toList();
      }
      return _smsHistory; // Fallback to local cache
    } catch (e) {
      AppLogger.warn(LogCategory.sms, 'getSmsHistory fallback to cache: $e');
      return _smsHistory;
    }
  }

  /// Resolve a risk entry and return the updated risk score
  Future<RiskModel?> resolveSmsRisk(int riskEntryId) async {
    try {
      final result = await _http.post(
        Uri.parse('$_baseUrl/risk/resolve/$riskEntryId'),
        headers: _headers,
      );
      if (result.isSuccess) {
        return await getRiskScore();
      }
      return null;
    } catch (e) {
      AppLogger.error(LogCategory.risk, 'resolveSmsRisk error: $e');
      return null;
    }
  }

  // Legacy local cache methods
  Future<List<SmsModel>> getSmsList() async {
    return _smsHistory;
  }

  // ── SOS ──────────────────────────────────────────────
  Future<bool> triggerSos({
    double? lat,
    double? lng,
    String? idempotencyKey,
  }) async {
    try {
      final result = await _http.post(
        Uri.parse('$_baseUrl/sos'),
        headers: _headers,
        body: jsonEncode({
          'message': 'Emergency SOS triggered from app',
          'latitude': lat,
          'longitude': lng,
          if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
        }),
        timeout: const Duration(seconds: 20), // More generous for SOS
      );
      AppLogger.info(LogCategory.sos, 'SOS backend sync: ${result.statusCode}');
      return result.isSuccess;
    } catch (e) {
      AppLogger.error(LogCategory.sos, 'SOS backend sync error: $e');
      return false;
    }
  }

  // ── Contacts Sync ────────────────────────────────────
  Future<List<dynamic>?> getContacts() async {
    const cacheKey = 'cache_contacts';
    try {
      if (!await NetworkManager.isOnline()) {
        AppLogger.info(
          LogCategory.network,
          'Offline: Loading /contacts from cache',
        );
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString(cacheKey);
        if (cached != null) {
          return await compute<String, dynamic>(jsonDecode, cached);
        }
        return null;
      }

      final result = await _http.get(
        Uri.parse('$_baseUrl/contacts/'),
        headers: _headers,
      );
      if (result.isSuccess) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(cacheKey, result.body);
        return await compute<String, dynamic>(jsonDecode, result.body);
      }
      return null;
    } catch (e) {
      AppLogger.error(LogCategory.network, 'getContacts error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> addContact(Map<String, dynamic> contact) async {
    try {
      final result = await _http.post(
        Uri.parse('$_baseUrl/contacts/'),
        headers: _headers,
        body: jsonEncode(contact),
      );
      if (result.isSuccess) {
        return await compute<String, dynamic>(jsonDecode, result.body);
      }
      AppLogger.warn(
        LogCategory.network,
        'addContact failed: ${result.statusCode}',
      );
      return null;
    } catch (e) {
      AppLogger.error(LogCategory.network, 'addContact error: $e');
      return null;
    }
  }

  Future<bool> deleteContact(String id) async {
    try {
      final result = await _http.delete(
        Uri.parse('$_baseUrl/contacts/$id'),
        headers: _headers,
      );
      return result.statusCode == 204 || result.isSuccess;
    } catch (e) {
      AppLogger.error(LogCategory.network, 'deleteContact error: $e');
      return false;
    }
  }

  // ── Health Monitor ───────────────────────────────────
  Future<Map<String, dynamic>?> getHealthSummary() async {
    const cacheKey = 'cache_health_summary';
    try {
      if (!await NetworkManager.isOnline()) {
        AppLogger.info(
          LogCategory.network,
          'Offline: Loading /health/summary from cache',
        );
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString(cacheKey);
        if (cached != null) {
          return await compute<String, dynamic>(jsonDecode, cached);
        }
        return null;
      }

      final result = await _http.get(
        Uri.parse('$_baseUrl/health/summary'),
        headers: _headers,
      );
      if (result.isSuccess) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(cacheKey, result.body);
        return await compute<String, dynamic>(jsonDecode, result.body);
      }
      return null;
    } catch (e) {
      AppLogger.error(LogCategory.network, 'getHealthSummary error: $e');
      return null;
    }
  }

  Future<bool> postVital(String type, double value, String unit) async {
    try {
      final result = await _http.post(
        Uri.parse('$_baseUrl/health/'),
        headers: _headers,
        body: jsonEncode({'type': type, 'value': value, 'unit': unit}),
      );
      return result.isSuccess;
    } catch (e) {
      AppLogger.error(LogCategory.network, 'postVital error: $e');
      return false;
    }
  }

  // ── Health Profile ──────────────────────────────────
  Future<Map<String, dynamic>?> getHealthProfile() async {
    const cacheKey = 'cache_health_profile';
    try {
      if (!await NetworkManager.isOnline()) {
        AppLogger.info(
          LogCategory.network,
          'Offline: Loading /health/profile from cache',
        );
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString(cacheKey);
        if (cached != null) {
          return await compute<String, dynamic>(jsonDecode, cached);
        }
        return null;
      }

      final result = await _http.get(
        Uri.parse('$_baseUrl/health/profile'),
        headers: _headers,
      );
      if (result.isSuccess) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(cacheKey, result.body);
        return await compute<String, dynamic>(jsonDecode, result.body);
      }
      return null;
    } catch (e) {
      AppLogger.error(LogCategory.network, 'getHealthProfile error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> saveHealthProfile(
    Map<String, dynamic> data,
  ) async {
    try {
      final result = await _http.post(
        Uri.parse('$_baseUrl/health/profile'),
        headers: _headers,
        body: jsonEncode(data),
      );
      if (result.isSuccess) {
        return await compute<String, dynamic>(jsonDecode, result.body);
      }
      AppLogger.warn(
        LogCategory.network,
        'saveHealthProfile failed: ${result.statusCode}',
      );
      return null;
    } catch (e) {
      AppLogger.error(LogCategory.network, 'saveHealthProfile error: $e');
      return null;
    }
  }

  // ── Alerts ───────────────────────────────────────────
  Future<List<dynamic>?> getAlerts({bool? isRead}) async {
    try {
      String query = '';
      if (isRead != null) {
        query = '?is_read=$isRead';
      }
      final result = await _http.get(
        Uri.parse('$_baseUrl/alerts$query'),
        headers: _headers,
      );
      if (result.isSuccess) {
        return await compute<String, dynamic>(jsonDecode, result.body);
      }
      return null;
    } catch (e) {
      AppLogger.error(LogCategory.network, 'getAlerts error: $e');
      return null;
    }
  }

  Future<List<AlertModel>> getElderAlerts(int elderId) async {
    try {
      final result = await _http.get(
        Uri.parse('$_baseUrl/guardian/elder/$elderId/alerts'),
        headers: _headers,
      );
      if (result.isSuccess) {
        final List<dynamic> data = await compute<String, dynamic>(
          jsonDecode,
          result.body,
        );
        return data.map((e) => AlertModel.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      AppLogger.error(LogCategory.network, 'getElderAlerts error: $e');
      return [];
    }
  }

  Future<bool> markAlertRead(int alertId) async {
    try {
      final result = await _http.post(
        Uri.parse('$_baseUrl/alerts/$alertId/read'),
        headers: _headers,
      );
      return result.isSuccess;
    } catch (e) {
      AppLogger.error(LogCategory.network, 'markAlertRead error: $e');
      return false;
    }
  }

  Future<bool> deleteAlert(int alertId) async {
    try {
      final result = await _http.delete(
        Uri.parse('$_baseUrl/alerts/$alertId'),
        headers: _headers,
      );
      return result.statusCode == 204 || result.isSuccess;
    } catch (e) {
      AppLogger.error(LogCategory.network, 'deleteAlert error: $e');
      return false;
    }
  }

  // ── Guardian Connect ─────────────────────────────────
  Future<List<GuardianModel>> getGuardians() async {
    try {
      final result = await _http.get(
        Uri.parse('$_baseUrl/guardians'),
        headers: _headers,
      );
      if (result.isSuccess) {
        final List<dynamic> data = await compute<String, dynamic>(
          jsonDecode,
          result.body,
        );
        return data.map((e) => GuardianModel.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      AppLogger.error(LogCategory.network, 'getGuardians error: $e');
      return [];
    }
  }

  Future<GuardianModel?> addGuardian(
    String name,
    String phone, {
    String? email,
  }) async {
    try {
      final result = await _http.post(
        Uri.parse('$_baseUrl/guardians'),
        headers: _headers,
        body: jsonEncode({
          'name': name,
          'phone': phone,
          'email': email,
          'is_primary': false,
        }),
      );
      if (result.statusCode == 201 || result.isSuccess) {
        return GuardianModel.fromJson(
          await compute<String, dynamic>(jsonDecode, result.body),
        );
      }
      AppLogger.warn(
        LogCategory.network,
        'addGuardian failed: ${result.statusCode}',
      );
      return null;
    } catch (e) {
      AppLogger.error(LogCategory.network, 'addGuardian error: $e');
      return null;
    }
  }

  Future<bool> deleteGuardian(int id) async {
    try {
      final result = await _http.delete(
        Uri.parse('$_baseUrl/guardians/$id'),
        headers: _headers,
      );
      return result.statusCode == 204 || result.isSuccess;
    } catch (e) {
      AppLogger.error(LogCategory.network, 'deleteGuardian error: $e');
      return false;
    }
  }

  Future<List<ElderStatsModel>> getGuardianDashboard() async {
    try {
      final result = await _http.get(
        Uri.parse('$_baseUrl/guardian/dashboard'),
        headers: _headers,
      );
      if (result.isSuccess) {
        final data = await compute<String, dynamic>(jsonDecode, result.body);
        final List<dynamic> elders = data['elders'];
        return elders.map((e) => ElderStatsModel.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      AppLogger.error(LogCategory.network, 'getGuardianDashboard error: $e');
      return [];
    }
  }

  // ── Profile Photo (Cloud Sync) ──────────────────────
  Future<bool> uploadProfilePhoto(String base64Image) async {
    try {
      final result = await _http.post(
        Uri.parse('$_baseUrl/auth/profile-photo'),
        headers: _headers,
        body: jsonEncode({'photo': base64Image}),
        timeout: const Duration(seconds: 30),
      );
      if (result.isSuccess) {
        AppLogger.info(LogCategory.network, 'Profile photo uploaded to cloud');
        return true;
      }
      AppLogger.warn(
        LogCategory.network,
        'uploadProfilePhoto failed: ${result.statusCode}',
      );
      return false;
    } catch (e) {
      AppLogger.error(LogCategory.network, 'uploadProfilePhoto error: $e');
      return false;
    }
  }

  Future<String?> getProfilePhoto() async {
    try {
      final result = await _http.get(
        Uri.parse('$_baseUrl/auth/profile-photo'),
        headers: _headers,
        timeout: const Duration(seconds: 10),
      );
      if (result.isSuccess) {
        final data = jsonDecode(result.body);
        if (data['has_photo'] == true && data['photo'] != null) {
          return data['photo'] as String;
        }
      }
      return null;
    } catch (e) {
      AppLogger.error(LogCategory.network, 'getProfilePhoto error: $e');
      return null;
    }
  }

  // ── Change PIN (Backend) ─────────────────────────────
  /// Returns null on success, or error message string on failure.
  Future<String?> changePin(String currentPin, String newPin) async {
    try {
      final result = await _http.post(
        Uri.parse('$_baseUrl/auth/change-pin'),
        headers: _headers,
        body: jsonEncode({'current_pin': currentPin, 'new_pin': newPin}),
      );
      if (result.isSuccess) {
        AppLogger.info(LogCategory.auth, 'PIN changed via backend');
        return null; // success
      }
      // Extract error detail from backend
      try {
        final errData = jsonDecode(result.body);
        return errData['detail'] as String? ?? 'Failed to change PIN';
      } catch (_) {
        return 'Failed to change PIN (${result.statusCode})';
      }
    } catch (e) {
      AppLogger.error(LogCategory.auth, 'changePin error: $e');
      return 'Network error. Please check your connection.';
    }
  }
}
