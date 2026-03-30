import 'dart:async';

import 'package:flutter/foundation.dart';

import '../ws/WsManager.dart';

class AppProtocolHandler {
  final String appId;
  final FutureOr<dynamic> Function(String command, Map<String, dynamic> params)? onCommand;
  final Map<String, dynamic> Function()? onGetState;

  AppProtocolHandler({
    required this.appId,
    this.onCommand,
    this.onGetState,
  });

  final List<StreamSubscription> _subscriptions = [];

  void start() {
    _subscriptions.add(WsManager.on('/APP.COMMAND', _handleAppCommand));
    _subscriptions.add(WsManager.on('/APP.QUERY', _handleAppQuery));
    _subscriptions.add(WsManager.on('/GREETING', (_) => _registerApp()));

    if (WsManager.isConnected) {
      _registerApp();
    }
  }

  void stop() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
  }

  void _registerApp() {
    if (!WsManager.isConnected) return;
    WsManager.sendAsync('/APP.REGISTER', {'appId': appId});
  }

  Future<void> _handleAppCommand(Map<String, dynamic> data) async {
    if (data['appId'] != appId) return;

    final command = data['command'] as String?;
    final requestId = data['requestId'] as String?;
    if (command == null) return;

    final params = data['params'] as Map<String, dynamic>? ?? {};
    final result = await onCommand?.call(command, params);

    if (requestId != null && result != null) {
      WsManager.sendAsync('/APP.COMMAND_RESPONSE', {
        'requestId': requestId,
        'result': result,
      });
    }
  }

  void _handleAppQuery(Map<String, dynamic> data) {
    if (data['appId'] != appId) return;

    final queryType = data['queryType'] as String?;
    final requestId = data['requestId'] as String?;

    if (requestId == null || queryType == null) return;

    if (queryType == 'GET_STATE' && onGetState != null) {
      WsManager.sendAsync('/APP.QUERY_RESPONSE', {
        'requestId': requestId,
        'result': onGetState!(),
      });
    } else {
      debugPrint('Unhandled queryType: $queryType');
    }
  }
}
