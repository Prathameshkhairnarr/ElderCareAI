import 'dart:async';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../services/app_logger.dart';
import 'tts_text_cleaner.dart';

/// Reason for Edge TTS failure — used for precise fallback logging.
enum EdgeTtsFailReason {
  notConfigured,
  networkError,
  timeout,
  emptyResponse,
  serverError,
  unknown,
}

/// Exception thrown when Edge TTS fails.
class EdgeTtsException implements Exception {
  final EdgeTtsFailReason reason;
  final String message;

  const EdgeTtsException(this.reason, this.message);

  @override
  String toString() => 'EdgeTtsException(${reason.name}): $message';
}

/// Edge TTS client — uses Microsoft Edge's neural voices via backend.
///
/// Features:
///   - Same neural voices as Azure (hi-IN-SwaraNeural, en-IN-NeerjaNeural)
///   - FREE — no subscription key needed
///   - Prosody tuning: rate -8%, pitch +2Hz (calm, caring doctor)
///   - 10-second timeout guard
///   - In-memory LRU cache (20 entries)
///   - Typed exceptions for precise fallback decisions
///   - Fully async — never blocks UI
class EdgeTtsService {
  EdgeTtsService._();
  static final EdgeTtsService instance = EdgeTtsService._();

  /// Timeout for API requests — triggers fallback if exceeded.
  static const _requestTimeout = Duration(seconds: 10);

  /// LRU cache: text hash → MP3 bytes.
  final Map<String, Uint8List> _audioCache = {};
  static const int _maxCacheEntries = 20;

  /// Edge TTS is always configured (no API key needed) — just needs backend URL.
  bool get isConfigured => ApiConfig.edgeTtsEndpoint.isNotEmpty;

  // ══════════════════════════════════════════════════════
  //  SYNTHESIZE
  // ══════════════════════════════════════════════════════

  /// Synthesize text to MP3 audio bytes via Edge TTS backend.
  ///
  /// The text is cleaned via [TtsTextCleaner].
  /// Supports multi-language: pass [voiceName] for dynamic language switching.
  /// Returns raw MP3 [Uint8List] on success.
  /// Throws [EdgeTtsException] with a typed [EdgeTtsFailReason] on failure.
  Future<Uint8List> synthesize(
    String text, {
    String? voiceName,
    String rate = '-8%',
    String pitch = '+2Hz',
  }) async {
    if (!isConfigured) {
      throw const EdgeTtsException(
        EdgeTtsFailReason.notConfigured,
        'Edge TTS backend endpoint not configured',
      );
    }

    if (text.trim().isEmpty) {
      throw const EdgeTtsException(
        EdgeTtsFailReason.emptyResponse,
        'Empty text provided',
      );
    }

    // ── Check cache ──
    final cacheKey = '${text.trim().toLowerCase()}_${voiceName ?? "default"}';
    if (_audioCache.containsKey(cacheKey)) {
      AppLogger.info(
        LogCategory.lifecycle,
        '[VOICE] Edge TTS cache hit (${cacheKey.length} chars)',
      );
      return _audioCache[cacheKey]!;
    }

    // ── Clean text ──
    final cleanedSentences = TtsTextCleaner.cleanForAzure(text);
    if (cleanedSentences.isEmpty) {
      throw const EdgeTtsException(
        EdgeTtsFailReason.emptyResponse,
        'Text cleaned to empty',
      );
    }

    // Join sentences for natural flow
    final cleanedText = cleanedSentences.join(' ');

    // ── API call with timeout ──
    final stopwatch = Stopwatch()..start();

    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.edgeTtsEndpoint),
            headers: {
              'Content-Type': 'application/json',
            },
            body: _buildRequestBody(cleanedText, voiceName, rate, pitch),
          )
          .timeout(_requestTimeout);

      stopwatch.stop();
      final elapsed = stopwatch.elapsedMilliseconds;

      // ── Handle HTTP status codes ──
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        if (bytes.isEmpty) {
          throw const EdgeTtsException(
            EdgeTtsFailReason.emptyResponse,
            'API returned empty audio',
          );
        }

        // Cache the result
        _addToCache(cacheKey, bytes);

        AppLogger.info(
          LogCategory.lifecycle,
          '[VOICE] Edge TTS success — voice=${voiceName ?? ApiConfig.edgeTtsDefaultVoice}, '
          '${bytes.length} bytes, ${elapsed}ms',
        );
        return bytes;
      } else {
        throw EdgeTtsException(
          EdgeTtsFailReason.serverError,
          'HTTP ${response.statusCode}: '
          '${response.body.length > 200 ? response.body.substring(0, 200) : response.body}',
        );
      }
    } on TimeoutException {
      stopwatch.stop();
      throw EdgeTtsException(
        EdgeTtsFailReason.timeout,
        'Request timed out after ${_requestTimeout.inSeconds}s',
      );
    } on EdgeTtsException {
      rethrow;
    } catch (e) {
      throw EdgeTtsException(
        EdgeTtsFailReason.networkError,
        'Network error: $e',
      );
    }
  }

  // ══════════════════════════════════════════════════════
  //  REQUEST BUILDER
  // ══════════════════════════════════════════════════════

  String _buildRequestBody(String text, String? voiceName, String rate, String pitch) {
    final voice = voiceName ?? ApiConfig.edgeTtsDefaultVoice;
    return '{"text":"${_escapeJson(text)}","voice":"$voice","rate":"$rate","pitch":"$pitch"}';
  }

  /// Escape special characters for JSON string.
  String _escapeJson(String text) {
    return text
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r')
        .replaceAll('\t', '\\t');
  }

  // ══════════════════════════════════════════════════════
  //  CACHE
  // ══════════════════════════════════════════════════════

  /// Add audio bytes to LRU cache, evicting oldest if full.
  void _addToCache(String key, Uint8List bytes) {
    if (_audioCache.length >= _maxCacheEntries) {
      _audioCache.remove(_audioCache.keys.first);
    }
    _audioCache[key] = bytes;
  }

  /// Clear the audio cache.
  void clearCache() => _audioCache.clear();
}
