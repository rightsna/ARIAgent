import 'package:ari_agent/models/scheduled_task.dart';
import 'package:flutter/foundation.dart';
import 'package:ari_plugin/ari_plugin.dart';
import '../providers/avatar_provider.dart';

/// TaskProvider: 서버를 Single Source of Truth로 사용하는 Thin Client.
/// 모든 CRUD는 서버 API를 호출하고, 로컬에는 캐시만 유지합니다.
class TaskProvider extends ChangeNotifier {
  static final TaskProvider _instance = TaskProvider._internal();
  factory TaskProvider() => _instance;
  TaskProvider._internal();

  List<Map<String, dynamic>> _tasksCache = [];
  bool _initialized = false;

  bool get isInitialized => _initialized;

  /// 서버 응답을 ScheduledTask 모델로 변환하여 반환
  List<ScheduledTask> get tasks =>
      _tasksCache.map((m) => ScheduledTask.fromMap(m)).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  /// 초기화: 서버에서 작업 목록을 가져옵니다
  Future<void> init() async {
    if (_initialized) return;
    await refresh();
    _initialized = true;
  }

  /// 서버에서 전체 목록 + 결과를 다시 가져옵니다
  Future<void> refresh() async {
    try {
      final tasksResult = await AriAgent.call('/TASKS');
      final parsed = tasksResult['tasks'] as List? ?? [];
      final tasksList = parsed.map((t) => Map<String, dynamic>.from(t)).toList();

      // 결과도 함께 가져와서 병합
      final resultsResult = await AriAgent.call('/TASKS.RESULTS');
      final resultsData = resultsResult['results'] ?? {};
      for (final task in tasksList) {
        final r = resultsData[task['id']];
        if (r != null) {
          task['lastResult'] = r['result'];
          task['lastRunAt'] = r['executedAt'];
        }
      }

      _tasksCache = tasksList;
    } catch (e) {
      debugPrint('[TaskProvider] 서버 갱신 실패: $e');
    }
    notifyListeners();
  }

  /// 작업 추가 (서버에 직접 생성)
  Future<ScheduledTask?> addTask({
    required String prompt,
    required String cron,
    String? label,
  }) async {
    try {
      final res = await AriAgent.call('/TASKS.ADD', {
        'prompt': prompt,
        'cron': cron,
        'label': label ?? _generateLabel(prompt),
        'agentId': AvatarProvider().currentAvatarId,
      });
      debugPrint('[TaskProvider] 작업 추가 완료: ${res['task']?['label']}');
      await refresh();
      final taskData = res['task'];
      if (taskData != null) {
        return ScheduledTask.fromMap(Map<String, dynamic>.from(taskData));
      }
    } catch (e) {
      debugPrint('[TaskProvider] 작업 추가 실패: $e');
    }
    return null;
  }

  /// 작업 삭제 (서버에서 삭제)
  Future<void> deleteTask(String id) async {
    try {
      await AriAgent.call('/TASKS.DELETE', {'taskId': id});
      debugPrint('[TaskProvider] 작업 삭제: $id');
      await refresh();
    } catch (e) {
      debugPrint('[TaskProvider] 작업 삭제 실패: $e');
    }
  }

  /// 작업 활성/비활성 (서버에서 토글)
  Future<void> toggleTask(String id) async {
    try {
      await AriAgent.call('/TASKS.TOGGLE', {'taskId': id});
      debugPrint('[TaskProvider] 작업 토글: $id');
      await refresh();
    } catch (e) {
      debugPrint('[TaskProvider] 작업 토글 실패: $e');
    }
  }

  /// 수동 실행
  Future<String> runTaskNow(String id) async {
    final task = tasks.firstWhere(
      (t) => t.id == id,
      orElse: () => throw Exception('작업을 찾을 수 없습니다'),
    );

    try {
      final res = await AriAgent.call('/AGENT', {'message': task.prompt});
      final response = res['response'] ?? '응답 없음';
      // 결과는 서버가 자동 관리하므로 refresh만 수행
      await refresh();
      return response;
    } catch (e) {
      return '❌ 실행 실패: $e';
    }
  }

  String _generateLabel(String prompt) {
    if (prompt.length <= 20) return prompt;
    return '${prompt.substring(0, 20)}...';
  }
}
