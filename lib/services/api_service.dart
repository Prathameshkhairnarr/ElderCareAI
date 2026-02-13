import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/risk_model.dart';
import '../models/sms_model.dart';
import 'auth_service.dart';

class ApiService {
  // ── Singleton ────────────────────────────────────────
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  static const _baseUrl = 'http://10.0.2.2:8000'; // Android emulator
  // Use 'http://localhost:8000' for web / desktop

  final _auth = AuthService();

  /// Local cache of analyzed SMS for the "Recent Messages" list.
  final List<SmsModel> _smsHistory = [];

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_auth.token != null) 'Authorization': 'Bearer ${_auth.token}',
  };

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
        _smsHistory.insert(0, sms); // Add to history
        return sms;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ── SMS History (local cache) ────────────────────────
  Future<List<SmsModel>> getSmsList() async {
    // Return the locally cached analysis history.
    // In production, this could fetch from a backend endpoint.
    return _smsHistory;
  }

  // ── SOS ──────────────────────────────────────────────
  Future<bool> triggerSos() async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/sos'),
        headers: _headers,
        body: jsonEncode({'message': 'Emergency SOS triggered from app'}),
      );
      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }
}
