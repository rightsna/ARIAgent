import 'package:ari_plugin/ari_plugin.dart';
import 'providers/log_provider.dart';

class ProtocolConfig {
  static const String appId = 'sample_control';

  /// Current state of the app to be sent to the agent
  static Map<String, dynamic> getAppState() {
    return {
      'connected': WsManager.isConnected,
      'timestamp': DateTime.now().toIso8601String(),
      'version': '1.0.0',
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
    );
  }

  /// Core logic for handling incoming commands
  static dynamic handleCommand({
    required String command,
    required Map<String, dynamic> params,
  }) {
    LogProvider().updateReceivedCommand(command, params.toString());
    LogProvider().add('RECEIVE: $command ($params)');

    // Common command handling logic
    switch (command) {
      case 'PING':
        return {'status': 'pong', 'timestamp': DateTime.now().toIso8601String()};
      case 'SYNC':
        // Handle sync logic here
        return {'status': 'sync_started'};
      default:
        return {
          'status': 'ok',
          'appId': appId,
          'handled': true,
        };
    }
  }
}
