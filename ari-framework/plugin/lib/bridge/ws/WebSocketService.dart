import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
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

class WebSocketService with WidgetsBindingObserver {
  static final WebSocketService _instance = WebSocketService._internal();

  factory WebSocketService() => _instance;

  WebSocketService._internal();

  Timer? _pauseTimer;
  Timer? _reconnectTimer;
  bool _isManuallyClosed = false;
  int _reconnectAttempt = 0;
  final ValueNotifier<bool> connectionNotifier = ValueNotifier<bool>(false);
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  Future<void>? _connecting;
  bool automaticallyClose = true;
  Future<String?> Function(String currentUrl)? _fallbackUrlResolver;
  bool _isRecoveringConnection = false;

  WebSocketChannel? _channel;
  StreamSubscription<List<ConnectivityResult>>? _networkListener;

  bool get isConnected => connectionNotifier.value;
  Stream<bool> get connectionStream => _connectionController.stream;

  String _url = '';
  String get url => _url;

  static const Duration _initialReconnectDelay = Duration(seconds: 3);
  static const Duration _maxReconnectDelay = Duration(seconds: 30);

  void setFallbackUrlResolver(Future<String?> Function(String currentUrl)? resolver) {
    _fallbackUrlResolver = resolver;
  }

  void _setConnected(bool value) {
    if (connectionNotifier.value != value) {
      connectionNotifier.value = value;
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
    debugPrint('\n>>>>> WebSocketService connect(): $_url \n');
    try {
      _channel?.sink.close(status.normalClosure);
      _channel = connectWebSocket(_url);

      _channel!.stream.listen(
        (message) {
          debugPrint('WebSocketService receive(): $message');
          receive(message);
        },
        onDone: () {
          debugPrint('WebSocket disconnected');
          _setConnected(false);
          _channel = null;
          if (!_isManuallyClosed) _recoverConnection();
        },
        onError: (error) {
          debugPrint('WebSocket error: $error');
          _setConnected(false);
          _channel = null;
          _recoverConnection();
        },
      );

      await _channel!.ready;
      _setConnected(true);
      _isManuallyClosed = false;
      _resetReconnectState();
      debugPrint('WebSocket connected');
    } catch (e) {
      debugPrint('WebSocket connect failed: $e');
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
          debugPrint('Switching WebSocket url to fallback: $nextUrl');
          _url = nextUrl;
        }
      } catch (e) {
        debugPrint('WebSocket fallback resolution failed: $e');
      } finally {
        _isRecoveringConnection = false;
      }

      _reconnect();
    });
  }

  void _reconnect() {
    if (_reconnectTimer?.isActive ?? false) return;

    final delay = _nextReconnectDelay();
    debugPrint(
      'Scheduling WebSocket reconnect in ${delay.inSeconds}s '
      '(attempt ${_reconnectAttempt + 1})...',
    );
    _reconnectTimer = Timer(delay, () {
      _reconnectTimer = null;
      if (!isConnected && !_isManuallyClosed) {
        debugPrint('Retrying WebSocket connection...');
        _reconnectAttempt++;
        connect();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _pauseTimer?.cancel();
      connect();
    } else if (state == AppLifecycleState.paused) {
      _pauseTimer?.cancel();
      _pauseTimer = Timer(const Duration(seconds: 60), () {
        if (automaticallyClose) close();
      });
    }
  }

  Future<void> listenForNetworkChanges() async {
    await _networkListener?.cancel();
    _networkListener = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> result,
    ) {
      if (!result.contains(ConnectivityResult.none) && !_isManuallyClosed) {
        connect();
      }
    });
  }

  Future<void> initialize(String url) async {
    _url = url;
    WidgetsBinding.instance.addObserver(this);
    await listenForNetworkChanges();
  }

  void destroy() {
    WidgetsBinding.instance.removeObserver(this);
    _reconnectTimer?.cancel();
    _connectionController.close();
    close();
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
      debugPrint('emit(): $data');
    } else {
      debugPrint('Failed to emit: $cmd');
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

    late StreamSubscription<Map<String, dynamic>> subscription;
    subscription = on(cmd).listen((data) {
      final response = Response.fromJson(data);
      callback(response);
      subscription.cancel();
    });

    final data = '$cmd ${jsonEncode(param)}';
    _channel!.sink.add(data);
    debugPrint('send(): $data');
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
      debugPrint('receive error = $e');
      debugPrintStack(stackTrace: stack);
    }
  }

  static final _CommandEventBus _eventBus = _CommandEventBus();

  static Stream<Map<String, dynamic>> on(String cmd) => _eventBus.on(cmd);

  static void offAll(String cmd) => _eventBus.offAll(cmd);
}
