import 'package:flutter/foundation.dart';
import 'package:ari_plugin/ari_plugin.dart';
import '../repositories/config_repository.dart';

/// ConfigProvider: 애플리케이션 설정을 관리하고 서버 설정을 중계합니다.
class ConfigProvider extends ChangeNotifier {
  static final ConfigProvider _instance = ConfigProvider._internal();
  factory ConfigProvider() => _instance;
  ConfigProvider._internal();

  final ConfigRepository _repository = ConfigRepository();

  int get port => _repository.port;
  String get baseUrl => _repository.baseUrl;
  String get wsUrl => _repository.wsUrl;
  bool get isPinned => _repository.getIsPinned();
  String get avatarSize => _repository.getAvatarSize();
  bool get isChatCollapsed => _repository.getIsChatCollapsed();
  bool get isNotificationEnabled => _repository.getIsNotificationEnabled();
  bool get showTaskMessages => _repository.getShowTaskMessages();
  String get backgroundTheme => _repository.getBackgroundTheme();

  bool _hasApiKey = true;
  bool get hasApiKey => _hasApiKey;

  String? _mode;
  String? get mode => _mode;
  bool get isDevelopment => _mode == 'development';

  Future<void> init() async {
    await _repository.init();

    // 서버 환경 상태 수신
    AriAgent.on('/GREETING', (data) {
      _mode = data['mode'];
      debugPrint('[SERVER] Running in ${data['mode']} mode');
      notifyListeners();
    });

    // 서버 로그 수신 시 디버그 콘솔에 출력
    AriAgent.on('/SERVER.LOG', (data) {
      debugPrint(
        '[SERVER-LOG] [${data['level']}] [${data['label']}] ${data['message']}',
      );
    });

    notifyListeners();
  }

  /// 포트 변경 (서버 재부팅 필요할 수 있음)
  Future<void> setPort(int newPort) async {
    await _repository.savePort(newPort);
    notifyListeners();
  }

  /// 항상 위 설정
  Future<void> updateIsPinned(bool value) async {
    await _repository.updateIsPinned(value);
    notifyListeners();
  }

  /// 아바타 크기 설정
  Future<void> updateAvatarSize(String size) async {
    await _repository.updateAvatarSize(size);
    notifyListeners();
  }

  /// 채팅 헤더 접힘 상태 설정
  Future<void> updateIsChatCollapsed(bool value) async {
    await _repository.updateIsChatCollapsed(value);
    notifyListeners();
  }

  Future<void> updateIsNotificationEnabled(bool value) async {
    await _repository.updateIsNotificationEnabled(value);
    notifyListeners();
  }

  Future<void> updateShowTaskMessages(bool value) async {
    await _repository.updateShowTaskMessages(value);
    try {
      await AriAgent.call('/SETTINGS', {'showTaskMessages': value});
    } catch (e) {
      debugPrint('[ConfigProvider] updateShowTaskMessages failed: $e');
    }
    notifyListeners();
  }

  /// 배경 테마 설정
  Future<void> updateBackgroundTheme(String theme) async {
    await _repository.updateBackgroundTheme(theme);
    notifyListeners();
  }

  // --- 서버 통신 (AriAgent 호출) ---

  /// 서버 상태 확인
  Future<Map<String, dynamic>?> getServerHealth() async {
    try {
      final health = await AriAgent.call('/HEALTH');
      if (health.containsKey('hasApiKey')) {
        final newHasApiKey = health['hasApiKey'] == true;
        if (_hasApiKey != newHasApiKey) {
          _hasApiKey = newHasApiKey;
          notifyListeners();
        }
      }
      return health;
    } catch (e) {
      debugPrint('[ConfigProvider] getServerHealth failed: $e');
      return null;
    }
  }

  Future<bool> saveApiKey(String? apiKey) async {
    if (apiKey == null) return false;
    try {
      await AriAgent.call('/SETTINGS', {'apiKey': apiKey});
      _hasApiKey = true;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[ConfigProvider] saveApiKey failed: $e');
      return false;
    }
  }

  Future<bool> saveProviders(List<Map<String, dynamic>> providers) async {
    try {
      await AriAgent.call('/SETTINGS', {'providers': providers});
      bool anyKey = providers.any(
        (p) => p['apiKey'] != null && p['apiKey'].toString().trim().isNotEmpty,
      );
      _hasApiKey = anyKey || providers.isNotEmpty;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[ConfigProvider] saveProviders failed: $e');
      return false;
    }
  }

  Future<bool> saveModel(String model) async {
    try {
      await AriAgent.call('/SETTINGS', {'model': model});
      return true;
    } catch (e) {
      debugPrint('[ConfigProvider] saveModel failed: $e');
      return false;
    }
  }

  Future<bool> saveProvider(String provider) async {
    try {
      await AriAgent.call('/SETTINGS', {'provider': provider});
      return true;
    } catch (e) {
      debugPrint('[ConfigProvider] saveProvider failed: $e');
      return false;
    }
  }

  Future<bool> savePortToServer(int port) async {
    try {
      await AriAgent.call('/SETTINGS', {'port': port});
      return true;
    } catch (e) {
      debugPrint('[ConfigProvider] savePortToServer failed: $e');
      return false;
    }
  }

  // ─── OAuth 관련 ─────────────────────────────────────────────

  /// 지원되는 OAuth 프로바이더 목록 + 로그인 상태 조회
  Future<List<Map<String, dynamic>>?> getOAuthProviders() async {
    try {
      final result = await AriAgent.call('/OAUTH_PROVIDERS');
      final providers = result['providers'];
      if (providers is List) {
        return providers.cast<Map<String, dynamic>>();
      }
      return null;
    } catch (e) {
      debugPrint('[ConfigProvider] getOAuthProviders failed: $e');
      return null;
    }
  }

  /// OAuth 로그인 시작 (진행 상황은 /OAUTH_EVENT push로 수신)
  Future<bool> startOAuthLogin(String provider) async {
    try {
      await AriAgent.call('/OAUTH_LOGIN', {'provider': provider});
      return true;
    } catch (e) {
      debugPrint('[ConfigProvider] startOAuthLogin failed: $e');
      return false;
    }
  }

  /// OAuth prompt에 사용자 입력값 전달 (코드 입력 등)
  Future<bool> sendOAuthPrompt(String provider, String value) async {
    try {
      await AriAgent.call('/OAUTH_PROMPT', {
        'provider': provider,
        'value': value,
      });
      return true;
    } catch (e) {
      debugPrint('[ConfigProvider] sendOAuthPrompt failed: $e');
      return false;
    }
  }

  /// OAuth 로그인 상태 조회
  Future<Map<String, dynamic>?> getOAuthStatus(String provider) async {
    try {
      return await AriAgent.call('/OAUTH_STATUS', {'provider': provider});
    } catch (e) {
      debugPrint('[ConfigProvider] getOAuthStatus failed: $e');
      return null;
    }
  }

  /// OAuth 로그아웃
  Future<bool> logoutOAuth(String provider) async {
    try {
      await AriAgent.call('/OAUTH_LOGOUT', {'provider': provider});
      return true;
    } catch (e) {
      debugPrint('[ConfigProvider] logoutOAuth failed: $e');
      return false;
    }
  }
}
