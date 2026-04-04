import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../bridge/ws/AriAgent.dart';
import '../../theme/ari_chat_theme.dart';
import '../providers/chat_provider.dart';
import 'chat_empty_state.dart';
import 'chat_input_area.dart';
import 'chat_message_item.dart';

class AriChatPanelBody extends StatefulWidget {
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

  const AriChatPanelBody({
    super.key,
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
  State<AriChatPanelBody> createState() => _AriChatPanelBodyState();
}

class _AriChatPanelBodyState extends State<AriChatPanelBody> {
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
