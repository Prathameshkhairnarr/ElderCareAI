import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/call_models.dart';
import '../utils/phone_hasher.dart';
import '../config/api_config.dart';
import 'auth_service.dart';

/// Call reputation service for scam detection.
/// Handles API calls to backend and local caching.
class ReputationService {
  // Singleton
  static final ReputationService _instance = ReputationService._internal();
  factory ReputationService() => _instance;
  ReputationService._internal();

  static const _baseUrl = ApiConfig.baseUrl;
  final _auth = AuthService();

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_auth.token != null) 'Authorization': 'Bearer ${_auth.token}',
  };

  /// Check reputation of a phone number.
  /// Returns cached result if available and fresh (< 24h).
  Future<CallReputation?> checkNumber(
    String phoneNumber, {
    int? callDuration,
    String? timeOfDay,
    bool? isVoip,
  }) async {
    try {
      // Hash phone number
      final phoneHash = PhoneHasher.hashPhone(phoneNumber);

      // Check cache first
      final cached = await _getCachedReputation(phoneHash);
      if (cached != null) {
        return cached;
      }

      // Build request body
      final body = {
        'phone_hash': phoneHash,
        if (callDuration != null || timeOfDay != null || isVoip != null)
          'metadata': {
            if (callDuration != null) 'call_duration': callDuration,
            if (timeOfDay != null) 'time_of_day': timeOfDay,
            if (isVoip != null) 'is_voip': isVoip,
          },
      };

      // API call
      final response = await http.post(
        Uri.parse('$_baseUrl/call/check-number'),
        headers: _headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reputation = CallReputation.fromJson(data);

        // Cache for 24 hours
        await _cacheReputation(phoneHash, reputation);

        return reputation;
      }

      return null;
    } catch (e) {
      print('Error checking reputation: $e');
      return null;
    }
  }

  /// Report a phone number as scam.
  Future<bool> reportNumber(
    String phoneNumber,
    ScamCategory category, {
    String? notes,
  }) async {
    try {
      final phoneHash = PhoneHasher.hashPhone(phoneNumber);

      final body = {
        'phone_hash': phoneHash,
        'category': category.value,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/call/report'),
        headers: _headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 201) {
        // Invalidate cache for this number
        await _invalidateCached(phoneHash);
        return true;
      }

      return false;
    } catch (e) {
      print('Error reporting number: $e');
      return false;
    }
  }

  /// Get user's report statistics.
  Future<Map<String, dynamic>?> getReportStats() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/call/report-stats'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }

      return null;
    } catch (e) {
      print('Error fetching report stats: $e');
      return null;
    }
  }

  // ── Cache Management ──────────────────────────────────────

  Future<CallReputation?> _getCachedReputation(String phoneHash) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'reputation_$phoneHash';
      final timestampKey = 'reputation_ts_$phoneHash';

      final cached = prefs.getString(cacheKey);
      final timestamp = prefs.getInt(timestampKey);

      if (cached != null && timestamp != null) {
        // Check if cache is still valid (24 hours)
        final age = DateTime.now().millisecondsSinceEpoch - timestamp;
        if (age < 24 * 60 * 60 * 1000) {
          return CallReputation.fromJson(jsonDecode(cached));
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> _cacheReputation(
    String phoneHash,
    CallReputation reputation,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'reputation_$phoneHash';
      final timestampKey = 'reputation_ts_$phoneHash';

      await prefs.setString(
        cacheKey,
        jsonEncode({
          'risk_score': reputation.riskScore,
          'risk_level': reputation.riskLevel,
          'category': reputation.category,
          'report_count': reputation.reportCount,
          'warning_message': reputation.warningMessage,
          'recommended_action': reputation.recommendedAction,
          'confidence': reputation.confidence,
        }),
      );
      await prefs.setInt(timestampKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      // Silent fail
    }
  }

  Future<void> _invalidateCached(String phoneHash) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('reputation_$phoneHash');
      await prefs.remove('reputation_ts_$phoneHash');
    } catch (e) {
      // Silent fail
    }
  }
}
