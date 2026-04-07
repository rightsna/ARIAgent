import 'package:flutter/foundation.dart';
import 'package:ari_plugin/ari_plugin.dart';

class HomeAssistantProvider extends ChangeNotifier {
  static final HomeAssistantProvider _instance = HomeAssistantProvider._internal();
  factory HomeAssistantProvider() => _instance;
  HomeAssistantProvider._internal();

  /// Home Assistant 자격증명 조회
  Future<Map<String, dynamic>?> getHACredentials() async {
    try {
      final res = await AriAgent.call('/GET_HA_CREDENTIALS');
      return res;
    } catch (e) {
      debugPrint('[HomeAssistantProvider] getHACredentials failed: $e');
      return null;
    }
  }

  /// Home Assistant 기기 목록 조회
  Future<List<Map<String, dynamic>>?> getHADevices() async {
    try {
      final res = await AriAgent.call('/GET_HA_DEVICES');
      final devices = res['devices'];
      if (devices is List) {
        return devices.map((item) => Map<String, dynamic>.from(item)).toList();
      }
      return null;
    } catch (e) {
      debugPrint('[HomeAssistantProvider] getHADevices failed: $e');
      return null;
    }
  }

  /// Home Assistant 자격증명 저장
  Future<Map<String, dynamic>> saveHACredentials(
    String url,
    String token,
  ) async {
    try {
      final res = await AriAgent.call('/SET_HA_CREDENTIALS', {
        'url': url,
        'token': token,
      });
      return {'ok': true, 'data': res};
    } catch (e) {
      debugPrint('[HomeAssistantProvider] saveHACredentials failed: $e');
      return {'ok': false, 'error': e.toString()};
    }
  }

  /// Home Assistant 기기 제어
  Future<bool> controlHADevice(
    String entityId,
    String service, {
    String? domain,
  }) async {
    try {
      final res = await AriAgent.call('/CONTROL_HA_DEVICE', {
        'entity_id': entityId,
        'service': service,
        if (domain != null) 'domain': domain,
      });
      return res['success'] == true;
    } catch (e) {
      debugPrint('[HomeAssistantProvider] controlHADevice failed: $e');
      return false;
    }
  }
}
