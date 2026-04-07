import 'dart:async';

import '../ws/AriAgent.dart';

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
  Timer? _registerRetryTimer;
  int _registerAttempts = 0;
  static const int _maxRegisterAttempts = 3;

  void start() {
    _subscriptions.add(AriAgent.on('/APP.COMMAND', _handleAppCommand));
    _subscriptions.add(AriAgent.on('/GREETING', (_) => _registerApp()));
    _subscriptions.add(AriAgent.on('/APP.REGISTER', _handleRegisterAck));
    _subscriptions.add(AriAgent.connectionStream.listen((connected) {
      if (connected) {
        _registerAttempts = 0;
        _registerApp();
        _startRegisterRetry();
      } else {
        _stopRegisterRetry();
      }
    }));

    if (AriAgent.isConnected) {
      _registerApp();
      _startRegisterRetry();
    }
  }

  void stop() {
    _stopRegisterRetry();
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
  }

  void _registerApp() {
    if (!AriAgent.isConnected) return;
    _registerAttempts++;
    AriAgent.register(appId);
  }

  void _startRegisterRetry() {
    _registerRetryTimer ??= Timer.periodic(const Duration(seconds: 2), (_) {
      if (!AriAgent.isConnected) {
        _stopRegisterRetry();
        return;
      }
      if (_registerAttempts >= _maxRegisterAttempts) {
        _stopRegisterRetry();
        return;
      }
      _registerApp();
    });
  }

  void _stopRegisterRetry() {
    _registerRetryTimer?.cancel();
    _registerRetryTimer = null;
  }

  void _handleRegisterAck(Map<String, dynamic> data) {
    final ackAppId = data['data']?['appId'] ?? data['appId'];
    if (ackAppId == appId) {
      _stopRegisterRetry();
    }
  }

  Future<void> _handleAppCommand(Map<String, dynamic> data) async {
    if (data['appId'] != appId) return;

    final command = data['command'] as String?;
    final requestId = data['requestId'] as String?;
    if (command == null) return;

    final params = data['params'] as Map<String, dynamic>? ?? {};

    // Handle reserved command: GET_STATE
    if (command == 'GET_STATE' && onGetState != null) {
      final state = onGetState!();
      if (requestId != null) {
        AriAgent.sendResponse(requestId: requestId, result: state);
      }
      return;
    }

    final result = await onCommand?.call(command, params);

    if (requestId != null && result != null) {
      AriAgent.sendResponse(requestId: requestId, result: result);
    }
  }
}
