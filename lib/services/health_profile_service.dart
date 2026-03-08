import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/health_profile.dart';
import 'app_logger.dart';

/// Multi-profile health persistence service.
/// Singleton — call [HealthProfileService()] anywhere.
/// Stores per-profile data in SharedPreferences with an index.
class HealthProfileService extends ChangeNotifier {
  // ── Singleton ──
  static final HealthProfileService _instance = HealthProfileService._();
  factory HealthProfileService() => _instance;
  HealthProfileService._();

  // ── Storage keys ──
  static const _indexKey = 'health_profiles_index';
  static const _activeKey = 'health_active_profile_id';
  static const _profilePrefix = 'health_profile_';
  static const _legacyKey = 'health_profile_v1'; // old single-profile key

  // ── State ──
  HealthProfile _profile = HealthProfile.empty;
  String _activeProfileId = 'default';
  List<Map<String, dynamic>> _profileIndex = [];
  bool _initialized = false;

  /// Current active profile (always available, never null).
  HealthProfile get profile => _profile;

  /// Update the current profile directly in memory (used by UI).
  set profile(HealthProfile newProfile) {
    _profile = newProfile;
    notifyListeners();
  }

  /// Active profile ID.
  String get activeProfileId => _activeProfileId;

  /// List of all profile summaries: {id, name, createdAt}.
  List<Map<String, dynamic>> get allProfiles =>
      List.unmodifiable(_profileIndex);

  // ══════════════════════════════════════════════
  //  INITIALIZATION + MIGRATION
  // ══════════════════════════════════════════════

  /// Must be called once on app start or first access.
  /// Handles migration from single-profile to multi-profile.
  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final prefs = await SharedPreferences.getInstance();

      // Load profile index
      final indexJsonStr = prefs.getString(_indexKey);
      if (indexJsonStr != null) {
        final decodedIndex = await compute(jsonDecode, indexJsonStr);
        _profileIndex = List<Map<String, dynamic>>.from(
          (decodedIndex as List).map((e) => Map<String, dynamic>.from(e)),
        );
      }

      // ── Migration: old single-profile → multi-profile ──
      if (_profileIndex.isEmpty) {
        final legacyJson = prefs.getString(_legacyKey);
        if (legacyJson != null && legacyJson.isNotEmpty) {
          AppLogger.info(
            LogCategory.lifecycle,
            '[HEALTH] Migrating legacy profile to multi-profile system',
          );
          // Save legacy data under 'default' key
          await prefs.setString('${_profilePrefix}default', legacyJson);
          // Remove legacy key
          await prefs.remove(_legacyKey);
        }

        // Create default profile entry
        _profileIndex = [
          {
            'id': 'default',
            'name': 'Default',
            'createdAt': DateTime.now().toIso8601String(),
          },
        ];
        await _saveIndex(prefs);
      }

      // Load active profile ID
      _activeProfileId = prefs.getString(_activeKey) ?? 'default';

      // Validate active ID exists in index
      if (!_profileIndex.any((p) => p['id'] == _activeProfileId)) {
        _activeProfileId = _profileIndex.first['id'] as String;
        await prefs.setString(_activeKey, _activeProfileId);
      }

      // Load active profile data
      await _loadProfile(prefs, _activeProfileId);
    } catch (e) {
      AppLogger.error(LogCategory.lifecycle, '[HEALTH] Init failed: $e');
    }
  }

  // ══════════════════════════════════════════════
  //  LOAD / SAVE
  // ══════════════════════════════════════════════

  /// Load the active profile from storage.
  Future<HealthProfile> load() async {
    await _ensureInitialized();
    return _profile;
  }

  Future<void> _loadProfile(SharedPreferences prefs, String id) async {
    final key = '$_profilePrefix$id';
    final jsonStr = prefs.getString(key);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      _profile = await compute(_parseProfileData, jsonStr);
      // Ensure profileId matches
      if (_profile.profileId != id) {
        _profile = _profile.copyWith(profileId: id);
      }
      AppLogger.info(
        LogCategory.lifecycle,
        '[HEALTH] Loaded profile "$id" → ${_profile.toJson()}',
      );
    } else {
      _profile = HealthProfile(profileId: id);
      AppLogger.info(
        LogCategory.lifecycle,
        '[HEALTH] No data for profile "$id" — using empty',
      );
    }
  }

  /// Save profile to local storage. Returns true on success.
  Future<bool> save(HealthProfile profile) async {
    await _ensureInitialized();
    try {
      // Stamp with current time and ensure correct profileId
      _profile = profile.copyWith(
        profileId: _activeProfileId,
        lastUpdated: DateTime.now(),
      );

      AppLogger.info(
        LogCategory.lifecycle,
        '[HEALTH] Saving profile "$_activeProfileId" → ${_profile.toJson()}',
      );

      final prefs = await SharedPreferences.getInstance();
      final key = '$_profilePrefix$_activeProfileId';
      await prefs.setString(key, _profile.toJsonString());

      // Update index timestamp
      final idx = _profileIndex.indexWhere((p) => p['id'] == _activeProfileId);
      if (idx >= 0) {
        _profileIndex[idx]['updatedAt'] = DateTime.now().toIso8601String();
        await _saveIndex(prefs);
      }

      notifyListeners();

      AppLogger.info(
        LogCategory.lifecycle,
        '[HEALTH] Save success (completeness: ${_profile.completeness}%)',
      );
      return true;
    } catch (e) {
      AppLogger.error(LogCategory.lifecycle, '[HEALTH] Save FAILED: $e');
      return false;
    }
  }

  // ══════════════════════════════════════════════
  //  MULTI-PROFILE OPERATIONS
  // ══════════════════════════════════════════════

  /// Switch to a different profile.
  Future<void> switchProfile(String id) async {
    await _ensureInitialized();
    if (id == _activeProfileId) return;
    if (!_profileIndex.any((p) => p['id'] == id)) return;

    try {
      _activeProfileId = id;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_activeKey, id);
      await _loadProfile(prefs, id);
      notifyListeners();

      AppLogger.info(
        LogCategory.lifecycle,
        '[HEALTH] Switched to profile "$id"',
      );
    } catch (e) {
      AppLogger.error(
        LogCategory.lifecycle,
        '[HEALTH] Switch profile failed: $e',
      );
    }
  }

  /// Add a new empty profile. Returns the new profile ID.
  Future<String> addProfile({String? name}) async {
    await _ensureInitialized();
    try {
      final id = 'profile_${DateTime.now().millisecondsSinceEpoch}';
      final displayName = name ?? 'Profile ${_profileIndex.length + 1}';

      _profileIndex.add({
        'id': id,
        'name': displayName,
        'createdAt': DateTime.now().toIso8601String(),
      });

      final prefs = await SharedPreferences.getInstance();
      await _saveIndex(prefs);

      // Save empty profile data
      final emptyProfile = HealthProfile(profileId: id, name: displayName);
      await prefs.setString('$_profilePrefix$id', emptyProfile.toJsonString());

      // Auto-switch to new profile
      await switchProfile(id);

      AppLogger.info(
        LogCategory.lifecycle,
        '[HEALTH] Created new profile "$id" ($displayName)',
      );
      return id;
    } catch (e) {
      AppLogger.error(LogCategory.lifecycle, '[HEALTH] Add profile failed: $e');
      return '';
    }
  }

  /// Delete a profile. Cannot delete the last remaining profile.
  Future<bool> deleteProfile(String id) async {
    await _ensureInitialized();
    if (_profileIndex.length <= 1) return false; // prevent deleting last
    if (!_profileIndex.any((p) => p['id'] == id)) return false;

    try {
      _profileIndex.removeWhere((p) => p['id'] == id);

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_profilePrefix$id');
      await _saveIndex(prefs);

      // If deleted the active profile, switch to first available
      if (_activeProfileId == id) {
        await switchProfile(_profileIndex.first['id'] as String);
      }

      notifyListeners();

      AppLogger.info(LogCategory.lifecycle, '[HEALTH] Deleted profile "$id"');
      return true;
    } catch (e) {
      AppLogger.error(
        LogCategory.lifecycle,
        '[HEALTH] Delete profile failed: $e',
      );
      return false;
    }
  }

  /// Get display name for a profile ID.
  String getProfileName(String id) {
    final entry = _profileIndex.firstWhere(
      (p) => p['id'] == id,
      orElse: () => {'name': 'Unknown'},
    );
    return entry['name'] as String? ?? 'Profile';
  }

  // ══════════════════════════════════════════════
  //  CLEAR / MERGE
  // ══════════════════════════════════════════════

  /// Remove active profile data (e.g. on logout).
  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_profilePrefix$_activeProfileId');
      _profile = HealthProfile(profileId: _activeProfileId);
      notifyListeners();
    } catch (e) {
      AppLogger.error(
        LogCategory.lifecycle,
        'Failed to clear health profile: $e',
      );
    }
  }

  /// Wipe the underlying memory state (singleton) and all associated cache.
  /// Call this when the user logs out so a new user gets a fresh profile.
  Future<void> hardReset() async {
    try {
      AppLogger.info(
        LogCategory.lifecycle,
        '[HEALTH] Performing hard reset of memory & storage.',
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_indexKey);
      await prefs.remove(_activeKey);
      await prefs.remove(_legacyKey);

      final keys = prefs.getKeys();
      for (String key in keys) {
        if (key.startsWith(_profilePrefix)) {
          await prefs.remove(key);
        }
      }

      // Reset internal RAM memory state
      _profileIndex = [];
      _activeProfileId = 'default';
      _profile = HealthProfile.empty;
      _initialized = false;

      notifyListeners();
    } catch (e) {
      AppLogger.error(LogCategory.lifecycle, '[HEALTH] Hard reset failed: $e');
    }
  }

  /// Update in-memory profile from API data without overwriting
  /// local-only fields. Saves to disk if API data is newer.
  Future<void> mergeFromApi(Map<String, dynamic>? apiData) async {
    if (apiData == null || apiData['id'] == 0) return;
    try {
      final apiProfile = HealthProfile.fromJson(apiData);
      if (_profile.isEmpty && !apiProfile.isEmpty) {
        await save(apiProfile);
      }
    } catch (e) {
      AppLogger.error(
        LogCategory.lifecycle,
        'Failed to merge API health data: $e',
      );
    }
  }

  // ── Internal helpers ──
  Future<void> _saveIndex(SharedPreferences prefs) async {
    await prefs.setString(_indexKey, jsonEncode(_profileIndex));
  }
}

HealthProfile _parseProfileData(String json) =>
    HealthProfile.fromJsonString(json);
