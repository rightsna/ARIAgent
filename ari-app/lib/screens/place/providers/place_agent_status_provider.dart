import 'dart:async';

import 'package:ari_plugin/ari_plugin.dart';
import 'package:flutter/foundation.dart';

class PlaceAgentStatusProvider extends ChangeNotifier {
  static final PlaceAgentStatusProvider _instance =
      PlaceAgentStatusProvider._internal();
  factory PlaceAgentStatusProvider() => _instance;
  PlaceAgentStatusProvider._internal();

  final Map<String, String> _statuses = {};
  bool _initialized = false;

  StreamSubscription? _requestSub;
  StreamSubscription? _progressSub;
  StreamSubscription? _pushSub;
  StreamSubscription? _taskResultSub;

  Future<void> init() async {
    if (_initialized) return;

    _requestSub = AriAgent.on('/AGENT.REQUEST', (data) {
      _setWorking(data['agentId']?.toString());
    });
    _progressSub = AriAgent.on('/AGENT.PROGRESS', (data) {
      final payload = data['data'] is Map ? data['data'] as Map : data;
      _setWorking(payload['agentId']?.toString());
    });
    _pushSub = AriAgent.on('/APP.PUSH', (data) {
      final payload = data['data'] is Map ? data['data'] as Map : data;
      _setIdle(payload['agentId']?.toString());
    });
    _taskResultSub = AriAgent.on('/TASK_RESULT', (data) {
      _setIdle(data['agentId']?.toString());
    });

    _initialized = true;
  }

  String statusFor(String agentId, {required bool isSelected}) {
    final status = _statuses[agentId];
    if (status == 'working') return '작업중';
    return isSelected ? '대기중' : '쉬는중';
  }

  void _setWorking(String? agentId) {
    if (agentId == null || agentId.isEmpty) return;
    _statuses[agentId] = 'working';
    notifyListeners();
  }

  void _setIdle(String? agentId) {
    if (agentId == null || agentId.isEmpty) return;
    _statuses[agentId] = 'idle';
    notifyListeners();
  }

  @override
  void dispose() {
    _requestSub?.cancel();
    _progressSub?.cancel();
    _pushSub?.cancel();
    _taskResultSub?.cancel();
    super.dispose();
  }
}
