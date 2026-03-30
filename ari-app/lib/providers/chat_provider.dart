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

    // 서버에 대화 맥락 주입 (이전 대화 복구 컨셉)
    _seedServerHistory(agentId, chatLogs);
  }

  void _seedServerHistory(String agentId, List<Map<String, dynamic>> chatLogs) {
    if (!AriAgent.isConnected) return;

    // 최근 20개 정도만 추출하여 서버에 전달 (AI 컨텍스트용)
    final recentLogs = chatLogs.length > 20
        ? chatLogs.sublist(chatLogs.length - 20)
        : chatLogs;

    final history = recentLogs.map((log) {
      return {
        'role': log['isUser'] == true ? 'user' : 'assistant',
        'content': [
          {
            'type': 'text',
            'text': log['message']?.toString() ?? '',
          }
        ],
      };
    }).toList();

    AriAgent.sendAsync('/AGENT.SET_HISTORY', {
      'agentId': agentId,
      'history': history,
    });
  }

  void _initWebSocket() {
    _taskResultSub = AriAgent.on('/TASK_RESULT', (data) {
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

    _progressSub = AriAgent.on('/AGENT.PROGRESS', (data) {
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

    _agentPushSub = AriAgent.on('/AGENT.PUSH', (data) {
      final payload = data['data'] is Map<String, dynamic>
          ? data['data'] as Map<String, dynamic>
          : data;
      final response = payload['response']?.toString() ?? '';
      final requestId = payload['requestId']?.toString() ?? '';

      if (response.isEmpty) return;

      // 만약 진행 중인 메시지가 있다면 제거
      if (requestId.isNotEmpty) {
        _removeProgressMessage(requestId);
      }

      // 채팅창에 에이전트의 응답으로 표시
      _messages.add(
        ChatMessage(text: response, isUser: false),
      );
      notifyListeners();

      // 로그 저장 (선택 사항)
      try {
        LogRepository().addChatLog(
          agentId: AvatarProvider().currentAvatarId,
          message: response,
          isUser: false,
        );
      } catch (_) {}
    });

    // 서버 사이드 컨텍스트 초기화 응답 핸들러 (디버깅용)
    _setHistorySub = AriAgent.on('/AGENT.SET_HISTORY', (data) {
      debugPrint('[Chat] Server history seeded ok');
    });

    AriAgent.connectionNotifier.addListener(_onConnectionChanged);
  }

  void _onConnectionChanged() {
    if (AriAgent.isConnected && _currentAgentId != null) {
      final chatLogs = LogRepository().getChatLogs(_currentAgentId!);
      _seedServerHistory(_currentAgentId!, chatLogs);
    }
  }

  StreamSubscription? _agentPushSub;
  StreamSubscription? _setHistorySub;


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

    // 취소되었거나 다른 요청이 시작된 경우 응답 무시
    if (_activeRequestId != requestId) {
      debugPrint('[Chat] Request $requestId was cancelled or superseded.');
      return;
    }

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

  void cancelSendMessage() {
    if (!_isLoading) return;
    final agentId = _currentAgentId ?? AvatarProvider().currentAvatarId;
    AriAgent.sendAsync('/AGENT.CANCEL', {'agentId': agentId});
    _removeProgressMessage(_activeRequestId ?? '');
    _isLoading = false;
    _activeRequestId = null;
    notifyListeners();
  }

  Future<AgentResponse> _callAgentApi(String message, String requestId) async {
    try {
      final avatar = AvatarProvider();
      final persona = avatar.persona.trim();

      final res = await AriAgent.call('/AGENT', {
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
    final isMyRequest =
        _activeRequestId != null && requestId == _activeRequestId;
    final isBackgroundRequest = requestId.startsWith('report-');

    if (!isMyRequest && !isBackgroundRequest) {
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
    _agentPushSub?.cancel();
    _setHistorySub?.cancel();
    AriAgent.connectionNotifier.removeListener(_onConnectionChanged);
    AvatarProvider().removeListener(_onAvatarChanged);
    super.dispose();
  }
}
