import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_update_service.dart';
import '../../bridge/ws/AriAgent.dart';
import '../../chat/providers/chat_provider.dart';

/// ARI 프레임워크 통합 업데이트 배너 위젯.
///
/// **자립(Self-standing) 모드**:
/// [feedUrl] 또는 [appId]를 제공하면 자체적으로 [AppUpdateService]를 구동하여 상태를 관리합니다.
/// [feedUrl] 미제공 시 https://ariwith.me/api/get-version?id=[appId] 경로를 기본으로 사용합니다.
///
/// **지능형 업데이트 (AI 연동)**:
/// 위젯 트리 내에서 [AriChatProvider]를 자동으로 찾아
/// AI에게 업데이트 설치 요청 메시지를 대신 보냅니다.
class AriUpdateBanner extends StatefulWidget {
  /// 업데이트 체크용 서버 URL. 직접 지정하거나 appId를 이용해 자동 생성할 수 있습니다.
  final String? feedUrl;

  /// 업데이트 체크 주기 (기본 3시간).
  final Duration checkInterval;

  /// 직접 주입하는 업데이트 정보 (수동 모드용).
  final AppUpdateInfo? updateInfo;

  /// 앱 이름 (AI 메시지 생성용). 미제공 시 "이 애플리케이션"으로 표시.
  final String? appName;

  /// AI 에이전트 식별자 (플랫폼 아이디). 필수 요소는 아니지만 AI 연동을 위해 권장됩니다.
  final String? appId;

  /// 업데이트 버튼 클릭 시 호출될 콜백.
  /// 명시적으로 `false`를 반환하지 않는 한 AI 설치 요청 기본 동작도 함께 수행됩니다.
  final FutureOr<dynamic> Function(AppUpdateInfo info)? onUpdate;

  final Color? backgroundColor;
  final Color? accentColor;

  const AriUpdateBanner({
    super.key,
    this.feedUrl,
    this.checkInterval = const Duration(hours: 3),
    this.updateInfo,
    this.appName,
    this.appId,
    this.onUpdate,
    this.backgroundColor,
    this.accentColor,
  });

  @override
  State<AriUpdateBanner> createState() => _AriUpdateBannerState();
}

class _AriUpdateBannerState extends State<AriUpdateBanner> {
  AppUpdateInfo? _selfUpdateInfo;
  Timer? _updateTimer;
  AppUpdateService? _service;
  bool _isDismissed = false;

  AppUpdateInfo? get _effectiveInfo => widget.updateInfo ?? _selfUpdateInfo;

  @override
  void initState() {
    super.initState();
    _initService();
  }

  @override
  void didUpdateWidget(AriUpdateBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.feedUrl != oldWidget.feedUrl || widget.appId != oldWidget.appId) {
      _initService();
    }
  }

  void _initService() {
    _updateTimer?.cancel();

    // feedUrl이 없어도 appId가 있으면 기본 ARI 버전 API URL 생성
    final effectiveFeedUrl = widget.feedUrl ??
        (widget.appId != null
            ? 'https://ariwith.me/api/get-version?id=${widget.appId}'
            : null);

    if (effectiveFeedUrl != null) {
      _service = AppUpdateService(feedUrl: effectiveFeedUrl);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _performUpdateCheck();
        _updateTimer = Timer.periodic(widget.checkInterval, (timer) {
          _performUpdateCheck();
        });
      });
    } else {
      _service = null;
    }
  }

  Future<void> _performUpdateCheck() async {
    if (_service == null || !mounted) return;
    try {
      final update = await _service!.checkForUpdate();
      if (!mounted) return;
      setState(() => _selfUpdateInfo = update);
    } catch (e) {
      debugPrint('[AriUpdateBanner] Update check error: $e');
    }
  }

  Future<void> _handleUpdate(AppUpdateInfo info) async {
    // 1. 커스텀 콜백 실행 (false 반환 시 전체 중단)
    if (widget.onUpdate != null) {
      final result = await widget.onUpdate!(info);
      if (result == false) return;
    }

    // 2. 즉시 UI 반응 (배너 숨김 및 스낵바 표시)
    if (mounted) {
      setState(() => _isDismissed = true);
      
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '${widget.appName ?? "애플리케이션"} 업데이트 설치를 시작합니다. 완료 후 앱이 자동으로 재시작됩니다.',
              style: const TextStyle(
                fontSize: 13, 
                color: Colors.white,
                decoration: TextDecoration.none,
              ),
            ),
            backgroundColor: const Color(0xFF1E3A8A),
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }

    // 3. 백그라운드에서 AI 에이전트에게 명령 전송 (UI 블로킹 방지)
    _sendUpdateCommand(info);
  }

  Future<void> _sendUpdateCommand(AppUpdateInfo info) async {
    try {
      final chatProvider = context.read<AriChatProvider?>();
      final url = info.downloadUrlForCurrentPlatform();
      if (url == null) return;

      final name = widget.appName ?? '애플리케이션';
      final message = "Install $url ${Platform.isMacOS ? '--mac' : '--windows'}\n"
          "설치가 완료되면 현재 실행 중인 $name 앱을 종료하고 새 버전으로 다시 시작해.";

      if (chatProvider != null) {
        await chatProvider.sendAgentMessage(
          message,
          platform: widget.appId ?? 'client',
        );
      } else {
        await AriAgent.call('/AGENT', {
          'message': message,
          'platform': widget.appId ?? 'client',
          'requestId': 'update-${DateTime.now().millisecondsSinceEpoch}',
        });
      }
    } catch (e) {
      debugPrint('[AriUpdateBanner] Background update command failed: $e');
    }
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final info = _effectiveInfo;
    if (info == null || _isDismissed) return const SizedBox.shrink();

    // 테마 색상 결정 (사용자 커스텀 또는 기본 ARI 블루 테마)
    final effectiveAccentColor = widget.accentColor ??
        (info.mandatory ? Colors.orange.shade200 : const Color(0xFFA7A1FF));

    final effectiveBackgroundColor = widget.backgroundColor ??
        (info.mandatory ? const Color(0xFF003366) : const Color(0xFF1E3A8A));

    // Material이 없는 환경을 대비하여 TextStyle에 decoration: TextDecoration.none 추가
    const defaultTextStyle = TextStyle(
      decoration: TextDecoration.none,
      fontFamily: '.AppleSystemUIFont', // Mac 시스템 기본 폰트
    );

    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: effectiveBackgroundColor,
          border: Border(
            bottom: BorderSide(
              color: effectiveAccentColor.withOpacity(0.1),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.system_update_alt_rounded,
              size: 18,
              color: effectiveAccentColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '새로운 버전(${info.latestVersion})이 출시되었습니다!',
                    style: defaultTextStyle.copyWith(
                      color: Colors.white.withOpacity(0.92),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (info.mandatory)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '원활한 이용을 위해 필수 업데이트가 필요합니다.',
                        style: defaultTextStyle.copyWith(
                          color: effectiveAccentColor.withOpacity(0.8),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () => _handleUpdate(info),
              style: ElevatedButton.styleFrom(
                backgroundColor: effectiveAccentColor,
                foregroundColor: effectiveBackgroundColor,
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('업데이트'),
            ),
          ],
        ),
      ),
    );
  }
}
