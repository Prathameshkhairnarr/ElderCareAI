import 'package:flutter/services.dart';
import '../services/app_logger.dart';
import 'language_detector.dart';

/// Offline command result — returned when a local command is matched.
class OfflineResult {
  final String spokenResponse;
  final String? navigateTo; // route name if navigation needed

  const OfflineResult({required this.spokenResponse, this.navigateTo});
}

/// Handles basic commands locally without network access.
///
/// Supported commands:
///   - Time: "samay", "time", "kitne baje"
///   - Date: "tarikh", "date", "aaj", "din"
///   - Battery: "battery", "charge"
///   - Open health: "health profile", "sehat", "health dikhao"
///   - Open medications: "dawai", "medication", "medicine dikhao"
///
/// Returns null if no offline command matched → pipeline continues to AI.
class OfflineCommandHandler {
  OfflineCommandHandler._();
  static final OfflineCommandHandler instance = OfflineCommandHandler._();

  // Battery channel for Android
  static const _batteryChannel = MethodChannel('eldercare/battery');

  /// Try to handle the user input as a local offline command.
  /// Returns null if no match — caller should proceed to AI.
  Future<OfflineResult?> tryHandle(
    String input,
    DetectedLanguage language,
  ) async {
    final text = input.toLowerCase().trim();
    final isHindi = language != DetectedLanguage.english;

    // ── Time ──
    if (_matchesTime(text)) {
      return OfflineResult(spokenResponse: _getTimeResponse(isHindi));
    }

    // ── Date ──
    if (_matchesDate(text)) {
      return OfflineResult(spokenResponse: _getDateResponse(isHindi));
    }

    // ── Battery ──
    if (_matchesBattery(text)) {
      final response = await _getBatteryResponse(isHindi);
      return OfflineResult(spokenResponse: response);
    }

    // ── Open health profile ──
    if (_matchesHealthProfile(text)) {
      return OfflineResult(
        spokenResponse: isHindi
            ? 'Health profile khol rahi hoon.'
            : 'Opening health profile.',
        navigateTo: '/health-profile-view',
      );
    }

    // ── Open medications ──
    if (_matchesMedication(text)) {
      return OfflineResult(
        spokenResponse: isHindi
            ? 'Dawai ka section khol rahi hoon.'
            : 'Opening medication section.',
        navigateTo: '/ai-doctor',
      );
    }

    return null; // no match
  }

  // ══════════════════════════════════════════════
  //  MATCHERS
  // ══════════════════════════════════════════════

  bool _matchesTime(String text) {
    const keywords = [
      'time',
      'samay',
      'kitne baje',
      'kya time',
      'waqt',
      'baj rahe',
      'baje hain',
      'abhi kya',
      'kitna baja',
    ];
    return keywords.any((k) => text.contains(k));
  }

  bool _matchesDate(String text) {
    const keywords = [
      'date',
      'tarikh',
      'aaj kya',
      'aaj ka din',
      'din kya',
      'today',
      'kaunsa din',
      'kaun sa din',
    ];
    return keywords.any((k) => text.contains(k));
  }

  bool _matchesBattery(String text) {
    const keywords = [
      'battery',
      'charge',
      'kitna charge',
      'battery level',
      'battery status',
      'phone charge',
    ];
    return keywords.any((k) => text.contains(k));
  }

  bool _matchesHealthProfile(String text) {
    const keywords = [
      'health profile',
      'health dikhao',
      'sehat dikhao',
      'mera health',
      'health open',
      'open health',
      'health batao',
    ];
    return keywords.any((k) => text.contains(k));
  }

  bool _matchesMedication(String text) {
    const keywords = [
      'medication',
      'medicine dikhao',
      'dawai dikhao',
      'dawai ka',
      'medicines open',
      'open medicine',
      'goli dikhao',
      'reminder dikhao',
    ];
    return keywords.any((k) => text.contains(k));
  }

  // ══════════════════════════════════════════════
  //  RESPONSE BUILDERS
  // ══════════════════════════════════════════════

  String _getTimeResponse(bool hindi) {
    final now = DateTime.now();
    final hour = now.hour;
    final minute = now.minute.toString().padLeft(2, '0');

    // 12-hour format for natural speech
    final period = hour >= 12
        ? (hindi ? 'dopahar' : 'PM')
        : (hindi ? 'subah' : 'AM');
    final h12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);

    if (hindi) {
      return 'Abhi $h12 bajke $minute minute hue hain, $period.';
    } else {
      return "It's $h12:$minute $period.";
    }
  }

  String _getDateResponse(bool hindi) {
    final now = DateTime.now();
    const hindiDays = [
      'Somvar',
      'Mangalvar',
      'Budhvar',
      'Guruvar',
      'Shukravar',
      'Shanivar',
      'Ravivar',
    ];
    const englishDays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const hindiMonths = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    final day = hindi
        ? hindiDays[now.weekday - 1]
        : englishDays[now.weekday - 1];
    final month = hindiMonths[now.month - 1];

    if (hindi) {
      return 'Aaj $day hai, ${now.day} $month ${now.year}.';
    } else {
      return "Today is $day, $month ${now.day}, ${now.year}.";
    }
  }

  Future<String> _getBatteryResponse(bool hindi) async {
    try {
      final level = await _batteryChannel.invokeMethod<int>('getBatteryLevel');
      if (level != null) {
        if (hindi) {
          return 'Aapke phone ki battery $level percent hai.';
        } else {
          return 'Your phone battery is at $level percent.';
        }
      }
    } catch (e) {
      AppLogger.warn(
        LogCategory.lifecycle,
        '[OFFLINE] Battery check failed: $e',
      );
    }

    // Fallback if battery channel not available
    if (hindi) {
      return 'Battery level check nahi ho paya. Settings mein dekh sakte hain.';
    } else {
      return 'Could not check battery level. Please check in settings.';
    }
  }
}
