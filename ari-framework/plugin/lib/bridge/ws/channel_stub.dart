import 'package:web_socket_channel/web_socket_channel.dart';

WebSocketChannel connectWebSocket(String url) {
  throw UnsupportedError('WebSocket is not supported on this platform: $url');
}
