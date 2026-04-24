import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  static const String baseUrl = 'https://eldercareai-1.onrender.com';

  // ── Gemini AI Configuration ──
  static final String geminiApiKey = dotenv.env['GEMINI_API_KEY'] ?? '';

  static const String geminiModel = 'gemini-2.0-flash';

  static String get geminiEndpoint =>
      'https://generativelanguage.googleapis.com/v1beta/models/$geminiModel:generateContent?key=$geminiApiKey';

  // ── Azure OpenAI Configuration (Used globally by Ai Doctor) ──
  static final String azureOpenAiKey = dotenv.env['AZURE_OPENAI_KEY'] ?? '';

  // ── Standalone GitHub Vision Token (Used explicitly by Prescription Reader) ──
  static final String visionGithubToken = dotenv.env['VISION_GITHUB_TOKEN'] ?? '';

  static final String azureOpenAiResource =
      dotenv.env['AZURE_OPENAI_RESOURCE'] ?? '';

  static final String azureOpenAiDeployment =
      dotenv.env['AZURE_OPENAI_DEPLOYMENT'] ?? 'eldercare-gpt';

  static final String azureOpenAiApiVersion =
      dotenv.env['AZURE_OPENAI_API_VERSION'] ?? '2024-02-15-preview';

  /// Whether Azure OpenAI is configured with a real key.
  static bool get isAzureOpenAiEnabled =>
      azureOpenAiKey.isNotEmpty && azureOpenAiResource.isNotEmpty;

  /// Azure OpenAI chat completions endpoint.
  static String get azureOpenAiEndpoint {
    if (azureOpenAiKey.startsWith('ghp_') ||
        azureOpenAiKey.startsWith('github_pat_')) {
      return 'https://models.inference.ai.azure.com/chat/completions';
    }
    return 'https://$azureOpenAiResource.openai.azure.com/openai/deployments/'
        '$azureOpenAiDeployment/chat/completions?api-version=$azureOpenAiApiVersion';
  }

  // ── Azure Speech Service Configuration ──
  static final String azureSubscriptionKey =
      dotenv.env['AZURE_SPEECH_KEY'] ?? '';

  static final String azureRegion =
      dotenv.env['AZURE_REGION'] ?? 'centralindia';

  // Primary voice: warm, natural Hindi female neural voice.
  static const String azureVoiceName = 'hi-IN-SwaraNeural';

  // Fallback voices if primary is unavailable.
  static const List<String> azureFallbackVoices = [
    'hi-IN-PallaviNeural',
    'hi-IN-MadhurNeural',
  ];

  // Output format: MP3 16kHz mono — good balance of quality and size.
  static const String azureOutputFormat = 'audio-16khz-32kbitrate-mono-mp3';

  /// Whether Azure TTS is configured with a real subscription key.
  static bool get isAzureEnabled => azureSubscriptionKey.isNotEmpty;

  /// Azure Speech Service TTS endpoint.
  static String get azureEndpoint =>
      'https://$azureRegion.tts.speech.microsoft.com/cognitiveservices/v1';

  // ── Google Cloud TTS Configuration ──
  static final String googleTtsApiKey = dotenv.env['GOOGLE_TTS_API_KEY'] ?? '';

  static const String googleTtsEndpoint =
      'https://texttospeech.googleapis.com/v1/text:synthesize';

  /// Whether Google Cloud TTS is configured with a real API key.
  static bool get isGoogleTtsEnabled => googleTtsApiKey.isNotEmpty;

  // Primary Google Voice — Neural2 (female, very natural)
  static const String googleVoiceName = 'hi-IN-Neural2-A';

  // ── ElevenLabs TTS Configuration ──
  static final String elevenLabsApiKey = dotenv.env['ELEVENLABS_API_KEY'] ?? '';

  // Voice ID — Charlotte: warm, sweet female voice for Hindi + English.
  static const String elevenLabsFemaleVoiceId = 'XB0fDUnXU5powFXDhCwa';
  
  // Voice ID — Charlie: casual, natural, conversational male voice.
  static const String elevenLabsMaleVoiceId = 'IKne3meq5aSn9XLyUdCD';

  // Model: multilingual v2 supports Hindi + English natively.
  static const String elevenLabsModel = 'eleven_multilingual_v2';

  /// Whether ElevenLabs is configured with a real API key.
  static bool get isElevenLabsEnabled => elevenLabsApiKey.isNotEmpty;

  /// ElevenLabs TTS endpoint.
  static String elevenLabsEndpoint(bool isMale) {
    final voiceId = isMale ? elevenLabsMaleVoiceId : elevenLabsFemaleVoiceId;
    return 'https://api.elevenlabs.io/v1/text-to-speech/$voiceId';
  }

  // ── APILayer Number Verification API ──
  static final String abstractPhoneApiKey =
      dotenv.env['APILAYER_API_KEY'] ?? '';

  /// Whether APILayer Number Verification API is configured.
  static bool get isAbstractPhoneEnabled => abstractPhoneApiKey.isNotEmpty;

  /// APILayer Number Verification endpoint.
  static String abstractPhoneEndpoint(String phone) =>
      'https://api.apilayer.com/number_verification/validate?number=$phone';
}
