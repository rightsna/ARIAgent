import 'package:ari_plugin/ari_plugin.dart';

class ProtocolConfig {
  static const String appId = 'sample_basic';

  /// Descriptions of commands this app supports
  static Map<String, String> get availableCommands => {
        'PING': 'Returns app availability and status',
      };

  /// Current state of the app to be sent to the agent
  static Map<String, dynamic> getAppState() {
    return {
      'connected': WsManager.isConnected,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Create a protocol handler with callbacks
  static AppProtocolHandler createHandler() {
    return AppProtocolHandler(
      appId: appId,
      onCommand: (command, params) => handleCommand(
        command: command,
        params: params,
      ),
      onGetState: getAppState,
      onGetCommands: () => availableCommands,
    );
  }

  /// Core logic for handling incoming commands
  static dynamic handleCommand({
    required String command,
    required Map<String, dynamic> params,
  }) {
    // Basic command handling
    switch (command) {
      case 'PING':
        return {'status': 'pong', 'timestamp': DateTime.now().toIso8601String()};
      default:
        return {
          'status': 'ok',
          'appId': appId,
          'handled': true,
        };
    }
  }
}
