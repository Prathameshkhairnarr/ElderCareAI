/// Resilient HTTP client with exponential backoff, jitter, timeouts, and
/// an offline event queue for critical operations (SOS, high-risk SMS).
///
/// Every outbound call goes through this layer — no raw `http.get/post`
/// anywhere else in the codebase.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'app_logger.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  HTTP RESULT TYPE
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class HttpResult {
  final int statusCode;
  final String body;
  final bool isSuccess;
  final String? errorMessage;

  const HttpResult({
    required this.statusCode,
    required this.body,
    required this.isSuccess,
    this.errorMessage,
  });

  /// Convenience: decode JSON body safely.
  dynamic get json {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  factory HttpResult.failure(String reason) => HttpResult(
    statusCode: 0,
    body: '',
    isSuccess: false,
    errorMessage: reason,
  );

  factory HttpResult.fromResponse(http.Response r) => HttpResult(
    statusCode: r.statusCode,
    body: r.body,
    isSuccess: r.statusCode >= 200 && r.statusCode < 300,
  );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  RESILIENT HTTP CLIENT
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class ResilientHttp {
  static final ResilientHttp _instance = ResilientHttp._internal();
  factory ResilientHttp() => _instance;
  ResilientHttp._internal();

  // ── Configuration ──
  static const Duration defaultReadTimeout = Duration(seconds: 10);
  static const Duration defaultWriteTimeout = Duration(seconds: 15);
  static const int maxRetries = 3;
  static const Duration _baseDelay = Duration(seconds: 1);
  static const Duration _maxDelay = Duration(seconds: 30);
  static const String _offlineQueueKey = 'resilient_http_offline_queue';

  final _random = Random();

  // ── GET ──
  Future<HttpResult> get(
    Uri url, {
    Map<String, String>? headers,
    Duration? timeout,
    int retries = 0,
  }) async {
    return _withRetry(
      retries: retries,
      label: 'GET ${url.path}',
      action: () => http
          .get(url, headers: headers)
          .timeout(timeout ?? defaultReadTimeout),
    );
  }

  // ── POST ──
  Future<HttpResult> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
    int retries = 0,
  }) async {
    return _withRetry(
      retries: retries,
      label: 'POST ${url.path}',
      action: () => http
          .post(url, headers: headers, body: body)
          .timeout(timeout ?? defaultWriteTimeout),
    );
  }

  // ── DELETE ──
  Future<HttpResult> delete(
    Uri url, {
    Map<String, String>? headers,
    Duration? timeout,
    int retries = 0,
  }) async {
    return _withRetry(
      retries: retries,
      label: 'DELETE ${url.path}',
      action: () => http
          .delete(url, headers: headers)
          .timeout(timeout ?? defaultWriteTimeout),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //  RETRY WITH EXPONENTIAL BACKOFF + JITTER
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Future<HttpResult> _withRetry({
    required int retries,
    required String label,
    required Future<http.Response> Function() action,
  }) async {
    final effectiveRetries = retries > 0 ? retries : maxRetries;

    for (int attempt = 0; attempt <= effectiveRetries; attempt++) {
      try {
        final response = await action();

        // Don't retry client errors (4xx) — they won't magically fix
        if (response.statusCode >= 400 && response.statusCode < 500) {
          AppLogger.warn(
            LogCategory.network,
            '$label failed with ${response.statusCode} (no retry)',
          );
          return HttpResult.fromResponse(response);
        }

        if (response.statusCode >= 200 && response.statusCode < 300) {
          return HttpResult.fromResponse(response);
        }

        // 5xx → retry if attempts remain
        if (attempt < effectiveRetries) {
          final delay = _backoffDelay(attempt);
          AppLogger.warn(
            LogCategory.network,
            '$label got ${response.statusCode}, retry ${attempt + 1}/$effectiveRetries in ${delay.inMilliseconds}ms',
          );
          await Future.delayed(delay);
          continue;
        }

        return HttpResult.fromResponse(response);
      } on TimeoutException catch (_) {
        AppLogger.error(
          LogCategory.network,
          '$label timed out (attempt ${attempt + 1})',
        );
        if (attempt < effectiveRetries) {
          await Future.delayed(_backoffDelay(attempt));
          continue;
        }
        return HttpResult.failure('Request timed out');
      } catch (e) {
        AppLogger.error(
          LogCategory.network,
          '$label error: $e (attempt ${attempt + 1})',
        );
        if (attempt < effectiveRetries) {
          await Future.delayed(_backoffDelay(attempt));
          continue;
        }
        return HttpResult.failure('Network error: $e');
      }
    }

    return HttpResult.failure('Max retries exceeded');
  }

  /// Exponential backoff with jitter:
  /// delay = min(base * 2^attempt, maxDelay) + random(0–1000ms)
  Duration _backoffDelay(int attempt) {
    final exponential = _baseDelay.inMilliseconds * pow(2, attempt);
    final capped = min(exponential.toInt(), _maxDelay.inMilliseconds);
    final jitter = _random.nextInt(1000);
    return Duration(milliseconds: capped + jitter);
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //  OFFLINE EVENT QUEUE
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// Queue a critical event when offline (SOS, high-risk SMS)
  static Future<void> queueOfflineEvent(Map<String, dynamic> event) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queue = prefs.getStringList(_offlineQueueKey) ?? [];
      if (queue.length >= 50) {
        AppLogger.warn(
          LogCategory.network,
          'Offline queue full (50), dropping oldest',
        );
        queue.removeAt(0);
      }
      queue.add(jsonEncode(event));
      await prefs.setStringList(_offlineQueueKey, queue);
      AppLogger.info(LogCategory.network, 'Event queued for offline retry');
    } catch (e) {
      AppLogger.error(LogCategory.network, 'Failed to queue offline event: $e');
    }
  }

  /// Flush queued events (call on reconnect)
  static Future<List<Map<String, dynamic>>> drainOfflineQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queue = prefs.getStringList(_offlineQueueKey) ?? [];
      if (queue.isEmpty) return [];

      final events = queue
          .map((s) {
            try {
              return jsonDecode(s) as Map<String, dynamic>;
            } catch (_) {
              return null;
            }
          })
          .whereType<Map<String, dynamic>>()
          .toList();

      await prefs.setStringList(_offlineQueueKey, []);
      AppLogger.info(
        LogCategory.network,
        'Drained ${events.length} offline events',
      );
      return events;
    } catch (e) {
      AppLogger.error(LogCategory.network, 'Failed to drain offline queue: $e');
      return [];
    }
  }
}
