import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import '../../bridge/ws/AriAgent.dart';
import '../../theme/ari_chat_theme.dart';
import '../providers/chat_provider.dart';
import 'chat_default_header.dart';
import 'chat_follow_up_banner.dart';
import 'chat_input_area.dart';
import 'chat_message_viewport.dart';

class AriChatPanelBody extends StatefulWidget {
  final String appId;
  final String? contextLabel;
  final String headerTitle;
  final List<AriChatMessage>? externalMessages;
  final Future<void> Function(String)? onSendExternal;
  final VoidCallback? onCancel;
  final bool externalIsLoading;
  final String? externalFollowUpMessage;
  final int externalFollowUpCount;
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
  final double followUpBannerTopOffset;
  final bool isExternalMode;

  const AriChatPanelBody({
    super.key,
    required this.appId,
    required this.contextLabel,
    required this.headerTitle,
    required this.externalMessages,
    required this.onSendExternal,
    required this.onCancel,
    required this.externalIsLoading,
    required this.externalFollowUpMessage,
    required this.externalFollowUpCount,
    required this.hintText,
    required this.theme,
    required this.reverseMessages,
    required this.headerBuilder,
    required this.overlayWidget,
    required this.messageBubbleBuilder,
    required this.emptyStateWidget,
    required this.inputAreaBuilder,
    required this.followUpBannerTopOffset,
    required this.isExternalMode,
  });

  @override
  State<AriChatPanelBody> createState() => _AriChatPanelBodyState();
}

class _AriChatPanelBodyState extends State<AriChatPanelBody> {
  static const double _scrollToBottomThreshold = 120;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int _lastMessageCount = 0;
  AriChatProvider? _internalProvider;
  bool _showScrollToBottomButton = false;

  bool get _isLoading => widget.isExternalMode
      ? widget.externalIsLoading
      : (_internalProvider?.isLoading ?? false);

  VoidCallback? get _cancelHandler => widget.isExternalMode
      ? widget.onCancel
      : () => _internalProvider?.cancelAgentMessage();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScrollChanged);
    if (!widget.isExternalMode) {
      _internalProvider = context.read<AriChatProvider>();
      _lastMessageCount = _internalProvider!.messages.length;
      _internalProvider!.addListener(_onMessagesChanged);
    } else {
      _lastMessageCount = widget.externalMessages!.length;
    }
  }

  @override
  void didUpdateWidget(AriChatPanelBody oldWidget) {
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
    _scrollController.removeListener(_handleScrollChanged);
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
    if (text.isEmpty) return;

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
      await _internalProvider?.sendAgentMessage(
        text,
        appId: widget.appId,
      );
    }
  }

  void _scrollToBottom({bool immediate = false}) {
    void performScroll() {
      if (!_scrollController.hasClients) {
        return;
      }

      final target = widget.reverseMessages
          ? _scrollController.position.minScrollExtent
          : _scrollController.position.maxScrollExtent;

      if (immediate) {
        _scrollController.jumpTo(target);
        return;
      }

      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
    }

    if (WidgetsBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => performScroll());
      return;
    }

    performScroll();
  }

  void _handleScrollChanged() {
    if (!_scrollController.hasClients) {
      return;
    }

    final position = _scrollController.position;
    final distanceFromBottom = widget.reverseMessages
        ? (position.pixels - position.minScrollExtent).abs()
        : (position.maxScrollExtent - position.pixels).abs();
    final shouldShow = distanceFromBottom > _scrollToBottomThreshold;

    if (shouldShow != _showScrollToBottomButton && mounted) {
      setState(() {
        _showScrollToBottomButton = shouldShow;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = widget.isExternalMode
        ? widget.externalMessages!
        : context.watch<AriChatProvider>().messages;
    final provider =
        widget.isExternalMode ? null : context.watch<AriChatProvider>();
    final theme = widget.theme;
    final followUpMessage = widget.isExternalMode
        ? widget.externalFollowUpMessage
        : provider?.latestFollowUpMessage;
    final followUpCount = widget.isExternalMode
        ? widget.externalFollowUpCount
        : (provider?.queuedFollowUpCount ?? 0);
    final inputArea = widget.inputAreaBuilder != null
        ? widget.inputAreaBuilder!(
            _sendText,
            _cancelHandler,
            _isLoading,
          )
        : ChatInputArea(
            controller: _controller,
            onSend: _sendMessage,
            theme: theme,
            hintText: widget.hintText,
            isLoading: _isLoading,
            onCancel: _cancelHandler,
          );

    return Container(
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        border: theme.borderWidth > 0
            ? Border(
                left: BorderSide(
                    color: theme.borderColor, width: theme.borderWidth))
            : null,
      ),
      child: Column(
        children: [
          // ── 헤더 ──────────────────────────────────────────────────────────
          widget.headerBuilder != null
              ? widget.headerBuilder!(context)
              : ChatDefaultHeader(
                  headerTitle: widget.headerTitle,
                  contextLabel: widget.contextLabel,
                  theme: theme,
                  onReset: widget.isExternalMode
                      ? null
                      : () => _internalProvider?.resetAgentSession(),
                ),

          // ── 메시지 영역 ────────────────────────────────────────────────────
          Expanded(
            child: ChatMessageViewport(
              messages: messages,
              theme: theme,
              reverseMessages: widget.reverseMessages,
              scrollController: _scrollController,
              overlayWidget: widget.overlayWidget,
              emptyStateWidget: widget.emptyStateWidget,
              messageBubbleBuilder: widget.messageBubbleBuilder,
              showScrollToBottomButton: _showScrollToBottomButton,
              onScrollToBottom: () => _scrollToBottom(immediate: true),
            ),
          ),

          // ── 입력창 ─────────────────────────────────────────────────────────
          Stack(
            clipBehavior: Clip.none,
            children: [
              inputArea,
              if (followUpMessage != null && followUpMessage.isNotEmpty)
                Positioned(
                  left: 16,
                  right: 16,
                  top: widget.followUpBannerTopOffset,
                  child: IgnorePointer(
                    ignoring: true,
                    child: AnimatedSlide(
                      offset: Offset.zero,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      child: AnimatedOpacity(
                        opacity: 1,
                        duration: const Duration(milliseconds: 180),
                        child: ChatFollowUpBanner(
                          theme: theme,
                          message: followUpMessage,
                          count: followUpCount,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
