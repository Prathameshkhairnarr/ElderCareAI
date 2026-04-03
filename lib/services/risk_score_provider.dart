/// Reactive risk score provider with auto-sync.
///
/// - Fetches risk score from backend on init
/// - Auto-refreshes every 5 minutes (lightweight polling)
/// - Exposes `refresh()` for event-driven updates (scam/SOS)
/// - Guardian can fetch elder-specific scores
///
/// HARDENED: guarded notifyListeners, safe timer cleanup, disposed-state check.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/risk_model.dart';
import 'api_service.dart';
import 'app_logger.dart';
import 'risk_score_engine.dart';

class RiskScoreProvider extends ChangeNotifier {
  static final RiskScoreProvider _instance = RiskScoreProvider._internal();
  factory RiskScoreProvider() => _instance;
  RiskScoreProvider._internal();

  final ApiService _api = ApiService();

  // ── State ──
  RiskModel _risk = RiskModel.empty;
  int _localRiskScore = 0; // Tracks on-device engine score for UI
  int _localActiveThreats = 0; // Tracks actual scam count from engine
  bool _isLoading = false;
  String? _error;
  Timer? _syncTimer;
  bool _disposed = false;

  // ── Getters ──
  RiskModel get risk => _risk;

  /// Returns the on-device engine score — this is the authoritative
  /// value that includes real-time decay. Backend score is used for
  /// model metadata (level, details, etc.) only.
  double get score => _localRiskScore.toDouble();

  /// Direct int access for UI widgets
  int get riskScore => _localRiskScore;
  String get level => _risk.level;
  String get details => _risk.details;
  int get activeThreats => _risk.activeThreats;
  /// Actual local threat count (1 scam SMS = 1 threat, resets on score 0)
  int get localActiveThreats => _localActiveThreats;
  bool get isVulnerable => _risk.isVulnerable;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ── Sync interval ──
  static const Duration _syncInterval = Duration(minutes: 5);

  /// Guarded notifyListeners — safe against disposed state.
  void _safeNotify() {
    if (!_disposed) {
      try {
        notifyListeners();
      } catch (_) {
        // Swallow: widget tree may have been disposed
      }
    }
  }

  /// Hard refresh: re-read persisted score from SharedPreferences.
  /// Always authoritative — fixes any cache/isolate mismatch.
  Future<void> refreshFromEngine() async {
    final latest = await RiskScoreEngine.getScore();
    final threats = await RiskScoreEngine.getActiveThreats();
    bool changed = false;

    if (latest != _localRiskScore) {
      _localRiskScore = latest;
      changed = true;
    }
    if (threats != _localActiveThreats) {
      _localActiveThreats = threats;
      changed = true;
    }

    if (changed) {
      _safeNotify();
      AppLogger.info(LogCategory.risk, 'Provider hard refresh → score=$latest threats=$threats');
    }
  }

  /// Initialize and start periodic sync.
  Future<void> init() async {
    _disposed = false;
    await refresh();
    await refreshFromEngine(); // ⭐ sync local score from engine
    _startPeriodicSync();
  }

  /// Fetch latest risk score from backend.
  Future<void> refresh() async {
    _isLoading = true;
    _error = null;
    _safeNotify();

    try {
      final result = await _api.getRiskScore();
      if (result != null) {
        _risk = result;
        _error = null;
      }
    } catch (e) {
      _error = 'Failed to sync risk score';
      AppLogger.warn(LogCategory.risk, 'RiskScoreProvider.refresh failed: $e');
    } finally {
      _isLoading = false;
      _safeNotify();
    }
  }

  /// Fetch risk score for a specific elder (guardian use).
  Future<RiskModel?> getElderRisk(int elderId) async {
    try {
      return await _api.getElderRiskScore(elderId);
    } catch (e) {
      AppLogger.warn(LogCategory.risk, 'getElderRisk($elderId) failed: $e');
      return null;
    }
  }

  /// Call after a scam is detected or SOS is triggered
  /// to immediately refresh the score.
  Future<void> onThreatEvent() async {
    await refreshFromEngine(); // ⭐ always re-read from engine

    // 🔴 Trigger guardian sync (non-blocking)
    unawaited(_syncRiskToBackend());
  }

  Future<void> _syncRiskToBackend() async {
    try {
      await _api.syncRiskScore(
        score: _localRiskScore,
        activeThreats: _localActiveThreats,
      );
      AppLogger.info(
        LogCategory.risk,
        'Risk synced to backend: score=$_localRiskScore threats=$_localActiveThreats',
      );
    } catch (e) {
      AppLogger.warn(LogCategory.risk, 'Guardian sync failed: $e');
    }
  }

  // ── Decay timer ──
  Timer? _decayTimer;
  static const Duration _decayInterval = Duration(seconds: 30);

  void _startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(_syncInterval, (_) => refresh());

    // Fast 30-second exponential decay timer
    _decayTimer?.cancel();
    _decayTimer = Timer.periodic(_decayInterval, (_) async {
      await RiskScoreEngine.applyTimeDecay(); // run decay
      await refreshFromEngine(); // ⭐ ALWAYS re-read from engine
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _syncTimer?.cancel();
    _syncTimer = null;
    _decayTimer?.cancel();
    _decayTimer = null;
    super.dispose();
  }
}
