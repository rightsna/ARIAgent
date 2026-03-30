import 'dart:async';

import 'package:flutter/foundation.dart';

import 'WebSocketService.dart';
import 'settings_loader_stub.dart'
    if (dart.library.io) 'settings_loader_io.dart';

class AriAgent {
  static final WebSocketService _webSocketService = WebSocketService();
  static const String defaultHost = '127.0.0.1';
  static const int defaultPort = 29277;

  static get url => _webSocketService.url;
  static get isConnected => _webSocketService.isConnected;
  static ValueNotifier<bool> get connectionNotifier =>
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
  static Future<void> report({
    required String appId,
    required String message,
    String type = 'info',
    Map<String, dynamic>? details,
  }) async {
    await emit('/APP.REPORT', {
      'appId': appId,
      'message': message,
      'type': type,
      if (details != null) 'details': details,
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
  ]) async {
    final completer = Completer<Map<String, dynamic>>();

    _webSocketService.send(uri, param ?? {}, (res) {
      if (res.r) {
        completer.complete(res.d as Map<String, dynamic>);
      } else {
        completer.completeError(Exception(res.m));
      }
    });

    return await completer.future.timeout(
      const Duration(seconds: 120),
      onTimeout: () => throw Exception('Request timeout: $uri'),
    );
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
