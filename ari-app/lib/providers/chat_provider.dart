import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/chat_message.dart';
import '../models/agent_response.dart';
import 'package:ari_plugin/ari_plugin.dart';
import '../repositories/log_repository.dart';
import 'avatar_provider.dart';

/// ChatProvider: 채팅 상태 관리 및 서버(에이전트) 통신 수행.
class ChatProvider extends ChangeNotifier {
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  final Set<String> _processedTaskIds = {}; // 중복 처리 방지용
  String? _activeRequestId;

  StreamSubscription? _taskResultSub;
  StreamSubscription? _progressSub;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;

  String? _currentAgentId;

  ChatProvider() {
    _initWebSocket();
    // 초기 로드
    _currentAgentId = AvatarProvider().currentAvatarId;
    loadHistory(_currentAgentId!);

    // 아바타 변경 시 히스토리 자동 갱신
    AvatarProvider().addListener(_onAvatarChanged);
  }

  void _onAvatarChanged() {
    final newAgentId = AvatarProvider().currentAvatarId;
    if (_currentAgentId != newAgentId) {
      loadHistory(newAgentId);
    }
  }

  void loadHistory(String agentId) {
    _currentAgentId = agentId;
    _messages.clear();

    final repo = LogRepository();
    final chatLogs = repo.getChatLogs(agentId);
    final taskLogs = repo.getTaskLogs(agentId);

    // 두 로그를 시간순으로 병합
    final allLogs = [...chatLogs, ...taskLogs];
    allLogs.sort((a, b) {
      final t1 = a['timestamp']?.toString() ?? '';
      final t2 = b['timestamp']?.toString() ?? '';
      return t1.compareTo(t2);
    });

    for (final log in allLogs) {
      if (log.containsKey('message')) {
        _messages.add(
          ChatMessage(
            text: log['message']?.toString() ?? '',
            isUser: log['isUser'] == true,
            isError: log['isError'] == true,
          ),
        );
      } else if (log.containsKey('taskId')) {
        final label = log['label'] ?? '스케줄 작업';
        final result = log['result'] ?? '';
        _messages.add(
          ChatMessage(text: '🕒 [$label] 실행 결과:\n$result', isUser: false),
        );
      }
    }

    notifyListeners();
  }

  void _initWebSocket() {
    _taskResultSub = WsManager.on('/TASK_RESULT', (data) {
      final taskData = data;
      final taskId = taskData['taskId']?.toString() ?? 'unknown';

      if (taskId != 'unknown' && _processedTaskIds.contains(taskId)) {
        return;
      }
      _processedTaskIds.add(taskId);

      final label = taskData['label'] ?? '스케줄 작업';
      final result = taskData['result'] ?? '';

      try {
        LogRepository().addTaskLog(
          taskId: taskData['taskId'] ?? 'unknown',
          label: label,
          result: result,
          agentId: AvatarProvider().currentAvatarId,
        );
      } catch (e) {
        debugPrint('[Hive] 저장 에러: $e');
      }

      _messages.add(
        ChatMessage(text: '🕒 [$label] 실행 결과:\n$result', isUser: false),
      );
      notifyListeners();
    });

    _progressSub = WsManager.on('/AGENT.PROGRESS', (data) {
      final payload = data['data'] is Map<String, dynamic>
          ? data['data'] as Map<String, dynamic>
          : data;
      final progressMessage = payload['message']?.toString() ?? '';
      final requestId = payload['requestId']?.toString() ?? '';

      if (progressMessage.isEmpty) {
        return;
      }

      _upsertProgressMessage(progressMessage, requestId);
      notifyListeners();
    });
  }

  /// 에이전트에게 메시지 송신 (기존 AgentService 통합)
  Future<void> sendMessage(String text, String agentId) async {
    final requestId = DateTime.now().microsecondsSinceEpoch.toString();
    _activeRequestId = requestId;
    _messages.add(ChatMessage(text: text, isUser: true));
    _isLoading = true;
    notifyListeners();

    // 로그 저장
    try {
      LogRepository().addChatLog(agentId: agentId, message: text, isUser: true);
    } catch (_) {}

    // 에이전트 호출 (이전 AgentService.sendMessage 로직)
    final response = await _callAgentApi(text, requestId);

    _removeProgressMessage(requestId);
    _messages.add(
      ChatMessage(
        text: response.message,
        isUser: false,
        isError: !response.success,
      ),
    );
    _isLoading = false;
    _activeRequestId = null;
    notifyListeners();

    // 로그 저장
    try {
      LogRepository().addChatLog(
        agentId: agentId,
        message: response.message,
        isUser: false,
        isError: !response.success,
      );
    } catch (_) {}
  }

  Future<AgentResponse> _callAgentApi(String message, String requestId) async {
    try {
      final avatar = AvatarProvider();
      final persona = avatar.persona.trim();

      final res = await WsManager.call('/AGENT', {
        'message': message,
        'requestId': requestId,
        'persona': persona,
        'avatarName': avatar.name,
        'platform': _getPlatformLabel(),
        'agentId': avatar.currentAvatarId,
      });

      return AgentResponse(message: res['response'] ?? '', success: true);
    } catch (e) {
      return AgentResponse(message: '에이전트에 연결할 수 없습니다. ($e)', success: false);
    }
  }

  String _getPlatformLabel() {
    switch (Platform.operatingSystem) {
      case 'macos':
        return 'macOS';
      case 'windows':
        return 'Windows';
      case 'linux':
        return 'Linux';
      default:
        return Platform.operatingSystem;
    }
  }

  void clearMessages() {
    _messages.clear();
    _activeRequestId = null;
    notifyListeners();
  }

  void _upsertProgressMessage(String text, String requestId) {
    if (_activeRequestId != null &&
        requestId.isNotEmpty &&
        requestId != _activeRequestId) {
      return;
    }
    final idx = _messages.lastIndexWhere(
      (m) => m.isSystem && m.requestId == requestId,
    );
    final msg = ChatMessage(
      text: text,
      isUser: false,
      isSystem: true,
      requestId: requestId,
    );

    if (idx >= 0) {
      _messages[idx] = msg;
    } else {
      _messages.add(msg);
    }
  }

  void _removeProgressMessage(String requestId) {
    _messages.removeWhere((m) => m.isSystem && m.requestId == requestId);
  }

  @override
  void dispose() {
    _taskResultSub?.cancel();
    _progressSub?.cancel();
    AvatarProvider().removeListener(_onAvatarChanged);
    super.dispose();
  }
}
