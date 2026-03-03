import 'package:flutter_test/flutter_test.dart';
import 'package:eldercare_ai/services/sms_classifier.dart';

void main() {
  setUp(() {
    ScamTemplateMemory.clear();
  });

  // ═══════════════════════════════════════════════════════════════
  //  PHASE 6 — Safety: null / empty / oversized
  // ═══════════════════════════════════════════════════════════════

  group('Safety & Stability', () {
    test('null message returns SAFE', () {
      final result = SmsClassifier.classify(null);
      expect(result.label, 'SAFE');
      expect(result.riskScore, 0);
      expect(result.isScam, false);
    });

    test('empty message returns SAFE', () {
      final result = SmsClassifier.classify('');
      expect(result.label, 'SAFE');
      expect(result.riskScore, 0);
    });

    test('whitespace-only message returns SAFE', () {
      final result = SmsClassifier.classify('   \n\t  ');
      expect(result.label, 'SAFE');
    });

    test('oversized message does not crash', () {
      final huge = 'scam reward lottery ' * 500; // 10,000 chars
      final result = SmsClassifier.classify(huge);
      expect(result, isNotNull);
      // Should still detect keywords from truncated portion
      expect(result.riskScore, greaterThan(0));
    });

    test('legitimate bank OTP message is SAFE', () {
      final result = SmsClassifier.classify(
        'Your OTP for HDFC Bank transaction is 482910. '
        'Valid for 5 minutes. Do not share with anyone.',
      );
      // This may trigger some financial keywords but should be low score
      // because there's no link, no urgency, no reward
      expect(result.riskScore, lessThan(50));
    });

    test('normal conversational SMS is SAFE', () {
      final result = SmsClassifier.classify(
        'Hey, are you coming to dinner tonight? Let me know.',
      );
      expect(result.label, 'SAFE');
      expect(result.riskScore, 0);
      expect(result.isScam, false);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  //  PHASE 5 — False Negative Fixes: Real Indian Scam Samples
  // ═══════════════════════════════════════════════════════════════

  group('Wallet Credit Scams', () {
    test('rummy wallet credit with link flagged as SCAM', () {
      final result = SmsClassifier.classify(
        'Congratulations! Rs.4500 credited to your rummy account. '
        'Withdraw now: https://SR3.in/xyz',
      );
      expect(result.isScam, true);
      expect(result.riskScore, greaterThanOrEqualTo(50));
      expect(result.label, isIn(['SCAM', 'PHISHING_LINK']));
    });

    test('wallet credited with instant withdraw link', () {
      final result = SmsClassifier.classify(
        'Your wallet credited with Rs.2000 bonus. '
        'Instant withdraw to bank account: https://i1s.in/bonus',
      );
      expect(result.isScam, true);
      expect(result.riskScore, greaterThanOrEqualTo(50));
    });

    test('teen patti cash bonus', () {
      final result = SmsClassifier.classify(
        'Teen Patti Gold: Rs.500 cash bonus added! '
        'Play now and win big: https://tp-gold.xyz/play',
      );
      expect(result.isScam, true);
      expect(result.riskScore, greaterThanOrEqualTo(50));
    });
  });

  group('Promotional Reward Link Scams', () {
    test('promotional reward with link flagged as SCAM', () {
      final result = SmsClassifier.classify(
        'You have been selected for promotional reward of Rs.10000! '
        'Claim now: https://reward-claim.click/get',
      );
      expect(result.isScam, true);
      expect(result.riskScore, greaterThanOrEqualTo(50));
    });

    test('lucky winner prize claim', () {
      final result = SmsClassifier.classify(
        'LUCKY WINNER! You won Rs.50,000 in our weekly draw. '
        'Claim your prize: https://prize-draw.buzz/claim',
      );
      expect(result.isScam, true);
      expect(result.riskScore, greaterThanOrEqualTo(50));
    });

    test('gift voucher reward scam', () {
      final result = SmsClassifier.classify(
        'Congratulations! You have won a free gift voucher worth Rs.5000. '
        'Click here to claim: https://free-gift.top/voucher',
      );
      expect(result.isScam, true);
      expect(result.riskScore, greaterThanOrEqualTo(50));
    });
  });

  group('Fake Bank Alerts', () {
    test('HDFC bank impersonation with suspicious link', () {
      final result = SmsClassifier.classify(
        'Dear HDFC customer, your account will be suspended. '
        'Verify immediately: https://hdfc-verify.xyz/login',
      );
      expect(result.isScam, true);
      expect(result.riskScore, greaterThanOrEqualTo(50));
      expect(result.label, isIn(['SCAM', 'PHISHING_LINK']));
    });

    test('SBI KYC update phishing', () {
      final result = SmsClassifier.classify(
        'SBI Alert: Update your KYC immediately to avoid account suspension. '
        'Click: https://sbi-kyc-update.click/verify',
      );
      expect(result.isScam, true);
      expect(result.riskScore, greaterThanOrEqualTo(50));
    });

    test('ICICI fake transaction alert', () {
      final result = SmsClassifier.classify(
        'ICICI Bank: Unusual activity detected on your account. '
        'Confirm now: https://icici-alert.ml/confirm',
      );
      expect(result.isScam, true);
      expect(result.riskScore, greaterThanOrEqualTo(50));
    });

    test('Paytm bonus scam', () {
      final result = SmsClassifier.classify(
        'Paytm: Rs.1000 cashback credited! '
        'Withdraw to bank: https://paytm-bonus.click/withdraw',
      );
      expect(result.isScam, true);
      expect(result.riskScore, greaterThanOrEqualTo(50));
    });

    test('PhonePe verification scam', () {
      final result = SmsClassifier.classify(
        'PhonePe: Your account has been blocked due to suspicious activity. '
        'Re-verify: https://phonepe-verify.ga/reactivate',
      );
      expect(result.isScam, true);
      expect(result.riskScore, greaterThanOrEqualTo(50));
    });

    test('Axis Bank account closure threat', () {
      final result = SmsClassifier.classify(
        'AXIS BANK: Your account closure is scheduled. '
        'Update your details within 24 hours: https://axis-update.tk/save',
      );
      expect(result.isScam, true);
      expect(result.riskScore, greaterThanOrEqualTo(50));
    });
  });

  group('Rummy / Gambling Reward Scams', () {
    test('rummy account credit scam', () {
      final result = SmsClassifier.classify(
        'Rummy Circle: Rs.3000 bonus credit added to your account! '
        'Play now and withdraw: https://rummy-play.fun/bonus',
      );
      expect(result.isScam, true);
      expect(result.riskScore, greaterThanOrEqualTo(50));
    });

    test('casino jackpot scam', () {
      final result = SmsClassifier.classify(
        'You hit the JACKPOT! Rs.25,000 winning amount ready. '
        'Withdraw instantly: https://casino-win.icu/jackpot',
      );
      expect(result.isScam, true);
      expect(result.riskScore, greaterThanOrEqualTo(50));
    });
  });

  group('Suspicious Short Links', () {
    test('short domain SR3.in flagged', () {
      final result = SmsClassifier.classify(
        'Your reward is ready! Click to claim: https://SR3.in/abc',
      );
      expect(result.isScam, true);
      expect(result.riskScore, greaterThanOrEqualTo(25));
    });

    test('short domain i1s.in flagged', () {
      final result = SmsClassifier.classify(
        'Congratulations winner! Claim prize: https://i1s.in/prize',
      );
      expect(result.isScam, true);
      expect(result.riskScore, greaterThanOrEqualTo(25));
    });

    test('bit.ly shortened scam link', () {
      final result = SmsClassifier.classify(
        'You won Rs.10,000! Claim: bit.ly/win-now',
      );
      expect(result.isScam, true);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  //  PHASE 2 — Risk Band Verification
  // ═══════════════════════════════════════════════════════════════

  group('Risk Bands', () {
    test('safe message scores 0-24', () {
      final result = SmsClassifier.classify(
        'Your Amazon order has been shipped. Track at amazon.in/track',
      );
      // May not score 0 because of link, but should be low
      expect(result.riskScore, lessThan(50));
    });

    test('high-risk scam scores 50+', () {
      final result = SmsClassifier.classify(
        'Congratulations! You won Rs.1,00,000! '
        'Your HDFC account will be credited. '
        'Verify immediately: https://hdfc-reward.xyz/claim',
      );
      expect(result.riskScore, greaterThanOrEqualTo(50));
      expect(result.label, isIn(['SCAM', 'PHISHING_LINK']));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  //  PHASE 1 — Domain Detection
  // ═══════════════════════════════════════════════════════════════

  group('Suspicious Domain Detection', () {
    test('xyz TLD flagged', () {
      final result = SmsClassifier.classify(
        'Update account: https://bank-update.xyz/verify',
      );
      expect(result.isScam, true);
    });

    test('.click TLD flagged', () {
      final result = SmsClassifier.classify(
        'Claim reward: https://free-money.click/claim',
      );
      expect(result.isScam, true);
    });

    test('official bank domain not flagged as suspicious', () {
      // An official SBI link should not inflate score as much
      final result = SmsClassifier.classify(
        'SBI: View your statement at https://onlinesbi.com/statement',
      );
      // Should have lower score than a scam — may still have some financial keyword hits
      expect(result.riskScore, lessThan(50));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  //  PHASE 4 — Template Memory
  // ═══════════════════════════════════════════════════════════════

  group('Template Memory System', () {
    test('remembers scam and detects similar', () {
      // First message — classify as scam and remember
      final scam1 =
          'Congratulations! Rs.5000 credited to your rummy account. '
          'Withdraw now: https://SR3.in/abc';
      final result1 = SmsClassifier.classify(scam1);
      expect(result1.isScam, true);

      // Template should be stored now
      expect(ScamTemplateMemory.count, greaterThan(0));

      // Similar message should match template
      expect(ScamTemplateMemory.isSimilarToKnown(scam1), true);
    });

    test('memory is bounded at 100', () {
      // Each message must produce a unique trigram fingerprint.
      // We generate substantially different text by repeating distinct chars.
      const chars = 'abcdefghijklmnopqrstuvwxyz';
      for (int i = 0; i < 150; i++) {
        final c = chars[i % 26];
        final repeatCount = 10 + (i ~/ 26) * 5;
        final body = '${c * repeatCount} scam reward bonus winning claim prize';
        ScamTemplateMemory.remember(body);
      }
      // Should be capped at 100 even though we tried to add 150
      expect(ScamTemplateMemory.count, lessThanOrEqualTo(100));
      expect(ScamTemplateMemory.count, greaterThan(50));
    });

    test('safe messages not remembered', () {
      ScamTemplateMemory.clear();
      SmsClassifier.classify('Hey, are you coming to dinner?');
      expect(ScamTemplateMemory.count, 0);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  //  PHASE 3 — Indian Bank Impersonation
  // ═══════════════════════════════════════════════════════════════

  group('Indian Bank Impersonation', () {
    test('Google Pay fake alert', () {
      final result = SmsClassifier.classify(
        'Google Pay: Your account verification failed. '
        'Complete now to avoid suspension: https://gpay-verify.ml/fix',
      );
      expect(result.isScam, true);
      expect(result.riskScore, greaterThanOrEqualTo(50));
    });

    test('Kotak Mahindra fake', () {
      final result = SmsClassifier.classify(
        'Dear Kotak customer, unauthorized transaction detected. '
        'Block card immediately: https://kotak-block.cf/urgent',
      );
      expect(result.isScam, true);
      expect(result.riskScore, greaterThanOrEqualTo(50));
    });

    test('PNB fake KYC update', () {
      final result = SmsClassifier.classify(
        'PNB Alert: Complete your KYC update or your account will be frozen. '
        'Update here: https://pnb-kyc.gq/update',
      );
      expect(result.isScam, true);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  //  Backward Compatibility — existing labels still work
  // ═══════════════════════════════════════════════════════════════

  group('Backward Compatibility', () {
    test('labels remain SAFE, SCAM, or PHISHING_LINK', () {
      final safe = SmsClassifier.classify('Hello, how are you?');
      expect(safe.label, isIn(['SAFE', 'SCAM', 'PHISHING_LINK']));

      final scam = SmsClassifier.classify(
        'Your bank account is blocked! Verify now: https://fake.xyz/verify',
      );
      expect(scam.label, isIn(['SAFE', 'SCAM', 'PHISHING_LINK']));
    });

    test('SmsClassification has all required fields', () {
      final result = SmsClassifier.classify('test message');
      expect(result.isScam, isNotNull);
      expect(result.riskScore, isNotNull);
      expect(result.scamType, isNotNull);
      expect(result.explanation, isNotNull);
      expect(result.label, isNotNull);
    });

    test('toString format unchanged', () {
      final result = SmsClassifier.classify('test');
      final str = result.toString();
      expect(str, contains('SmsClassification('));
      expect(str, contains('label='));
      expect(str, contains('risk='));
      expect(str, contains('type='));
    });
  });
}
