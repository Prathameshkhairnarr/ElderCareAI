import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../services/app_logger.dart';

/// Reason for ElevenLabs failure — used for precise fallback logging.
enum ElevenLabsFailReason {
  notConfigured,
  quotaExceeded,
  invalidApiKey,
  networkError,
  timeout,
  emptyResponse,
  serverError,
  unknown,
}

/// Exception thrown when ElevenLabs TTS fails.
class ElevenLabsException implements Exception {
  final ElevenLabsFailReason reason;
  final String message;

  const ElevenLabsException(this.reason, this.message);

  @override
  String toString() => 'ElevenLabsException(${reason.name}): $message';
}

/// ElevenLabs Text-to-Speech API client.
///
/// Features:
///   - 6-second timeout guard
///   - In-memory LRU cache for repeated phrases (last 20)
///   - Typed exceptions for precise fallback decisions
///   - Elder-care optimized voice settings (stable, warm)
///   - Fully async — never blocks UI
class ElevenLabsService {
  ElevenLabsService._();
  static final ElevenLabsService instance = ElevenLabsService._();

  /// Timeout for API requests — triggers fallback if exceeded.
  static const _requestTimeout = Duration(seconds: 6);

  /// LRU cache: text hash → MP3 bytes.
  /// Avoids re-fetching audio for repeated phrases like greetings.
  final Map<String, Uint8List> _audioCache = {};
  static const int _maxCacheEntries = 20;

  /// Whether ElevenLabs is configured with a real API key.
  bool get isConfigured => ApiConfig.isElevenLabsEnabled;

  /// Synthesize text to MP3 audio bytes via ElevenLabs API.
  ///
  /// Returns raw MP3 [Uint8List] on success.
  /// Throws [ElevenLabsException] with a typed [ElevenLabsFailReason] on failure.
  Future<Uint8List> synthesize(String text) async {
    if (!isConfigured) {
      throw const ElevenLabsException(
        ElevenLabsFailReason.notConfigured,
        'ElevenLabs API key not configured',
      );
    }

    if (text.trim().isEmpty) {
      throw const ElevenLabsException(
        ElevenLabsFailReason.emptyResponse,
        'Empty text provided',
      );
    }

    // ── Check cache ──
    final cacheKey = text.trim().toLowerCase();
    if (_audioCache.containsKey(cacheKey)) {
      AppLogger.info(
        LogCategory.lifecycle,
        '[VOICE] ElevenLabs cache hit (${cacheKey.length} chars)',
      );
      return _audioCache[cacheKey]!;
    }

    // ── API call with timeout ──
    final stopwatch = Stopwatch()..start();

    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.elevenLabsEndpoint),
            headers: {
              'xi-api-key': ApiConfig.elevenLabsApiKey,
              'Content-Type': 'application/json',
              'Accept': 'audio/mpeg',
            },
            body: jsonEncode({
              'text': text,
              'model_id': ApiConfig.elevenLabsModel,
              'voice_settings': {
                // Stability: 0.6 for natural expressiveness
                'stability': 0.6,
                // Similarity boost: close to original voice
                'similarity_boost': 0.75,
                // Style: subtle expressiveness for warmth
                'style': 0.35,
                // Speaker boost for clarity
                'use_speaker_boost': true,
              },
            }),
          )
          .timeout(_requestTimeout);

      stopwatch.stop();
      final elapsed = stopwatch.elapsedMilliseconds;

      // ── Handle HTTP status codes ──
      switch (response.statusCode) {
        case 200:
          final bytes = response.bodyBytes;
          if (bytes.isEmpty) {
            throw const ElevenLabsException(
              ElevenLabsFailReason.emptyResponse,
              'API returned empty audio',
            );
          }

          // Cache the result
          _addToCache(cacheKey, bytes);

          AppLogger.info(
            LogCategory.lifecycle,
            '[VOICE] ElevenLabs success — voice=${ApiConfig.elevenLabsVoiceId}, '
            '${bytes.length} bytes, ${elapsed}ms',
          );
          return bytes;

        case 401:
          throw const ElevenLabsException(
            ElevenLabsFailReason.invalidApiKey,
            'Invalid API key (401)',
          );

        case 402:
        case 429:
          throw ElevenLabsException(
            ElevenLabsFailReason.quotaExceeded,
            'Quota exceeded or rate limited (${response.statusCode})',
          );

        default:
          throw ElevenLabsException(
            ElevenLabsFailReason.serverError,
            'HTTP ${response.statusCode}: ${response.body.length > 200 ? response.body.substring(0, 200) : response.body}',
          );
      }
    } on TimeoutException {
      stopwatch.stop();
      throw ElevenLabsException(
        ElevenLabsFailReason.timeout,
        'Request timed out after ${_requestTimeout.inSeconds}s',
      );
    } on ElevenLabsException {
      rethrow;
    } catch (e) {
      throw ElevenLabsException(
        ElevenLabsFailReason.networkError,
        'Network error: $e',
      );
    }
  }

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
