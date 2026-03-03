/// Lightweight structured logger for production observability.
///
/// Categories: SMS, SOS, NETWORK, AUTH, RISK, SHAKE, LIFECYCLE
/// Levels: INFO, WARN, ERROR
///
/// Privacy-safe: never logs message content, phone numbers, or tokens.
/// Maintains a circular buffer of the last 200 entries for debug export.
library;

import 'dart:collection';

enum LogCategory { sms, sos, network, auth, risk, shake, lifecycle }

enum LogLevel { info, warn, error }

class LogEntry {
  final DateTime timestamp;
  final LogCategory category;
  final LogLevel level;
  final String message;

  const LogEntry({
    required this.timestamp,
    required this.category,
    required this.level,
    required this.message,
  });

  @override
  String toString() =>
      '[${timestamp.toIso8601String()}][${category.name.toUpperCase()}][${level.name.toUpperCase()}] $message';
}

class AppLogger {
  AppLogger._();

  static const int _maxEntries = 200;
  static final _buffer = Queue<LogEntry>();

  static void _log(LogCategory category, LogLevel level, String message) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      category: category,
      level: level,
      message: message,
    );

    // Circular buffer
    if (_buffer.length >= _maxEntries) {
      _buffer.removeFirst();
    }
    _buffer.add(entry);

    // Also print for debug builds (stripped in release by Flutter)
    assert(() {
      // ignore: avoid_print
      print(entry.toString());
      return true;
    }());
  }

  static void info(LogCategory category, String message) =>
      _log(category, LogLevel.info, message);

  static void warn(LogCategory category, String message) =>
      _log(category, LogLevel.warn, message);

  static void error(LogCategory category, String message) =>
      _log(category, LogLevel.error, message);

  /// Get all log entries (for debug export / screen)
  static List<LogEntry> getEntries() => _buffer.toList();

  /// Clear all entries
  static void clear() => _buffer.clear();
}
