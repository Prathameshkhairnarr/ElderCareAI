/// Smart alert policy — prevents notification spam for guardians/elders.
/// Controls when a local notification should actually fire.
library;

class AlertPolicy {
  AlertPolicy._();

  // ── Tuning ──
  static const Duration _globalCooldown = Duration(minutes: 5);
  static const Duration _sameTypeCooldown = Duration(minutes: 30);

  // ── State (in-memory, resets on restart — acceptable) ──
  static DateTime? _lastAlertTime;
  static final Map<String, DateTime> _lastAlertByType = {};

  /// Decide if a notification should be shown.
  ///
  /// Returns `true` if the alert is allowed to fire.
  ///
  /// [currentRiskScore] — elder's rolling risk score (0–100)
  /// [smsRiskScore] — this individual SMS's score (0–100)
  /// [scamType] — category from classifier (e.g., 'financial_scam')
  static bool shouldAlert({
    required int currentRiskScore,
    required int smsRiskScore,
    required String scamType,
  }) {
    final now = DateTime.now();

    // 🚨 High-risk SMS should always alert
    if (smsRiskScore >= 45) {
      // passes threshold check
    }
    // ⚠️ Medium risk depends on global risk
    else if (smsRiskScore >= 30 && currentRiskScore >= 10) {
      // passes threshold check
    }
    // 🔴 Very high global risk user
    else if (currentRiskScore >= 25) {
      // passes threshold check
    }
    // Below all thresholds — suppress
    else {
      return false;
    }

    // Condition 2: Global cooldown (max 1 alert per 5 min)
    if (_lastAlertTime != null &&
        now.difference(_lastAlertTime!) < _globalCooldown) {
      return false;
    }

    // Condition 3: Same scam type cooldown (30 min)
    final lastForType = _lastAlertByType[scamType];
    if (lastForType != null &&
        now.difference(lastForType) < _sameTypeCooldown) {
      return false;
    }

    // ✅ Alert allowed — record it
    _lastAlertTime = now;
    _lastAlertByType[scamType] = now;
    return true;
  }

  /// Reset all state (for testing).
  static void reset() {
    _lastAlertTime = null;
    _lastAlertByType.clear();
  }
}
