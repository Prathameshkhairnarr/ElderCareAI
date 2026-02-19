/// Client-side dynamic risk scoring engine with time-based decay.
/// Persists to SharedPreferences so score survives app restarts.
library;

import 'package:shared_preferences/shared_preferences.dart';

class RiskScoreEngine {
  RiskScoreEngine._();

  // ── Persistence Keys ──
  static const _keyScore = 'risk_engine_score';
  static const _keyLastScamAt = 'risk_engine_last_scam_at';
  static const _keyRecentScamCount = 'risk_engine_recent_scam_count';
  static const _keyRecentScamWindowStart = 'risk_engine_recent_window_start';

  // ── Tuning Constants ──
  static const int _scamContribution = 15; // points per scam SMS
  static const int _safeDecay = 1; // points removed per safe SMS
  static const double _hourlyDecay = 2.0; // points per hour since last scam
  static const int _spikeThreshold = 3; // scams in window → spike
  static const int _spikeWindowMinutes = 10;
  static const double _spikeMultiplier = 1.5;

  /// Record an SMS event and return the updated risk score.
  static Future<int> recordEvent({
    required bool isScam,
    required int riskScore,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    double current = (prefs.getDouble(_keyScore) ?? 0.0);

    if (isScam) {
      // Weight contribution by the classifier's confidence
      final double contribution =
          _scamContribution * (riskScore / 100.0).clamp(0.5, 1.0);

      // Spike detection: 3+ scams in 10 min → multiplier
      final spikeContribution = _checkSpike(prefs)
          ? contribution * _spikeMultiplier
          : contribution;

      current = (current + spikeContribution).clamp(0, 100);

      // Record timestamp for time-decay
      await prefs.setString(_keyLastScamAt, DateTime.now().toIso8601String());
    } else {
      // Safe SMS → slow decay
      current = (current - _safeDecay).clamp(0, 100);
    }

    await prefs.setDouble(_keyScore, current);
    return current.round();
  }

  /// Get the current risk score with time-based decay applied.
  static Future<int> getScore() async {
    final prefs = await SharedPreferences.getInstance();
    double raw = prefs.getDouble(_keyScore) ?? 0.0;

    // Apply hourly decay since last scam
    final lastScamStr = prefs.getString(_keyLastScamAt);
    if (lastScamStr != null) {
      final lastScam = DateTime.tryParse(lastScamStr);
      if (lastScam != null) {
        final hoursSince = DateTime.now().difference(lastScam).inMinutes / 60.0;
        final decay = hoursSince * _hourlyDecay;
        raw = (raw - decay).clamp(0, 100);
        // Persist the decayed value
        await prefs.setDouble(_keyScore, raw);
      }
    }

    return raw.round();
  }

  /// Check if we're in a scam spike (3+ scams within 10 min window).
  /// Also updates the spike tracking counters.
  static bool _checkSpike(SharedPreferences prefs) {
    final now = DateTime.now();
    final windowStartStr = prefs.getString(_keyRecentScamWindowStart);
    int count = prefs.getInt(_keyRecentScamCount) ?? 0;

    if (windowStartStr != null) {
      final windowStart = DateTime.tryParse(windowStartStr);
      if (windowStart != null &&
          now.difference(windowStart).inMinutes <= _spikeWindowMinutes) {
        // Still in current window
        count++;
        prefs.setInt(_keyRecentScamCount, count);
        return count >= _spikeThreshold;
      }
    }

    // Start new window
    prefs.setString(_keyRecentScamWindowStart, now.toIso8601String());
    prefs.setInt(_keyRecentScamCount, 1);
    return false;
  }

  /// Reset score (for testing / admin purposes).
  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyScore);
    await prefs.remove(_keyLastScamAt);
    await prefs.remove(_keyRecentScamCount);
    await prefs.remove(_keyRecentScamWindowStart);
  }
}
