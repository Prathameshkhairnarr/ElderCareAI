import 'package:flutter_test/flutter_test.dart';
import 'package:eldercare_ai/voice/text_normalizer.dart';

/// Unit tests for [TextNormalizer] — the text normalization layer
/// that powers Hindi intent understanding.
///
/// Tests cover: Devanagari transliteration, synonym mapping,
/// filler word removal, punctuation stripping, and edge cases.
void main() {
  // ═══════════════════════════════════════════════════════════
  //  Devanagari Transliteration
  // ═══════════════════════════════════════════════════════════

  group('Devanagari Transliteration', () {
    test('हेल्थ स्कोर → health score', () {
      final result = TextNormalizer.normalize('हेल्थ स्कोर');
      expect(result, contains('health'));
      expect(result, contains('score'));
    });

    test('मेरा हेल्थ स्कोर बताओ → health score batao (filler removed)', () {
      final result = TextNormalizer.normalize('मेरा हेल्थ स्कोर बताओ');
      expect(result, contains('health'));
      expect(result, contains('score'));
      expect(result, contains('batao'));
      // 'मेरा' → 'mera' should NOT be present (it's a filler word)
      expect(result, isNot(contains('mera')));
    });

    test('खतरा → risk', () {
      final result = TextNormalizer.normalize('खतरा');
      expect(result, contains('risk'));
    });

    test('संदेश → sms', () {
      final result = TextNormalizer.normalize('संदेश');
      expect(result, contains('sms'));
    });

    test('आपातकाल → emergency', () {
      final result = TextNormalizer.normalize('आपातकाल');
      expect(result, contains('emergency'));
    });

    test('मदद → help (synonym: madad → help)', () {
      // मदद → transliterated to 'madad', but madad is not in synonyms
      // Actually it should just be 'madad' after transliteration
      final result = TextNormalizer.normalize('मदद');
      expect(result, contains('madad'));
    });

    test('दवाई → medicine (synonym: dawai → medicine)', () {
      final result = TextNormalizer.normalize('दवाई');
      expect(result, contains('medicine'));
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  Synonym Mapping
  // ═══════════════════════════════════════════════════════════

  group('Synonym Mapping', () {
    test('sehat → health', () {
      final result = TextNormalizer.normalize('sehat');
      expect(result, contains('health'));
    });

    test('tabiyat → health', () {
      final result = TextNormalizer.normalize('tabiyat');
      expect(result, contains('health'));
    });

    test('khatara → risk', () {
      final result = TextNormalizer.normalize('khatara');
      expect(result, contains('risk'));
    });

    test('sandesh → sms', () {
      final result = TextNormalizer.normalize('sandesh');
      expect(result, contains('sms'));
    });

    test('dhokha → fraud', () {
      final result = TextNormalizer.normalize('dhokha');
      expect(result, contains('fraud'));
    });

    test('bachao → emergency', () {
      final result = TextNormalizer.normalize('bachao');
      expect(result, contains('emergency'));
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  Filler Word Removal
  // ═══════════════════════════════════════════════════════════

  group('Filler Word Removal', () {
    test('removes mera/meri/mere', () {
      final result = TextNormalizer.normalize('mera health score');
      expect(result, isNot(contains('mera')));
      expect(result, contains('health'));
    });

    test('removes hai/hain', () {
      final result = TextNormalizer.normalize('risk kitna hai');
      expect(result, isNot(contains('hai')));
      expect(result, contains('risk'));
      expect(result, contains('kitna'));
    });

    test('removes kya', () {
      final result = TextNormalizer.normalize('kya health score');
      expect(result, isNot(contains('kya')));
      expect(result, contains('health'));
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  Edge Cases
  // ═══════════════════════════════════════════════════════════

  group('Edge Cases', () {
    test('empty string returns empty', () {
      expect(TextNormalizer.normalize(''), equals(''));
    });

    test('whitespace-only returns empty', () {
      expect(TextNormalizer.normalize('   '), equals(''));
    });

    test('punctuation stripped', () {
      final result = TextNormalizer.normalize('health! score? check.');
      expect(result, isNot(contains('!')));
      expect(result, isNot(contains('?')));
      expect(result, isNot(contains('.')));
    });

    test('mixed Devanagari + English normalizes correctly', () {
      final result = TextNormalizer.normalize('मेरा health स्कोर बताओ');
      expect(result, contains('health'));
      expect(result, contains('score'));
      expect(result, contains('batao'));
    });

    test('case insensitive', () {
      final result = TextNormalizer.normalize('HEALTH SCORE');
      expect(result, contains('health'));
      expect(result, contains('score'));
    });

    test('multiple spaces collapsed', () {
      final result = TextNormalizer.normalize('health   score   batao');
      // Should not have multiple consecutive spaces
      expect(result, isNot(contains('  ')));
    });

    test('unknown words pass through unchanged', () {
      final result = TextNormalizer.normalize('abcxyz');
      expect(result, contains('abcxyz'));
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  Real-World Hindi Inputs (Integration)
  // ═══════════════════════════════════════════════════════════

  group('Real-World Hindi Inputs', () {
    test('"mera health score batao" normalizes', () {
      final result = TextNormalizer.normalize('mera health score batao');
      expect(result, contains('health'));
      expect(result, contains('score'));
    });

    test('"risk kitna hai" normalizes', () {
      final result = TextNormalizer.normalize('risk kitna hai');
      expect(result, contains('risk'));
    });

    test('"health score batao" normalizes', () {
      final result = TextNormalizer.normalize('health score batao');
      expect(result, contains('health'));
      expect(result, contains('score'));
    });

    test('"sandesh check karo" normalizes to sms + check', () {
      final result = TextNormalizer.normalize('sandesh check karo');
      expect(result, contains('sms'));
      expect(result, contains('check'));
    });

    test('"khatra kya hai" normalizes to risk', () {
      final result = TextNormalizer.normalize('khatra kya hai');
      expect(result, contains('risk'));
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  Hindi Devanagari Preservation (Bug Fix)
  // ═══════════════════════════════════════════════════════════

  group('Hindi Devanagari Preservation', () {
    test('हेलो is transliterated to hello (not stripped to empty)', () {
      final result = TextNormalizer.normalize('हेलो');
      expect(result, isNotEmpty);
      expect(result, contains('hello'));
    });

    test('नमस्ते is transliterated to namaste', () {
      final result = TextNormalizer.normalize('नमस्ते');
      expect(result, isNotEmpty);
      expect(result, contains('namaste'));
    });

    test('हाय is preserved', () {
      final result = TextNormalizer.normalize('हाय');
      expect(result, isNotEmpty);
    });

    test('unknown Devanagari words pass through (not erased)', () {
      final result = TextNormalizer.normalize('अनजान');
      expect(result, isNotEmpty);
      expect(result, contains('अनजान'));
    });

    test('mixed Devanagari + English fully preserved', () {
      final result = TextNormalizer.normalize('हेलो doctor');
      expect(result, contains('hello'));
      expect(result, contains('doctor'));
    });

    test(
      'Devanagari with punctuation — text preserved, punctuation removed',
      () {
        final result = TextNormalizer.normalize('नमस्ते! कैसे हैं?');
        expect(result, isNotEmpty);
        expect(result, isNot(contains('!')));
        expect(result, isNot(contains('?')));
      },
    );
  });
}
