import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'app_logger.dart';

/// Service that reads prescription images via Gemini Vision API.
///
/// Uses `gemini-2.0-flash` with a detailed medical-assistant system prompt.
/// All stages are logged so issues are instantly visible in the console.
class PrescriptionService {
  static final PrescriptionService _instance = PrescriptionService._();
  factory PrescriptionService() => _instance;
  PrescriptionService._();


  static const String _systemInstruction = '''
You are a highly intelligent AI medical assistant called Doctor Veda.
You are an EXPERT at reading handwritten doctor prescriptions — even messy, unclear, or abbreviated ones.

CRITICAL FIRST STEP — IMAGE VALIDATION:
Before doing anything else, check whether the provided image is actually a doctor's prescription, pharmacy bill/slip, medical test report, or medicine package/strip.
- If the image is NOT a prescription or medical document (for example: selfies, persons, random objects, vehicles, animals, nature, household items, grocery bills, computer screens, random text/books, blank or dark photos, etc.):
DO NOT output the medical analysis sections.
INSTEAD, immediately output this exact Hinglish message format:

❌ **Yeh Doctor Ki Prescription Nahi Hai**

Aapne jo photo bheji hai, yeh doctor ki prescription nahi lag rahi hai.
(Explain what the photo actually shows in 1-2 simple, polite Hinglish sentences. E.g. "Yeh kisi cheez/screen/vyakti ki photo hai, dawai ya doctor ki parchi nahi hai.")

📸 **Kripya Sahi Photo Upload Karein**:
- Doctor dwara likhi gayi parchi (Prescription slip) ki saaf aur seedhi photo kheenche.
- Ya fir dawai ke patte (strip) ya dibbe ki clear photo upload karein.
- Light achhi rakhein taaki doctor ki likhawat aur dawaiyon ke naam saaf dikhein.

- ONLY IF the image IS a valid doctor prescription or medicine list, proceed with full analysis:

CRITICAL CAPABILITY:
- You CAN read doctor handwriting. Doctors write in a specific medical shorthand you understand.
- Common abbreviations: Tab = Tablet, Cap = Capsule, Syp = Syrup, Inj = Injection, OD = Once daily, BD = Twice daily, TDS = Three times daily, QID = Four times daily, SOS = As needed, HS = At bedtime, AC = Before food, PC = After food, Stat = Immediately
- You understand medical shorthand like 1-0-1 (morning-afternoon-night), 1x1, 1+1+1, etc.
- Even if handwriting is partially illegible, use context clues from other readable medicines to guess the condition and fill gaps intelligently.

Your goal is:
- To simplify complex medical prescriptions
- To explain medicines and conditions in simple language
- To guide users safely like a caring doctor assistant

You are NOT a replacement for a doctor.

Rules:
- NEVER prescribe new medicines
- NEVER change doctor's prescription
- NEVER give dangerous medical advice
- ALWAYS include a disclaimer to consult a real doctor
- If unsure about a specific medicine name, say "This looks like [best guess] — please confirm with your pharmacist"

Your role is to explain, not prescribe.

Analyze the prescription image and provide:
1. Possible condition: What illness the prescription suggests (simple language)
2. Medicines: Identify each medicine, explain what it is used for
3. Dosage (if available): Explain how it might be taken (morning/afternoon/night)
4. Treatment purpose: What the doctor is trying to treat

For each medicine:
- Name: (exactly as written or best reading)
- Purpose: (what it treats)
- How it helps: (simple explanation)
- Important note: (if any side effects or precautions)

Keep it simple and easy for elderly users.

Precautions section:
- Diet suggestions relevant to the condition
- Lifestyle advice
- Things to avoid
Make it practical and easy to follow.

Future guidance:
- What can happen if medicines are skipped
- How to prevent this issue in future
- Simple daily habits to improve health

When to see a doctor:
- If symptoms worsen despite medication
- If no improvement in specified days
- If specific warning signs appear

Tone:
- Warm and caring
- Simple Hindi + English mix (Hinglish)
- Like talking to a family member

Speak like: "Aap chinta mat kariye, main aapko simple tarike se samjhata hoon"

Respond strictly in this Markdown format with DOUBLE SPACE (new lines) between each section for easy reading:

**Kya Hua Hai (Possible Condition)**:
(Aapko prescription padh kar bataana hai ki patient ko exactly kya beemari ya takleef hui lag rahi hai. Sirf technical term nahi balki sadhaaran bhaasha mein samjhayen ki kya problem hogi. E.g. "Doctor ki dawaiyon se lagta hai ki aapko sardi-khasi aur gala kharab (Throat Infection) hai.")

**Dawaiyaan (Medicines)**:
1. **[Medicine Name Here]**
   - **Kaam (Purpose)**: (What it does in simple Hinglish)
   - **Kyun Diya (How it helps)**: (Why the doctor gave it)

2. **[Next Medicine]**
   ...

**Kaise Leni Hai (Dosage & Timing)**:
(Har dawai ke liye clear details: kab lena hai, paani ke sath ya khali pet etc.)

**Dhyan Rakhein (Precautions & Tips)**:
- **Diet**: (Kya khayein ya avoid karein)
- **Aaram**: (Any lifestyle advice or rest tips)

🚨 **Doctor ko kab dikhayein**:
(Warning signs or when they must absolutely revisit the clinic)

⚠️ **Disclaimer**:
Ye information sirf aapki better understanding ke liye hai. In dawaiyon ka dose ya time apni marzi se na badlein, humesha apne asli doctor ki aagya ka palan karein.
''';

  /// Detect MIME type from file extension
  String _getMimeType(File file) {
    final ext = file.path.split('.').last.toLowerCase();
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'bmp':
        return 'image/bmp';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }

  /// Reads a local image file and sends it to Gemini to extract prescription data.
  /// Returns the analysis text, or null on failure.
  Future<String?> analyzePrescriptionImage(File imageFile) async {
    final stopwatch = Stopwatch()..start();

    // ── Step 1: Validate file ──
    if (!imageFile.existsSync()) {
      AppLogger.error(LogCategory.network, '[RX] ❌ Image file does not exist: ${imageFile.path}');
      return null;
    }

    final fileSize = await imageFile.length();
    final mimeType = _getMimeType(imageFile);
    AppLogger.info(
      LogCategory.network,
      '[RX] ▶ Starting prescription analysis\n'
      '    📁 File: ${imageFile.path}\n'
      '    📏 Size: ${(fileSize / 1024).toStringAsFixed(1)} KB\n'
      '    🏷️ MIME: $mimeType\n'
      '    🤖 Model: ${ApiConfig.geminiModel} (Google Gemini Vision)\n'
      '    🔑 Key: ${ApiConfig.geminiApiKey.isNotEmpty ? "configured (${ApiConfig.geminiApiKey.substring(0, 8)}...)" : "❌ MISSING"}',
    );

    if (ApiConfig.geminiApiKey.isEmpty) {
      AppLogger.error(LogCategory.network, '[RX] ❌ Gemini API key is missing.');
      throw Exception('Gemini API key is missing. Please add GEMINI_API_KEY in your .env file.');
    }

    try {
      // ── Step 2: Encode image to base64 ──
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      AppLogger.info(
        LogCategory.network,
        '[RX] ✅ Base64 encoded — ${base64Image.length} chars (${(base64Image.length / 1024).toStringAsFixed(1)} KB)',
      );

      // ── Step 3: Build request payload for Gemini Vision ──
      final requestBody = {
        'system_instruction': {
          'parts': [
            {'text': _systemInstruction}
          ]
        },
        'contents': [
          {
            'role': 'user',
            'parts': [
              {
                'text':
                    'Please first verify whether this image is a doctor prescription, pharmacy slip, medical report, or medicine package. If it is NOT a prescription, tell the user clearly in Hinglish as instructed. If it IS a prescription, extract all medicine names, dosages, timings, and explanations in simple Hinglish for an elderly person.'
              },
              {
                'inline_data': {
                  'mime_type': mimeType,
                  'data': base64Image,
                }
              }
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.3,
          'maxOutputTokens': 2048,
        },
      };

      final headers = <String, String>{
        'Content-Type': 'application/json',
      };

      // ── Step 4: Make API call with model fallback and retry ──
      // gemini-3-flash-preview is prioritized as it has the best uptime.
      final candidateModels = <String>{
        'gemini-3-flash-preview',
        ApiConfig.geminiModel,
        'gemini-3.5-flash',
        'gemini-3.7-flash',
        'gemini-flash-latest',
      }.toList();

      http.Response? response;

      for (final model in candidateModels) {
        final endpoint =
            'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=${ApiConfig.geminiApiKey}';

        for (int attempt = 1; attempt <= 2; attempt++) {
          try {
            AppLogger.info(LogCategory.network, '[RX] 📤 Sending request to Gemini Vision ($model, attempt $attempt)...');
            response = await http
                .post(
                  Uri.parse(endpoint),
                  headers: headers,
                  body: jsonEncode(requestBody),
                )
                .timeout(const Duration(seconds: 90));

            if (response.statusCode == 200) {
              break;
            }

            if (response.statusCode == 401 || response.statusCode == 403) {
              throw Exception('Invalid Gemini API Key or permissions issue.');
            }

            AppLogger.warn(
              LogCategory.network,
              '[RX] ⚠️ Model $model attempt $attempt returned HTTP ${response.statusCode}',
            );
            if (attempt == 1) {
              await Future.delayed(const Duration(milliseconds: 1500));
            }
          } catch (netErr) {
            if (netErr.toString().contains('Invalid Gemini API Key')) rethrow;
            AppLogger.warn(LogCategory.network, '[RX] ⚠️ Model $model network error: $netErr');
            if (attempt == 1) {
              await Future.delayed(const Duration(milliseconds: 1500));
            }
          }
        }

        if (response != null && response.statusCode == 200) {
          break;
        }
      }

      stopwatch.stop();

      if (response == null) {
        throw Exception('Internet connection problem. Kripya apna network check karein aur Retry dabayein.');
      }

      AppLogger.info(
        LogCategory.network,
        '[RX] 📥 Response received — HTTP ${response.statusCode} — ${stopwatch.elapsedMilliseconds}ms',
      );

      // ── Step 5: Handle non-200 responses ──
      if (response.statusCode != 200) {
        final errorPreview = response.body.length > 500
            ? response.body.substring(0, 500)
            : response.body;
        AppLogger.error(
          LogCategory.network,
          '[RX] ❌ Gemini API error:\n'
          '    Status: ${response.statusCode}\n'
          '    Body: $errorPreview',
        );

        if (response.statusCode == 503) {
          throw Exception('Google AI server par temporary traffic zyada hai (503 High Demand). Kripya 5-10 second baad Retry button dabayein.');
        }

        if (response.statusCode == 429) {
          throw Exception('Gemini API Quota Exceeded. Kripya thodi der baad dobara koshish karein.');
        }

        throw Exception('API Error: ${response.statusCode}');
      }

      // ── Step 6: Parse Gemini response ──
      final json = jsonDecode(response.body) as Map<String, dynamic>;

      if (json.containsKey('error')) {
        final err = json['error'];
        final msg = err is Map ? (err['message'] ?? 'Gemini API Error') : err.toString();
        throw Exception(msg);
      }

      final candidates = json['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) {
        throw Exception('No response generated by AI model.');
      }

      final firstCandidate = candidates[0] as Map<String, dynamic>?;
      final content = firstCandidate?['content'] as Map<String, dynamic>?;
      if (content == null) throw Exception('Malformed content object from AI.');

      final parts = content['parts'] as List<dynamic>?;
      if (parts == null || parts.isEmpty) throw Exception('Empty response parts from AI.');

      final buffer = StringBuffer();
      for (final part in parts) {
        if (part is Map && part['text'] != null) {
          buffer.write(part['text']);
        }
      }

      final resultText = buffer.toString().trim();

      if (resultText.isEmpty) {
        throw Exception('Empty response from AI.');
      }

      // ── Step 7: Success! ──
      final previewLength = resultText.length > 200 ? 200 : resultText.length;
      AppLogger.info(
        LogCategory.network,
        '[RX] ✅ Prescription analyzed successfully!\n'
        '    📝 Response length: ${resultText.length} chars\n'
        '    ⏱️ Total time: ${stopwatch.elapsedMilliseconds}ms\n'
        '    👁️ Preview: "${resultText.substring(0, previewLength)}..."',
      );

      return resultText;
    } catch (e, stack) {
      stopwatch.stop();
      AppLogger.error(
        LogCategory.network,
        '[RX] ❌ Exception during prescription analysis:\n'
        '    Error: $e\n'
        '    Time elapsed: ${stopwatch.elapsedMilliseconds}ms\n'
        '    Stack: ${stack.toString().split('\n').take(5).join('\n    ')}',
      );
      rethrow;
    }
  }
}
