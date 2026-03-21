import 'package:ari_agent/models/scheduled_task.dart';
import 'package:ari_agent/repositories/task_schedule_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:ari_plugin/ari_plugin.dart';
import '../providers/avatar_provider.dart';

/// TaskProvider: 스케줄 작업을 관리하고 서버와 동기화합니다.
class TaskProvider extends ChangeNotifier {
  static final TaskProvider _instance = TaskProvider._internal();
  factory TaskProvider() => _instance;
  TaskProvider._internal();

  final TaskScheduleRepository _repository = TaskScheduleRepository();

  bool get isInitialized => _repository.isInitialized;
  List<ScheduledTask> get tasks => _repository.getAllTasks();

  /// 초기화
  Future<void> init() async {
    await _repository.init();
    notifyListeners();
  }

  /// 작업 추가
  Future<ScheduledTask> addTask({
    required String prompt,
    required String cron,
    String? label,
  }) async {
    final task = ScheduledTask(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      prompt: prompt,
      cron: cron,
      label: label ?? _generateLabel(prompt),
      enabled: true,
      createdAt: DateTime.now(),
      agentId: AvatarProvider().currentAvatarId,
    );

    await _repository.saveTask(task);
    debugPrint('[TaskProvider] 작업 추가: ${task.label} ($cron)');

    await _syncToSystem();
    notifyListeners();
    return task;
  }

  /// 작업 삭제
  Future<void> deleteTask(String id) async {
    await _repository.deleteTask(id);
    await _syncToSystem();
    notifyListeners();
  }

  /// 작업 활성/비활성
  Future<void> toggleTask(String id) async {
    final task = _repository.getTask(id);
    if (task == null) return;
    final updated = task.copyWith(enabled: !task.enabled);
    await _repository.saveTask(updated);
    await _syncToSystem();
    notifyListeners();
  }

  /// 작업 결과 업데이트
  Future<void> updateResult(String id, String result) async {
    final task = _repository.getTask(id);
    if (task == null) return;
    final updated = task.copyWith(
      lastResult: result,
      lastRunAt: DateTime.now(),
    );
    await _repository.saveTask(updated);
    notifyListeners();
  }

  /// 수동 실행
  Future<String> runTaskNow(String id) async {
    final task = _repository.getTask(id);
    if (task == null) return '❌ 작업을 찾을 수 없습니다.';

    try {
      final res = await WsManager.call('/AGENT', {'message': task.prompt});
      final response = res['response'] ?? '응답 없음';
      await updateResult(id, response);
      return response;
    } catch (e) {
      return '❌ 실행 실패: $e';
    }
  }

  /// 서버 동기화
  Future<void> _syncToSystem() async {
    try {
      final allTasks = tasks.map((t) => t.toMap()).toList();
      await WsManager.call('/TASKS.SYNC', {'tasks': allTasks});

      final enabledTasks = tasks.where((t) => t.enabled).toList();
      await WsManager.call('/TASKS.CRONTAB', {
        'tasks': enabledTasks.map((t) => {'id': t.id, 'cron': t.cron}).toList(),
      });
    } catch (e) {
      debugPrint('[TaskProvider] 동기화 실패: $e');
    }
  }

  String _generateLabel(String prompt) {
    if (prompt.length <= 20) return prompt;
    return '${prompt.substring(0, 20)}...';
  }

  /// (UI 지원용) 서버에서 직접 작업 목록을 가져옴
  Future<List<Map<String, dynamic>>> fetchTasksFromServer() async {
    final List<Map<String, dynamic>> tasksList = [];
    try {
      final tasksResult = await WsManager.call('/TASKS');
      final parsed = tasksResult['tasks'] as List? ?? [];
      tasksList.addAll(
        parsed.map((t) => Map<String, dynamic>.from(t)).toList(),
      );

      final resultsResult = await WsManager.call('/TASKS.RESULTS');
      final resultsData = resultsResult['results'] ?? {};
      for (final task in tasksList) {
        final r = resultsData[task['id']];
        if (r != null) {
          task['lastResult'] = r['result'];
          task['lastRunAt'] = r['executedAt'];
        }
      }
    } catch (e) {
      debugPrint('[TaskProvider] 서버 로드 실패: $e');
    }
    return tasksList;
  }
}
