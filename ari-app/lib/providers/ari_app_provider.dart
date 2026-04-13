import 'package:flutter/foundation.dart';
import 'package:ari_plugin/ari_plugin.dart';
import '../repositories/app_repository.dart';

class AriAppProvider extends ChangeNotifier {
  static final AriAppProvider _instance = AriAppProvider._internal();
  factory AriAppProvider() => _instance;
  AriAppProvider._internal();

  final AppRepository _repository = AppRepository();

  List<String> _connectedAppIds = [];
  List<String> get connectedAppIds => _connectedAppIds;

  int _installedAppsVersion = 0;
  int get installedAppsVersion => _installedAppsVersion;

  Future<void> init() async {
    // 실시간 연결된 앱 목록 수신
    AriAgent.on('/CONNECTED_APPS_CHANGED', (data) {
      final ids = data['connectedIds'];
      if (ids is List) {
        _connectedAppIds = ids.cast<String>();
        debugPrint('[AriAppProvider] Connected Apps Changed: $_connectedAppIds');
        notifyListeners();
      }
    });

    // 앱 설치/삭제 후 목록 갱신 수신
    AriAgent.on('/INSTALLED_APPS_CHANGED', (data) {
      debugPrint('[AriAppProvider] Installed Apps Changed: $data');
      _installedAppsVersion++;
      notifyListeners();
    });
  }

  /// 설치된 앱 목록 조회 (로컬 저장소 탐색)
  Future<List<Map<String, dynamic>>> getInstalledApps() async {
    return await _repository.getInstalledApps();
  }

  /// 서버에 연결된 앱 목록 조회
  Future<List<String>> getConnectedApps() async {
    try {
      final res = await AriAgent.call('/GET_CONNECTED_APPS');
      final connectedIds = res['connectedIds'];
      if (connectedIds is List) {
        _connectedAppIds = connectedIds.cast<String>();
        notifyListeners();
        return _connectedAppIds;
      }
      return [];
    } catch (e) {
      debugPrint('[AriAppProvider] getConnectedApps failed: $e');
      return [];
    }
  }

  /// 앱 실행
  Future<bool> launchApp(String appId) async {
    try {
      await AriAgent.call('/LAUNCH_APP', {'appId': appId});
      return true;
    } catch (e) {
      debugPrint('[AriAppProvider] launchApp failed: $e');
      return false;
    }
  }

  /// 스킬 삭제
  Future<bool> deleteSkill(String name) async {
    try {
      await AriAgent.call('/DELETE_SKILL', {'name': name});
      return true;
    } catch (e) {
      debugPrint('[AriAppProvider] deleteSkill failed: $e');
      return false;
    }
  }

  /// 앱 삭제
  Future<bool> deleteApp(String name) async {
    try {
      await AriAgent.call('/DELETE_APP', {'name': name});
      return true;
    } catch (e) {
      debugPrint('[AriAppProvider] deleteApp failed: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getSkills() async {
    try {
      final res = await AriAgent.call('/PLUGINS.SKILLS');
      return (res['skills'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();
    } catch (e) {
      debugPrint('[AriAppProvider] getSkills failed: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getApps() async {
    try {
      final res = await AriAgent.call('/PLUGINS.APPS');
      return (res['apps'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();
    } catch (e) {
      debugPrint('[AriAppProvider] getApps failed: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getTools() async {
    try {
      final res = await AriAgent.call('/PLUGINS.TOOLS');
      return (res['tools'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();
    } catch (e) {
      debugPrint('[AriAppProvider] getTools failed: $e');
      return [];
    }
  }
}
