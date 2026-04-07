import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../services/app_logger.dart';
import 'tts_text_cleaner.dart';

/// Exception thrown when Google TTS fails.
class GoogleTtsException implements Exception {
  final String message;

  const GoogleTtsException(this.message);

  @override
  String toString() => 'GoogleTtsException: $message';
}

/// Google Cloud Text-to-Speech client.
class GoogleTtsService {
  GoogleTtsService._();
  static final GoogleTtsService instance = GoogleTtsService._();

  static const _requestTimeout = Duration(seconds: 6);

  final Map<String, Uint8List> _audioCache = {};
  static const int _maxCacheEntries = 20;

  bool get isConfigured => ApiConfig.isGoogleTtsEnabled;

  Future<Uint8List> synthesize(
    String text, {
    String languageCode = 'hi-IN',
    String? voiceName,
  }) async {
    if (!isConfigured) {
      throw const GoogleTtsException('Google TTS API key not configured');
    }

    if (text.trim().isEmpty) {
      throw const GoogleTtsException('Empty text provided');
    }

    final cacheKey = text.trim().toLowerCase();
    if (_audioCache.containsKey(cacheKey)) {
      AppLogger.info(
        LogCategory.lifecycle,
        '[VOICE] Google TTS cache hit (${cacheKey.length} chars)',
      );
      return _audioCache[cacheKey]!;
    }

    final cleanedSentences = TtsTextCleaner.cleanForAzure(text);
    if (cleanedSentences.isEmpty) {
      throw const GoogleTtsException('Text cleaned to empty');
    }
    final cleanedText = cleanedSentences.join(' ');

    final stopwatch = Stopwatch()..start();

    try {
      final requestBody = jsonEncode({
        'input': {
          'ssml': '<speak><prosody pitch="+1st">$cleanedText</prosody></speak>'
        },
        'voice': {
          'languageCode': languageCode,
          'name': voiceName ?? ApiConfig.googleVoiceName
        },
        'audioConfig': {'audioEncoding': 'MP3'}
      });

      final response = await http
          .post(
            Uri.parse('${ApiConfig.googleTtsEndpoint}?key=${ApiConfig.googleTtsApiKey}'),
            headers: {'Content-Type': 'application/json'},
            body: requestBody,
          )
          .timeout(_requestTimeout);

      stopwatch.stop();

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['audioContent'] != null) {
          final bytes = base64Decode(json['audioContent']);
          _addToCache(cacheKey, bytes);

          AppLogger.info(
            LogCategory.lifecycle,
            '[VOICE] Google TTS success — voice=${voiceName ?? ApiConfig.googleVoiceName}, '
            '${bytes.length} bytes, ${stopwatch.elapsedMilliseconds}ms',
          );
          return bytes;
        } else {
          throw const GoogleTtsException('API returned empty audioContent');
        }
      } else {
        throw GoogleTtsException(
          'HTTP ${response.statusCode}: '
          '${response.body.length > 200 ? response.body.substring(0, 200) : response.body}',
        );
      }
    } on TimeoutException {
      stopwatch.stop();
      throw const GoogleTtsException('Request timed out');
    } catch (e) {
      stopwatch.stop();
      throw GoogleTtsException('Network error: $e');
    }
  }

  void _addToCache(String key, Uint8List bytes) {
    if (_audioCache.length >= _maxCacheEntries) {
      _audioCache.remove(_audioCache.keys.first);
    }
    _audioCache[key] = bytes;
  }

  void clearCache() => _audioCache.clear();
}
