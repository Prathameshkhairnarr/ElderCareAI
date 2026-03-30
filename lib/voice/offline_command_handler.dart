import 'package:flutter/services.dart';
import 'dart:convert';
import '../services/app_logger.dart';
import 'language_detector.dart';

/// Offline command result — returned when a local command is matched.
class OfflineResult {
  final String? spokenResponse;
  final String? navigateTo; 
  final String? actionJson; // For layer 3 & 4 direct actions

  const OfflineResult({this.spokenResponse, this.navigateTo, this.actionJson});
}

/// Strict Priority-Based Routing Engine for Voice OS.
/// Bypasses AI instantly if confidence is high for known offline actions.
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

    // ── Layer 2: Time, Date, Battery (Instant Response) ──
    if (_matchesTime(text)) {
      return OfflineResult(spokenResponse: _getTimeResponse(isHindi));
    }

    if (_matchesDate(text)) {
      return OfflineResult(spokenResponse: _getDateResponse(isHindi));
    }

    if (_matchesBattery(text)) {
      final response = await _getBatteryResponse(isHindi);
      return OfflineResult(spokenResponse: response);
    }

    // ── Layer 3: App Command & Navigation ──
    if (_matchesDarkMode(text)) {
      return OfflineResult(
        spokenResponse: isHindi ? 'Dark mode on kar rahi hoon.' : 'Enabling dark mode.',
        actionJson: jsonEncode({"action": "change_theme", "value": "dark"})
      );
    }

    if (RegExp(r'(health profile|health dikhao|sehat dikhao|open health|स्वास्थ्य प्रोफाइल|सेहत दिखाओ)', caseSensitive: false).hasMatch(text)) {
      return OfflineResult(
        spokenResponse: isHindi ? 'Health profile khol rahi hoon.' : 'Opening health profile.',
        actionJson: jsonEncode({"action": "navigate", "value": "health_profile"}),
        navigateTo: '/health-profile-view',
      );
    }

    if (RegExp(r'(medication|medicine dikhao|dawai dikhao|open medicine|दवा|दवाइयां|मेडिसिन दिखाओ)', caseSensitive: false).hasMatch(text)) {
      return OfflineResult(
        spokenResponse: isHindi ? 'Dawai ka list khol rahi hoon.' : 'Opening medication list.',
        actionJson: jsonEncode({"action": "navigate", "value": "medication"}),
        navigateTo: '/ai-doctor',
      );
    }

    // ── Layer 4: Health Data Update (Extracting details locally) ──
    final weightMatch = RegExp(r'(weight|wazan)[\s:]*(\d{2,3})', caseSensitive: false).firstMatch(text);
    if (weightMatch != null) {
      final weightVal = weightMatch.group(2)!;
      return OfflineResult(
        spokenResponse: isHindi ? 'Aapka wazan $weightVal kilo save kar liya gaya hai.' : 'Your weight of $weightVal kg has been saved.',
        actionJson: jsonEncode({"action": "update_health_profile", "field": "weight", "value": weightVal})
      );
    }

    final sugarMatch = RegExp(r'(sugar|sugar level)[\s:]*(\d{2,3})', caseSensitive: false).firstMatch(text);
    if (sugarMatch != null) {
      final sugarVal = sugarMatch.group(2)!;
      return OfflineResult(
        spokenResponse: isHindi ? 'Aapka sugar level $sugarVal record kar liya.' : 'Your sugar level of $sugarVal has been recorded.',
        actionJson: jsonEncode({"action": "update_health_profile", "field": "sugar_level", "value": sugarVal})
      );
    }

    // Layer 5 Fallthrough -> Null -> Goes to Azure AI
    return null;
  }

  // ══════════════════════════════════════════════
  //  FUZZY / REGEX MATCHERS
  // ══════════════════════════════════════════════

  bool _matchesTime(String text) {
    // Removed \b because Dart word boundaries do not work with Devanagari Unicode
    final reg = RegExp(r'(time|tym|samay|waqt|kitne baje|kitne bje|kya time|kitna baja|kis time|टाइम|समय|कितने बजे|वक़्त|बज रहे)', caseSensitive: false);
    return reg.hasMatch(text);
  }

  bool _matchesDate(String text) {
    final reg = RegExp(r'(date|tarikh|tareek|aaj kya|aaj ka din|din kya|today|kaunsa din|kaun sa din|aj date|डेट|तारीख|आज|दिन क्या|कौन सा दिन)', caseSensitive: false);
    return reg.hasMatch(text);
  }

  bool _matchesBattery(String text) {
    final reg = RegExp(r'(battery|batery|charge|charg|kitna charge|phone charge|बैटरी|चार्ज|फ़ोन चार्ज)', caseSensitive: false);
    return reg.hasMatch(text);
  }

  bool _matchesDarkMode(String text) {
    final reg = RegExp(r'(dark mode|theme dark|theme change|black theme|kala theme|डार्क मोड|थीम बदलें|काला थीम)', caseSensitive: false);
    return reg.hasMatch(text);
  }

  // ══════════════════════════════════════════════
  //  RESPONSE BUILDERS (Direct & Non-Conversational)
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
      return 'Ji, abhi $h12 bajke $minute minute hue hain, $period.';
    } else {
      return "Sure, it is currently $h12:$minute $period.";
    }
  }

  String _getDateResponse(bool hindi) {
    final now = DateTime.now();
    const hindiDays = [
      'Somvar', 'Mangalvar', 'Budhvar', 'Guruvar', 'Shukravar', 'Shanivar', 'Ravivar'
    ];
    const englishDays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    const hindiMonths = [
      'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August',
      'September', 'October', 'November', 'December'
    ];

    final day = hindi ? hindiDays[now.weekday - 1] : englishDays[now.weekday - 1];
    final month = hindiMonths[now.month - 1];

    if (hindi) {
      return 'Ji, aaj $day hai, ${now.day} $month ${now.year}.';
    } else {
      return "Yes, today is $day, $month ${now.day}, ${now.year}.";
    }
  }

  Future<String> _getBatteryResponse(bool hindi) async {
    try {
      final level = await _batteryChannel.invokeMethod<int>('getBatteryLevel');
      if (level != null) {
        if (hindi) {
          return 'Ji, aapke phone ki battery $level percent hai.';
        } else {
          return 'Your phone battery is at $level percent.';
        }
      }
    } catch (e) {
      AppLogger.warn(LogCategory.lifecycle, '[OFFLINE] Battery check failed: $e');
    }

    if (hindi) {
      return 'Ji, battery check nahi ho paya.';
    } else {
      return 'Could not check battery level at this moment.';
    }
  }
}
