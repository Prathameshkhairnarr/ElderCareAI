import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'app_logger.dart';

/// Service to lookup phone number details using APILayer Number Verification API.
class PhoneLookupService {
  static const String _fallbackKey = 'KGRLVLwCoTbx6bzOcnxSrmAQbDLnUCG0';

  /// Look up phone number info (carrier, location, line type, validity).
  /// Returns parsed response map or null on failure.
  static Future<Map<String, dynamic>?> lookupNumber(String phone) async {
    try {
      // Use config key, fallback to hardcoded if dotenv not yet loaded
      final apiKey = ApiConfig.abstractPhoneApiKey.isNotEmpty
          ? ApiConfig.abstractPhoneApiKey
          : _fallbackKey;

      // Use Uri.https which automatically URL-encodes query parameters (like +)
      // APILayer needs the + for international numbers
      String cleanPhone = phone.trim();
      if (!cleanPhone.startsWith('+')) {
        cleanPhone = '+$cleanPhone';
      }

      final url = Uri.https(
        'api.apilayer.com',
        '/number_verification/validate',
        {'number': cleanPhone},
      );

      AppLogger.info(LogCategory.network, 'Phone lookup (APILayer): $cleanPhone');
      final response = await http.get(url, headers: {'apikey': apiKey});

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        AppLogger.info(LogCategory.network, 'Phone lookup success: ${data['valid']}');
        return data;
      } else {
        AppLogger.warn(
          LogCategory.network,
          'Phone lookup failed: ${response.statusCode} - ${response.body}',
        );
        return null;
      }
    } catch (e) {
      AppLogger.error(LogCategory.network, 'Phone lookup error: $e');
      return null;
    }
  }
}
