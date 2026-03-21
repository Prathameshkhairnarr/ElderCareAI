import 'dart:collection';
import '../services/settings_service.dart';
import '../services/app_logger.dart';
import '../voice/voice_engine.dart';

/// Priority levels for voice alerts.
enum AlertPriority { high, medium, low }

/// Categories of voice alerts — each can be toggled independently.
enum AlertCategory { scam, medication, health, sos, callWarning, system }

/// Centralized voice alert service with smart spam filtering.
///
/// Features:
///   - Priority-based interrupt (HIGH interrupts current speech)
///   - Duplicate suppression (same message within 30s)
///   - Rate limiting (max 5 alerts per minute)
///   - Per-category and master toggle via [SettingsService]
///   - Logging with [VOICE_ALERT] prefix
///
/// Usage:
/// ```dart
/// await VoiceAlertService().speakAlert(
///   'Warning! Yeh message scam ho sakta hai.',
///   priority: AlertPriority.high,
///   category: AlertCategory.scam,
/// );
/// ```
class VoiceAlertService {
  // ── Singleton ──
  static final VoiceAlertService _instance = VoiceAlertService._internal();
  factory VoiceAlertService() => _instance;
  VoiceAlertService._internal();

  final VoiceEngine _voiceEngine = VoiceEngine();
  final SettingsService _settings = SettingsService();
  bool _initialized = false;

  // ── Spam prevention state ──
  final LinkedHashMap<String, DateTime> _recentAlerts = LinkedHashMap();
  static const Duration _duplicateCooldown = Duration(seconds: 30);
  static const int _maxAlertsPerMinute = 5;
  final List<DateTime> _alertTimestamps = [];

  // ── Initialize ──
  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await _voiceEngine.initialize();
    _initialized = true;
    AppLogger.info(
      LogCategory.lifecycle,
      '[VOICE_ALERT] Service initialized',
    );
  }

  // ══════════════════════════════════════════════════════
  //  PUBLIC API
  // ══════════════════════════════════════════════════════

  /// Speak an alert if it passes all filters.
  ///
  /// Returns `true` if the alert was spoken, `false` if skipped.
  Future<bool> speakAlert(
    String message, {
    AlertPriority priority = AlertPriority.medium,
    AlertCategory category = AlertCategory.system,
    String locale = 'hi-IN',
  }) async {
    // ── Master toggle check ──
    if (!_settings.voiceFeedback) {
      AppLogger.info(
        LogCategory.lifecycle,
        '[VOICE_ALERT] skipped: master toggle OFF',
      );
      return false;
    }

    // ── Category toggle check ──
    if (!_isCategoryEnabled(category)) {
      AppLogger.info(
        LogCategory.lifecycle,
        '[VOICE_ALERT] skipped: category ${category.name} disabled',
      );
      return false;
    }

    // ── Priority filter (LOW ignored by default) ──
    if (priority == AlertPriority.low) {
      AppLogger.info(
        LogCategory.lifecycle,
        '[VOICE_ALERT] skipped: low priority',
      );
      return false;
    }

    // ── Duplicate check ──
    if (_isDuplicate(message)) {
      AppLogger.info(
        LogCategory.lifecycle,
        '[VOICE_ALERT] skipped: duplicate within ${_duplicateCooldown.inSeconds}s',
      );
      return false;
    }

    // ── Rate limit check ──
    if (_isRateLimited()) {
      AppLogger.info(
        LogCategory.lifecycle,
        '[VOICE_ALERT] skipped: rate limited ($_maxAlertsPerMinute/min)',
      );
      return false;
    }

    // ── Priority interrupt ──
    if (priority == AlertPriority.high && _voiceEngine.isSpeaking) {
      AppLogger.info(
        LogCategory.lifecycle,
        '[VOICE_ALERT] HIGH priority — interrupting current speech',
      );
      await _voiceEngine.stop();
    }

    // ── Speak! ──
    await _ensureInitialized();

    AppLogger.info(
      LogCategory.lifecycle,
      '[VOICE_ALERT] speaking: ${category.name} (${priority.name}) — '
      '"${message.length > 60 ? '${message.substring(0, 60)}...' : message}"',
    );

    _recordAlert(message);

    try {
      await _voiceEngine.speak(message, locale);
      return true;
    } catch (e) {
      AppLogger.error(
        LogCategory.lifecycle,
        '[VOICE_ALERT] TTS failed: $e',
      );
      return false;
    }
  }

  /// Stop current voice alert playback.
  Future<void> stop() async {
    await _voiceEngine.stop();
  }

  // ══════════════════════════════════════════════════════
  //  CATEGORY SETTINGS
  // ══════════════════════════════════════════════════════

  bool _isCategoryEnabled(AlertCategory category) {
    switch (category) {
      case AlertCategory.scam:
        return _settings.voiceAlertScam;
      case AlertCategory.medication:
        return _settings.voiceAlertMedicine;
      case AlertCategory.health:
        return _settings.voiceAlertHealth;
      case AlertCategory.sos:
        return _settings.voiceAlertSos;
      case AlertCategory.callWarning:
        return _settings.voiceAlertCallWarning;
      case AlertCategory.system:
        return true; // system alerts always pass category check
    }
  }

  // ══════════════════════════════════════════════════════
  //  SPAM PREVENTION
  // ══════════════════════════════════════════════════════

  /// Check if the same message was spoken recently.
  bool _isDuplicate(String message) {
    final key = message.toLowerCase().trim();
    final lastTime = _recentAlerts[key];
    if (lastTime != null &&
        DateTime.now().difference(lastTime) < _duplicateCooldown) {
      return true;
    }
    return false;
  }

  /// Check if we've exceeded the rate limit.
  bool _isRateLimited() {
    final now = DateTime.now();
    // Remove timestamps older than 1 minute
    _alertTimestamps.removeWhere(
      (t) => now.difference(t) > const Duration(minutes: 1),
    );
    return _alertTimestamps.length >= _maxAlertsPerMinute;
  }

  /// Record an alert for dedup and rate tracking.
  void _recordAlert(String message) {
    final key = message.toLowerCase().trim();
    _recentAlerts[key] = DateTime.now();

    // Keep only last 50 entries to prevent memory leak
    while (_recentAlerts.length > 50) {
      _recentAlerts.remove(_recentAlerts.keys.first);
    }

    _alertTimestamps.add(DateTime.now());
  }
}
