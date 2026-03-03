import 'dart:async';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../services/app_logger.dart';
import 'tts_text_cleaner.dart';

/// Reason for Azure TTS failure — used for precise fallback logging.
enum AzureTtsFailReason {
  notConfigured,
  quotaExceeded,
  invalidKey,
  networkError,
  timeout,
  emptyResponse,
  serverError,
  unknown,
}

/// Exception thrown when Azure TTS fails.
class AzureTtsException implements Exception {
  final AzureTtsFailReason reason;
  final String message;

  const AzureTtsException(this.reason, this.message);

  @override
  String toString() => 'AzureTtsException(${reason.name}): $message';
}

/// Azure Cognitive Services Neural Text-to-Speech client.
///
/// Features:
///   - SSML with `mstts:express-as style="chat"` for natural conversational tone
///   - `hi-IN-SwaraNeural` primary voice (female, warm, elder-friendly)
///   - Prosody tuning: rate -5% (responsive, not sleepy)
///   - 6-second timeout guard
///   - In-memory LRU cache (20 entries)
///   - Typed exceptions for precise fallback decisions
///   - Fully async — never blocks UI
class AzureTtsService {
  AzureTtsService._();
  static final AzureTtsService instance = AzureTtsService._();

  /// Timeout for API requests — triggers fallback if exceeded.
  static const _requestTimeout = Duration(seconds: 6);

  /// LRU cache: text hash → MP3 bytes.
  final Map<String, Uint8List> _audioCache = {};
  static const int _maxCacheEntries = 20;

  /// Whether Azure is configured with a real subscription key.
  bool get isConfigured => ApiConfig.isAzureEnabled;

  // ══════════════════════════════════════════════════════
  //  SSML BUILDER
  // ══════════════════════════════════════════════════════

  /// Build SSML markup for Azure Neural TTS.
  ///
  /// Optimized for real-time conversational feel:
  ///   - `chat` style — natural rhythm, no dramatic pauses
  ///   - Rate `-5%` — responsive, not sleepy
  ///   - Dynamic `ssmlLang` + `voiceName` for multi-language
  ///
  /// The [text] must already be XML-escaped before calling this method.
  static String buildSsml(
    String text, {
    String? voiceName,
    String ssmlLang = 'hi-IN',
  }) {
    final voice = voiceName ?? ApiConfig.azureVoiceName;

    return '''<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xmlns:mstts="https://www.w3.org/2001/mstts" xml:lang="$ssmlLang">
  <voice name="$voice">
    <mstts:express-as style="chat">
      <prosody rate="-5%" pitch="0%">
        $text
      </prosody>
    </mstts:express-as>
  </voice>
</speak>''';
  }

  // ══════════════════════════════════════════════════════
  //  SYNTHESIZE
  // ══════════════════════════════════════════════════════

  /// Synthesize text to MP3 audio bytes via Azure Speech Service.
  ///
  /// The text is cleaned via [TtsTextCleaner] and wrapped in SSML.
  /// Supports multi-language: pass [ssmlLang] and [voiceName] for
  /// dynamic language switching (defaults to Hindi).
  /// Returns raw MP3 [Uint8List] on success.
  /// Throws [AzureTtsException] with a typed [AzureTtsFailReason] on failure.
  Future<Uint8List> synthesize(
    String text, {
    String ssmlLang = 'hi-IN',
    String? voiceName,
  }) async {
    if (!isConfigured) {
      throw const AzureTtsException(
        AzureTtsFailReason.notConfigured,
        'Azure subscription key not configured',
      );
    }

    if (text.trim().isEmpty) {
      throw const AzureTtsException(
        AzureTtsFailReason.emptyResponse,
        'Empty text provided',
      );
    }

    // ── Check cache ──
    final cacheKey = text.trim().toLowerCase();
    if (_audioCache.containsKey(cacheKey)) {
      AppLogger.info(
        LogCategory.lifecycle,
        '[VOICE] Azure cache hit (${cacheKey.length} chars)',
      );
      return _audioCache[cacheKey]!;
    }

    // ── Clean text and build SSML ──
    final cleanedSentences = TtsTextCleaner.cleanForAzure(text);
    if (cleanedSentences.isEmpty) {
      throw const AzureTtsException(
        AzureTtsFailReason.emptyResponse,
        'Text cleaned to empty',
      );
    }

    // Join sentences with natural pauses (period + space) for SSML
    final cleanedText = cleanedSentences.join(' ');
    final ssml = buildSsml(
      cleanedText,
      ssmlLang: ssmlLang,
      voiceName: voiceName,
    );

    // ── API call with timeout ──
    final stopwatch = Stopwatch()..start();

    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.azureEndpoint),
            headers: {
              'Ocp-Apim-Subscription-Key': ApiConfig.azureSubscriptionKey,
              'Content-Type': 'application/ssml+xml',
              'X-Microsoft-OutputFormat': ApiConfig.azureOutputFormat,
              'User-Agent': 'eldercare-app',
            },
            body: ssml,
          )
          .timeout(_requestTimeout);

      stopwatch.stop();
      final elapsed = stopwatch.elapsedMilliseconds;

      // ── Handle HTTP status codes ──
      switch (response.statusCode) {
        case 200:
          final bytes = response.bodyBytes;
          if (bytes.isEmpty) {
            throw const AzureTtsException(
              AzureTtsFailReason.emptyResponse,
              'API returned empty audio',
            );
          }

          // Cache the result
          _addToCache(cacheKey, bytes);

          AppLogger.info(
            LogCategory.lifecycle,
            '[VOICE] Azure success — voice=${ApiConfig.azureVoiceName}, '
            '${bytes.length} bytes, ${elapsed}ms',
          );
          return bytes;

        case 401:
          throw const AzureTtsException(
            AzureTtsFailReason.invalidKey,
            'Invalid subscription key (401)',
          );

        case 403:
          throw const AzureTtsException(
            AzureTtsFailReason.invalidKey,
            'Forbidden — check subscription key and region (403)',
          );

        case 429:
          throw AzureTtsException(
            AzureTtsFailReason.quotaExceeded,
            'Rate limited or quota exceeded (${response.statusCode})',
          );

        default:
          throw AzureTtsException(
            AzureTtsFailReason.serverError,
            'HTTP ${response.statusCode}: '
            '${response.body.length > 200 ? response.body.substring(0, 200) : response.body}',
          );
      }
    } on TimeoutException {
      stopwatch.stop();
      throw AzureTtsException(
        AzureTtsFailReason.timeout,
        'Request timed out after ${_requestTimeout.inSeconds}s',
      );
    } on AzureTtsException {
      rethrow;
    } catch (e) {
      throw AzureTtsException(
        AzureTtsFailReason.networkError,
        'Network error: $e',
      );
    }
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
