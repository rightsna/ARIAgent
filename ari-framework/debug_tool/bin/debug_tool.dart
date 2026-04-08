/// ARI WebSocket Debug Tool
///
/// ARI 서버에 클라이언트로 연결하여 앱 명령을 테스트합니다.
/// AI 에이전트 없이 /APP.CALL 라우트를 통해 직접 앱 명령을 실행합니다.
///
/// 사용법:
///   dart run bin/debug_tool.dart -cmd GET_MARKET_DATA -params '{"symbol":"KRW-BTC","timeframe":"1h","limit":10}'
import 'dart:async';
import 'dart:convert';
import 'dart:io';

// ──────────────────────────────────────────────────────────────────────────────
// Entry point
// ──────────────────────────────────────────────────────────────────────────────

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    _printUsage();
    exit(0);
  }

  final config = _parseArgs(args);
  if (config == null) exit(1);

  final exitCode = await _runDebugSession(config);
  exit(exitCode);
}

// ──────────────────────────────────────────────────────────────────────────────
// Config
// ──────────────────────────────────────────────────────────────────────────────

class _Config {
  final String ip;
  final int port;
  final String appId;
  final String cmd;
  final Map<String, dynamic> params;
  final int timeoutSeconds;
  final bool verbose;

  const _Config({
    required this.ip,
    required this.port,
    required this.appId,
    required this.cmd,
    required this.params,
    required this.timeoutSeconds,
    required this.verbose,
  });

  String get wsUrl => 'ws://$ip:$port';
}

_Config? _parseArgs(List<String> args) {
  final ip = _getArg(args, '-ip') ?? '127.0.0.1';
  final portStr = _getArg(args, '-port') ?? '29277';
  final appId = _getArg(args, '-app') ?? 'bitnari';
  final cmd = _getArg(args, '-cmd');
  final paramsStr = _getArg(args, '-params') ?? '{}';
  final timeoutStr = _getArg(args, '-timeout') ?? '60';
  final verbose = args.contains('-v') || args.contains('--verbose');

  if (cmd == null || cmd.isEmpty) {
    _printError('Missing required argument: -cmd');
    _printUsage();
    return null;
  }

  final port = int.tryParse(portStr);
  if (port == null) {
    _printError('Invalid port: $portStr');
    return null;
  }

  Map<String, dynamic> params;
  try {
    params = jsonDecode(paramsStr) as Map<String, dynamic>;
  } catch (e) {
    _printError('Invalid JSON in -params: $paramsStr');
    return null;
  }

  return _Config(
    ip: ip,
    port: port,
    appId: appId,
    cmd: cmd,
    params: params,
    timeoutSeconds: int.tryParse(timeoutStr) ?? 60,
    verbose: verbose,
  );
}

// ──────────────────────────────────────────────────────────────────────────────
// Debug session
// ──────────────────────────────────────────────────────────────────────────────

Future<int> _runDebugSession(_Config cfg) async {
  _printHeader();
  print('  Server : ${cfg.wsUrl}');
  print('  App    : ${cfg.appId}');
  print('  Command: ${cfg.cmd}');
  print('  Params : ${_prettyJson(cfg.params)}');
  _printDivider();
  print('Connecting to ARI server...');

  WebSocket ws;
  try {
    ws = await WebSocket.connect(cfg.wsUrl).timeout(const Duration(seconds: 10));
  } catch (e) {
    _printError('Cannot connect to ${cfg.wsUrl} → $e');
    return 1;
  }

  print('[CONNECTED] ${cfg.wsUrl}');
  return await _handleSession(ws, cfg);
}

// ──────────────────────────────────────────────────────────────────────────────
// WebSocket session
// ──────────────────────────────────────────────────────────────────────────────

Future<int> _handleSession(WebSocket ws, _Config cfg) async {
  final requestId = 'dbg-${DateTime.now().millisecondsSinceEpoch}';
  final completer = Completer<int>();

  final timeoutTimer = Timer(Duration(seconds: cfg.timeoutSeconds), () {
    if (!completer.isCompleted) {
      _printError('Timeout: no response within ${cfg.timeoutSeconds}s');
      ws.close();
      completer.complete(1);
    }
  });

  ws.listen(
    (raw) {
      if (raw is! String) return;
      if (cfg.verbose) print('[RECV] $raw');

      final parsed = _parseMessage(raw);
      if (parsed == null) return;
      final (msgCmd, msgData) = parsed;

      switch (msgCmd) {
        // 서버 연결 후 /GREETING 수신 → /APP.CALL 전송
        case '/GREETING':
          final ver = msgData['ver'] ?? '';
          final mode = msgData['mode'] ?? '';
          print('[GREETING] server=$ver mode=$mode');
          print('[SEND] /APP.CALL → appId=${cfg.appId} cmd=${cfg.cmd}');

          _sendMsg(ws, '/APP.CALL', {
            'appId': cfg.appId,
            'command': cfg.cmd,
            'params': cfg.params,
            'requestId': requestId,
          }, cfg.verbose);

        // 서버가 앱 실행 결과를 돌려줌
        case '/APP.CALL':
          final resId = msgData['requestId'] as String?;
          if (resId != requestId) {
            if (cfg.verbose) print('[SKIP] requestId mismatch: $resId');
            return;
          }

          timeoutTimer.cancel();
          final ok = msgData['ok'] as bool? ?? false;
          if (!ok) {
            _printError('Error: ${msgData['message']}');
            ws.close();
            if (!completer.isCompleted) completer.complete(1);
            return;
          }

          final exitCode = _printResult(msgData['result']);
          ws.close();
          if (!completer.isCompleted) completer.complete(exitCode);

        default:
          if (cfg.verbose) print('[SKIP] $msgCmd');
      }
    },
    onDone: () {
      timeoutTimer.cancel();
      if (!completer.isCompleted) completer.complete(1);
    },
    onError: (e) {
      _printError('WebSocket error: $e');
      timeoutTimer.cancel();
      if (!completer.isCompleted) completer.complete(1);
    },
  );

  return completer.future;
}

// ──────────────────────────────────────────────────────────────────────────────
// Helpers
// ──────────────────────────────────────────────────────────────────────────────

int _printResult(dynamic result) {
  print('');
  _printDivider();
  print('RESULT');
  _printDivider();
  print(_prettyJson(result));
  _printDivider();

  if (result is Map && result['status'] == 'error') {
    _printError('Command returned error: ${result['message'] ?? ''}');
    return 1;
  }
  return 0;
}

void _sendMsg(WebSocket ws, String cmd, Map<String, dynamic> payload, bool verbose) {
  final msg = '$cmd ${jsonEncode(payload)}';
  if (verbose) print('[SEND] $msg');
  ws.add(msg);
}

(String, Map<String, dynamic>)? _parseMessage(String message) {
  if (!message.startsWith('/')) return null;
  final spaceIdx = message.indexOf(' ');
  if (spaceIdx == -1) return (message, {});
  final cmd = message.substring(0, spaceIdx);
  final body = message.substring(spaceIdx).trim();
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return (cmd, decoded);
  } catch (_) {}
  return null;
}

String? _getArg(List<String> args, String flag) {
  final idx = args.indexOf(flag);
  if (idx == -1 || idx + 1 >= args.length) return null;
  return args[idx + 1];
}

String _prettyJson(dynamic value) => const JsonEncoder.withIndent('  ').convert(value);

void _printError(String msg) => print('[ERROR] $msg');

void _printHeader() {
  print('');
  print('┌─────────────────────────────────────────┐');
  print('│      ARI WebSocket Debug Tool  v1.0     │');
  print('└─────────────────────────────────────────┘');
}

void _printDivider() => print('─────────────────────────────────────────');

void _printUsage() {
  print('''
ARI WebSocket Debug Tool

ARI 서버에 클라이언트로 연결 → /APP.CALL 로 앱 명령 실행 → 결과 출력.
(ARI 서버와 Flutter 앱이 먼저 실행 중이어야 합니다)

Usage:
  dart run bin/debug_tool.dart [options]

Options:
  -ip       <address>   ARI 서버 주소 (기본값: 127.0.0.1)
  -port     <port>      ARI 서버 포트 (기본값: 29277)
  -app      <appId>     대상 앱 ID (기본값: bitnari)
  -cmd      <command>   전송할 명령 [필수]
  -params   <json>      명령 파라미터 JSON (기본값: {})
  -timeout  <seconds>   응답 대기 타임아웃 (기본값: 60)
  -v        --verbose   상세 로그 출력
  -h        --help      도움말 출력

Bitnari 예시:
  dart run bin/debug_tool.dart -cmd GET_APP_STATUS
  dart run bin/debug_tool.dart -cmd GET_STRATEGY -params \'{"symbol":"KRW-BTC"}\'
  dart run bin/debug_tool.dart -cmd GET_MARKET_DATA -params \'{"symbol":"KRW-BTC","timeframe":"1h","limit":10}\'
  dart run bin/debug_tool.dart -cmd CALCULATE_INDICATOR -params \'{"symbol":"KRW-BTC","type":"rsi","timeframe":"1h","limit":120}\'
  dart run bin/debug_tool.dart -cmd GET_TRADING_RECORDS -params \'{"symbol":"KRW-BTC","limit":5}\'

ARIStock 예시:
  dart run bin/debug_tool.dart -app aristock -cmd GET_ANALYSIS -params \'{"symbol":"005930"}\'
  dart run bin/debug_tool.dart -app aristock -cmd GET_ACCOUNT_INFO
''');
}
