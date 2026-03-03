import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/app_logger.dart';

/// A single medicine reminder entry.
class MedicineReminder {
  final String id;
  final String name;
  final String time; // "08:00", "14:00", "21:00"
  final bool taken;
  final String date; // "2026-03-03"

  const MedicineReminder({
    required this.id,
    required this.name,
    required this.time,
    this.taken = false,
    required this.date,
  });

  MedicineReminder copyWith({bool? taken}) => MedicineReminder(
    id: id,
    name: name,
    time: time,
    taken: taken ?? this.taken,
    date: date,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'time': time,
    'taken': taken,
    'date': date,
  };

  factory MedicineReminder.fromJson(Map<String, dynamic> json) =>
      MedicineReminder(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        time: json['time'] as String? ?? '',
        taken: json['taken'] as bool? ?? false,
        date: json['date'] as String? ?? '',
      );
}

/// Local medicine reminder service for elderly users.
///
/// Features:
///   - Add/remove medicine reminders
///   - Mark medicines as taken
///   - Query today's reminders and next upcoming
///   - Persists in shared_preferences (survives app restart)
///   - Hindi/English voice status reports
///
/// No external packages needed — uses shared_preferences (already a dep).
class MedicineReminderService {
  MedicineReminderService._();
  static final MedicineReminderService instance = MedicineReminderService._();

  static const String _storageKey = 'eldercare_medicine_reminders';

  List<MedicineReminder> _reminders = [];
  bool _loaded = false;

  /// All reminders (read-only).
  List<MedicineReminder> get reminders => List.unmodifiable(_reminders);

  // ══════════════════════════════════════════════════════
  //  LOAD / SAVE
  // ══════════════════════════════════════════════════════

  /// Load reminders from local storage.
  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_storageKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> list = jsonDecode(jsonStr);
        _reminders = list
            .map((e) => MedicineReminder.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      _loaded = true;
      AppLogger.info(
        LogCategory.lifecycle,
        '[MED] Loaded ${_reminders.length} medicine reminders',
      );
    } catch (e) {
      AppLogger.error(
        LogCategory.lifecycle,
        '[MED] Failed to load reminders: $e',
      );
      _loaded = true;
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(_reminders.map((r) => r.toJson()).toList());
      await prefs.setString(_storageKey, jsonStr);
    } catch (e) {
      AppLogger.error(
        LogCategory.lifecycle,
        '[MED] Failed to save reminders: $e',
      );
    }
  }

  // ══════════════════════════════════════════════════════
  //  CRUD
  // ══════════════════════════════════════════════════════

  /// Add a new medicine reminder.
  Future<void> addReminder(String name, String time) async {
    await load();
    final today = _todayStr();
    final id = '${name.hashCode}_${time.hashCode}_$today';

    // Prevent duplicates for same day
    final exists = _reminders.any(
      (r) => r.name == name && r.time == time && r.date == today,
    );
    if (exists) return;

    _reminders.add(
      MedicineReminder(id: id, name: name, time: time, date: today),
    );
    await _save();

    AppLogger.info(
      LogCategory.lifecycle,
      '[MED] Added reminder: $name at $time',
    );
  }

  /// Mark a medicine as taken by ID.
  Future<void> markTaken(String id) async {
    await load();
    final index = _reminders.indexWhere((r) => r.id == id);
    if (index >= 0) {
      _reminders[index] = _reminders[index].copyWith(taken: true);
      await _save();
      AppLogger.info(
        LogCategory.lifecycle,
        '[MED] Marked as taken: ${_reminders[index].name}',
      );
    }
  }

  /// Mark a medicine as taken by name (voice-friendly).
  Future<bool> markTakenByName(String name) async {
    await load();
    final today = _todayStr();
    final lower = name.toLowerCase();
    final index = _reminders.indexWhere(
      (r) =>
          r.name.toLowerCase().contains(lower) && r.date == today && !r.taken,
    );
    if (index >= 0) {
      _reminders[index] = _reminders[index].copyWith(taken: true);
      await _save();
      return true;
    }
    return false;
  }

  /// Remove a reminder by ID.
  Future<void> removeReminder(String id) async {
    await load();
    _reminders.removeWhere((r) => r.id == id);
    await _save();
  }

  // ══════════════════════════════════════════════════════
  //  QUERIES
  // ══════════════════════════════════════════════════════

  /// Get today's reminders.
  Future<List<MedicineReminder>> getTodayReminders() async {
    await load();
    final today = _todayStr();
    return _reminders.where((r) => r.date == today).toList()
      ..sort((a, b) => a.time.compareTo(b.time));
  }

  /// Get the next upcoming (untaken) reminder for today.
  Future<MedicineReminder?> getNextReminder() async {
    final today = await getTodayReminders();
    final now = _nowTimeStr();
    try {
      return today.firstWhere((r) => !r.taken && r.time.compareTo(now) >= 0);
    } catch (_) {
      return null;
    }
  }

  /// Get pending (untaken) count for today.
  Future<int> getPendingCount() async {
    final today = await getTodayReminders();
    return today.where((r) => !r.taken).length;
  }

  // ══════════════════════════════════════════════════════
  //  VOICE STATUS REPORT
  // ══════════════════════════════════════════════════════

  /// Get a voice-friendly status report about today's medicines.
  Future<String> getStatusReport(bool hindi) async {
    final today = await getTodayReminders();

    if (today.isEmpty) {
      return hindi
          ? 'Aaj ke liye koi dawai ka reminder set nahi hai.'
          : 'No medicine reminders set for today.';
    }

    final taken = today.where((r) => r.taken).length;
    final pending = today.length - taken;

    if (hindi) {
      final report = StringBuffer();
      report.write('Aaj ${today.length} dawai ka reminder hai. ');
      if (taken > 0) report.write('$taken le chuke hain. ');
      if (pending > 0) {
        final nextPending = today.where((r) => !r.taken).toList();
        report.write('$pending baaki hain: ');
        report.write(
          nextPending.map((r) => '${r.name} ${r.time} baje').join(', '),
        );
        report.write('.');
      } else {
        report.write('Sab dawai le chuke hain!');
      }
      return report.toString();
    } else {
      final report = StringBuffer();
      report.write('You have ${today.length} medicine reminders today. ');
      if (taken > 0) report.write('$taken taken. ');
      if (pending > 0) {
        final nextPending = today.where((r) => !r.taken).toList();
        report.write('$pending remaining: ');
        report.write(
          nextPending.map((r) => '${r.name} at ${r.time}').join(', '),
        );
        report.write('.');
      } else {
        report.write('All medicines taken!');
      }
      return report.toString();
    }
  }

  // ══════════════════════════════════════════════════════
  //  HELPERS
  // ══════════════════════════════════════════════════════

  static String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static String _nowTimeStr() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }
}
