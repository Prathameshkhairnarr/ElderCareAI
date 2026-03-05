import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_logger.dart';

/// Persistent user memory service — remembers user details across app restarts.
///
/// Stores:
///   - Name, age, city, language preference
///   - Health conditions (diabetes, BP, etc.)
///   - Preferences (greeting style, etc.)
///
/// Uses SharedPreferences (already a dependency).
/// Voice commands like "My name is Rahul" or "Meri umar 65 hai" persist here.
class UserMemoryService {
  UserMemoryService._();
  static final UserMemoryService instance = UserMemoryService._();

  static const String _storageKey = 'eldercare_user_memory';

  final Map<String, String> _memory = {};
  bool _loaded = false;

  // ── Known memory keys ──
  static const kName = 'name';
  static const kAge = 'age';
  static const kCity = 'city';
  static const kLanguage = 'language';
  static const kConditions = 'conditions'; // comma-separated
  static const kBloodGroup = 'blood_group';
  static const kEmergencyContact = 'emergency_contact';

  /// All stored memories (read-only).
  Map<String, String> get all => Map.unmodifiable(_memory);

  /// Whether any user data is stored.
  bool get hasData => _memory.isNotEmpty;

  /// Get a specific memory value.
  String? get(String key) => _memory[key];

  /// User name shortcut.
  String? get userName => _memory[kName];

  // ══════════════════════════════════════════════
  //  LOAD / SAVE
  // ══════════════════════════════════════════════

  /// Load from local storage.
  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_storageKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final Map<String, dynamic> data = jsonDecode(jsonStr);
        _memory.clear();
        data.forEach((key, value) {
          if (value is String) _memory[key] = value;
        });
      }
      _loaded = true;
      AppLogger.info(
        LogCategory.lifecycle,
        '[MEMORY] Loaded ${_memory.length} user memory entries',
      );
    } catch (e) {
      AppLogger.error(LogCategory.lifecycle, '[MEMORY] Failed to load: $e');
      _loaded = true;
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(_memory));
    } catch (e) {
      AppLogger.error(LogCategory.lifecycle, '[MEMORY] Failed to save: $e');
    }
  }

  // ══════════════════════════════════════════════
  //  CRUD
  // ══════════════════════════════════════════════

  /// Store a key-value pair and persist.
  Future<void> set(String key, String value) async {
    await load();
    _memory[key] = value.trim();
    await _save();
    AppLogger.info(
      LogCategory.lifecycle,
      '[MEMORY] Saved: $key = "${value.length > 30 ? '${value.substring(0, 30)}...' : value}"',
    );
  }

  /// Remove a memory entry.
  Future<void> remove(String key) async {
    await load();
    _memory.remove(key);
    await _save();
  }

  /// Clear all user memory.
  Future<void> clear() async {
    _memory.clear();
    await _save();
    AppLogger.info(LogCategory.lifecycle, '[MEMORY] All user memory cleared');
  }

  // ══════════════════════════════════════════════
  //  CONTEXT BUILDER (for AI prompts)
  // ══════════════════════════════════════════════

  /// Build a context string for AI prompt injection.
  /// Returns empty string if no data stored.
  String buildContextString() {
    if (_memory.isEmpty) return '';

    final parts = <String>[];
    if (_memory.containsKey(kName)) parts.add('Name: ${_memory[kName]}');
    if (_memory.containsKey(kAge)) parts.add('Age: ${_memory[kAge]}');
    if (_memory.containsKey(kCity)) parts.add('City: ${_memory[kCity]}');
    if (_memory.containsKey(kBloodGroup)) {
      parts.add('Blood: ${_memory[kBloodGroup]}');
    }
    if (_memory.containsKey(kConditions)) {
      parts.add('Conditions: ${_memory[kConditions]}');
    }

    return parts.isEmpty ? '' : parts.join(' | ');
  }
}
