import 'dart:async';
import 'package:flutter/material.dart';
import '../../bridge/ws/AriAgent.dart';
import '../models/ari_chat_message.dart';
import '../models/ari_queued_follow_up.dart';

export '../models/ari_chat_message.dart';

/// ARI 에이전트 스트림을 구독하여 채팅 메시지 상태를 관리하는 Provider.
class AriChatProvider extends ChangeNotifier {
  final List<AriChatMessage> _messages = [];
  StreamSubscription? _agentPushSub;
  StreamSubscription? _agentRequestSub;
  StreamSubscription? _progressSub;
  StreamSubscription? _followUpSub;
  StreamSubscription? _cancelSub;
  StreamSubscription? _taskResultSub;
  final List<StreamSubscription> _customSubs = [];
  final Set<String> _inFlightRequestIds = {};
  final Set<String> _backgroundRequestIds = {};
  final Set<String> _taskRequestIds = {};
  final List<AriQueuedFollowUp> _queuedFollowUps = [];

  bool _isLoading = false;
  String? _activeRequestId;
  bool showTaskMessages = true;

  bool get isLoading => _isLoading;
  String? get activeRequestId => _activeRequestId;
  String? get latestFollowUpMessage =>
      _queuedFollowUps.isEmpty ? null : _queuedFollowUps.last.message;
  int get queuedFollowUpCount => _queuedFollowUps.length;

  void _syncLoadingState() {
    _isLoading =
        _inFlightRequestIds.isNotEmpty || _backgroundRequestIds.isNotEmpty;
  }

  void _clearPendingSystemMessages() {
    final pendingRequestIds = {
      ..._inFlightRequestIds,
      ..._backgroundRequestIds,
      if (_activeRequestId != null) _activeRequestId!,
    };
    if (pendingRequestIds.isEmpty) return;
    _messages.removeWhere(
      (m) => m.isSystem && pendingRequestIds.contains(m.requestId),
    );
  }

  bool _removeFollowUpByRequestId(String requestId) {
    if (requestId.isEmpty) return false;
    final index =
        _queuedFollowUps.indexWhere((item) => item.requestId == requestId);
    if (index == -1) return false;
    _queuedFollowUps.removeAt(index);
    return true;
  }

  // 추가 이벤트 핸들러 주입
  final Map<String, void Function(dynamic data, AriChatProvider provider)>?
      customEventHandlers;

  AriChatProvider({
    this.customEventHandlers,
  }) {
    _initListeners();

    // 주입된 커스텀 이벤트 핸들러 등록
    customEventHandlers?.forEach((event, handler) {
      _customSubs.add(AriAgent.on(event, (data) => handler(data, this)));
    });
  }

  void _initListeners() {
    _agentRequestSub = AriAgent.on('/AGENT.REQUEST', (data) {
      final requestId = data['requestId']?.toString() ?? '';
      final message = data['message']?.toString() ?? '';
      final source = data['source']?.toString() ?? 'user';

      if (message.isEmpty) return;
      if (source == 'task') {
        _taskRequestIds.add(requestId);
      }
      if (requestId.isNotEmpty &&
          _messages.any((m) => m.isUser && m.requestId == requestId)) return;

      _messages.add(AriChatMessage(
        text: message,
        isUser: true,
        createdAt: DateTime.now(),
        requestId: requestId,
      ));
      notifyListeners();
    });

    _agentPushSub = AriAgent.on('/APP.PUSH', (data) {
      final payload = data['data'] is Map ? data['data'] as Map : data;
      final response = payload['response']?.toString() ?? '';
      final requestId = payload['requestId']?.toString() ?? '';
      final source = payload['source']?.toString() ?? 'user';

      if (response.isEmpty) return;

      if (source == 'task') {
        _taskRequestIds.add(requestId);
      }
      if (requestId.isNotEmpty) removeSystemMessage(requestId);
      final removedFollowUp = _removeFollowUpByRequestId(requestId);
      onResponseReceived(requestId);

      if (requestId.isNotEmpty &&
          _messages.any(
            (m) => !m.isUser && !m.isSystem && m.requestId == requestId,
          )) return;

      _messages.add(AriChatMessage(
        text: response,
        isUser: false,
        createdAt: DateTime.now(),
        requestId: requestId,
      ));

      notifyListeners();
      if (removedFollowUp) {
        notifyListeners();
      }
    });

    _progressSub = AriAgent.on('/AGENT.PROGRESS', (data) {
      final payload = data['data'] is Map ? data['data'] as Map : data;
      final progressMessage = payload['message']?.toString() ?? '';
      final requestId = payload['requestId']?.toString() ?? '';
      final source = payload['source']?.toString() ?? '';

      if (progressMessage.isEmpty) return;

      if (requestId.isNotEmpty) {
        _inFlightRequestIds.add(requestId);
      }
      if (source == 'task') {
        _taskRequestIds.add(requestId);
      } else if (requestId.startsWith('report-') ||
          requestId.startsWith('sys-')) {
        _backgroundRequestIds.add(requestId);
      } else if (requestId.isNotEmpty && requestId != _activeRequestId) {
        _taskRequestIds.add(requestId);
      }
      _syncLoadingState();
      final removedFollowUp = _removeFollowUpByRequestId(requestId);

      upsertSystemMessage(progressMessage, requestId);
      if (removedFollowUp) {
        notifyListeners();
      }
    });

    _followUpSub = AriAgent.on('/AGENT.FOLLOW_UP', (data) {
      final payload = data['data'] is Map ? data['data'] as Map : data;
      final requestId = payload['requestId']?.toString() ?? '';
      final message = payload['message']?.toString() ?? '';

      if (message.isEmpty || requestId.isEmpty) return;
      if (_queuedFollowUps.any((item) => item.requestId == requestId)) return;

      _messages.removeWhere((m) => m.isUser && m.requestId == requestId);
      _inFlightRequestIds.remove(requestId);
      _backgroundRequestIds.remove(requestId);
      if (_activeRequestId == requestId) {
        _activeRequestId = null;
      }
      _syncLoadingState();

      _queuedFollowUps.add(AriQueuedFollowUp(
        requestId: requestId,
        message: message,
      ));
      notifyListeners();
    });

    _cancelSub = AriAgent.on('/AGENT.CANCEL', (_) {
      _clearPendingSystemMessages();
      _queuedFollowUps.clear();
      _backgroundRequestIds.clear();
      _inFlightRequestIds.clear();
      _activeRequestId = null;
      _syncLoadingState();
      notifyListeners();
    });

    _taskResultSub = AriAgent.on('/TASK_RESULT', (data) {
      final taskId = data['taskId']?.toString() ?? 'unknown';
      final requestId = data['requestId']?.toString() ?? '';
      if (taskId != 'unknown') {
        _taskRequestIds.remove(taskId);
        if (requestId.isNotEmpty) {
          _taskRequestIds.remove(requestId);
          _inFlightRequestIds.remove(requestId);
          _backgroundRequestIds.remove(requestId);
          removeSystemMessage(requestId);
        }
        _inFlightRequestIds.remove(taskId);
        _backgroundRequestIds.remove(taskId);
        removeSystemMessage(taskId);
        _syncLoadingState();
        notifyListeners();
      }
    });
  }

  List<AriChatMessage> get messages => List.unmodifiable(_messages);

  // 자식 클래스 오버라이드를 위한 훅 또는 내부 호출
  void onResponseReceived(String requestId) {
    if (requestId == _activeRequestId) _activeRequestId = null;
    if (requestId.isNotEmpty) _inFlightRequestIds.remove(requestId);
    if (requestId.isNotEmpty) {
      _backgroundRequestIds.remove(requestId);
    }
    _syncLoadingState();
  }

  /// 표준 서버 히스토리 불러오기
  Future<void> loadServerHistory(String agentId) async {
    if (!AriAgent.isConnected) return;
    try {
      final response = await AriAgent.call('/CHAT.GET_HISTORY', {
        'agentId': agentId,
        'index': 0,
        'size': 50,
      });

      final List logs = response['logs'] ?? [];
      final List<AriChatMessage> history = [];
      if (logs.isNotEmpty) {
        for (final log in logs.reversed) {
          if (log['type'] == 'chat') {
            history.add(AriChatMessage(
              text: log['message']?.toString() ?? '',
              isUser: log['isUser'] == true,
              isError: log['isError'] == true,
              createdAt: DateTime.now(),
              requestId: log['requestId']?.toString(),
            ));
          } else if (log['type'] == 'task') {
            final label = log['label'] ?? '스케줄 작업';
            final result = log['result'] ?? '';
            history.add(AriChatMessage(
              text: '🕒 [$label] 실행 결과:\n$result',
              isUser: false,
              createdAt: DateTime.now(),
            ));
          }
        }
      }
      setMessages(history);
    } catch (e) {
      debugPrint('[AriChatProvider] 히스토리 로드 실패: $e');
    }
  }

  /// 표준 에이전트 메시지 송신 API
  Future<void> sendAgentMessage(
    String text, {
    String? agentId,
    String? persona,
    String? avatarName,
    String? appId,
    String platform = 'Client',
  }) async {
    final requestId = DateTime.now().microsecondsSinceEpoch.toString();
    _activeRequestId = requestId;
    _inFlightRequestIds.add(requestId);
    _syncLoadingState();
    addUserMessage(text, requestId: requestId);
    notifyListeners();

    try {
      await AriAgent.call('/AGENT', {
        'message': text,
        'requestId': requestId,
        if (agentId != null) 'agentId': agentId,
        if (persona != null) 'persona': persona,
        if (avatarName != null) 'avatarName': avatarName,
        if (appId != null) 'appId': appId,
        'platform': platform,
      });
    } catch (e) {
      _inFlightRequestIds.remove(requestId);
      _backgroundRequestIds.remove(requestId);
      final removedFollowUp = _removeFollowUpByRequestId(requestId);
      removeSystemMessage(requestId);
      if (_activeRequestId != requestId) {
        _syncLoadingState();
        if (removedFollowUp) {
          notifyListeners();
        }
        return;
      }
      addMessage(AriChatMessage(
        text: '에이전트에 연결할 수 없습니다. ($e)',
        isUser: false,
        isError: true,
        createdAt: DateTime.now(),
      ));
      _activeRequestId = null;
      _syncLoadingState();
    }
  }

  /// 송신 취소
  void cancelAgentMessage({String? agentId}) {
    if (!_isLoading) return;
    final payload = <String, dynamic>{};
    if (agentId != null) payload['agentId'] = agentId;
    AriAgent.emit('/AGENT.CANCEL', payload);
    _clearPendingSystemMessages();
    if (_activeRequestId != null) {
      _inFlightRequestIds.remove(_activeRequestId);
    }
    _backgroundRequestIds.clear();
    _queuedFollowUps.clear();
    _activeRequestId = null;
    _syncLoadingState();
    notifyListeners();
  }

  void upsertSystemMessage(String text, String requestId) {
    bool isMyRequest =
        _activeRequestId != null && requestId == _activeRequestId;
    bool isBackgroundRequest =
        requestId.startsWith('report-') || requestId.startsWith('sys-');
    bool isScheduledTaskRequest =
        showTaskMessages && _taskRequestIds.contains(requestId);
    if (!isMyRequest && !isBackgroundRequest && !isScheduledTaskRequest) return;

    final idx = _messages.lastIndexWhere(
      (m) => m.isSystem && m.requestId == requestId,
    );
    final msg = AriChatMessage(
      text: text,
      isUser: false,
      isSystem: true,
      requestId: requestId,
      createdAt: DateTime.now(),
    );
    if (idx >= 0) {
      _messages[idx] = msg;
    } else {
      _messages.add(msg);
    }
    notifyListeners();
  }

  void removeSystemMessage(String requestId) {
    _messages.removeWhere((m) => m.isSystem && m.requestId == requestId);
    notifyListeners();
  }

  void addAiMessage(String text, {String? requestId}) {
    if (requestId != null &&
        _messages.any((m) => !m.isUser && m.requestId == requestId)) return;
    _messages.add(AriChatMessage(
      text: text,
      isUser: false,
      createdAt: DateTime.now(),
      requestId: requestId,
    ));
    notifyListeners();
  }

  void addUserMessage(String text, {String? requestId}) {
    if (requestId != null &&
        _messages.any((m) => m.isUser && m.requestId == requestId)) return;
    _messages.add(AriChatMessage(
      text: text,
      isUser: true,
      createdAt: DateTime.now(),
      requestId: requestId,
    ));
    notifyListeners();
  }

  void addMessage(AriChatMessage message) {
    _messages.add(message);
    notifyListeners();
  }

  void setMessages(List<AriChatMessage> newMessages) {
    _messages.clear();
    _messages.addAll(newMessages);
    notifyListeners();
  }

  void clearMessages() {
    _messages.clear();
    _inFlightRequestIds.clear();
    _backgroundRequestIds.clear();
    _taskRequestIds.clear();
    _queuedFollowUps.clear();
    _activeRequestId = null;
    _syncLoadingState();
    notifyListeners();
  }

  Future<void> resetAgentSession({String? agentId}) async {
    final payload = <String, dynamic>{};
    if (agentId != null) payload['agentId'] = agentId;

    try {
      await AriAgent.call('/AGENT.RESET', payload);
    } catch (e) {
      debugPrint('[AriChatProvider] 세션 리셋 실패: $e');
    }

    clearMessages();
  }

  /// 서버의 대화 이력을 삭제하고 로컬 메시지도 초기화합니다.
  Future<void> clearServerHistory(String agentId) async {
    AriAgent.emit('/CHAT.CLEAR', {'agentId': agentId});
    clearMessages();
  }

  @override
  void dispose() {
    _agentPushSub?.cancel();
    _agentRequestSub?.cancel();
    _progressSub?.cancel();
    _followUpSub?.cancel();
    _cancelSub?.cancel();
    _taskResultSub?.cancel();
    for (final sub in _customSubs) {
      sub.cancel();
    }
    super.dispose();
  }
}
