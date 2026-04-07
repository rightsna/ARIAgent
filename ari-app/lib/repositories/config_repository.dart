import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// ConfigRepository: Hive(상태) 및 settings.json(시스템 설정) 데이터를 통합 관리하는 레포지토리.
class ConfigRepository {
  static final ConfigRepository _instance = ConfigRepository._internal();
  factory ConfigRepository() => _instance;
  ConfigRepository._internal();

  int _port = 29277;
  bool _isPinned = true;
  bool _isChatCollapsed = false;
  bool _isNotificationEnabled = true;
  String _avatarSize = 'medium';
  String _backgroundTheme = 'dark';
  Map<String, dynamic> _fullConfig = {};

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  int get port => _port;
  String get baseUrl => 'http://localhost:$_port';
  String get wsUrl => 'ws://localhost:$_port';

  Future<void> init() async {
    // settings.json 로드
    await _loadSystemConfig();
    _isInitialized = true;
  }

  // --- 시스템 설정 (settings.json) ---

  File get _configFile {
    final String home =
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    return File(p.join(home, '.ari-agent', 'settings.json'));
  }

  Future<void> _loadSystemConfig() async {
    final file = _configFile;
    if (await file.exists()) {
      try {
        final content = await file.readAsString();
        _fullConfig = jsonDecode(content);

        if (_fullConfig['PORT'] != null) {
          _port = int.tryParse(_fullConfig['PORT'].toString()) ?? 29277;
        }
        if (_fullConfig['IS_PINNED'] != null) {
          _isPinned = _fullConfig['IS_PINNED'] == true;
        }
        if (_fullConfig['IS_CHAT_COLLAPSED'] != null) {
          _isChatCollapsed = _fullConfig['IS_CHAT_COLLAPSED'] == true;
        }
        if (_fullConfig['IS_NOTIFICATION_ENABLED'] != null) {
          _isNotificationEnabled =
              _fullConfig['IS_NOTIFICATION_ENABLED'] == true;
        }
        if (_fullConfig['AVATAR_SIZE'] != null) {
          _avatarSize = _fullConfig['AVATAR_SIZE'].toString();
        }
        if (_fullConfig['BACKGROUND_THEME'] != null) {
          _backgroundTheme = _fullConfig['BACKGROUND_THEME'].toString();
        }
      } catch (e) {
        debugPrint('[ConfigRepository] settings.json 로드 에러: $e');
      }
    }
  }

  Future<void> _saveConfig() async {
    final file = _configFile;

    // 다시 한번 파일에서 읽어서 최신 상태 유지 (병합을 위해)
    if (await file.exists()) {
      try {
        final content = await file.readAsString();
        final current = jsonDecode(content);
        if (current is Map<String, dynamic>) {
          _fullConfig.addAll(current);
        }
      } catch (_) {}
    }

    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }

    _fullConfig['PORT'] = _port;
    _fullConfig['IS_PINNED'] = _isPinned;
    _fullConfig['IS_CHAT_COLLAPSED'] = _isChatCollapsed;
    _fullConfig['IS_NOTIFICATION_ENABLED'] = _isNotificationEnabled;
    _fullConfig['AVATAR_SIZE'] = _avatarSize;
    _fullConfig['BACKGROUND_THEME'] = _backgroundTheme;

    await file.writeAsString(jsonEncode(_fullConfig));
  }

  Future<void> savePort(int newPort) async {
    _port = newPort;
    await _saveConfig();
  }

  // --- UI 설정 (이제 settings.json에 저장) ---

  bool getIsPinned() {
    return _isPinned;
  }

  Future<void> updateIsPinned(bool value) async {
    _isPinned = value;
    await _saveConfig();
  }

  String getAvatarSize() {
    return _avatarSize;
  }

  Future<void> updateAvatarSize(String size) async {
    _avatarSize = size;
    await _saveConfig();
  }

  bool getIsChatCollapsed() {
    return _isChatCollapsed;
  }

  Future<void> updateIsChatCollapsed(bool value) async {
    _isChatCollapsed = value;
    await _saveConfig();
  }

  bool getIsNotificationEnabled() {
    return _isNotificationEnabled;
  }

  Future<void> updateIsNotificationEnabled(bool value) async {
    _isNotificationEnabled = value;
    await _saveConfig();
  }

  String getBackgroundTheme() {
    return _backgroundTheme;
  }

  Future<void> updateBackgroundTheme(String theme) async {
    _backgroundTheme = theme;
    await _saveConfig();
  }
}
