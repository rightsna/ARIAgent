import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/chat_message.dart';
import 'package:ari_plugin/ari_plugin.dart';
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
    _currentAgentId = AvatarProvider().currentAvatarId;

    // 아바타 변경 시 히스토리 자동 갱신
    AvatarProvider().addListener(_onAvatarChanged);
  }

  void _onAvatarChanged() {
    final newAgentId = AvatarProvider().currentAvatarId;
    if (_currentAgentId != newAgentId) {
      loadHistory(newAgentId);
    }
  }

  Future<void> loadHistory(String agentId) async {
    _currentAgentId = agentId;
    if (!AriAgent.isConnected) return;

    try {
      final response = await AriAgent.call('/CHAT.GET_HISTORY', {
        'agentId': agentId,
        'index': 0,
        'size': 50,
      });

      if (response['ok'] == true) {
        final List logs = response['data']['logs'] ?? [];
        _messages.clear();

        // 서버 로그는 최신순이므로 역순(과거->최신)으로 추가
        for (final log in logs.reversed) {
          if (log['type'] == 'chat') {
            _messages.add(
              ChatMessage(
                text: log['message']?.toString() ?? '',
                isUser: log['isUser'] == true,
                isError: log['isError'] == true,
                requestId: log['requestId']?.toString(),
              ),
            );
          } else if (log['type'] == 'task') {
            final label = log['label'] ?? '스케줄 작업';
            final result = log['result'] ?? '';
            _messages.add(
              ChatMessage(text: '🕒 [$label] 실행 결과:\n$result', isUser: false),
            );
          }
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[Chat] 히스토리 로드 실패: $e');
    }
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
    });

    AriAgent.connectionNotifier.addListener(_onConnectionChanged);
  }

  void _onConnectionChanged() {
    if (AriAgent.isConnected && _currentAgentId != null) {
      loadHistory(_currentAgentId!);
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
