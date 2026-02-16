import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Privacy-preserving phone number hashing utility.
/// Ensures phone numbers are never sent to backend in plaintext.
class PhoneHasher {
  // Salt for hashing (in production, fetch from secure backend config)
  static const String _salt = "ElderCareAI_v1_privacy_salt_2026";

  /// Hash a phone number with SHA256 + salt.
  /// Returns 64-character hex string.
  static String hashPhone(String phoneNumber) {
    // Normalize phone number first
    String normalized = _normalizePhone(phoneNumber);

    // Add salt and hash
    String salted = normalized + _salt;
    var bytes = utf8.encode(salted);
    var hash = sha256.convert(bytes);

    return hash.toString();
  }

  /// Normalize phone number to consistent format.
  /// Removes spaces, dashes, parentheses, and handles country code.
  static String _normalizePhone(String phone) {
    // Remove all non-digit characters
    String digits = phone.replaceAll(RegExp(r'[^\d]'), '');

    // Handle Indian numbers: +91 or 91 prefix
    if (digits.startsWith('91') && digits.length == 12) {
      return digits.substring(2); // Strip 91 prefix, keep 10 digits
    }

    // Handle +91 already stripped
    if (digits.length == 10) {
      return digits;
    }

    // For other formats, return as-is
    return digits;
  }

  /// Format phone number for display (add country code and spaces).
  static String formatForDisplay(String phoneNumber) {
    String normalized = _normalizePhone(phoneNumber);

    if (normalized.length == 10) {
      // Indian format: +91 XXXXX XXXXX
      return '+91 ${normalized.substring(0, 5)} ${normalized.substring(5)}';
    }

    return phoneNumber; // Return original if not 10 digits
  }
}
