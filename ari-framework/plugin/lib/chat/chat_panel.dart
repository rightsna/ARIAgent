import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/chat_provider.dart';
import 'widgets/chat_panel_body.dart';
import '../theme/ari_chat_theme.dart';

/// ARI 프레임워크 표준 채팅 패널.
///
/// **기본 모드** (`messages` 미제공):
///   내부 [AriChatProvider]를 생성하고 `/AGENT` 경로로 메시지를 전송합니다.
///   ARIStock처럼 단순한 사용 사례에 적합합니다.
///
/// **외부 모드** (`messages` 제공):
///   외부에서 메시지 목록과 콜백을 주입합니다. 별도 Provider를 사용하거나
///   다양한 비즈니스 로직이 필요한 앱(ari-app 등)에 적합합니다.
///
/// **슬롯 오버라이드** (두 모드 공통):
/// - [headerBuilder]: 헤더 전체를 커스텀 위젯으로 교체
/// - [overlayWidget]: 메시지 영역 위에 오버레이 (예: 서버 정지, 모델 미설정 화면)
/// - [messageBubbleBuilder]: 개별 메시지 말풍선을 커스텀 위젯으로 교체
/// - [emptyStateWidget]: 메시지 없을 때 표시할 위젯 교체
///
/// 사용 예시 (기본):
/// ```dart
/// AriChatPanel(appId: 'aristock', contextLabel: '종목분석')
/// ```
///
/// 사용 예시 (외부 모드):
/// ```dart
/// AriChatPanel(
///   appId: 'ari_agent',
///   messages: chatProvider.messages,
///   onSend: (text) => chatProvider.sendMessage(text, agentId),
///   onCancel: chatProvider.cancelSendMessage,
///   isLoading: chatProvider.isLoading,
///   reverseMessages: true,
///   headerBuilder: (_) => ChatHeader(isLoading: chatProvider.isLoading),
///   overlayWidget: !server.isRunning ? ServerStoppedView() : null,
///   messageBubbleBuilder: (msg) => ChatBubble(...),
/// )
/// ```
class AriChatPanel extends StatelessWidget {
  final String appId;

  // ── 기본 모드 옵션 ──────────────────────────────────────────────────────────
  /// 헤더 서브타이틀에 표시될 현재 컨텍스트 레이블 (기본 모드에서 사용).
  final String? contextLabel;

  /// 헤더 타이틀 (기본 모드에서 사용). 기본값: 'AI 에이전트'
  final String headerTitle;

  // ── 외부 모드 ───────────────────────────────────────────────────────────────
  /// 외부에서 제공하는 메시지 목록. 제공 시 내부 Provider를 생성하지 않습니다.
  final List<AriChatMessage>? messages;

  /// 외부 모드에서 메시지 전송 핸들러.
  final Future<void> Function(String text)? onSend;

  /// 로딩 중 취소 콜백.
  final VoidCallback? onCancel;

  /// 외부에서 주입하는 로딩 상태 (외부 모드에서 사용).
  final bool isLoading;

  /// 외부 모드에서 주입하는 최신 follow-up 메시지.
  final String? followUpMessage;

  /// 외부 모드에서 주입하는 follow-up 대기 개수.
  final int followUpCount;

  // ── UI 공통 옵션 ────────────────────────────────────────────────────────────
  /// 입력창 힌트 텍스트.
  final String hintText;

  /// 테마 커스터마이징.
  final AriChatTheme theme;

  /// 최신 메시지를 아래에 유지하는 역순 ListView (기본 false).
  final bool reverseMessages;

  // ── 슬롯 오버라이드 ─────────────────────────────────────────────────────────
  /// 헤더 전체를 교체할 빌더. null이면 기본 헤더 사용.
  final WidgetBuilder? headerBuilder;

  /// 메시지 영역 대신 표시할 위젯 (서버 정지, 모델 미설정 등).
  /// null이면 메시지 목록 표시.
  final Widget? overlayWidget;

  /// 개별 메시지 말풍선 커스텀 빌더. null이면 기본 [AriChatMessageItem] 사용.
  final Widget Function(AriChatMessage message)? messageBubbleBuilder;

  /// 메시지 없을 때 표시할 위젯. null이면 기본 [ChatEmptyState] 사용.
  final Widget? emptyStateWidget;

  /// 메시지 없을 때 표시할 기본 텍스트.
  final String? emptyStateMessage;

  /// 입력창 전체를 교체할 빌더. null이면 기본 [ChatInputArea] 사용.
  /// 빌더 인자: onSend(text), onCancel, isLoading
  final Widget Function(
    Future<void> Function(String) onSend,
    VoidCallback? onCancel,
    bool isLoading,
  )? inputAreaBuilder;
  final double followUpBannerTopOffset;

  const AriChatPanel({
    super.key,
    required this.appId,
    this.contextLabel,
    this.headerTitle = 'AI 에이전트',
    this.messages,
    this.onSend,
    this.onCancel,
    this.isLoading = false,
    this.followUpMessage,
    this.followUpCount = 0,
    this.hintText = '메시지를 입력하세요...',
    this.theme = const AriChatTheme(),
    this.reverseMessages = false,
    this.headerBuilder,
    this.overlayWidget,
    this.messageBubbleBuilder,
    this.emptyStateWidget,
    this.emptyStateMessage,
    this.inputAreaBuilder,
    this.followUpBannerTopOffset = -52,
  }) : assert(
          messages == null || onSend != null,
          'onSend must be provided when messages is provided (external mode)',
        );

  bool get _isExternalMode => messages != null;

  @override
  Widget build(BuildContext context) {
    final body = AriChatPanelBody(
      appId: appId,
      contextLabel: contextLabel,
      headerTitle: headerTitle,
      externalMessages: messages,
      onSendExternal: onSend,
      onCancel: onCancel,
      externalIsLoading: isLoading,
      externalFollowUpMessage: followUpMessage,
      externalFollowUpCount: followUpCount,
      hintText: hintText,
      theme: theme,
      reverseMessages: reverseMessages,
      headerBuilder: headerBuilder,
      overlayWidget: overlayWidget,
      messageBubbleBuilder: messageBubbleBuilder,
      emptyStateWidget: emptyStateWidget,
      emptyStateMessage: emptyStateMessage,
      inputAreaBuilder: inputAreaBuilder,
      followUpBannerTopOffset: followUpBannerTopOffset,
      isExternalMode: _isExternalMode,
    );

    if (_isExternalMode) return body;

    return ChangeNotifierProvider(
      create: (_) => AriChatProvider(),
      child: body,
    );
  }
}
