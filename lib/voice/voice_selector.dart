import 'package:flutter_tts/flutter_tts.dart';
import '../services/app_logger.dart';

/// Queries available TTS voices and selects the best voice using
/// heuristic scoring. Does NOT rely on gender metadata (Android often
/// does not expose it). Instead uses name hints, locale priority, and
/// quality indicators.
///
/// Selection priority (by score):
///   1. hi-IN voice with female/quality hints   (highest)
///   2. hi-IN voice (any)
///   3. en-IN voice with female/quality hints
///   4. en-IN voice (any)
///   5. en-US neural/enhanced voice
///   6. best available voice on device           (lowest, but never fails)
class VoiceSelector {
  VoiceSelector._();
  static final VoiceSelector instance = VoiceSelector._();

  Map<String, String>? _cachedVoice;
  bool _scanned = false;

  /// The cached best voice, or null if not yet scanned.
  Map<String, String>? get cachedVoice => _cachedVoice;

  /// Whether a suitable voice was found and cached.
  bool get hasVoice => _cachedVoice != null;

  /// Scan available voices and select the best one via heuristic scoring.
  /// Safe to call multiple times — only scans once.
  Future<void> selectBestVoice(FlutterTts tts) async {
    if (_scanned) return;
    _scanned = true;

    try {
      final List<dynamic> rawVoices = await tts.getVoices;
      if (rawVoices.isEmpty) {
        AppLogger.warn(
          LogCategory.lifecycle,
          '[VOICE] No TTS voices available on device',
        );
        return;
      }

      // Normalize voice data
      final voices = rawVoices
          .whereType<Map>()
          .map(
            (v) => {
              'name': (v['name'] ?? '').toString().toLowerCase(),
              'locale': (v['locale'] ?? '').toString().toLowerCase(),
            },
          )
          .toList();

      AppLogger.info(
        LogCategory.lifecycle,
        '[VOICE] Found ${voices.length} TTS voices, scoring for best match',
      );

      // Log first 20 voices for debugging
      for (int i = 0; i < voices.length && i < 20; i++) {
        AppLogger.info(
          LogCategory.lifecycle,
          '[VOICE]   [$i] name=${voices[i]['name']}, locale=${voices[i]['locale']}',
        );
      }
      if (voices.length > 20) {
        AppLogger.info(
          LogCategory.lifecycle,
          '[VOICE]   ... and ${voices.length - 20} more voices',
        );
      }

      // ── Score every voice and pick the highest ──
      Map<String, String>? bestVoice;
      int bestScore = -1;

      for (final voice in voices) {
        final score = _scoreVoice(voice);
        if (score > bestScore) {
          bestScore = score;
          bestVoice = voice;
        }
      }

      if (bestVoice != null) {
        _cachedVoice = bestVoice;
        AppLogger.info(
          LogCategory.lifecycle,
          '[VOICE] Selected voice: ${bestVoice['name']} '
          'locale=${bestVoice['locale']} (score=$bestScore)',
        );
      } else {
        AppLogger.warn(
          LogCategory.lifecycle,
          '[VOICE] Could not score any voice, using device default',
        );
      }
    } catch (e) {
      AppLogger.error(
        LogCategory.lifecycle,
        '[VOICE] Voice selection failed: $e',
      );
    }
  }

  // ══════════════════════════════════════════════════════
  //  HEURISTIC SCORING ENGINE
  // ══════════════════════════════════════════════════════

  /// Score a voice from 0–100+ based on heuristic signals.
  /// Higher score = better match for ElderCare.
  int _scoreVoice(Map<String, String> voice) {
    final name = voice['name'] ?? '';
    final locale = voice['locale'] ?? '';
    int score = 0;

    // ── Locale scoring (most important) ──
    if (locale.startsWith('hi')) {
      score += 50; // Hindi is highest priority
    } else if (locale.contains('en') && locale.contains('in')) {
      score += 35; // en-IN is second priority
    } else if (locale.startsWith('en')) {
      score += 15; // any English
    }

    // ── Female hint scoring ──
    // Android voices often have female names even without explicit gender metadata
    const femaleHints = [
      'female', 'woman', 'girl', 'fem',
      // Indian female voice names (Google, Samsung, OEMs)
      'swara', 'lekha', 'aditi', 'raveena', 'priya', 'neerja',
      'sapna', 'sunita', 'anjali', 'kavita', 'pooja', 'meera',
      'sita', 'devi', 'rani', 'ananya', 'divya', 'neha', 'shreya',
      // English female names commonly used by TTS engines
      'zira', 'samantha', 'karen', 'moira', 'tessa', 'joanna',
    ];
    if (femaleHints.any((hint) => name.contains(hint))) {
      score += 25;
    }

    // ── Quality/neural scoring ──
    const qualityHints = [
      'neural',
      'wavenet',
      'enhanced',
      'premium',
      'natural',
      'studio',
      'hd',
      'high',
    ];
    if (qualityHints.any((hint) => name.contains(hint))) {
      score += 15;
    }

    // ── Penalize compact/low-quality voices ──
    if (name.contains('compact') || name.contains('legacy')) {
      score -= 10;
    }

    // ── Prefer network voices (often higher quality on Android) ──
    if (name.contains('network') || name.contains('online')) {
      score += 5;
    }

    // ── Male hint penalty (lower priority, not exclude) ──
    const maleHints = ['male', 'man', 'boy'];
    // Only apply penalty if explicitly male AND no female hint
    if (maleHints.any((h) => name.contains(h)) &&
        !femaleHints.any((h) => name.contains(h))) {
      score -= 10;
    }

    return score;
  }

  /// Reset cache (for testing or manual re-scan).
  void reset() {
    _cachedVoice = null;
    _scanned = false;
  }
}
