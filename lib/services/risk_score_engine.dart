/// Client-side dynamic risk scoring engine with time-based decay.
/// Persists to SharedPreferences so score survives app restarts.
///
/// HARDENED: all SharedPreferences writes use await, score always bounded 0–100.
library;

import 'package:shared_preferences/shared_preferences.dart';
import 'app_logger.dart';

class RiskScoreEngine {
  RiskScoreEngine._();

  // ── Persistence Keys ──
  static const _keyScore = 'risk_engine_score';
  static const _keyLastScamAt = 'risk_engine_last_scam_at';
  static const _keyRecentScamCount = 'risk_engine_recent_scam_count';
  static const _keyRecentScamWindowStart = 'risk_engine_recent_window_start';
  static const _keyLastRiskEventAt = 'risk_engine_last_risk_event_at';
  static const _keyLastDecayCheckAt = 'risk_engine_last_decay_check_at';

  // ── Tuning Constants ──
  static const int _safeDecay = 1; // points removed per safe SMS
  static const double _hourlyDecay = 2.0; // points per hour since last scam
  static const int _spikeThreshold = 3; // scams in window → spike
  static const int _spikeWindowMinutes = 10;
  static const double _spikeMultiplier = 1.5;

  // ── Fast Exponential Decay ──
  static const int _decayWindowSeconds = 30;
  static const double _decayMultiplier = 0.8; // retain 80% each window

  /// Record an SMS event and return the updated risk score.
  static Future<int> recordEvent({
    required bool isScam,
    required int riskScore,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      double current = (prefs.getDouble(_keyScore) ?? 0.0);

      if (isScam) {
        // 🧠 Adaptive bump based on severity
        final int bump = riskScore >= 70
            ? 10
            : riskScore >= 40
            ? 6
            : 3;

        // Spike detection: 3+ scams in 10 min → multiplier
        final double spikeContribution = await _checkSpike(prefs)
            ? bump * _spikeMultiplier
            : bump.toDouble();

        current = (current + spikeContribution).clamp(0, 100);

        // Record timestamp for time-decay
        await prefs.setString(_keyLastScamAt, DateTime.now().toIso8601String());
      } else {
        // Safe SMS → slow decay
        current = (current - _safeDecay).clamp(0, 100);
      }

      await prefs.setDouble(_keyScore, current);
      // Stamp last risk event + decay check time
      final nowStr = DateTime.now().toIso8601String();
      await prefs.setString(_keyLastRiskEventAt, nowStr);
      await prefs.setString(_keyLastDecayCheckAt, nowStr);
      return current.round();
    } catch (e) {
      AppLogger.error(
        LogCategory.risk,
        'RiskScoreEngine.recordEvent error: $e',
      );
      return 0;
    }
  }

  /// Get the current risk score with time-based decay applied.
  static Future<int> getScore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      double raw = prefs.getDouble(_keyScore) ?? 0.0;

      // Apply hourly decay since last scam
      final lastScamStr = prefs.getString(_keyLastScamAt);
      if (lastScamStr != null) {
        final lastScam = DateTime.tryParse(lastScamStr);
        if (lastScam != null) {
          final hoursSince =
              DateTime.now().difference(lastScam).inMinutes / 60.0;
          final decay = hoursSince * _hourlyDecay;
          raw = (raw - decay).clamp(0, 100);
          // Persist the decayed value
          await prefs.setDouble(_keyScore, raw);
        }
      }

      return raw.round();
    } catch (e) {
      AppLogger.error(LogCategory.risk, 'RiskScoreEngine.getScore error: $e');
      return 0;
    }
  }

  /// Check if we're in a scam spike (3+ scams within 10 min window).
  /// Also updates the spike tracking counters.
  /// FIXED: all prefs writes now use await.
  static Future<bool> _checkSpike(SharedPreferences prefs) async {
    try {
      final now = DateTime.now();
      final windowStartStr = prefs.getString(_keyRecentScamWindowStart);
      int count = prefs.getInt(_keyRecentScamCount) ?? 0;

      if (windowStartStr != null) {
        final windowStart = DateTime.tryParse(windowStartStr);
        if (windowStart != null &&
            now.difference(windowStart).inMinutes <= _spikeWindowMinutes) {
          // Still in current window
          count++;
          await prefs.setInt(_keyRecentScamCount, count);
          return count >= _spikeThreshold;
        }
      }

      // Start new window
      await prefs.setString(_keyRecentScamWindowStart, now.toIso8601String());
      await prefs.setInt(_keyRecentScamCount, 1);
      return false;
    } catch (e) {
      AppLogger.error(
        LogCategory.risk,
        'RiskScoreEngine._checkSpike error: $e',
      );
      return false;
    }
  }

  /// Apply fast exponential time-based decay.
  ///
  /// Called every 30 seconds by RiskScoreProvider's decay timer.
  /// For each 30-second window elapsed since last check:
  ///   newScore = score * 0.8
  ///
  /// Handles missed windows (app was killed) by computing N = elapsed / 30
  /// and applying score * 0.8^N in one shot.
  ///
  /// Idempotent: safe across app restarts (uses SharedPreferences timestamps).
  /// Returns the updated score.
  static Future<int> applyTimeDecay() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      double current = prefs.getDouble(_keyScore) ?? 0.0;

      if (current <= 0) return 0;

      // Use lastDecayCheckAt for precise window tracking
      final lastCheckStr = prefs.getString(_keyLastDecayCheckAt);
      if (lastCheckStr == null) {
        // No decay check recorded yet — stamp now and skip
        await prefs.setString(
          _keyLastDecayCheckAt,
          DateTime.now().toIso8601String(),
        );
        return current.round();
      }

      final lastCheck = DateTime.tryParse(lastCheckStr);
      if (lastCheck == null) return current.round();

      final now = DateTime.now();
      final elapsedSeconds = now.difference(lastCheck).inSeconds;

      if (elapsedSeconds < _decayWindowSeconds) {
        return current.round(); // Not enough time elapsed
      }

      // How many 30-second windows have passed?
      final int loops = elapsedSeconds ~/ _decayWindowSeconds;
      final int oldScore = current.round();

      // Apply exponential decay: score * 0.8^loops
      for (int i = 0; i < loops; i++) {
        current = current * _decayMultiplier;
        if (current < 1) {
          current = 0;
          break;
        }
      }

      current = current.clamp(0, 100);
      final int newScore = current.round();

      // Persist only if changed
      if (oldScore != newScore) {
        await prefs.setDouble(_keyScore, current);
        AppLogger.info(
          LogCategory.risk,
          '[RISK][INFO] Risk score decayed: $oldScore → $newScore (${loops}x windows)',
        );
      }

      // Always update decay check timestamp
      await prefs.setString(_keyLastDecayCheckAt, now.toIso8601String());

      return newScore;
    } catch (e) {
      AppLogger.error(
        LogCategory.risk,
        'RiskScoreEngine.applyTimeDecay error: $e',
      );
      return 0;
    }
  }

  /// Reset score (for testing / admin purposes).
  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyScore);
    await prefs.remove(_keyLastScamAt);
    await prefs.remove(_keyRecentScamCount);
    await prefs.remove(_keyRecentScamWindowStart);
    await prefs.remove(_keyLastRiskEventAt);
    await prefs.remove(_keyLastDecayCheckAt);
  }
}
