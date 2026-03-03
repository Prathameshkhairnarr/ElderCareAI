import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  static const String baseUrl = 'https://eldercareai.onrender.com';

  // ── Gemini AI Configuration ──
  static final String geminiApiKey = dotenv.env['GEMINI_API_KEY'] ?? '';

  static const String geminiModel = 'gemini-2.0-flash';

  static String get geminiEndpoint =>
      'https://generativelanguage.googleapis.com/v1beta/models/$geminiModel:generateContent?key=$geminiApiKey';

  // ── Azure OpenAI Configuration ──
  static final String azureOpenAiKey = dotenv.env['AZURE_OPENAI_KEY'] ?? '';

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
  static String get azureOpenAiEndpoint =>
      'https://$azureOpenAiResource.openai.azure.com/openai/deployments/'
      '$azureOpenAiDeployment/chat/completions?api-version=$azureOpenAiApiVersion';

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

  // ── ElevenLabs TTS Configuration ──
  static final String elevenLabsApiKey = dotenv.env['ELEVENLABS_API_KEY'] ?? '';

  // Voice ID — Charlotte: warm, sweet female voice for Hindi + English.
  static const String elevenLabsVoiceId = 'XB0fDUnXU5powFXDhCwa';

  // Model: multilingual v2 supports Hindi + English.
  static const String elevenLabsModel = 'eleven_multilingual_v2';

  /// Whether ElevenLabs is configured with a real API key.
  static bool get isElevenLabsEnabled => elevenLabsApiKey.isNotEmpty;

  /// ElevenLabs TTS endpoint.
  static String get elevenLabsEndpoint =>
      'https://api.elevenlabs.io/v1/text-to-speech/$elevenLabsVoiceId';
}
