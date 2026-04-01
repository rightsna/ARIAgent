import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/chat_message.dart';
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
  StreamSubscription? _agentRequestSub;

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

    AriAgent.emit('/AGENT.SET_HISTORY', {
      'agentId': agentId,
      'history': history,
    });
  }

  void _initWebSocket() {
    // 질문 표시 — 본앱/다른 앱 모두 이 경로로 표시 (requestId로 중복 제거)
    _agentRequestSub = AriAgent.on('/AGENT.REQUEST', (data) {
      final requestId = data['requestId']?.toString() ?? '';
      final message = data['message']?.toString() ?? '';

      if (message.isEmpty) return;
      if (_messages.any((m) => m.isUser && m.requestId == requestId)) return;

      _messages.add(ChatMessage(text: message, isUser: true, requestId: requestId));
      notifyListeners();

      try {
        LogRepository().addChatLog(
          agentId: _currentAgentId ?? AvatarProvider().currentAvatarId,
          message: message,
          isUser: true,
        );
      } catch (_) {}
    });

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

      if (progressMessage.isEmpty) return;

      _upsertProgressMessage(progressMessage, requestId);
      notifyListeners();
    });

    _agentPushSub = AriAgent.on('/APP.PUSH', (data) {
      final payload = data['data'] is Map<String, dynamic>
          ? data['data'] as Map<String, dynamic>
          : data;
      final response = payload['response']?.toString() ?? '';
      final requestId = payload['requestId']?.toString() ?? '';

      if (response.isEmpty) return;

      if (requestId.isNotEmpty) {
        _removeProgressMessage(requestId);
      }

      _messages.add(ChatMessage(text: response, isUser: false));

      // 요청자인 경우 로딩 상태 해제
      if (requestId == _activeRequestId) {
        _isLoading = false;
        _activeRequestId = null;
      }

      notifyListeners();

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


  /// 에이전트에게 메시지 송신
  /// 질문은 서버가 /AGENT.REQUEST 로 브로드캐스트 → 리스너에서 표시 (양쪽 동일 코드패스)
  /// 응답은 서버가 /APP.PUSH 로 브로드캐스트 → _agentPushSub 에서 처리
  Future<void> sendMessage(String text, String agentId) async {
    final requestId = DateTime.now().microsecondsSinceEpoch.toString();
    _activeRequestId = requestId;
    _isLoading = true;
    notifyListeners();

    try {
      final avatar = AvatarProvider();
      await AriAgent.call('/AGENT', {
        'message': text,
        'requestId': requestId,
        'persona': avatar.persona.trim(),
        'avatarName': avatar.name,
        'platform': _getPlatformLabel(),
        'agentId': avatar.currentAvatarId,
      });
      // 응답은 /APP.PUSH 리스너에서 처리
    } catch (e) {
      if (_activeRequestId != requestId) return;
      _removeProgressMessage(requestId);
      _messages.add(
        ChatMessage(text: '에이전트에 연결할 수 없습니다. ($e)', isUser: false, isError: true),
      );
      _isLoading = false;
      _activeRequestId = null;
      notifyListeners();
      try {
        LogRepository().addChatLog(
          agentId: agentId,
          message: '에이전트에 연결할 수 없습니다. ($e)',
          isUser: false,
          isError: true,
        );
      } catch (_) {}
    }
  }

  void cancelSendMessage() {
    if (!_isLoading) return;
    final agentId = _currentAgentId ?? AvatarProvider().currentAvatarId;
    AriAgent.emit('/AGENT.CANCEL', {'agentId': agentId});
    _removeProgressMessage(_activeRequestId ?? '');
    _isLoading = false;
    _activeRequestId = null;
    notifyListeners();
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
    _agentRequestSub?.cancel();
    _taskResultSub?.cancel();
    _progressSub?.cancel();
    _agentPushSub?.cancel();
    _setHistorySub?.cancel();
    AriAgent.connectionNotifier.removeListener(_onConnectionChanged);
    AvatarProvider().removeListener(_onAvatarChanged);
    super.dispose();
  }
}
