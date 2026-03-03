/// Foreground SMS Listener Service
///
/// Initializes Telephony SMS listener in the MAIN isolate (foreground).
/// The background isolate listener lives in background_service.dart's onStart().
///
/// ─── REAL DEVICE SAFETY NOTES ───
/// • On some OEMs (Xiaomi, Samsung, Huawei), the app may need to be set as
///   the default SMS app to reliably receive SMS_RECEIVED broadcasts.
/// • Battery optimization MUST be disabled for this app — OEMs aggressively
///   kill background processes. Guide: https://dontkillmyapp.com
/// • Emulators are UNRELIABLE for testing SMS reception. Always test on a
///   real device with an active SIM card.
/// • Android 13+ requires explicit POST_NOTIFICATIONS permission for alerts.
/// • Some OEMs (MIUI, OneUI) delay or batch broadcasts — the listener may
///   fire with a slight delay on those devices.
library;

import 'dart:async';
import 'package:another_telephony/telephony.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_logger.dart';
import 'background_service.dart' show backgroundMessageHandler, processSms;

// ── Duplicate listener guard ──
bool _listenerInitialized = false;

// ── Dedup state (shared key with background_service.dart) ──
const String _dedupKey = 'processed_sms_hashes';
DateTime _lastProcessedAt = DateTime(2000);
const Duration _debounceInterval = Duration(seconds: 3);

String _quickHash(String text) {
  final normalized = text.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
  return normalized.hashCode.toString();
}

/// Skip OTPs and very short messages — null-safe
bool _isOtpOrCode(String? body) {
  if (body == null || body.trim().isEmpty) return true;
  final trimmed = body.trim().toLowerCase();
  if (trimmed.length < 6) return true;
  final digitCount = trimmed.replaceAll(RegExp(r'[^0-9]'), '').length;
  if (trimmed.length <= 20 && digitCount / trimmed.length > 0.6) return true;
  if (RegExp(r'\b(otp|code|verification|pin|password)\b').hasMatch(trimmed) &&
      digitCount >= 4) {
    return true;
  }
  return false;
}

/// Initialize the foreground SMS listener in the MAIN isolate.
///
/// Call this AFTER [initECAIBackground] in main.dart.
/// Safe to call multiple times — guarded by [_listenerInitialized].
Future<void> initializeSmsListener() async {
  // ── Guard: prevent duplicate listeners ──
  if (_listenerInitialized) {
    AppLogger.info(
      LogCategory.sms,
      'SMS listener already initialized, skipping duplicate call',
    );
    return;
  }

  // ── STEP 1: Check SMS permission ──
  PermissionStatus smsPermission;
  try {
    smsPermission = await Permission.sms.status;
    if (!smsPermission.isGranted) {
      smsPermission = await Permission.sms.request();
    }
  } catch (e) {
    AppLogger.error(LogCategory.sms, 'SMS permission check failed: $e');

    return;
  }

  AppLogger.info(
    LogCategory.sms,
    'SMS permission granted: ${smsPermission.isGranted}',
  );

  if (!smsPermission.isGranted) {
    AppLogger.warn(
      LogCategory.sms,
      'SMS permission denied. Listener not started. '
      'On some OEMs, the app must be set as the default SMS app.',
    );
    return;
  }

  // ── STEP 2: Also request phone permission (needed by another_telephony) ──
  try {
    final phonePermission = await Permission.phone.status;
    if (!phonePermission.isGranted) {
      await Permission.phone.request();
    }
  } catch (e) {
    // Non-fatal: phone permission is secondary
    AppLogger.warn(LogCategory.sms, 'Phone permission request failed: $e');
  }

  // ── STEP 3: Start foreground listener ──
  try {
    final Telephony telephony = Telephony.instance;

    telephony.listenIncomingSms(
      onNewMessage: (SmsMessage message) async {
        final body = message.body ?? '';
        final sender = message.address ?? 'Unknown';

        AppLogger.info(LogCategory.sms, 'FG-MAIN SMS received from $sender');

        if (body.trim().isEmpty || _isOtpOrCode(body)) {
          AppLogger.info(LogCategory.sms, 'FG-MAIN SMS ignored: empty/OTP');
          return;
        }

        // Debounce
        final now = DateTime.now();
        if (now.difference(_lastProcessedAt) < _debounceInterval) {
          AppLogger.info(LogCategory.sms, 'FG-MAIN SMS debounced');
          return;
        }
        _lastProcessedAt = now;

        try {
          // Dedup with SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          List<String> recentHashes = prefs.getStringList(_dedupKey) ?? [];
          final hash = _quickHash(body);

          if (recentHashes.contains(hash)) {
            AppLogger.info(LogCategory.sms, 'FG-MAIN SMS duplicate suppressed');
            return;
          }

          recentHashes.add(hash);
          if (recentHashes.length > 200) recentHashes.removeAt(0);
          await prefs.setStringList(_dedupKey, recentHashes);

          // 🚀 Forward to full intelligence pipeline
          AppLogger.info(LogCategory.sms, 'FG-MAIN SMS → pipeline');
          await processSms(body, sender);
        } catch (e) {
          AppLogger.error(LogCategory.sms, 'Error in FG-MAIN onNewMessage: $e');
        }
      },
      onBackgroundMessage: backgroundMessageHandler,
      listenInBackground: true,
    );

    _listenerInitialized = true;
    AppLogger.info(
      LogCategory.lifecycle,
      'Foreground SMS listener started successfully',
    );
  } catch (e) {
    AppLogger.error(LogCategory.sms, 'Failed to start SMS listener: $e');
  }
}
