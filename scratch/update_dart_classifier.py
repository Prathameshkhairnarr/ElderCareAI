import re
import os

path = r"d:\3d design\ElderCareAI\lib\services\sms_classifier.dart"
with open(path, "r", encoding="utf-8") as f:
    content = f.read()

# Replace the signature
sig_old = r"static SmsClassification classify\(String\? message\) \{"
sig_new = r"""static SmsClassification classify(
    String? message, {
    String? sender,
    DateTime? timeReceived,
    bool isRepeated = false,
  }) {"""
content = re.sub(sig_old, sig_new, content, count=1)

# Find where "2. STEP 2: TRUSTED MESSAGE DETECTION" starts
step2_start = content.find("// 2. STEP 2: TRUSTED MESSAGE DETECTION")
if step2_start == -1:
    print("Could not find STEP 2")
    exit(1)

# Prepare the new advanced rules block
advanced_rules = """      // --- ADVANCED BEHAVIORAL CHECKS ---
      if (sender != null && sender.isNotEmpty) {
        if (RegExp(r'^\\+?[0-9]{10,12}\$').hasMatch(sender)) {
          score += 20;
          signals['sender_random_mobile'] = 20;
          reasons.add('Sender appears to be a random mobile number (+20)');
        } else if (RegExp(r'^[A-Z]{2}-[A-Z0-9]{5,6}\$').hasMatch(sender) &&
            !['hdfc', 'sbi', 'airtel', 'jio', 'paytm'].any((t) => sender.toLowerCase().contains(t))) {
          score += 15;
          signals['sender_unusual'] = 15;
          reasons.add('Sender ID is unknown/unusual format (+15)');
        } else if (['hdfc', 'sbi', 'airtel', 'jio', 'paytm', 'icici'].any((t) => sender.toLowerCase().contains(t))) {
          score -= 40;
          signals['sender_trusted'] = -40;
          reasons.add('Trusted sender pattern (-40)');
        }
      }

      if (isRepeated) {
        score += 30;
        signals['high_frequency'] = 30;
        reasons.add('High frequency: similar message repeated (+30)');
      }

      if (textLower.contains('dear user') || textLower.contains('dear customer')) {
        score += 10;
        signals['generic_greeting'] = 10;
        reasons.add('Generic greeting used (+10)');
      }

      int upperCount = 0;
      for (int i = 0; i < safeMessage.length; i++) {
        if (safeMessage[i].toUpperCase() == safeMessage[i] && safeMessage[i].toLowerCase() != safeMessage[i].toUpperCase()) {
          upperCount++;
        }
      }
      double upperRatio = safeMessage.isNotEmpty ? upperCount / safeMessage.length : 0;
      if (upperRatio > 0.4 || safeMessage.contains('!!!')) {
        score += 15;
        signals['unnatural_language'] = 15;
        reasons.add('Unnatural language/ALL CAPS/punctuation (+15)');
      }

      final actionWords = ['click', 'verify', 'update', 'pay', 'login', 'download'];
      if (actionWords.any((w) => textLower.contains(w))) {
        score += 25;
        signals['action_intended'] = 25;
        reasons.add('Action intended (click/verify/pay) (+25)');
      }

      final manipulativePhrases = ['turant verify karo', 'account band ho jayega', 'paise jeete ho', 'block ho jayega'];
      if (manipulativePhrases.any((p) => textLower.contains(p))) {
        score += 20;
        signals['multi_lang_manipulation'] = 20;
        reasons.add('Manipulative multi-language phrase detected (+20)');
      }

      if (timeReceived != null) {
        final hour = timeReceived.hour;
        if (hour >= 23 || hour <= 6) {
          score += 10;
          signals['unusual_hour'] = 10;
          reasons.add('Arrived at unusual hour (+10)');
        }
      }

      """

# Insert the advanced rules before step 2
content = content[:step2_start] + advanced_rules + content[step2_start:]

# Advanced URL behavior (Rule 5)
url_behavior = """
          // URL Behavior Simulation
          for (final rawUrl in urls) {
            final u = rawUrl.toLowerCase();
            if (RegExp(r'[a-z]+\\d+[a-z]+').hasMatch(u)) {
              score += 20;
              signals['digits_in_domain'] = 20;
              reasons.add('Numbers inside domain (+20)');
            }
            if ('-'.allMatches(u).length >= 2) {
              score += 20;
              signals['multiple_hyphens'] = 20;
              reasons.add('Multiple hyphens in domain (+20)');
            }
            if ('/'.allMatches(u).length > 4) {
              score += 20;
              signals['long_path'] = 20;
              reasons.add('Long suspicious path (+20)');
            }
          }
"""

step4_domain_idx = content.find("if (hasSuspiciousDomain) {")
if step4_domain_idx != -1:
    content = content[:step4_domain_idx] + url_behavior + "        " + content[step4_domain_idx:]

with open(path, "w", encoding="utf-8") as f:
    f.write(content)

print("Dart Classifier Updated with 10 Advanced Behaviors")
