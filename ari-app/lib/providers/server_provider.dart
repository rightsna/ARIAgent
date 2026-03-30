import 'package:flutter/foundation.dart';
import '../services/server_service.dart';
import 'package:ari_plugin/ari_plugin.dart';

enum ServerStatus { stopped, starting, running, stopping, error }

/// 로컬 Node.js 에이전트의 상태(UI 연결)를 관리하는 Provider
class ServerProvider extends ChangeNotifier {
  static final ServerProvider _instance = ServerProvider._internal();
  factory ServerProvider() => _instance;
  ServerProvider._internal();

  final ServerService _service = ServerService();
  String? _version;
  String? _mode;

  ServerStatus _status = ServerStatus.stopped;
  final List<String> _logs = [];

  ServerStatus get status => _status;
  List<String> get logs => List.unmodifiable(_logs);
  bool get isRunning => _status == ServerStatus.running;

  Future<bool> start({String? version, String? mode}) async {
    if (version != null) _version = version;
    if (mode != null) _mode = mode;

    if (_status == ServerStatus.running) {
      _addLog('⚠️ 에이전트가 이미 실행 중');
      return true;
    }

    _setStatus(ServerStatus.starting);

    final success = await _service.startServer(
      version: _version,
      mode: _mode,
      onLog: (msg) {
        debugPrint('[ServerProvider] $msg');
        _addLog(msg);
      },
      onErrorLog: (msg) {
        debugPrint('[ServerProvider ERR] $msg');
        _addLog(msg);
      },
      onExit: (code) {
        debugPrint('[ServerProvider] 프로세스 종료 (코드: $code)');
        _addLog('프로세스 종료 (코드: $code)');
        if (_status != ServerStatus.stopping) {
          _setStatus(ServerStatus.stopped);
        }
      },
    );

    if (success) {
      _setStatus(ServerStatus.running);
      AriAgent.connect(); // 서버가 정상적으로 켜졌을 때 웹소켓 연결 시도
    } else {
      _setStatus(ServerStatus.error);
    }

    return success;
  }

  Future<void> stop() async {
    _setStatus(ServerStatus.stopping);
    AriAgent.close(); // 에이전트 종료 시 웹소켓 먼저 닫기
    await _service.stopServer((msg) {
      debugPrint('[ServerProvider] $msg');
      _addLog(msg);
    });
    _setStatus(ServerStatus.stopped);
  }

  Future<bool> restart() async {
    _addLog('🔄 재시작...');
    await stop();
    await Future.delayed(const Duration(milliseconds: 500));
    return start(version: _version, mode: _mode);
  }

  void _setStatus(ServerStatus newStatus) {
    debugPrint('[ServerProvider] $_status → $newStatus');
    _status = newStatus;
    notifyListeners();
  }

  void _addLog(String message) {
    final ts = DateTime.now().toIso8601String().substring(11, 19);
    _logs.add('[$ts] $message');
    if (_logs.length > 100) _logs.removeAt(0);
    notifyListeners();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}
