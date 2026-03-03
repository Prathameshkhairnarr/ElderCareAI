import 'package:flutter_test/flutter_test.dart';
import 'package:eldercare_ai/voice/azure_tts_service.dart';
import 'package:eldercare_ai/voice/tts_text_cleaner.dart';

/// Unit tests for Azure TTS integration.
///
/// Covers:
///   - SSML generation (structure, voice, prosody, namespace)
///   - TtsTextCleaner pipeline (emoji, numbers, abbreviations, XML escaping)
///   - AzureTtsException hierarchy
void main() {
  // ═══════════════════════════════════════════════════════════
  //  SSML GENERATION
  // ═══════════════════════════════════════════════════════════

  group('SSML Generation', () {
    test('contains correct XML declaration and namespaces', () {
      final ssml = AzureTtsService.buildSsml('Namaste');
      expect(ssml, contains('version="1.0"'));
      expect(ssml, contains('xmlns="http://www.w3.org/2001/10/synthesis"'));
      expect(ssml, contains('xmlns:mstts="https://www.w3.org/2001/mstts"'));
      expect(ssml, contains('xml:lang="hi-IN"'));
    });

    test('uses correct voice name', () {
      final ssml = AzureTtsService.buildSsml('Hello');
      expect(ssml, contains('name="hi-IN-SwaraNeural"'));
    });

    test('uses custom voice name when provided', () {
      final ssml = AzureTtsService.buildSsml(
        'Hello',
        voiceName: 'hi-IN-PallaviNeural',
      );
      expect(ssml, contains('name="hi-IN-PallaviNeural"'));
      expect(ssml, isNot(contains('hi-IN-SwaraNeural')));
    });

    test('applies responsive prosody rate', () {
      final ssml = AzureTtsService.buildSsml('Test');
      expect(ssml, contains('rate="-5%"'));
    });

    test('applies natural pitch', () {
      final ssml = AzureTtsService.buildSsml('Test');
      expect(ssml, contains('pitch="0%"'));
    });

    test('uses chat expression style', () {
      final ssml = AzureTtsService.buildSsml('Test');
      expect(ssml, contains('mstts:express-as'));
      expect(ssml, contains('style="chat"'));
    });

    test('embeds text inside SSML structure', () {
      final ssml = AzureTtsService.buildSsml('Aapki sehat theek hai');
      expect(ssml, contains('Aapki sehat theek hai'));
    });

    test('produces well-formed XML with start and end tags', () {
      final ssml = AzureTtsService.buildSsml('Test');
      expect(ssml, startsWith('<speak'));
      expect(ssml, endsWith('</speak>'));
      expect(ssml, contains('</voice>'));
      expect(ssml, contains('</prosody>'));
      expect(ssml, contains('</mstts:express-as>'));
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  TEXT CLEANER — EMOJI REMOVAL
  // ═══════════════════════════════════════════════════════════

  group('TtsTextCleaner — Emoji Removal', () {
    test('removes smiley emojis', () {
      final result = TtsTextCleaner.cleanForAzure('Hello 🙂');
      expect(result.join(' '), isNot(contains('🙂')));
      expect(result.join(' '), contains('Hello'));
    });

    test('removes multiple emojis', () {
      final result = TtsTextCleaner.cleanForAzure('Good morning! 🌞💊❤️');
      expect(result.join(' '), isNot(contains('🌞')));
      expect(result.join(' '), isNot(contains('💊')));
      expect(result.join(' '), contains('Good morning'));
    });

    test('handles text with only emojis', () {
      final result = TtsTextCleaner.cleanForAzure('🙂😊👍');
      expect(result, isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  TEXT CLEANER — ABBREVIATION EXPANSION
  // ═══════════════════════════════════════════════════════════

  group('TtsTextCleaner — Abbreviation Expansion', () {
    test('BP expands to Blood Pressure', () {
      final result = TtsTextCleaner.cleanForAzure('BP is normal');
      expect(result.join(' '), contains('Blood Pressure'));
    });

    test('OTP expands to O T P', () {
      final result = TtsTextCleaner.cleanForAzure('Enter OTP');
      expect(result.join(' '), contains('O T P'));
    });

    test('multiple abbreviations expand', () {
      final result = TtsTextCleaner.cleanForAzure('BP and HR are normal');
      expect(result.join(' '), contains('Blood Pressure'));
      expect(result.join(' '), contains('Heart Rate'));
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  TEXT CLEANER — NUMBER NORMALIZATION
  // ═══════════════════════════════════════════════════════════

  group('TtsTextCleaner — Number Normalization', () {
    test('BP-style fraction normalized', () {
      final result = TtsTextCleaner.cleanForAzure('120/80');
      expect(result.join(' '), contains('120 over 80'));
    });

    test('percentage normalized', () {
      final result = TtsTextCleaner.cleanForAzure('85%');
      expect(result.join(' '), contains('85 percent'));
    });

    test('temperature Celsius normalized', () {
      final result = TtsTextCleaner.cleanForAzure('37°C');
      expect(result.join(' '), contains('degrees Celsius'));
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  TEXT CLEANER — XML ESCAPING
  // ═══════════════════════════════════════════════════════════

  group('TtsTextCleaner — XML Escaping', () {
    test('escapes ampersand', () {
      final result = TtsTextCleaner.cleanForAzure('A & B');
      expect(result.join(' '), contains('&amp;'));
      expect(result.join(' '), isNot(contains(' & ')));
    });

    test('escapes angle brackets', () {
      final result = TtsTextCleaner.lightClean('value > 5');
      expect(result, contains('&gt;'));
    });

    test('escapes quotes', () {
      final result = TtsTextCleaner.lightClean('say "hello"');
      expect(result, contains('&quot;'));
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  TEXT CLEANER — SENTENCE SPLITTING
  // ═══════════════════════════════════════════════════════════

  group('TtsTextCleaner — Sentence Splitting', () {
    test('splits on periods', () {
      final result = TtsTextCleaner.cleanForAzure(
        'Namaste. Aapki sehat theek hai.',
      );
      expect(result.length, greaterThanOrEqualTo(2));
    });

    test('splits on Hindi purna viram', () {
      final result = TtsTextCleaner.cleanForAzure(
        'Sab theek hai। Aapka dhyaan rakhein।',
      );
      expect(result.length, greaterThanOrEqualTo(2));
    });

    test('short text stays as single sentence', () {
      final result = TtsTextCleaner.cleanForAzure('Namaste');
      expect(result.length, equals(1));
    });

    test('empty string returns empty list', () {
      final result = TtsTextCleaner.cleanForAzure('');
      expect(result, isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  TEXT CLEANER — REAL-WORLD SCENARIOS
  // ═══════════════════════════════════════════════════════════

  group('TtsTextCleaner — Real-World', () {
    test('BP 120/80 OK 🙂 transforms naturally', () {
      final result = TtsTextCleaner.cleanForAzure('BP 120/80 OK 🙂');
      final joined = result.join(' ');
      expect(joined, contains('Blood Pressure'));
      expect(joined, contains('120 over 80'));
      expect(joined, isNot(contains('🙂')));
    });

    test('preserves Hindi Unicode', () {
      final result = TtsTextCleaner.cleanForAzure('आपकी सेहत अच्छी है।');
      final joined = result.join(' ');
      expect(joined, contains('आपकी'));
      expect(joined, contains('सेहत'));
    });

    test('handles mixed Hindi-English', () {
      final result = TtsTextCleaner.cleanForAzure(
        'Aapka blood pressure 120 over 80 hai',
      );
      final joined = result.join(' ');
      expect(joined, contains('Aapka'));
      expect(joined, contains('blood'));
      expect(joined, contains('hai'));
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  AZURE TTS EXCEPTION
  // ═══════════════════════════════════════════════════════════

  group('AzureTtsException', () {
    test('creates with correct reason and message', () {
      const exc = AzureTtsException(
        AzureTtsFailReason.timeout,
        'Timed out after 6s',
      );
      expect(exc.reason, equals(AzureTtsFailReason.timeout));
      expect(exc.message, equals('Timed out after 6s'));
    });

    test('toString includes reason name', () {
      const exc = AzureTtsException(
        AzureTtsFailReason.networkError,
        'Connection refused',
      );
      expect(exc.toString(), contains('networkError'));
      expect(exc.toString(), contains('Connection refused'));
    });

    test('all fail reasons are defined', () {
      expect(AzureTtsFailReason.values.length, greaterThanOrEqualTo(7));
      expect(
        AzureTtsFailReason.values.map((e) => e.name),
        containsAll([
          'notConfigured',
          'quotaExceeded',
          'invalidKey',
          'networkError',
          'timeout',
          'emptyResponse',
          'serverError',
        ]),
      );
    });
  });
}
