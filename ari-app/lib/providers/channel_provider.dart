import 'package:flutter/foundation.dart';
import 'package:ari_plugin/ari_plugin.dart';

class TelegramChannelState {
  final bool enabled;
  final String botTokenMasked; // 서버에서 마스킹된 토큰
  final String? agentId;
  final bool isPolling;

  const TelegramChannelState({
    this.enabled = false,
    this.botTokenMasked = '',
    this.agentId,
    this.isPolling = false,
  });

  bool get hasToken => botTokenMasked.isNotEmpty;

  TelegramChannelState copyWith({
    bool? enabled,
    String? botTokenMasked,
    String? agentId,
    bool? isPolling,
  }) {
    return TelegramChannelState(
      enabled: enabled ?? this.enabled,
      botTokenMasked: botTokenMasked ?? this.botTokenMasked,
      agentId: agentId ?? this.agentId,
      isPolling: isPolling ?? this.isPolling,
    );
  }
}

class ChannelProvider extends ChangeNotifier {
  static final ChannelProvider _instance = ChannelProvider._internal();
  factory ChannelProvider() => _instance;
  ChannelProvider._internal();

  TelegramChannelState _telegram = const TelegramChannelState();
  bool _isLoading = false;
  String? _errorMessage;

  TelegramChannelState get telegram => _telegram;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // ─── 조회 ──────────────────────────────────────────────────
  // AriAgent.call: 성공 시 data 필드만 반환, 실패 시 throw

  Future<void> loadTelegram() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await AriAgent.call('/CHANNEL.GET', {'type': 'telegram'});
      _telegram = TelegramChannelState(
        enabled: data['enabled'] == true,
        botTokenMasked: data['botToken'] as String? ?? '',
        agentId: data['agentId'] as String?,
        isPolling: data['isPolling'] == true,
      );
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('[ChannelProvider] loadTelegram failed: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── 저장 ──────────────────────────────────────────────────

  Future<bool> saveTelegram({
    String? botToken,
    String? agentId,
  }) async {
    try {
      await AriAgent.call('/CHANNEL.SAVE', {
        'type': 'telegram',
        if (botToken != null) 'botToken': botToken,
        if (agentId != null) 'agentId': agentId,
      });
      await loadTelegram();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('[ChannelProvider] saveTelegram failed: $e');
      notifyListeners();
      return false;
    }
  }

  // ─── 활성화/비활성화 ────────────────────────────────────────

  Future<bool> toggleTelegram(bool enabled) async {
    try {
      final data = await AriAgent.call('/CHANNEL.TOGGLE', {
        'type': 'telegram',
        'enabled': enabled,
      });
      _telegram = _telegram.copyWith(
        enabled: data['enabled'] == true,
        isPolling: data['isPolling'] == true,
      );
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('[ChannelProvider] toggleTelegram failed: $e');
      notifyListeners();
      return false;
    }
  }

  // ─── 연결 테스트 ────────────────────────────────────────────

  /// Returns {'ok': bool, 'botName': String?, 'message': String?}
  Future<Map<String, dynamic>> testTelegram(String botToken) async {
    try {
      final data = await AriAgent.call('/CHANNEL.TEST', {
        'type': 'telegram',
        if (botToken.isNotEmpty) 'botToken': botToken,
      });
      // AriAgent.call 성공 시 data 필드만 반환 → {botName: "..."}
      final botName = data['botName'] as String?;
      return {'ok': true, 'botName': botName, 'message': null};
    } catch (e) {
      return {'ok': false, 'botName': null, 'message': e.toString()};
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
