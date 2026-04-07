import 'dart:async';

import 'WebSocketService.dart';
import 'settings_loader_stub.dart'
    if (dart.library.io) 'settings_loader_io.dart';

void _logDebug(Object message) {
  print(message);
}

class AriAgent {
  static final WebSocketService _webSocketService = WebSocketService();
  static const String defaultHost = '127.0.0.1';
  static const int defaultPort = 29277;

  static get url => _webSocketService.url;
  static get isConnected => _webSocketService.isConnected;
  static AriConnectionNotifier get connectionNotifier =>
      _webSocketService.connectionNotifier;
  static Stream<bool> get connectionStream =>
      _webSocketService.connectionStream;

  static void init({
    String? url,
    String host = defaultHost,
    int port = defaultPort,
  }) {
    final resolvedUrl = url ?? 'ws://$host:$port';
    _webSocketService.setFallbackUrlResolver(_resolveFallbackUrl);
    _webSocketService.initialize(resolvedUrl);
  }

  static void connect() {
    _webSocketService.connect();
  }

  static void close() {
    _webSocketService.close();
  }

  static void setAutomaticallyClose(bool value) {
    _webSocketService.automaticallyClose = value;
  }

  static Future<void> emit(String cmd, Map<String, dynamic> param) async {
    await _webSocketService.emit(cmd, param);
  }

  /// Registers the application with the given appId.
  static Future<void> register(String appId) async {
    await emit('/APP.REGISTER', {'appId': appId});
  }

  /// Reports an event or message to the agent.
  /// The agent will typically analyze this and respond to the user.
  static Future<Map<String, dynamic>> report({
    required String appId,
    required String message,
    String type = 'info',
    Map<String, dynamic>? details,
    String? agentId,
  }) async {
    final requestId = 'report-${DateTime.now().millisecondsSinceEpoch}';

    return await call('/AGENT', {
      'source': 'app',
      'appId': appId,
      'message': message,
      'type': type,
      'details': details,
      'requestId': requestId,
      'agentId': agentId,
    });
  }

  /// Sends a response to a previously received command.
  static Future<void> sendResponse({
    required String requestId,
    required dynamic result,
  }) async {
    await emit('/APP.COMMAND_RESPONSE', {
      'requestId': requestId,
      'result': result,
    });
  }

  static Future<Map<String, dynamic>> call(
    String uri, [
    Map<String, dynamic>? param,
    Duration idleTimeout = const Duration(seconds: 60),
  ]) async {
    final completer = Completer<Map<String, dynamic>>();
    final requestId = param?['requestId']?.toString();

    Timer? timer;
    StreamSubscription? progressSub;

    // 타임아웃 타이머를 초기화하거나 갱신하는 내부 함수 (Activity Watchdog)
    void resetTimer() {
      timer?.cancel();
      timer = Timer(idleTimeout, () {
        if (!completer.isCompleted) {
          progressSub?.cancel();
          completer.completeError(
            Exception('[AriAgent] Inactivity timeout: $uri ($requestId)'),
          );
        }
      });
    }

    resetTimer(); // 첫 실행 시 타이머 시작

    // 만약 requestId가 전달되었다면, 해당 요청에 대한 PROGRESS가 올 때마다 타이머 갱신
    if (requestId != null) {
      progressSub = on('/AGENT.PROGRESS', (data) {
        final payload = data['data'] ?? data;
        if (payload['requestId']?.toString() == requestId) {
          _logDebug(
            '[AriAgent] Refreshing timeout for $requestId due to activity signal.',
          );
          resetTimer();
        }
      });
    }

    _webSocketService.send(uri, param ?? {}, (res) {
      progressSub?.cancel();
      timer?.cancel();
      if (completer.isCompleted) return;

      if (res.r) {
        completer.complete(res.d as Map<String, dynamic>);
      } else {
        completer.completeError(Exception(res.m));
      }
    });

    return await completer.future;
  }

  static StreamSubscription<Map<String, dynamic>> on(
    String cmd,
    void Function(Map<String, dynamic>) callback,
  ) {
    return WebSocketService.on(cmd).listen(callback);
  }

  static void offAll(String cmd) => WebSocketService.offAll(cmd);

  static Future<String?> _resolveFallbackUrl(String currentUrl) async {
    final settings = await loadAriAgentSettings();
    if (settings == null) return null;

    final configuredUrl = settings['URL'];
    if (configuredUrl is String && configuredUrl.isNotEmpty) {
      return configuredUrl == currentUrl ? null : configuredUrl;
    }

    final configuredHost =
        (settings['HOST'] as String?)?.trim().isNotEmpty == true
            ? (settings['HOST'] as String).trim()
            : defaultHost;
    final configuredPort = _parsePort(settings['PORT']);
    if (configuredPort == null) return null;

    final fallbackUrl = 'ws://$configuredHost:$configuredPort';
    return fallbackUrl == currentUrl ? null : fallbackUrl;
  }

  static int? _parsePort(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }
}
