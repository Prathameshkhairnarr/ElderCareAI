import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../services/app_logger.dart';
import 'tts_text_cleaner.dart';

/// Reason for Edge TTS failure — used for precise fallback logging.
enum EdgeTtsFailReason {
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

/// Edge TTS client — calls backend which uses edge-tts Python library.
///
/// The Python library handles Sec-MS-GEC token generation (required since Oct 2024).
/// Same neural voices as Azure (hi-IN-SwaraNeural, en-IN-NeerjaNeural).
/// FREE — no API key needed.
class EdgeTtsService {
  EdgeTtsService._();
  static final EdgeTtsService instance = EdgeTtsService._();

  /// Timeout for API requests.
  static const _requestTimeout = Duration(seconds: 15);

  /// LRU cache: text+voice hash → MP3 bytes.
  final Map<String, Uint8List> _audioCache = {};
  static const int _maxCacheEntries = 20;

  /// Edge TTS is always configured (backend handles auth).
  bool get isConfigured => true;

  // ══════════════════════════════════════════════════════
  //  SYNTHESIZE
  // ══════════════════════════════════════════════════════

  /// Synthesize text to MP3 audio bytes via backend Edge TTS endpoint.
  ///
  /// Backend uses edge-tts Python library which handles Sec-MS-GEC token.
  /// Returns raw MP3 [Uint8List] on success.
  /// Throws [EdgeTtsException] on failure.
  Future<Uint8List> synthesize(
    String text, {
    String? voiceName,
    String rate = '-8%',
    String pitch = '+2Hz',
    String volume = '+0%',
  }) async {
    if (text.trim().isEmpty) {
      throw const EdgeTtsException(
        EdgeTtsFailReason.emptyResponse,
        'Empty text provided',
      );
    }

    final voice = voiceName ?? 'hi-IN-SwaraNeural';

    // ── Check cache ──
    final cacheKey = '${text.trim().toLowerCase()}_$voice';
    if (_audioCache.containsKey(cacheKey)) {
      AppLogger.info(
        LogCategory.lifecycle,
        '[VOICE] Edge TTS cache hit',
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
    final cleanedText = cleanedSentences.join(' ');

    // ── Call backend ──
    final stopwatch = Stopwatch()..start();

    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/tts/synthesize'),
            headers: {'Content-Type': 'application/json'},
            body: '{"text":"${_escapeJson(cleanedText)}","voice":"$voice","rate":"$rate","pitch":"$pitch"}',
          )
          .timeout(_requestTimeout);

      stopwatch.stop();
      final elapsed = stopwatch.elapsedMilliseconds;

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        if (bytes.isEmpty || bytes.length < 100) {
          throw const EdgeTtsException(
            EdgeTtsFailReason.emptyResponse,
            'Backend returned empty/tiny audio',
          );
        }

        _addToCache(cacheKey, bytes);

        AppLogger.info(
          LogCategory.lifecycle,
          '[VOICE] Edge TTS success — voice=$voice, '
          '${bytes.length} bytes, ${elapsed}ms',
        );
        return bytes;
      } else {
        throw EdgeTtsException(
          EdgeTtsFailReason.serverError,
          'HTTP ${response.statusCode}: ${response.body.length > 150 ? response.body.substring(0, 150) : response.body}',
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
      stopwatch.stop();
      throw EdgeTtsException(
        EdgeTtsFailReason.networkError,
        'Network error: $e',
      );
    }
  }

  // ══════════════════════════════════════════════════════
  //  HELPERS
  // ══════════════════════════════════════════════════════

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

  void _addToCache(String key, Uint8List bytes) {
    if (_audioCache.length >= _maxCacheEntries) {
      _audioCache.remove(_audioCache.keys.first);
    }
    _audioCache[key] = bytes;
  }

  void clearCache() => _audioCache.clear();
}
