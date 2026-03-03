import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/health_profile.dart';
import '../services/app_logger.dart';
import '../services/emergency_service.dart';
import '../services/health_profile_service.dart';
import '../services/settings_service.dart';
import '../services/system_status_manager.dart';

/// Parsed action from AI response.
class VoiceAction {
  final String action;
  final String? field;
  final dynamic value;
  final String? module;

  const VoiceAction({
    required this.action,
    this.field,
    this.value,
    this.module,
  });

  factory VoiceAction.fromJson(Map<String, dynamic> json) => VoiceAction(
    action: json['action'] as String? ?? '',
    field: json['field'] as String?,
    value: json['value'],
    module: json['module'] as String?,
  );
}

/// Result of executing a voice action.
class ActionResult {
  final bool success;
  final String spokenResponse;

  const ActionResult({required this.success, required this.spokenResponse});
}

/// Voice OS Action Handler — parses and executes JSON actions from AI.
///
/// Wired to real services:
///   - [SettingsService] for theme changes
///   - [EmergencyService] for SOS triggers
///   - [HealthProfileService] for health profile updates
///   - [SystemStatusManager] for module toggles
///   - [SharedPreferences] for user name persistence
///
/// Safety:
///   - Never crashes on malformed JSON
///   - Strips markdown wrappers (```json ... ```)
///   - Prevents duplicate execution within 2s window
///   - Logs all actions for debugging
class ActionHandler {
  ActionHandler._();
  static final ActionHandler instance = ActionHandler._();

  static const _userNameKey = 'eldercare_user_name';
  String? _userName;

  /// Duplicate execution guard — last action + timestamp.
  String? _lastActionKey;
  DateTime _lastActionTime = DateTime(2000);
  static const _dedupeWindowMs = 2000;

  /// Current user name (null if not set).
  String? get userName => _userName;

  /// Load saved user name from storage.
  Future<void> loadUserName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _userName = prefs.getString(_userNameKey);
      if (_userName != null) {
        AppLogger.info(
          LogCategory.lifecycle,
          '[ACTION] Loaded user name: $_userName',
        );
      }
    } catch (_) {}
  }

  // ══════════════════════════════════════════════════════
  //  JSON DETECTION & PARSING
  // ══════════════════════════════════════════════════════

  /// Check if AI response is a JSON action (not plain text).
  /// Handles markdown-wrapped JSON: ```json\n{...}\n```
  static bool isActionResponse(String response) {
    final clean = _stripMarkdownWrapper(response).trim();
    return clean.startsWith('{') && clean.endsWith('}');
  }

  /// Parse a JSON action from AI response.
  /// Returns null if parsing fails — never crashes.
  static VoiceAction? parseAction(String response) {
    try {
      final clean = _stripMarkdownWrapper(response).trim();
      if (!clean.startsWith('{')) return null;

      final json = jsonDecode(clean) as Map<String, dynamic>;
      if (!json.containsKey('action')) return null;

      return VoiceAction.fromJson(json);
    } catch (e) {
      AppLogger.warn(
        LogCategory.lifecycle,
        '[ACTION] JSON parse failed (treating as text): $e',
      );
      return null;
    }
  }

  /// Strip markdown code block wrappers if present.
  /// Handles: ```json\n{...}\n``` and ```\n{...}\n```
  static String _stripMarkdownWrapper(String text) {
    var clean = text.trim();

    // Remove leading ```json or ```
    if (clean.startsWith('```')) {
      final firstNewline = clean.indexOf('\n');
      if (firstNewline > 0) {
        clean = clean.substring(firstNewline + 1);
      }
    }

    // Remove trailing ```
    if (clean.endsWith('```')) {
      clean = clean.substring(0, clean.length - 3);
    }

    return clean.trim();
  }

  // ══════════════════════════════════════════════════════
  //  ACTION EXECUTOR
  // ══════════════════════════════════════════════════════

  /// Execute a parsed voice action and return what to speak.
  /// Wired to real app services. Never blocks UI. Never crashes.
  Future<ActionResult> execute(VoiceAction action, {bool hindi = true}) async {
    // ── Duplicate guard ──
    final actionKey =
        '${action.action}:${action.field}:${action.value}:${action.module}';
    final now = DateTime.now();
    if (actionKey == _lastActionKey &&
        now.difference(_lastActionTime).inMilliseconds < _dedupeWindowMs) {
      AppLogger.warn(
        LogCategory.lifecycle,
        '[ACTION] Duplicate blocked: $actionKey',
      );
      return ActionResult(
        success: false,
        spokenResponse: hindi
            ? 'Yeh abhi ho chuka hai.'
            : 'This was already done.',
      );
    }
    _lastActionKey = actionKey;
    _lastActionTime = now;

    AppLogger.info(
      LogCategory.lifecycle,
      '[ACTION] Executing: ${action.action} '
      '${action.field != null ? "field=${action.field} " : ""}'
      '${action.value != null ? "value=${action.value}" : ""}',
    );

    try {
      switch (action.action) {
        case 'change_theme':
          return await _changeTheme(action.value as String?, hindi);

        case 'send_sos':
          return await _sendSos(hindi);

        case 'update_health_profile':
          return await _updateHealthProfile(
            action.field ?? '',
            action.value?.toString() ?? '',
            hindi,
          );

        case 'toggle_module':
          return _toggleModule(
            action.module ?? '',
            action.value == true || action.value == 'true',
            hindi,
          );

        case 'save_user_name':
          return await _saveUserName(action.value?.toString() ?? '', hindi);

        default:
          return ActionResult(
            success: false,
            spokenResponse: hindi
                ? 'Yeh command samajh nahi aaya.'
                : 'I did not understand that command.',
          );
      }
    } catch (e) {
      AppLogger.error(
        LogCategory.lifecycle,
        '[ACTION] Execution failed: ${action.action} — $e',
      );
      return ActionResult(
        success: false,
        spokenResponse: hindi
            ? 'Kuch gadbad ho gayi, dobara try karein.'
            : 'Something went wrong, please try again.',
      );
    }
  }

  // ══════════════════════════════════════════════════════
  //  THEME — via SettingsService
  // ══════════════════════════════════════════════════════

  Future<ActionResult> _changeTheme(String? value, bool hindi) async {
    final isDark = value?.toLowerCase() == 'dark';
    final mode = isDark ? ThemeMode.dark : ThemeMode.light;

    // Real execution via SettingsService → notifyListeners() → UI rebuilds
    await SettingsService().updateThemeMode(mode);

    AppLogger.info(
      LogCategory.lifecycle,
      '[ACTION] Theme changed to: ${isDark ? "dark" : "light"}',
    );

    return ActionResult(
      success: true,
      spokenResponse: hindi
          ? '${isDark ? "Dark" : "Light"} mode laga diya hai.'
          : '${isDark ? "Dark" : "Light"} mode has been applied.',
    );
  }

  // ══════════════════════════════════════════════════════
  //  SOS — via EmergencyService
  // ══════════════════════════════════════════════════════

  Future<ActionResult> _sendSos(bool hindi) async {
    AppLogger.info(
      LogCategory.lifecycle,
      '[ACTION] SOS triggered via voice command',
    );

    // Fire SOS immediately — don't wait for completion to speak
    final emergency = EmergencyService();
    emergency.triggerSOS(); // fire-and-forget — don't await

    return ActionResult(
      success: true,
      spokenResponse: hindi
          ? 'SOS bhej diya gaya hai, aapke emergency contacts ko alert hoga.'
          : 'SOS has been sent, your emergency contacts will be alerted.',
    );
  }

  // ══════════════════════════════════════════════════════
  //  HEALTH PROFILE — via HealthProfileService
  // ══════════════════════════════════════════════════════

  Future<ActionResult> _updateHealthProfile(
    String field,
    String value,
    bool hindi,
  ) async {
    final healthService = HealthProfileService();
    final current = healthService.profile;

    // Map AI field names to HealthProfile.copyWith parameters
    HealthProfile? updated;
    switch (field) {
      case 'weight':
        final kg = double.tryParse(value);
        if (kg != null) updated = current.copyWith(weightKg: kg);
        break;
      case 'height':
        final cm = double.tryParse(value);
        if (cm != null) updated = current.copyWith(heightCm: cm);
        break;
      case 'age':
        final a = int.tryParse(value);
        if (a != null) updated = current.copyWith(age: a);
        break;
      case 'blood_pressure':
      case 'sugar_level':
      case 'heart_rate':
        // These don't have dedicated fields — store in medicalConditions
        final existing = current.medicalConditions ?? '';
        final combined = existing.isEmpty
            ? '$field: $value'
            : '$existing, $field: $value';
        updated = current.copyWith(medicalConditions: combined);
        break;
      default:
        return ActionResult(
          success: false,
          spokenResponse: hindi
              ? 'Yeh health field samajh nahi aaya.'
              : 'Unknown health field.',
        );
    }

    if (updated == null) {
      return ActionResult(
        success: false,
        spokenResponse: hindi
            ? 'Value sahi nahi hai, dobara boliye.'
            : 'Invalid value, please try again.',
      );
    }

    // Save to local storage
    final saved = await healthService.save(updated);

    final fieldLabels = {
      'weight': 'weight',
      'height': 'height',
      'age': hindi ? 'umar' : 'age',
      'blood_pressure': 'BP',
      'sugar_level': 'sugar level',
      'heart_rate': 'heart rate',
    };
    final label = fieldLabels[field] ?? field;

    AppLogger.info(
      LogCategory.lifecycle,
      '[ACTION] Health profile update: $field = $value (saved: $saved)',
    );

    return ActionResult(
      success: saved,
      spokenResponse: saved
          ? (hindi
                ? 'Aapka $label $value update kar diya hai.'
                : 'Your $label has been updated to $value.')
          : (hindi
                ? '$label update nahi ho paya, dobara try karein.'
                : 'Failed to update $label, please try again.'),
    );
  }

  // ══════════════════════════════════════════════════════
  //  MODULE TOGGLE — via SystemStatusManager
  // ══════════════════════════════════════════════════════

  ActionResult _toggleModule(String module, bool enable, bool hindi) {
    final statusMgr = SystemStatusManager.instance;

    switch (module) {
      case 'sms_listener':
        statusMgr.setSmsListener(enable);
        break;
      case 'call_protection':
        statusMgr.setCallProtection(enable);
        break;
      case 'health_monitor':
        statusMgr.setHealthMonitor(enable);
        break;
      case 'sos':
        statusMgr.setSosReady(enable);
        break;
      default:
        return ActionResult(
          success: false,
          spokenResponse: hindi ? 'Yeh module nahi mila.' : 'Module not found.',
        );
    }

    final moduleLabels = {
      'sms_listener': 'SMS listener',
      'call_protection': 'call protection',
      'health_monitor': 'health monitor',
      'sos': 'SOS',
    };

    final label = moduleLabels[module] ?? module;
    final stateText = enable
        ? (hindi ? 'chalu' : 'enabled')
        : (hindi ? 'band' : 'disabled');

    return ActionResult(
      success: true,
      spokenResponse: hindi
          ? '$label $stateText kar diya hai.'
          : '$label has been $stateText.',
    );
  }

  // ══════════════════════════════════════════════════════
  //  USER NAME — via SharedPreferences
  // ══════════════════════════════════════════════════════

  Future<ActionResult> _saveUserName(String name, bool hindi) async {
    if (name.isEmpty) {
      return ActionResult(
        success: false,
        spokenResponse: hindi
            ? 'Naam samajh nahi aaya, dobara boliye.'
            : 'Could not understand the name, please say again.',
      );
    }

    _userName = name;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userNameKey, name);
    } catch (_) {}

    AppLogger.info(LogCategory.lifecycle, '[ACTION] User name saved: $name');

    return ActionResult(
      success: true,
      spokenResponse: hindi
          ? '$name ji, main aapka naam yaad rakhungi.'
          : '$name, I will remember your name.',
    );
  }
}
