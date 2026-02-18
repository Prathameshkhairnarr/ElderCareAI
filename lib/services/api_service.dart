import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/risk_model.dart';
import '../models/sms_model.dart';
import '../models/guardian_model.dart';
import '../models/alert_model.dart';
import 'auth_service.dart';

class ApiService {
  // ── Singleton ────────────────────────────────────────
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  static const _baseUrl = 'http://10.0.2.2:8001'; // Android Emulator
  // static const _baseUrl = 'http://10.0.2.2:8000'; // Android emulator

  final _auth = AuthService();

  /// Local cache of analyzed SMS for the "Recent Messages" list.
  final List<SmsModel> _smsHistory = [];

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_auth.token != null) 'Authorization': 'Bearer ${_auth.token}',
  };

  // Health Check
  Future<bool> checkHealth() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/'));
      return response.statusCode == 200;
    } catch (e) {
      print("Health check failed: $e");
      return false;
    }
  }

  // ── Risk Score ───────────────────────────────────────
  Future<RiskModel?> getRiskScore() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/risk'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        return RiskModel.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> resolveRisk(int riskEntryId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/risk/resolve/$riskEntryId'),
        headers: _headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Resolve Risk Error: $e");
      return false;
    }
  }

  // ── SMS Analysis ─────────────────────────────────────
  Future<SmsModel?> analyzeSms(String message) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/sms/analyze-sms'),
        headers: _headers,
        body: jsonEncode({'message': message}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final sms = SmsModel.fromAnalysis(data, message);
        // Deduplicate: remove existing entry with same body before inserting
        _smsHistory.removeWhere(
          (s) => s.body.trim().toLowerCase() == message.trim().toLowerCase(),
        );
        _smsHistory.insert(0, sms); // Add to history
        return sms;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ── SMS History (from backend) ────────────────────────
  Future<List<SmsModel>> getSmsHistory() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/sms/sms-history'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data
            .map((item) => SmsModel.fromHistory(item as Map<String, dynamic>))
            .toList();
      }
      return _smsHistory; // Fallback to local cache
    } catch (e) {
      print("SMS History Error: $e");
      return _smsHistory; // Fallback to local cache
    }
  }

  /// Resolve a risk entry and return the updated risk score
  Future<RiskModel?> resolveSmsRisk(int riskEntryId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/risk/resolve/$riskEntryId'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        // Fetch the updated risk score immediately
        return await getRiskScore();
      }
      return null;
    } catch (e) {
      print("Resolve Risk Error: $e");
      return null;
    }
  }

  // Legacy local cache methods
  Future<List<SmsModel>> getSmsList() async {
    return _smsHistory;
  }

  // ── SOS ──────────────────────────────────────────────
  Future<bool> triggerSos({double? lat, double? lng}) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/sos'),
        headers: _headers,
        body: jsonEncode({
          'message': 'Emergency SOS triggered from app',
          'latitude': lat,
          'longitude': lng,
        }),
      );
      print("SOS Backend Sync: ${response.statusCode}");
      return response.statusCode == 201;
    } catch (e) {
      print("SOS Backend Sync Error: $e");
      return false;
    }
  }

  // ── Contacts Sync ────────────────────────────────────
  Future<List<dynamic>?> getContacts() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/contacts/'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print("Get Contacts Error: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> addContact(Map<String, dynamic> contact) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/contacts/'),
        headers: _headers,
        body: jsonEncode(contact),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      print("Add Contact Failed: ${response.body}");
      return null;
    } catch (e) {
      print("Add Contact Error: $e");
      return null;
    }
  }

  Future<bool> deleteContact(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/contacts/$id'),
        headers: _headers,
      );
      return response.statusCode == 204;
    } catch (e) {
      print("Delete Contact Error: $e");
      return false;
    }
  }

  // ── Health Monitor ───────────────────────────────────
  Future<Map<String, dynamic>?> getHealthSummary() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/health/summary'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print("Get Health Summary Error: $e");
      return null;
    }
  }

  Future<bool> postVital(String type, double value, String unit) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/health/'),
        headers: _headers,
        body: jsonEncode({'type': type, 'value': value, 'unit': unit}),
      );
      return response.statusCode == 201;
    } catch (e) {
      print("Post Vital Error: $e");
      return false;
    }
  }

  // ── Health Profile ──────────────────────────────────
  Future<Map<String, dynamic>?> getHealthProfile() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/health/profile'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print("Get Health Profile Error: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> saveHealthProfile(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/health/profile'),
        headers: _headers,
        body: jsonEncode(data),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      print("Save Health Profile Failed: ${response.body}");
      return null;
    } catch (e) {
      print("Save Health Profile Error: $e");
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
      final response = await http.get(
        Uri.parse('$_baseUrl/alerts$query'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print("Get Alerts Error: $e");
      return null;
    }
  }

  Future<List<AlertModel>> getElderAlerts(int elderId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/guardian/elder/$elderId/alerts'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((e) => AlertModel.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      print("Get Elder Alerts Error: $e");
      return [];
    }
  }

  Future<bool> markAlertRead(int alertId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/alerts/$alertId/read'),
        headers: _headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Mark Alert Read Error: $e");
      return false;
    }
  }

  // ── Guardian Connect ─────────────────────────────────
  Future<List<GuardianModel>> getGuardians() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/guardians'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((e) => GuardianModel.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      print("Get Guardians Error: $e");
      return [];
    }
  }

  Future<GuardianModel?> addGuardian(
    String name,
    String phone, {
    String? email,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/guardians'),
        headers: _headers,
        body: jsonEncode({
          'name': name,
          'phone': phone,
          'email': email,
          'is_primary': false,
        }),
      );
      if (response.statusCode == 201) {
        return GuardianModel.fromJson(jsonDecode(response.body));
      }
      print("Add Guardian Failed: ${response.body}");
      return null;
    } catch (e) {
      print("Add Guardian Error: $e");
      return null;
    }
  }

  Future<bool> deleteGuardian(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/guardians/$id'),
        headers: _headers,
      );
      return response.statusCode == 204;
    } catch (e) {
      print("Delete Guardian Error: $e");
      return false;
    }
  }

  Future<List<ElderStatsModel>> getGuardianDashboard() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/guardian/dashboard'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> elders = data['elders'];
        return elders.map((e) => ElderStatsModel.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      print("Get Guardian Dashboard Error: $e");
      return [];
    }
  }
}
