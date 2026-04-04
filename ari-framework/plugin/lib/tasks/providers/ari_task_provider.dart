import 'package:flutter/foundation.dart';
import '../../bridge/ws/AriAgent.dart';
import '../models/ari_scheduled_task.dart';

export '../models/ari_scheduled_task.dart';

/// ARI 프레임워크 - 서버를 Single Source of Truth로 사용하는 Task Provider.
/// 앱에서는 이 Provider를 가져다 쓰면 됩니다.
///
/// 사용법:
/// ```dart
/// // Provider 등록
/// ChangeNotifierProvider<AriTaskProvider>.value(value: AriTaskProvider()),
///
/// // 초기화 (AriAgent 연결 이후)
/// await AriTaskProvider().init();
///
/// // 작업 추가
/// await AriTaskProvider().addTask(prompt: '...', cron: '0 9 * * *', agentId: 'default');
/// ```
class AriTaskProvider extends ChangeNotifier {
  static final AriTaskProvider _instance = AriTaskProvider._internal();
  factory AriTaskProvider() => _instance;
  AriTaskProvider._internal();

  List<Map<String, dynamic>> _tasksCache = [];
  bool _initialized = false;

  bool get isInitialized => _initialized;

  /// 서버 응답을 AriScheduledTask 모델로 변환하여 반환
  List<AriScheduledTask> get tasks =>
      _tasksCache.map((m) => AriScheduledTask.fromMap(m)).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  /// 원본 Map 형태의 캐시 (UI에서 직접 Map으로 사용 시)
  List<Map<String, dynamic>> get tasksRaw =>
      List.unmodifiable(_tasksCache);

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
      debugPrint('[AriTaskProvider] 서버 갱신 실패: $e');
    }
    notifyListeners();
  }

  /// 작업 추가 (서버에 직접 생성)
  /// [agentId]는 호출하는 앱에서 주입해야 합니다.
  Future<AriScheduledTask?> addTask({
    required String prompt,
    required String cron,
    String? label,
    String agentId = 'default',
    bool isOneOff = false,
  }) async {
    try {
      final res = await AriAgent.call('/TASKS.ADD', {
        'prompt': prompt,
        'cron': cron,
        'label': label ?? _generateLabel(prompt),
        'agentId': agentId,
        'isOneOff': isOneOff,
      });
      debugPrint('[AriTaskProvider] 작업 추가 완료: ${res['task']?['label']}');
      await refresh();
      final taskData = res['task'];
      if (taskData != null) {
        return AriScheduledTask.fromMap(Map<String, dynamic>.from(taskData));
      }
    } catch (e) {
      debugPrint('[AriTaskProvider] 작업 추가 실패: $e');
    }
    return null;
  }

  /// 작업 삭제 (서버에서 삭제)
  Future<bool> deleteTask(String id) async {
    try {
      await AriAgent.call('/TASKS.DELETE', {'taskId': id});
      debugPrint('[AriTaskProvider] 작업 삭제: $id');
      await refresh();
      return true;
    } catch (e) {
      debugPrint('[AriTaskProvider] 작업 삭제 실패: $e');
      return false;
    }
  }

  /// 작업 활성/비활성 (서버에서 토글)
  Future<bool> toggleTask(String id) async {
    try {
      await AriAgent.call('/TASKS.TOGGLE', {'taskId': id});
      debugPrint('[AriTaskProvider] 작업 토글: $id');
      await refresh();
      return true;
    } catch (e) {
      debugPrint('[AriTaskProvider] 작업 토글 실패: $e');
      return false;
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
      await refresh();
      return response;
    } catch (e) {
      return '❌ 실행 실패: $e';
    }
  }

  /// 특정 agentId의 작업만 필터링
  List<AriScheduledTask> tasksForAgent(String agentId) =>
      tasks.where((t) {
        final aid = (t.agentId?.trim().isEmpty ?? true) ? 'default' : t.agentId!.trim();
        return aid == agentId;
      }).toList();

  String _generateLabel(String prompt) {
    if (prompt.length <= 20) return prompt;
    return '${prompt.substring(0, 20)}...';
  }
}
