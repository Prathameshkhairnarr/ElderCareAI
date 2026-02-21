/// Reactive risk score provider with auto-sync.
///
/// - Fetches risk score from backend on init
/// - Auto-refreshes every 5 minutes (lightweight polling)
/// - Exposes `refresh()` for event-driven updates (scam/SOS)
/// - Smooth animated transitions via `score` getter
/// - Guardian can fetch elder-specific scores
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/risk_model.dart';
import 'api_service.dart';

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

  /// Initialize and start periodic sync.
  Future<void> init() async {
    await refresh();
    _startPeriodicSync();
  }

  /// Fetch latest risk score from backend.
  Future<void> refresh() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _api.getRiskScore();
      if (result != null) {
        _risk = result;
        _error = null;
      }
    } catch (e) {
      _error = 'Failed to sync risk score';
      debugPrint('⚠️ RiskScoreProvider.refresh failed: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch risk score for a specific elder (guardian use).
  Future<RiskModel?> getElderRisk(int elderId) async {
    try {
      return await _api.getElderRiskScore(elderId);
    } catch (e) {
      debugPrint('⚠️ getElderRisk($elderId) failed: $e');
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
    _syncTimer?.cancel();
    super.dispose();
  }
}
