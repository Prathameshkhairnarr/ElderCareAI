import '../services/app_logger.dart';

/// Central system state manager — tracks status of all active modules.
///
/// Singleton that provides a unified status report for the voice assistant.
/// When users ask "kya kya chal raha hai?" or "SMS listener active hai?",
/// this manager provides the answer.
///
/// Zero persistence needed — reflects runtime state only.
class SystemStatusManager {
  SystemStatusManager._();
  static final SystemStatusManager instance = SystemStatusManager._();

  // ══════════════════════════════════════════════════════
  //  MODULE STATUS FLAGS
  // ══════════════════════════════════════════════════════

  bool _smsListenerActive = false;
  bool _callProtectionActive = false;
  bool _sosReady = false;
  bool _healthMonitorActive = false;
  bool _backgroundServiceRunning = false;
  bool _notificationsEnabled = false;
  bool _voiceAssistantReady = false;
  bool _azureTtsActive = false;

  DateTime? _lastSmsCheckAt;
  int _smsCheckedCount = 0;

  // ── Getters ──
  bool get smsListenerActive => _smsListenerActive;
  bool get callProtectionActive => _callProtectionActive;
  bool get sosReady => _sosReady;
  bool get healthMonitorActive => _healthMonitorActive;
  bool get backgroundServiceRunning => _backgroundServiceRunning;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get voiceAssistantReady => _voiceAssistantReady;
  bool get azureTtsActive => _azureTtsActive;

  // ══════════════════════════════════════════════════════
  //  UPDATE METHODS
  // ══════════════════════════════════════════════════════

  void setSmsListener(bool active) {
    _smsListenerActive = active;
    AppLogger.info(
      LogCategory.lifecycle,
      '[STATUS] SMS listener: ${active ? "ON" : "OFF"}',
    );
  }

  void setCallProtection(bool active) => _callProtectionActive = active;
  void setSosReady(bool ready) => _sosReady = ready;
  void setHealthMonitor(bool active) => _healthMonitorActive = active;
  void setBackgroundService(bool running) =>
      _backgroundServiceRunning = running;
  void setNotifications(bool enabled) => _notificationsEnabled = enabled;
  void setVoiceAssistant(bool ready) => _voiceAssistantReady = ready;
  void setAzureTts(bool active) => _azureTtsActive = active;

  void recordSmsCheck() {
    _lastSmsCheckAt = DateTime.now();
    _smsCheckedCount++;
  }

  // ══════════════════════════════════════════════════════
  //  STATUS REPORT
  // ══════════════════════════════════════════════════════

  /// Get a map of all module statuses.
  Map<String, bool> getStatusMap() => {
    'sms_listener': _smsListenerActive,
    'call_protection': _callProtectionActive,
    'sos': _sosReady,
    'health_monitor': _healthMonitorActive,
    'background_service': _backgroundServiceRunning,
    'notifications': _notificationsEnabled,
    'voice_assistant': _voiceAssistantReady,
    'azure_tts': _azureTtsActive,
  };

  /// Count of active modules.
  int get activeModuleCount => getStatusMap().values.where((v) => v).length;

  /// Get a human-readable status report for voice output.
  String getStatusReport(bool hindi) {
    final status = getStatusMap();
    final active = <String>[];
    final inactive = <String>[];

    final labels = hindi
        ? {
            'sms_listener': 'SMS listener',
            'call_protection': 'Call protection',
            'sos': 'SOS emergency',
            'health_monitor': 'Health monitor',
            'background_service': 'Background service',
            'notifications': 'Notifications',
            'voice_assistant': 'Voice assistant',
            'azure_tts': 'Azure voice',
          }
        : {
            'sms_listener': 'SMS Listener',
            'call_protection': 'Call Protection',
            'sos': 'SOS Emergency',
            'health_monitor': 'Health Monitor',
            'background_service': 'Background Service',
            'notifications': 'Notifications',
            'voice_assistant': 'Voice Assistant',
            'azure_tts': 'Azure TTS',
          };

    for (final entry in status.entries) {
      final label = labels[entry.key] ?? entry.key;
      if (entry.value) {
        active.add(label);
      } else {
        inactive.add(label);
      }
    }

    if (hindi) {
      final report = StringBuffer();
      report.write('Abhi ${active.length} module active hain. ');
      if (active.isNotEmpty) {
        report.write('Chal rahe hain: ${active.join(", ")}. ');
      }
      if (inactive.isNotEmpty && inactive.length <= 3) {
        report.write('Band hain: ${inactive.join(", ")}.');
      }
      if (_smsCheckedCount > 0) {
        report.write(' Aaj ${_smsCheckedCount} SMS check kiye.');
      }
      return report.toString();
    } else {
      final report = StringBuffer();
      report.write('${active.length} modules are active. ');
      if (active.isNotEmpty) {
        report.write('Running: ${active.join(", ")}. ');
      }
      if (inactive.isNotEmpty && inactive.length <= 3) {
        report.write('Inactive: ${inactive.join(", ")}.');
      }
      if (_smsCheckedCount > 0) {
        report.write(' ${_smsCheckedCount} SMS checked today.');
      }
      return report.toString();
    }
  }

  /// Answer a specific module query.
  String answerModuleQuery(String moduleName, bool hindi) {
    final statusMap = {
      'sms': _smsListenerActive,
      'sms_listener': _smsListenerActive,
      'call': _callProtectionActive,
      'call_protection': _callProtectionActive,
      'sos': _sosReady,
      'health': _healthMonitorActive,
      'notification': _notificationsEnabled,
      'background': _backgroundServiceRunning,
      'voice': _voiceAssistantReady,
      'azure': _azureTtsActive,
    };

    final key = moduleName.toLowerCase();
    for (final entry in statusMap.entries) {
      if (key.contains(entry.key)) {
        final isOn = entry.value;
        if (hindi) {
          return isOn
              ? 'Ji haan, ${entry.key} abhi active hai aur chal raha hai.'
              : '${entry.key} abhi band hai.';
        } else {
          return isOn
              ? 'Yes, ${entry.key} is currently active and running.'
              : '${entry.key} is currently inactive.';
        }
      }
    }

    // No specific match — return full report
    return getStatusReport(hindi);
  }
}
