import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/task_model.dart';
import 'api_service.dart';
import 'auth_service.dart';
import 'app_logger.dart';
import '../voice/voice_engine.dart';

class TaskReminderService {
  static final TaskReminderService _instance = TaskReminderService._internal();
  factory TaskReminderService() => _instance;
  TaskReminderService._internal();

  Timer? _poller;
  final _apiService = ApiService();
  final _authService = AuthService();
  final _voiceEngine = VoiceEngine(); // Handles TTS

  bool _isSpeaking = false;

  void startPolling() {
    if (_poller != null && _poller!.isActive) return;
    
    // Poll every 5 minutes
    _poller = Timer.periodic(const Duration(minutes: 5), (timer) async {
      await _checkPendingReminders();
    });
    
    // Also check immediately
    _checkPendingReminders();
  }

  void stopPolling() {
    _poller?.cancel();
    _poller = null;
  }

  Future<void> _checkPendingReminders() async {
    final elderId = _authService.currentUser?.id;
    if (elderId == null) return;

    final tasks = await _apiService.getPendingReminders(elderId);
    if (tasks.isEmpty) return;

    for (var task in tasks) {
      if (!_isSpeaking) {
        await _playVoiceReminder(task);
        // We wait for the voice to finish, then maybe trigger local notification
      }
    }
  }

  Future<void> _playVoiceReminder(TaskModel task) async {
    _isSpeaking = true;
    try {
      String message = "Namaste! Aapka ek naya kaam hai: ${task.title}.";
      
      if (task.taskType == 'medicine') {
        message = "Namaste! Aapki dawai ka time ho gaya hai. Kripya dawai le lijiye: ${task.title}.";
      } else if (task.taskType == 'water') {
        message = "Aapne paani piya? Thoda paani zaroor piyein: ${task.title}.";
      }

      await _voiceEngine.speak(message);
      
      // Delay before next TTS if needed
      await Future.delayed(const Duration(seconds: 2));
    } catch (e) {
      AppLogger.error(LogCategory.voice, 'Failed to play voice reminder: $e');
    } finally {
      _isSpeaking = false;
    }
  }
}
