import 'dart:async';
import 'package:flutter/material.dart';
import '../../bridge/ws/AriAgent.dart';
import '../models/ari_chat_message.dart';

export '../models/ari_chat_message.dart';

/// ARI 에이전트 스트림을 구독하여 채팅 메시지 상태를 관리하는 Provider.
class AriChatProvider extends ChangeNotifier {
  final List<AriChatMessage> _messages = [];
  StreamSubscription? _agentPushSub;
  StreamSubscription? _agentRequestSub;
  StreamSubscription? _progressSub;
  StreamSubscription? _taskResultSub;
  final List<StreamSubscription> _customSubs = [];
  final Set<String> _processedTaskIds = {};

  bool _isLoading = false;
  String? _activeRequestId;

  bool get isLoading => _isLoading;
  String? get activeRequestId => _activeRequestId;

  // 추가 이벤트 핸들러 주입
  final Map<String, void Function(dynamic data, AriChatProvider provider)>? customEventHandlers;

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

      if (message.isEmpty) return;
      if (requestId.isNotEmpty &&
          _messages.any((m) => m.isUser && m.requestId == requestId))
        return;

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

      if (response.isEmpty) return;

      if (requestId.isNotEmpty) removeSystemMessage(requestId);

      if (requestId.isNotEmpty &&
          _messages.any(
            (m) => !m.isUser && !m.isSystem && m.requestId == requestId,
          ))
        return;

      _messages.add(AriChatMessage(
        text: response,
        isUser: false,
        createdAt: DateTime.now(),
        requestId: requestId,
      ));
      
      onResponseReceived(requestId);
      notifyListeners();
    });

    _progressSub = AriAgent.on('/AGENT.PROGRESS', (data) {
      final payload = data['data'] is Map ? data['data'] as Map : data;
      final progressMessage = payload['message']?.toString() ?? '';
      final requestId = payload['requestId']?.toString() ?? '';

      if (progressMessage.isEmpty) return;

      upsertSystemMessage(progressMessage, requestId);
    });

    _taskResultSub = AriAgent.on('/TASK_RESULT', (data) {
      final taskId = data['taskId']?.toString() ?? 'unknown';

      if (taskId != 'unknown' && _processedTaskIds.contains(taskId)) return;
      _processedTaskIds.add(taskId);

      final label = data['label'] ?? '시스템 작업';
      final result = data['result'] ?? '';

      _messages.add(AriChatMessage(
        text: '🕒 [$label] 실행 결과:\n$result',
        isUser: false,
        createdAt: DateTime.now(),
      ));
      notifyListeners();
    });
  }

  List<AriChatMessage> get messages => List.unmodifiable(_messages);

  // 자식 클래스 오버라이드를 위한 훅 또는 내부 호출
  void onResponseReceived(String requestId) {
    if (requestId == _activeRequestId) {
      _isLoading = false;
      _activeRequestId = null;
    }
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
  Future<void> sendAgentMessage(String text, {
    String? agentId,
    String? persona,
    String? avatarName,
    String platform = 'Client',
  }) async {
    final requestId = DateTime.now().microsecondsSinceEpoch.toString();
    _activeRequestId = requestId;
    _isLoading = true;
    notifyListeners();

    try {
      await AriAgent.call('/AGENT', {
        'message': text,
        'requestId': requestId,
        if (agentId != null) 'agentId': agentId,
        if (persona != null) 'persona': persona,
        if (avatarName != null) 'avatarName': avatarName,
        'platform': platform,
      });
    } catch (e) {
      if (_activeRequestId != requestId) return;
      removeSystemMessage(requestId);
      addMessage(AriChatMessage(
        text: '에이전트에 연결할 수 없습니다. ($e)',
        isUser: false,
        isError: true,
        createdAt: DateTime.now(),
      ));
      _isLoading = false;
      _activeRequestId = null;
    }
  }

  /// 송신 취소
  void cancelAgentMessage({String? agentId}) {
    if (!_isLoading) return;
    final payload = <String, dynamic>{};
    if (agentId != null) payload['agentId'] = agentId;
    AriAgent.emit('/AGENT.CANCEL', payload);
    removeSystemMessage(_activeRequestId ?? '');
    _isLoading = false;
    _activeRequestId = null;
    notifyListeners();
  }

  void upsertSystemMessage(String text, String requestId) {
    bool isMyRequest = _activeRequestId != null && requestId == _activeRequestId;
    bool isBackgroundRequest = requestId.startsWith('report-') || requestId.startsWith('sys-');
    if (!isMyRequest && !isBackgroundRequest) return;

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
        _messages.any((m) => !m.isUser && m.requestId == requestId))
      return;
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
        _messages.any((m) => m.isUser && m.requestId == requestId))
      return;
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
    _processedTaskIds.clear();
    _activeRequestId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _agentPushSub?.cancel();
    _agentRequestSub?.cancel();
    _progressSub?.cancel();
    _taskResultSub?.cancel();
    for (final sub in _customSubs) {
      sub.cancel();
    }
    super.dispose();
  }
}
