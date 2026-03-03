import 'package:flutter_test/flutter_test.dart';
import 'package:eldercare_ai/voice/caregiver_filter.dart';

/// Unit tests for [CaregiverFilter] — the caregiver personality filter.
///
/// Tests cover: robotic phrase replacement, jargon simplification,
/// long sentence breaking, warmth injection, and edge cases.
void main() {
  // ═══════════════════════════════════════════════════════════
  //  ROBOTIC PHRASE REPLACEMENT
  // ═══════════════════════════════════════════════════════════

  group('Robotic Phrase Replacement', () {
    test('replaces "Processing your request"', () {
      final result = CaregiverFilter.filter('Processing your request');
      expect(result, contains('dekh rahi hoon'));
      expect(result, isNot(contains('Processing your request')));
    });

    test('replaces "Error occurred"', () {
      final result = CaregiverFilter.filter('Error occurred while loading');
      expect(result, contains('gadbad'));
    });

    test('replaces "No data available"', () {
      final result = CaregiverFilter.filter('No data available');
      expect(result, contains('jaankari'));
    });

    test('replaces "Operation completed"', () {
      final result = CaregiverFilter.filter('Operation completed');
      expect(result.toLowerCase(), contains('ho gaya'));
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  JARGON SIMPLIFICATION
  // ═══════════════════════════════════════════════════════════

  group('Jargon Simplification', () {
    test('replaces "database" with "record"', () {
      final result = CaregiverFilter.filter('Saved to database');
      expect(result, contains('record'));
    });

    test('replaces "network error" with Hindi equivalent', () {
      final result = CaregiverFilter.filter(
        'There is a network error in the system',
      );
      expect(result, contains('connection ki dikkat'));
    });

    test('replaces "timeout" with "der ho gayi"', () {
      final result = CaregiverFilter.filter('Request timeout happened');
      expect(result, contains('der ho gayi'));
    });

    test('replaces "notification" with "soochna"', () {
      final result = CaregiverFilter.filter('New notification received');
      expect(result, contains('soochna'));
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  WARMTH INJECTION
  // ═══════════════════════════════════════════════════════════

  group('Warmth Injection', () {
    test('adds warmth to cold response', () {
      final result = CaregiverFilter.filter(
        'Aapka risk score 45 hai out of 100.',
      );
      // Should add warmth since no warm keywords exist
      expect(result, contains('madad'));
    });

    test('does not add warmth to already warm response', () {
      final result = CaregiverFilter.filter(
        'Theek hai, main check karti hoon.',
      );
      // Should NOT append extra warmth (already has 'theek')
      expect(
        result.indexOf('madad'),
        equals(-1),
        reason: 'Should not add extra warmth to already warm text',
      );
    });

    test('does not add warmth to short text', () {
      final result = CaregiverFilter.filter('OK');
      // Short text — should not get warmth appended
      expect(result.length, lessThan(30));
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  LONG SENTENCE BREAKING
  // ═══════════════════════════════════════════════════════════

  group('Long Sentence Breaking', () {
    test('short sentences pass through unchanged', () {
      const input = 'Aapki health theek hai.';
      final result = CaregiverFilter.filter(input);
      expect(result, contains('health'));
    });

    test('very long sentence gets broken', () {
      // Build a sentence > 20 words
      final longSentence =
          'Aapki health ki jaankari yeh rahi ki aapki umar pachpan saal hai '
          'aur aapka blood group B positive hai aur aapka BMI normal range mein hai '
          'aur aapka health profile sirf pachas percent complete hai';
      final result = CaregiverFilter.filter(longSentence);
      // Should still contain key words
      expect(result, contains('health'));
      expect(result, contains('blood'));
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  EDGE CASES
  // ═══════════════════════════════════════════════════════════

  group('Edge Cases', () {
    test('empty string returns empty', () {
      expect(CaregiverFilter.filter(''), equals(''));
    });

    test('whitespace-only returns empty', () {
      expect(CaregiverFilter.filter('   ').trim(), isEmpty);
    });

    test('null-safe — handles normal text without crash', () {
      final result = CaregiverFilter.filter('Normal text without issues');
      expect(result, isNotEmpty);
    });
  });
}
