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
import 'auth_service.dart';

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
  static const Duration defaultWriteTimeout = Duration(seconds: 10);
  static const int maxRetries = 3;
  static const String _offlineQueueKey = 'resilient_http_offline_queue';

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
      headers: headers,
      action: (h) =>
          http.get(url, headers: h).timeout(timeout ?? defaultReadTimeout),
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
      headers: headers,
      action: (h) => http
          .post(url, headers: h, body: body)
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
      headers: headers,
      action: (h) =>
          http.delete(url, headers: h).timeout(timeout ?? defaultWriteTimeout),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //  RETRY WITH EXPONENTIAL BACKOFF + JITTER
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Future<HttpResult> _withRetry({
    required int retries,
    required String label,
    required Future<http.Response> Function(Map<String, String>?) action,
    Map<String, String>? headers,
  }) async {
    final effectiveRetries = retries > 0 ? retries : maxRetries;
    bool authRetried = false;

    // Make headers modifiable if non-null
    Map<String, String>? currentHeaders = headers != null
        ? Map.from(headers)
        : null;

    for (int attempt = 0; attempt <= effectiveRetries; attempt++) {
      try {
        if (attempt == 0) {
          AppLogger.info(LogCategory.network, '[NETWORK] Request $label');
        }

        final response = await action(currentHeaders);
        AppLogger.info(
          LogCategory.network,
          '[NETWORK] Response ${response.statusCode}',
        );

        // 401 Interceptor
        if (response.statusCode == 401 && !authRetried) {
          authRetried = true;
          AppLogger.warn(
            LogCategory.network,
            '$label got 401, attempting token refresh...',
          );
          final refreshed = await AuthService().refreshToken();
          if (refreshed) {
            final newToken = AuthService().token;
            if (newToken != null) {
              currentHeaders ??= {};
              currentHeaders['Authorization'] = 'Bearer $newToken';
            }
            attempt--; // Retry this attempt with new token
            continue;
          }
        }

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
            '[NETWORK] Retry attempt ${attempt + 1} for $label in ${delay.inSeconds}s',
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

  /// Strict exponential backoff: 1s, 2s, 4s...
  Duration _backoffDelay(int attempt) {
    final seconds = pow(2, attempt).toInt();
    return Duration(seconds: seconds);
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //  OFFLINE EVENT QUEUE
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// Queue a general API mutation (POST/DELETE) when offline.
  /// Converts request info so it can be replayed when internet is restored.
  static Future<void> queueOfflineRequest({
    required String method,
    required String url,
    Map<String, dynamic>? body,
  }) async {
    await queueOfflineEvent({
      'type': 'queued_request',
      'method': method,
      'url': url,
      'body': body,
      'queued_at': DateTime.now().toIso8601String(),
    });
  }

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
