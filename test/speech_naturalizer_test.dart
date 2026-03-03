import 'package:flutter_test/flutter_test.dart';
import 'package:eldercare_ai/voice/speech_naturalizer.dart';

/// Unit tests for [SpeechNaturalizer] — the pre-TTS text normalization layer.
///
/// Tests cover: emoji removal, abbreviation expansion, number normalization,
/// Hinglish avoidance, micro-pause insertion, and edge cases.
void main() {
  // ═══════════════════════════════════════════════════════════
  //  EMOJI REMOVAL
  // ═══════════════════════════════════════════════════════════

  group('Emoji Removal', () {
    test('removes common smiley emojis', () {
      final result = SpeechNaturalizer.naturalize('Hello 🙂');
      expect(result, isNot(contains('🙂')));
      expect(result.trim(), contains('Hello'));
    });

    test('removes multiple emojis', () {
      final result = SpeechNaturalizer.naturalize('Good morning! 🌞💊❤️');
      expect(result, isNot(contains('🌞')));
      expect(result, isNot(contains('💊')));
      expect(result, isNot(contains('❤️')));
      expect(result, contains('Good morning'));
    });

    test('handles text with only emojis', () {
      final result = SpeechNaturalizer.naturalize('🙂😊👍');
      expect(result.trim(), isEmpty);
    });

    test('preserves text around emojis', () {
      final result = SpeechNaturalizer.naturalize('Sab 🙂 theek 👍 hai');
      expect(result, contains('Sab'));
      expect(result, contains('hai'));
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  ABBREVIATION EXPANSION
  // ═══════════════════════════════════════════════════════════

  group('Abbreviation Expansion', () {
    test('BP expands to Blood Pressure', () {
      final result = SpeechNaturalizer.naturalize('BP is normal');
      expect(result, contains('Blood Pressure'));
      expect(result, isNot(contains(' BP ')));
    });

    test('BMI expands to Body Mass Index', () {
      final result = SpeechNaturalizer.naturalize('Your BMI is 22');
      expect(result, contains('Body Mass Index'));
    });

    test('OTP expands to O T P', () {
      final result = SpeechNaturalizer.naturalize('Enter OTP');
      expect(result, contains('O T P'));
    });

    test('multiple abbreviations expand correctly', () {
      final result = SpeechNaturalizer.naturalize('BP and HR are normal');
      expect(result, contains('Blood Pressure'));
      expect(result, contains('Heart Rate'));
    });

    test('units expand correctly', () {
      final result = SpeechNaturalizer.naturalize('Take 500 mg daily');
      expect(result, contains('milligram'));
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  NUMBER NORMALIZATION
  // ═══════════════════════════════════════════════════════════

  group('Number Normalization', () {
    test('BP-style fraction normalized', () {
      final result = SpeechNaturalizer.naturalize('120/80');
      expect(result, contains('120 over 80'));
    });

    test('percentage normalized', () {
      final result = SpeechNaturalizer.naturalize('85%');
      expect(result, contains('85 percent'));
    });

    test('temperature Fahrenheit normalized', () {
      final result = SpeechNaturalizer.naturalize('98.6°F');
      expect(result, contains('degrees Fahrenheit'));
    });

    test('temperature Celsius normalized', () {
      final result = SpeechNaturalizer.naturalize('37°C');
      expect(result, contains('degrees Celsius'));
    });

    test('range normalized', () {
      final result = SpeechNaturalizer.naturalize('50-60');
      expect(result, contains('50 to 60'));
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  HINGLISH AVOIDANCE
  // ═══════════════════════════════════════════════════════════

  group('Hinglish Avoidance', () {
    test('replaces OK with theek hai in Hindi context', () {
      final result = SpeechNaturalizer.naturalize('Aapka test OK hai');
      expect(result, contains('theek hai'));
    });

    test('does not replace in pure English text', () {
      final result = SpeechNaturalizer.naturalize('Everything is OK');
      // No Hindi signals -> no replacement
      expect(result, contains('OK'));
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  MICRO-PAUSE INSERTION
  // ═══════════════════════════════════════════════════════════

  group('Micro-Pause Insertion', () {
    test('adds space after period if missing', () {
      final result = SpeechNaturalizer.naturalize('Hello.World');
      expect(result, contains('. '));
    });

    test('adds space after question mark if missing', () {
      final result = SpeechNaturalizer.naturalize('Kaise hain?Theek');
      expect(result, contains('? '));
    });

    test('replaces colon-space with comma-space', () {
      final result = SpeechNaturalizer.naturalize('Status: Normal');
      expect(result, contains(', '));
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  SYMBOL CLEANUP
  // ═══════════════════════════════════════════════════════════

  group('Symbol Cleanup', () {
    test('removes markdown-style symbols', () {
      final result = SpeechNaturalizer.naturalize('**Bold** text');
      expect(result, isNot(contains('**')));
      expect(result, contains('Bold'));
    });

    test('replaces ellipsis with comma', () {
      final result = SpeechNaturalizer.naturalize('Wait... please');
      expect(result, contains(','));
    });

    test('replaces em-dash with comma', () {
      final result = SpeechNaturalizer.naturalize('Health—good');
      expect(result, contains(','));
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  INTEGRATION / REAL-WORLD SCENARIOS
  // ═══════════════════════════════════════════════════════════

  group('Real-World Scenarios', () {
    test('BP 120/80 OK 🙂 transforms naturally', () {
      final result = SpeechNaturalizer.naturalize('BP 120/80 OK 🙂');
      expect(result, contains('Blood Pressure'));
      expect(result, contains('120 over 80'));
      expect(result, isNot(contains('🙂')));
    });

    test('empty string returns empty', () {
      expect(SpeechNaturalizer.naturalize(''), equals(''));
    });

    test('whitespace-only returns empty-ish', () {
      expect(SpeechNaturalizer.naturalize('   ').trim(), isEmpty);
    });

    test('Hindi text with emojis cleans up', () {
      final result = SpeechNaturalizer.naturalize('Aapki sehat theek hai 🙏✨');
      expect(result, isNot(contains('🙏')));
      expect(result, isNot(contains('✨')));
      expect(result, contains('sehat'));
    });
  });
}
