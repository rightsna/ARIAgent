import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/status.dart' as status;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../model/Response.dart';
import 'channel_stub.dart'
    if (dart.library.io) 'channel_io.dart'
    if (dart.library.html) 'channel_html.dart';

class _CommandEventBus {
  final Map<String, StreamController<Map<String, dynamic>>> _controllers = {};

  Stream<Map<String, dynamic>> on(String key) {
    _controllers[key] ??= StreamController<Map<String, dynamic>>.broadcast();
    return _controllers[key]!.stream;
  }

  void emit(String key, Map<String, dynamic> data) {
    if (_controllers.containsKey(key)) {
      _controllers[key]!.add(data);
    }
  }

  void offAll(String key) {
    _controllers[key]?.close();
    _controllers.remove(key);
  }
}

class AriConnectionNotifier {
  AriConnectionNotifier(this._value);

  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  final Set<void Function()> _listeners = <void Function()>{};
  bool _value;

  bool get value => _value;
  Stream<bool> get stream => _controller.stream;

  void update(bool value) {
    if (_value == value) return;
    _value = value;
    _controller.add(value);
    for (final listener in List<void Function()>.from(_listeners)) {
      listener();
    }
  }

  void addListener(void Function() listener) {
    _listeners.add(listener);
  }

  void removeListener(void Function() listener) {
    _listeners.remove(listener);
  }

  Future<void> close() async {
    _listeners.clear();
    await _controller.close();
  }
}

void _logDebug(Object message) {
  print(message);
}

void _logDebugStack(Object error, StackTrace stackTrace) {
  print(error);
  print(stackTrace);
}

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();

  factory WebSocketService() => _instance;

  WebSocketService._internal();

  Timer? _pauseTimer;
  Timer? _reconnectTimer;
  bool _isManuallyClosed = false;
  int _reconnectAttempt = 0;
  final AriConnectionNotifier connectionNotifier = AriConnectionNotifier(false);
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  Future<void>? _connecting;
  bool automaticallyClose = true;
  Future<String?> Function(String currentUrl)? _fallbackUrlResolver;
  bool _isRecoveringConnection = false;

  WebSocketChannel? _channel;

  bool get isConnected => connectionNotifier.value;
  Stream<bool> get connectionStream => _connectionController.stream;

  String _url = '';
  String get url => _url;

  static const Duration _initialReconnectDelay = Duration(seconds: 3);
  static const Duration _maxReconnectDelay = Duration(seconds: 30);

  void setFallbackUrlResolver(
      Future<String?> Function(String currentUrl)? resolver) {
    _fallbackUrlResolver = resolver;
  }

  void _setConnected(bool value) {
    if (connectionNotifier.value != value) {
      connectionNotifier.update(value);
      _connectionController.add(value);
    }
  }

  void _resetReconnectState() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempt = 0;
  }

  Duration _nextReconnectDelay() {
    final seconds = _initialReconnectDelay.inSeconds * (1 << _reconnectAttempt);
    final cappedSeconds = seconds > _maxReconnectDelay.inSeconds
        ? _maxReconnectDelay.inSeconds
        : seconds;
    return Duration(seconds: cappedSeconds);
  }

  Future<void> connect({String url = ''}) async {
    if (isConnected) return;
    if (_connecting != null) {
      await _connecting;
      return;
    }
    if (url.isNotEmpty) _url = url;
    if (_url.isEmpty) return;

    _connecting = _connectInternal();
    try {
      await _connecting;
    } finally {
      _connecting = null;
    }
  }

  Future<void> _connectInternal() async {
    _logDebug('\n>>>>> WebSocketService connect(): $_url \n');
    try {
      _channel?.sink.close(status.normalClosure);
      _channel = connectWebSocket(_url);

      _channel!.stream.listen(
        (message) {
          _logDebug('[WSS] receive(): $message');
          receive(message);
        },
        onDone: () {
          _logDebug('[WSS] disconnected');
          _setConnected(false);
          _channel = null;
          if (!_isManuallyClosed) _recoverConnection();
        },
        onError: (error) {
          _logDebug('[WSS] error: $error');
          _setConnected(false);
          _channel = null;
          _recoverConnection();
        },
      );

      await _channel!.ready;
      _setConnected(true);
      _isManuallyClosed = false;
      _resetReconnectState();
      _logDebug('[WSS] connected');
    } catch (e) {
      _logDebug('[WSS] connect failed: $e');
      _setConnected(false);
      _channel = null;
      _recoverConnection();
    }
  }

  void _recoverConnection() {
    if (_isManuallyClosed || _isRecoveringConnection) return;

    _isRecoveringConnection = true;
    Future<void>(() async {
      try {
        final nextUrl = await _fallbackUrlResolver?.call(_url);
        if (nextUrl != null && nextUrl.isNotEmpty && nextUrl != _url) {
          _logDebug('[WSS] Switching WebSocket url to fallback: $nextUrl');
          _url = nextUrl;
        }
      } catch (e) {
        _logDebug('[WSS] fallback resolution failed: $e');
      } finally {
        _isRecoveringConnection = false;
      }

      _reconnect();
    });
  }

  void _reconnect() {
    if (_reconnectTimer?.isActive ?? false) return;

    final delay = _nextReconnectDelay();
    _logDebug(
      'Scheduling WebSocket reconnect in ${delay.inSeconds}s '
      '(attempt ${_reconnectAttempt + 1})...',
    );
    _reconnectTimer = Timer(delay, () {
      _reconnectTimer = null;
      if (!isConnected && !_isManuallyClosed) {
        _logDebug('Retrying WebSocket connection...');
        _reconnectAttempt++;
        connect();
      }
    });
  }

  Future<void> initialize(String url) async {
    _url = url;
  }

  Future<void> destroy() async {
    _reconnectTimer?.cancel();
    _pauseTimer?.cancel();
    close();
    await connectionNotifier.close();
    await _connectionController.close();
  }

  void close() {
    _isManuallyClosed = true;
    _resetReconnectState();
    _setConnected(false);
    _channel?.sink.close(status.normalClosure);
  }

  Future<void> emit(String cmd, Map<String, dynamic> param) async {
    if (_channel == null || !isConnected) {
      await connect();
    }

    if (_channel != null && isConnected) {
      final data = '$cmd ${jsonEncode(param)}';
      _channel!.sink.add(data);
      _logDebug('emit(): $data');
    } else {
      _logDebug('Failed to emit: $cmd');
    }
  }

  Future<void> send(
    String cmd,
    Map<String, dynamic> param,
    void Function(Response) callback,
  ) async {
    if (_channel == null || !isConnected) {
      await connect();
      if (!isConnected) return;
    }

    final expectedRequestId = param['requestId']?.toString();
    late StreamSubscription<Map<String, dynamic>> subscription;
    subscription = on(cmd).listen((data) {
      final payload = data['data'] is Map<String, dynamic>
          ? data['data'] as Map<String, dynamic>
          : null;
      final responseRequestId =
          payload?['requestId']?.toString() ?? data['requestId']?.toString();

      if (expectedRequestId != null &&
          expectedRequestId.isNotEmpty &&
          responseRequestId != expectedRequestId) {
        return;
      }

      final response = Response.fromJson(data);
      callback(response);
      subscription.cancel();
    });

    final data = '$cmd ${jsonEncode(param)}';
    _channel!.sink.add(data);
    _logDebug('send(): $data');
  }

  void receive(String message) {
    if (!message.startsWith('/')) return;
    try {
      final cmdIndex = message.indexOf(' ');
      if (cmdIndex == -1) {
        _eventBus.emit(message, {});
        return;
      }

      final cmd = message.substring(0, cmdIndex);
      final data = message.substring(cmdIndex).trim();
      final map = jsonDecode(data) as Map<String, dynamic>;
      _eventBus.emit(cmd, map);
    } catch (e, stack) {
      _logDebugStack('receive error = $e', stack);
    }
  }

  static final _CommandEventBus _eventBus = _CommandEventBus();

  static Stream<Map<String, dynamic>> on(String cmd) => _eventBus.on(cmd);

  static void offAll(String cmd) => _eventBus.offAll(cmd);
}
