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

  // ── Use Dedicated GitHub Models endpoint (GPT-4o) ──
  // We use a separate standalone token exclusively for the Ai Doctor scanner
  // to avoid draining the standard voice token.
  String get _endpoint => 'https://models.inference.ai.azure.com/chat/completions';

  static const String _systemInstruction = '''
You are a highly intelligent AI medical assistant called Doctor Veda.
You are an EXPERT at reading handwritten doctor prescriptions — even messy, unclear, or abbreviated ones.

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

IMPORTANT: Even if the handwriting is difficult, TRY YOUR BEST to read it. Use medical context to make educated guesses. Only say you cannot read it if the image is truly blank or completely unrelated to medicine.
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
      '    🤖 Agent Identity: RX Reader-Viraj\n'
      '    📁 File: ${imageFile.path}\n'
      '    📏 Size: ${(fileSize / 1024).toStringAsFixed(1)} KB\n'
      '    🏷️ MIME: $mimeType\n'
      '    🤖 Model: GPT-4o (Azure/GitHub)\n'
      '    🔑 Token: ${ApiConfig.visionGithubToken.isNotEmpty ? "configured (${ApiConfig.visionGithubToken.substring(0, 8)}...)" : "❌ MISSING"}',
    );

    if (ApiConfig.visionGithubToken.isEmpty) {
      AppLogger.error(LogCategory.network, '[RX] ❌ Dedicated Vision GitHub token is missing.');
      throw Exception('Vision API key is missing. Please add VISION_GITHUB_TOKEN in your .env file.');
    }

    try {
      // ── Step 2: Encode image to base64 ──
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      AppLogger.info(
        LogCategory.network,
        '[RX] ✅ Base64 encoded — ${base64Image.length} chars (${(base64Image.length / 1024).toStringAsFixed(1)} KB)',
      );

      // ── Step 3: Build request payload for OpenAI ──
      // Always expect it to be a github token since we explicitly isolated the system.
      final requestBody = {
        'model': 'gpt-4o', // GitHub Models natively supports this model parameter
        'messages': [
          {
            'role': 'system',
            'content': _systemInstruction
          },
          {
            'role': 'user',
            'content': [
              {
                'type': 'text',
                'text': 'Please carefully read this handwritten doctor prescription image. Extract all medicine names, dosages, and timings. Explain everything in simple Hinglish for an elderly person. Even if handwriting is messy, try your best to read it using medical context.'
              },
              {
                'type': 'image_url',
                'image_url': {
                  'url': 'data:$mimeType;base64,$base64Image'
                }
              }
            ]
          }
        ],
        'temperature': 0.4,
        'max_tokens': 2048,
      };

      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${ApiConfig.visionGithubToken}',
      };

      AppLogger.info(LogCategory.network, '[RX] 📤 Sending request to GitHub Models (GPT-4o Vision)...');

      // ── Step 4: Make API call ──
      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: headers,
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 40));

      stopwatch.stop();

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
          '[RX] ❌ Azure API error:\n'
          '    Status: ${response.statusCode}\n'
          '    Body: $errorPreview',
        );
        
        
        if (response.statusCode == 401) {
           throw Exception('Invalid Azure API Key.');
        }
        
        if (response.statusCode == 429) {
           throw Exception('OpenAI API Quota Exceeded.');
        }
        
        throw Exception('API Error: ${response.statusCode}');
      }

      // ── Step 6: Parse response (OpenAI format) ──
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      
      if (json.containsKey('error')) {
        final err = json['error'];
        throw Exception(err['message'] ?? 'Unknown Azure OpenAI API error');
      }

      final choices = json['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) {
        throw Exception('No response generated by AI model.');
      }

      final message = choices[0]['message'] as Map<String, dynamic>?;
      if (message == null) throw Exception('Malformed message object from AI.');

      final resultText = (message['content'] as String?)?.trim();

      if (resultText == null || resultText.isEmpty) {
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
      return null;
    }
  }
}
