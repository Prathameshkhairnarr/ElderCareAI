import 'dart:async';
import '../services/medicine_reminder_service.dart';
import '../services/user_memory_service.dart';
import '../services/app_logger.dart';
import 'voice_engine.dart';

/// Smart medication voice alert system.
///
/// Periodically checks for upcoming medicine reminders and speaks
/// personalized voice alerts when it's time to take medication.
///
/// Example alert:
///   "Rahul ji, aapki diabetes ki goli lene ka samay ho gaya hai."
///
/// Must be started explicitly via [start()] and stopped via [stop()].
class MedicationVoiceAlert {
  MedicationVoiceAlert._();
  static final MedicationVoiceAlert instance = MedicationVoiceAlert._();

  Timer? _checkTimer;
  final VoiceEngine _voiceEngine = VoiceEngine();
  bool _initialized = false;

  /// Check every 60 seconds for upcoming reminders.
  static const _checkInterval = Duration(seconds: 60);

  /// Prevent repeated alerts for the same reminder within 10 minutes.
  final Set<String> _alertedIds = {};
  static const _alertCooldown = Duration(minutes: 10);
  final Map<String, DateTime> _alertTimes = {};

  /// Start the medication reminder check loop.
  Future<void> start() async {
    if (_checkTimer != null) return; // already running

    if (!_initialized) {
      await _voiceEngine.initialize();
      _initialized = true;
    }

    _checkTimer = Timer.periodic(_checkInterval, (_) => _checkReminders());
    AppLogger.info(
      LogCategory.lifecycle,
      '[MED_ALERT] Medication voice alert started',
    );
  }

  /// Stop the medication reminder check loop.
  void stop() {
    _checkTimer?.cancel();
    _checkTimer = null;
    AppLogger.info(
      LogCategory.lifecycle,
      '[MED_ALERT] Medication voice alert stopped',
    );
  }

  /// Check if any reminder is due and speak the alert.
  Future<void> _checkReminders() async {
    try {
      final service = MedicineReminderService.instance;
      final todayReminders = await service.getTodayReminders();
      final now = DateTime.now();
      final nowTime =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      for (final reminder in todayReminders) {
        if (reminder.taken) continue;

        // Check if this reminder time has arrived (within 2-minute window)
        if (_isTimeMatch(reminder.time, nowTime)) {
          // Check cooldown
          if (_alertedIds.contains(reminder.id)) {
            final lastAlert = _alertTimes[reminder.id];
            if (lastAlert != null &&
                now.difference(lastAlert) < _alertCooldown) {
              continue; // skip, already alerted recently
            }
          }

          // Speak the alert!
          await _speakReminder(reminder);
          _alertedIds.add(reminder.id);
          _alertTimes[reminder.id] = now;
        }
      }
    } catch (e) {
      AppLogger.error(LogCategory.lifecycle, '[MED_ALERT] Check failed: $e');
    }
  }

  /// Check if the reminder time matches current time (within ±2 minutes).
  bool _isTimeMatch(String reminderTime, String currentTime) {
    try {
      final rParts = reminderTime.split(':');
      final cParts = currentTime.split(':');
      final rMinutes = int.parse(rParts[0]) * 60 + int.parse(rParts[1]);
      final cMinutes = int.parse(cParts[0]) * 60 + int.parse(cParts[1]);
      return (cMinutes - rMinutes).abs() <= 2;
    } catch (_) {
      return false;
    }
  }

  /// Speak a personalized medicine reminder.
  Future<void> _speakReminder(MedicineReminder reminder) async {
    final userName = UserMemoryService.instance.userName;
    final namePrefix = userName != null ? '$userName ji, ' : '';

    final message =
        '${namePrefix}aapki ${reminder.name} lene ka samay ho gaya hai. '
        'Abhi le lijiye.';

    AppLogger.info(
      LogCategory.lifecycle,
      '[MED_ALERT] Speaking reminder: ${reminder.name} at ${reminder.time}',
    );

    try {
      await _voiceEngine.speak(message, 'hi-IN');
    } catch (e) {
      AppLogger.error(LogCategory.lifecycle, '[MED_ALERT] TTS failed: $e');
    }
  }

  /// Clean up resources.
  void dispose() {
    stop();
    _voiceEngine.dispose();
  }
}
