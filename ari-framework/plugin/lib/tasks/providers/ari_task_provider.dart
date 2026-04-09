import 'dart:async';

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

  /// taskId → 진행 중인 progress 메시지 목록
  final Map<String, List<String>> _progressMessages = {};

  StreamSubscription? _taskResultSub;
  StreamSubscription? _progressSub;

  bool get isInitialized => _initialized;

  /// 특정 task의 progress 메시지 목록
  List<String> progressFor(String taskId) =>
      List.unmodifiable(_progressMessages[taskId] ?? []);

  /// 서버 응답을 AriScheduledTask 모델로 변환하여 반환
  List<AriScheduledTask> get tasks =>
      _tasksCache.map((m) => AriScheduledTask.fromMap(m)).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  /// 원본 Map 형태의 캐시 (UI에서 직접 Map으로 사용 시)
  List<Map<String, dynamic>> get tasksRaw =>
      List.unmodifiable(_tasksCache);

  /// 초기화: 서버에서 작업 목록을 가져오고 WebSocket 이벤트를 구독합니다
  Future<void> init() async {
    if (_initialized) return;
    await refresh();
    _subscribeToEvents();
    _initialized = true;
  }

  void _subscribeToEvents() {
    // 작업 완료 시 서버 데이터로 갱신
    _taskResultSub = AriAgent.on('/TASK_RESULT', (data) {
      final taskId = data['taskId']?.toString();
      if (taskId != null) _progressMessages.remove(taskId);
      refresh();
    });

    // 진행 메시지를 provider에 저장
    _progressSub = AriAgent.on('/AGENT.PROGRESS', (data) {
      final payload = data['data'] ?? data;
      final taskId = payload['requestId']?.toString();
      final message = payload['message']?.toString();
      if (taskId == null || message == null) return;
      _progressMessages.putIfAbsent(taskId, () => []).add(message);
      notifyListeners();
    });
  }

  /// 서버에서 전체 목록 + 결과를 다시 가져옵니다
  Future<void> refresh() async {
    try {
      final tasksResult = await AriAgent.call('/TASKS');
      final parsed = tasksResult['tasks'] as List? ?? [];
      final tasksList = parsed.map((t) => Map<String, dynamic>.from(t)).toList();

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
    String? appId,
    bool isOneOff = false,
  }) async {
    try {
      final res = await AriAgent.call('/TASKS.ADD', {
        'prompt': prompt,
        'cron': cron,
        'label': label ?? _generateLabel(prompt),
        'agentId': agentId,
        if (appId != null) 'appId': appId,
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
    try {
      final res = await AriAgent.call('/TASKS.RUN', {'taskId': id});
      final response = res['started'] == true ? '실행 완료' : '실행되지 않음';
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

  /// 특정 appId의 작업만 필터링
  List<AriScheduledTask> tasksForApp(String appId) =>
      tasks.where((t) => t.appId == appId).toList();

  String _generateLabel(String prompt) {
    if (prompt.length <= 20) return prompt;
    return '${prompt.substring(0, 20)}...';
  }
}
