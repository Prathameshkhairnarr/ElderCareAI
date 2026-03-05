import 'dart:async';
import '../services/medicine_reminder_service.dart';
import '../services/user_memory_service.dart';
import '../services/app_logger.dart';

/// Proactive AI Doctor — initiates health conversations unprompted.
///
/// Triggers:
///   - Morning greeting with medicine check
///   - Evening health check-in
///   - Inactivity alert (no interaction for X hours)
///   - Pending medicine reminders
///
/// Example prompts:
///   "Rahul ji, aapne aaj subah ki dawai li?"
///   "Good evening, how are you feeling today?"
class ProactiveHealthService {
  ProactiveHealthService._();
  static final ProactiveHealthService instance = ProactiveHealthService._();

  Timer? _checkTimer;

  /// Check every 30 minutes for proactive triggers.
  static const _checkInterval = Duration(minutes: 30);

  /// Track last user interaction time.
  DateTime _lastInteractionTime = DateTime.now();

  /// Inactivity threshold before proactive prompt.
  static const _inactivityThreshold = Duration(hours: 3);

  /// Track what prompts we've already spoken today.
  final Set<String> _spokenToday = {};
  String? _lastDate;

  /// Callback to speak a proactive message.
  /// Set by the voice controller or main app.
  void Function(String message, String locale)? onProactiveSpeak;

  /// Start proactive health monitoring.
  Future<void> start() async {
    if (_checkTimer != null) return;

    _checkTimer = Timer.periodic(_checkInterval, (_) => _checkTriggers());
    AppLogger.info(
      LogCategory.lifecycle,
      '[PROACTIVE] Proactive health service started',
    );
  }

  /// Stop proactive health monitoring.
  void stop() {
    _checkTimer?.cancel();
    _checkTimer = null;
  }

  /// Record user interaction (resets inactivity timer).
  void recordInteraction() {
    _lastInteractionTime = DateTime.now();
  }

  /// Check all proactive triggers.
  Future<void> _checkTriggers() async {
    final now = DateTime.now();

    // Reset daily tracking at midnight
    final todayStr = '${now.year}-${now.month}-${now.day}';
    if (_lastDate != todayStr) {
      _spokenToday.clear();
      _lastDate = todayStr;
    }

    // ── Morning greeting (7-9 AM) ──
    if (now.hour >= 7 && now.hour < 9 && !_spokenToday.contains('morning')) {
      _spokenToday.add('morning');
      await _speakMorningGreeting();
      return;
    }

    // ── Evening check-in (6-8 PM) ──
    if (now.hour >= 18 && now.hour < 20 && !_spokenToday.contains('evening')) {
      _spokenToday.add('evening');
      await _speakEveningCheckIn();
      return;
    }

    // ── Inactivity check ──
    if (now.difference(_lastInteractionTime) > _inactivityThreshold) {
      if (!_spokenToday.contains('inactivity_${now.hour}')) {
        _spokenToday.add('inactivity_${now.hour}');
        await _speakInactivityPrompt();
        return;
      }
    }

    // ── Pending medicine check ──
    try {
      final pending = await MedicineReminderService.instance.getPendingCount();
      if (pending > 0 && !_spokenToday.contains('pending_meds_${now.hour}')) {
        _spokenToday.add('pending_meds_${now.hour}');
        await _speakPendingMedicineReminder(pending);
      }
    } catch (e) {
      AppLogger.warn(
        LogCategory.lifecycle,
        '[PROACTIVE] Medicine check failed: $e',
      );
    }
  }

  Future<void> _speakMorningGreeting() async {
    final name = UserMemoryService.instance.userName;
    final greeting = name != null
        ? '$name ji, suprabhat! Aaj kaisi tabiyat hai? Subah ki dawai yaad rakhiyega.'
        : 'Suprabhat! Aaj kaisi tabiyat hai? Subah ki dawai yaad rakhiyega.';

    _speak(greeting);
  }

  Future<void> _speakEveningCheckIn() async {
    final name = UserMemoryService.instance.userName;
    final message = name != null
        ? '$name ji, shaam ho gayi hai. Aaj ka din kaisa raha? '
              'Raat ki dawai lena mat bhooliyega.'
        : 'Shaam ho gayi hai. Aaj ka din kaisa raha? '
              'Raat ki dawai lena mat bhooliyega.';

    _speak(message);
  }

  Future<void> _speakInactivityPrompt() async {
    final name = UserMemoryService.instance.userName;
    final message = name != null
        ? '$name ji, kaafi der se baat nahi hui. Sab theek hai? '
              'Kuch chahiye to bataiye.'
        : 'Kaafi der se baat nahi hui. Sab theek hai? '
              'Kuch chahiye to bataiye.';

    _speak(message);
  }

  Future<void> _speakPendingMedicineReminder(int count) async {
    final name = UserMemoryService.instance.userName;
    final message = name != null
        ? '$name ji, aaj $count dawai abhi baaki hai. Yaad rakhiyega.'
        : 'Aaj $count dawai abhi baaki hai. Yaad rakhiyega.';

    _speak(message);
  }

  void _speak(String message) {
    if (onProactiveSpeak != null) {
      onProactiveSpeak!(message, 'hi-IN');
    } else {
      AppLogger.info(
        LogCategory.lifecycle,
        '[PROACTIVE] Would speak: "$message" (no speaker wired)',
      );
    }
  }

  /// Clean up.
  void dispose() {
    stop();
  }
}
