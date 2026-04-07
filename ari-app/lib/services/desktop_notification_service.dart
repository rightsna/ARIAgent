import 'dart:async';
import 'dart:io';

import 'package:ari_plugin/ari_plugin.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../repositories/config_repository.dart';

class DesktopNotificationService {
  DesktopNotificationService._();

  static final DesktopNotificationService instance =
      DesktopNotificationService._();

  static const MethodChannel _channel = MethodChannel(
    'ari_agent/desktop_notification',
  );

  final Set<String> _notifiedRequestIds = <String>{};
  StreamSubscription<Map<String, dynamic>>? _pushSub;
  bool _permissionRequested = false;
  bool _permissionGranted = false;

  bool get _isSupportedDesktop =>
      !kIsWeb && (Platform.isMacOS || Platform.isWindows);

  bool get _isNotificationEnabled =>
      ConfigRepository().getIsNotificationEnabled();

  Future<void> init() async {
    if (!_isSupportedDesktop || _pushSub != null) {
      return;
    }

    if (Platform.isMacOS && _isNotificationEnabled) {
      unawaited(_ensurePermission());
    }

    _pushSub = AriAgent.on('/APP.PUSH', (data) {
      unawaited(_handlePush(data));
    });
  }

  Future<void> dispose() async {
    await _pushSub?.cancel();
    _pushSub = null;
  }

  Future<void> _handlePush(Map<String, dynamic> data) async {
    if (!_isNotificationEnabled) {
      return;
    }

    final payload = data['data'] is Map
        ? Map<String, dynamic>.from(data['data'] as Map)
        : Map<String, dynamic>.from(data);
    final response = payload['response']?.toString().trim() ?? '';
    final requestId = payload['requestId']?.toString() ?? '';

    if (response.isEmpty) {
      return;
    }

    if (requestId.isNotEmpty && !_notifiedRequestIds.add(requestId)) {
      return;
    }

    final isVisible = await windowManager.isVisible();
    if (isVisible) {
      return;
    }

    final title =
        requestId.startsWith('report-') || requestId.startsWith('sys-')
        ? 'ARI 백그라운드 응답'
        : 'ARI 새 메시지';

    await show(title: title, body: _normalizeBody(response));
  }

  Future<void> show({required String title, required String body}) async {
    if (!_isSupportedDesktop ||
        !_isNotificationEnabled ||
        body.trim().isEmpty) {
      return;
    }

    if (Platform.isMacOS) {
      final granted = await _ensurePermission();
      if (!granted) {
        return;
      }
    }

    try {
      await _channel.invokeMethod<bool>('showNotification', <String, dynamic>{
        'title': title,
        'body': body,
      });
    } catch (e) {
      debugPrint('[DesktopNotificationService] 알림 표시 실패: $e');
    }
  }

  Future<bool> _ensurePermission() async {
    if (!Platform.isMacOS) {
      return true;
    }

    if (_permissionRequested) {
      return _permissionGranted;
    }

    _permissionRequested = true;

    try {
      _permissionGranted =
          await _channel.invokeMethod<bool>('requestPermission') ?? false;
      if (!_permissionGranted) {
        debugPrint('[DesktopNotificationService] macOS 알림 권한이 거부되었습니다.');
      }
      return _permissionGranted;
    } catch (e) {
      debugPrint('[DesktopNotificationService] macOS 알림 권한 요청 실패: $e');
      return false;
    }
  }

  String _normalizeBody(String text) {
    final collapsed = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (collapsed.length <= 180) {
      return collapsed;
    }
    return '${collapsed.substring(0, 177)}...';
  }
}
