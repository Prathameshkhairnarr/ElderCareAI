import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// A single prescription scan record.
class PrescriptionRecord {
  final String id;
  final String result;
  final DateTime scannedAt;
  final String? imagePath;

  PrescriptionRecord({
    required this.id,
    required this.result,
    required this.scannedAt,
    this.imagePath,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'result': result,
    'scannedAt': scannedAt.toIso8601String(),
    'imagePath': imagePath,
  };

  factory PrescriptionRecord.fromJson(Map<String, dynamic> json) {
    return PrescriptionRecord(
      id: json['id'] as String,
      result: json['result'] as String,
      scannedAt: DateTime.parse(json['scannedAt'] as String),
      imagePath: json['imagePath'] as String?,
    );
  }
}

/// Service to persist prescription scan history locally.
class PrescriptionHistoryService {
  static const _storageKey = 'prescription_history';
  static const int _maxRecords = 50;

  /// Save a new prescription scan result.
  static Future<void> save(PrescriptionRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getAll();
    history.insert(0, record);

    // Keep only last N records
    while (history.length > _maxRecords) {
      history.removeLast();
    }

    final jsonList = history.map((r) => r.toJson()).toList();
    await prefs.setString(_storageKey, jsonEncode(jsonList));
  }

  /// Get all saved prescription records (newest first).
  static Future<List<PrescriptionRecord>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final List<dynamic> jsonList = jsonDecode(raw);
      return jsonList
          .map((e) => PrescriptionRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Delete a specific record by ID.
  static Future<void> delete(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getAll();
    history.removeWhere((r) => r.id == id);
    final jsonList = history.map((r) => r.toJson()).toList();
    await prefs.setString(_storageKey, jsonEncode(jsonList));
  }

  /// Clear all history.
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
