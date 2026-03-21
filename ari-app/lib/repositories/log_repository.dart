import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

class LogRepository {
  static final LogRepository _instance = LogRepository._internal();
  factory LogRepository() => _instance;
  LogRepository._internal();

  late Box _chatBox;
  late Box _taskBox;

  Future<void> init() async {
    _chatBox = await Hive.openBox(kDebugMode ? 'chat_logs_test' : 'chat_logs');
    _taskBox = await Hive.openBox(kDebugMode ? 'task_logs_test' : 'task_logs');
  }

  ValueListenable<Box> get chatLogsListenable => _chatBox.listenable();
  ValueListenable<Box> get taskLogsListenable => _taskBox.listenable();

  Box get chatBox => _chatBox;
  Box get taskBox => _taskBox;

  List<Map<String, dynamic>> getChatLogs(String agentId) {
    return _chatBox.values
        .where((log) => log is Map && log['agentId'] == agentId)
        .map((log) => Map<String, dynamic>.from(log))
        .toList();
  }

  List<Map<String, dynamic>> getTaskLogs(String agentId) {
    return _taskBox.values
        .where((log) => log is Map && log['agentId'] == agentId)
        .map((log) => Map<String, dynamic>.from(log))
        .toList();
  }

  void addChatLog({
    required String agentId,
    required String message,
    required bool isUser,
    bool isError = false,
  }) {
    _chatBox.add({
      'agentId': agentId,
      'message': message,
      'isUser': isUser,
      'isError': isError,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  void addTaskLog({
    required String agentId,
    required String taskId,
    required String label,
    required String result,
  }) {
    _taskBox.add({
      'agentId': agentId,
      'taskId': taskId,
      'label': label,
      'result': result,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<void> clearLogs(String agentId) async {
    final chatKeysToDelete = _chatBox.keys.where((key) {
      final log = _chatBox.get(key);
      return log is Map && log['agentId'] == agentId;
    }).toList();
    for (final key in chatKeysToDelete) {
      await _chatBox.delete(key);
    }

    final taskKeysToDelete = _taskBox.keys.where((key) {
      final log = _taskBox.get(key);
      return log is Map && log['agentId'] == agentId;
    }).toList();
    for (final key in taskKeysToDelete) {
      await _taskBox.delete(key);
    }
  }
}
