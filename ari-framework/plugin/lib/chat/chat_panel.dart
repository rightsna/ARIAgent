import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../bridge/ws/AriAgent.dart';
import '../theme/ari_chat_theme.dart';
import 'chat_provider.dart';
import 'widgets/chat_empty_state.dart';
import 'widgets/chat_input_area.dart';
import 'widgets/chat_message_item.dart';

/// ARI 프레임워크 표준 채팅 패널.
///
/// **기본 모드** (`messages` 미제공):
///   내부 [AriChatProvider]를 생성하고 AriAgent.report()로 메시지를 전송합니다.
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

  /// 입력창 전체를 교체할 빌더. null이면 기본 [ChatInputArea] 사용.
  /// 빌더 인자: onSend(text), onCancel, isLoading
  final Widget Function(
    Future<void> Function(String) onSend,
    VoidCallback? onCancel,
    bool isLoading,
  )? inputAreaBuilder;

  const AriChatPanel({
    super.key,
    required this.appId,
    this.contextLabel,
    this.headerTitle = 'AI 에이전트',
    this.messages,
    this.onSend,
    this.onCancel,
    this.isLoading = false,
    this.hintText = '메시지를 입력하세요...',
    this.theme = const AriChatTheme(),
    this.reverseMessages = false,
    this.headerBuilder,
    this.overlayWidget,
    this.messageBubbleBuilder,
    this.emptyStateWidget,
    this.inputAreaBuilder,
  }) : assert(
          messages == null || onSend != null,
          'onSend must be provided when messages is provided (external mode)',
        );

  bool get _isExternalMode => messages != null;

  @override
  Widget build(BuildContext context) {
    final body = _AriChatPanelBody(
      appId: appId,
      contextLabel: contextLabel,
      headerTitle: headerTitle,
      externalMessages: messages,
      onSendExternal: onSend,
      onCancel: onCancel,
      externalIsLoading: isLoading,
      hintText: hintText,
      theme: theme,
      reverseMessages: reverseMessages,
      headerBuilder: headerBuilder,
      overlayWidget: overlayWidget,
      messageBubbleBuilder: messageBubbleBuilder,
      emptyStateWidget: emptyStateWidget,
      inputAreaBuilder: inputAreaBuilder,
      isExternalMode: _isExternalMode,
    );

    if (_isExternalMode) return body;

    return ChangeNotifierProvider(
      create: (_) => AriChatProvider(),
      child: body,
    );
  }
}

class _AriChatPanelBody extends StatefulWidget {
  final String appId;
  final String? contextLabel;
  final String headerTitle;
  final List<AriChatMessage>? externalMessages;
  final Future<void> Function(String)? onSendExternal;
  final VoidCallback? onCancel;
  final bool externalIsLoading;
  final String hintText;
  final AriChatTheme theme;
  final bool reverseMessages;
  final WidgetBuilder? headerBuilder;
  final Widget? overlayWidget;
  final Widget Function(AriChatMessage)? messageBubbleBuilder;
  final Widget? emptyStateWidget;
  final Widget Function(
    Future<void> Function(String) onSend,
    VoidCallback? onCancel,
    bool isLoading,
  )? inputAreaBuilder;
  final bool isExternalMode;

  const _AriChatPanelBody({
    required this.appId,
    required this.contextLabel,
    required this.headerTitle,
    required this.externalMessages,
    required this.onSendExternal,
    required this.onCancel,
    required this.externalIsLoading,
    required this.hintText,
    required this.theme,
    required this.reverseMessages,
    required this.headerBuilder,
    required this.overlayWidget,
    required this.messageBubbleBuilder,
    required this.emptyStateWidget,
    required this.inputAreaBuilder,
    required this.isExternalMode,
  });

  @override
  State<_AriChatPanelBody> createState() => _AriChatPanelBodyState();
}

class _AriChatPanelBodyState extends State<_AriChatPanelBody> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int _lastMessageCount = 0;
  AriChatProvider? _internalProvider;

  bool get _isLoading =>
      widget.isExternalMode ? widget.externalIsLoading : false;

  @override
  void initState() {
    super.initState();
    if (!widget.isExternalMode) {
      _internalProvider = context.read<AriChatProvider>();
      _lastMessageCount = _internalProvider!.messages.length;
      _internalProvider!.addListener(_onMessagesChanged);
    } else {
      _lastMessageCount = widget.externalMessages!.length;
    }
  }

  @override
  void didUpdateWidget(_AriChatPanelBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExternalMode) {
      final newCount = widget.externalMessages!.length;
      if (newCount > _lastMessageCount) {
        _lastMessageCount = newCount;
        _scrollToBottom();
      }
    }
  }

  @override
  void dispose() {
    _internalProvider?.removeListener(_onMessagesChanged);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onMessagesChanged() {
    if (!mounted) return;
    final messages = _internalProvider!.messages;
    if (messages.length > _lastMessageCount) {
      _lastMessageCount = messages.length;
      _scrollToBottom();
    }
  }

  // inputAreaBuilder에서 호출하는 외부용 — 텍스트를 직접 전달
  Future<void> _sendText(String text) async {
    _controller.text = text;
    await _sendMessage();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    if (widget.isExternalMode) {
      _controller.clear();
      _scrollToBottom();
      await widget.onSendExternal!(text);
    } else {
      if (!AriAgent.isConnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI 에이전트가 연결되어 있지 않습니다.')),
        );
        return;
      }
      _controller.clear();
      _scrollToBottom();
      AriAgent.report(
        appId: widget.appId,
        type: 'CHAT_MESSAGE',
        message: text,
        details: widget.contextLabel != null ? {'currentTab': widget.contextLabel} : {},
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final target = widget.reverseMessages
            ? _scrollController.position.minScrollExtent
            : _scrollController.position.maxScrollExtent;
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutQuart,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = widget.isExternalMode
        ? widget.externalMessages!
        : context.watch<AriChatProvider>().messages;
    final theme = widget.theme;

    return Container(
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        border: theme.borderWidth > 0
            ? Border(left: BorderSide(color: theme.borderColor, width: theme.borderWidth))
            : null,
      ),
      child: Column(
        children: [
          // ── 헤더 ──────────────────────────────────────────────────────────
          widget.headerBuilder != null
              ? widget.headerBuilder!(context)
              : _buildDefaultHeader(context, messages, theme),

          // ── 메시지 영역 ────────────────────────────────────────────────────
          Expanded(
            child: widget.overlayWidget != null
                ? widget.overlayWidget!
                : Container(
                    color: theme.backgroundColor.withValues(alpha: 0.3),
                    child: messages.isEmpty
                        ? (widget.emptyStateWidget ?? ChatEmptyState(theme: theme))
                        : ListView.builder(
                            controller: _scrollController,
                            reverse: widget.reverseMessages,
                            padding: const EdgeInsets.all(20),
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final msg = widget.reverseMessages
                                  ? messages[messages.length - 1 - index]
                                  : messages[index];
                              return widget.messageBubbleBuilder != null
                                  ? widget.messageBubbleBuilder!(msg)
                                  : AriChatMessageItem(message: msg, theme: theme);
                            },
                          ),
                  ),
          ),

          // ── 입력창 ─────────────────────────────────────────────────────────
          widget.inputAreaBuilder != null
              ? widget.inputAreaBuilder!(_sendText, widget.onCancel, _isLoading)
              : ChatInputArea(
                  controller: _controller,
                  onSend: _sendMessage,
                  theme: theme,
                  hintText: widget.hintText,
                  isLoading: _isLoading,
                  onCancel: widget.onCancel,
                ),
        ],
      ),
    );
  }

  Widget _buildDefaultHeader(
    BuildContext context,
    List<AriChatMessage> messages,
    AriChatTheme theme,
  ) {
    final provider = widget.isExternalMode ? null : _internalProvider;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.auto_awesome_rounded, size: 18, color: theme.primaryColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.headerTitle,
                  style: TextStyle(
                    color: theme.textMain,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                if (widget.contextLabel != null)
                  Text(
                    '현재 모드: ${widget.contextLabel}',
                    style: TextStyle(color: theme.textSub, fontSize: 11),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => provider?.clearMessages(),
            icon: Icon(Icons.refresh_rounded, size: 20, color: theme.textSub),
          ),
        ],
      ),
    );
  }
}
