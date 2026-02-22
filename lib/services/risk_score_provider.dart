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

class RiskScoreProvider extends ChangeNotifier {
  static final RiskScoreProvider _instance = RiskScoreProvider._internal();
  factory RiskScoreProvider() => _instance;
  RiskScoreProvider._internal();

  final ApiService _api = ApiService();

  // ── State ──
  RiskModel _risk = RiskModel.empty;
  bool _isLoading = false;
  String? _error;
  Timer? _syncTimer;
  bool _disposed = false;

  // ── Getters ──
  RiskModel get risk => _risk;
  double get score => _risk.score;
  String get level => _risk.level;
  String get details => _risk.details;
  int get activeThreats => _risk.activeThreats;
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

  /// Initialize and start periodic sync.
  Future<void> init() async {
    _disposed = false;
    await refresh();
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
    // Small delay to let backend process the event
    await Future.delayed(const Duration(milliseconds: 500));
    await refresh();
  }

  void _startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(_syncInterval, (_) => refresh());
  }

  @override
  void dispose() {
    _disposed = true;
    _syncTimer?.cancel();
    _syncTimer = null;
    super.dispose();
  }
}
