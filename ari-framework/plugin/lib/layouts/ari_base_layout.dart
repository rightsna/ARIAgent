import 'package:flutter/material.dart';
import '../chat/chat_panel.dart';
import '../chat/providers/chat_provider.dart';
import '../theme/ari_chat_theme.dart';
import '../update/widgets/ari_update_banner.dart';
import 'widgets/connection_warning_banner.dart';
import 'widgets/thinking_glow_overlay.dart';

class AriBaseLayout extends StatefulWidget {
  const AriBaseLayout({
    super.key,
    required this.appId,
    required this.appName,
    required this.body,
    this.appBar,
    this.drawer,
    this.backgroundColor,
    this.scaffoldKey,

    // Chat Layout Ops
    this.showChat = false,
    this.chatPanel,

    // Integrated Chat Provider Mode
    this.chatProvider,

    // Individual Chat Options override
    this.onChatSend,
    this.onChatCancel,
    this.chatMessages,
    this.isChatLoading = false,
    this.chatContextLabel,
    this.chatHeaderTitle = 'AI 에이전트',
    this.chatHintText = '메시지를 입력하세요...',
    this.chatTheme = const AriChatTheme(),
    this.chatFollowUpMessage,
    this.chatFollowUpCount = 0,
  });

  final String appId;
  final String appName;
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? drawer;
  final Color? backgroundColor;
  final Key? scaffoldKey;

  final AriChatProvider? chatProvider;
  final bool showChat;
  final Widget? chatPanel;

  final Future<void> Function(String)? onChatSend;
  final VoidCallback? onChatCancel;
  final List<AriChatMessage>? chatMessages;
  final bool isChatLoading;
  final String? chatContextLabel;
  final String chatHeaderTitle;
  final String chatHintText;
  final AriChatTheme chatTheme;
  final String? chatFollowUpMessage;
  final int chatFollowUpCount;

  @override
  State<AriBaseLayout> createState() => _AriBaseLayoutState();
}

class _AriBaseLayoutState extends State<AriBaseLayout> {
  double _chatWidth = 360;
  static const double _minChatWidth = 240.0;
  static const double _maxChatWidthRatio = 0.6;

  @override
  Widget build(BuildContext context) {
    final maxChatWidth = MediaQuery.of(context).size.width * _maxChatWidthRatio;
    final themeBackground = Theme.of(context).scaffoldBackgroundColor;

    return Stack(
      children: [
        Scaffold(
          key: widget.scaffoldKey,
          drawer: widget.drawer,
          backgroundColor: widget.backgroundColor ?? themeBackground,
          body: SafeArea(
            child: Column(
              children: [
                const ConnectionWarningBanner(),
                AriUpdateBanner(appId: widget.appId, appName: widget.appName),
                Expanded(
                  child: Row(
                    children: [
                      // Left Side: Header + Content
                      Expanded(
                        child: Column(
                          children: [
                            if (widget.appBar != null)
                              SizedBox(
                                height: widget.appBar!.preferredSize.height,
                                child: widget.appBar!,
                              ),
                            Expanded(child: widget.body),
                          ],
                        ),
                      ),
                      // Right Side: Chat Panel
                      if (widget.showChat) ...[
                        // Resize Handle
                        GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onHorizontalDragUpdate: (details) {
                            setState(() {
                              _chatWidth = (_chatWidth - details.delta.dx).clamp(
                                _minChatWidth,
                                maxChatWidth,
                              );
                            });
                          },
                          child: MouseRegion(
                            cursor: SystemMouseCursors.resizeLeftRight,
                            child: Container(
                              width: 1,
                              height: double.infinity,
                              color: Theme.of(context)
                                  .dividerColor
                                  .withOpacity(0.1),
                            ),
                          ),
                        ),
                        // Chat Panel Area
                        SizedBox(
                          width: _chatWidth,
                          child: _buildChatPanel(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // AI Thinking Glow Effect
        _buildThinkingEffect(),
      ],
    );
  }

  Widget _buildThinkingEffect() {
    final isLoading = widget.chatProvider != null
        ? widget.chatProvider!.isLoading
        : widget.isChatLoading;

    if (widget.chatProvider != null) {
      return ListenableBuilder(
        listenable: widget.chatProvider!,
        builder: (context, _) => ThinkingGlowOverlay(
          isLoading: widget.chatProvider!.isLoading,
          color: widget.chatTheme.primaryColor,
        ),
      );
    }

    return ThinkingGlowOverlay(
      isLoading: isLoading,
      color: widget.chatTheme.primaryColor,
    );
  }

  Widget _buildChatPanel() {
    if (widget.chatPanel != null) return widget.chatPanel!;

    final p = widget.chatProvider;
    if (p != null) {
      return ListenableBuilder(
        listenable: p,
        builder: (context, _) => AriChatPanel(
          appId: widget.appId,
          onSend: widget.onChatSend ??
              (text) => p.sendAgentMessage(text, appId: widget.appId),
          onCancel: widget.onChatCancel ?? p.cancelAgentMessage,
          messages: p.messages,
          isLoading: p.isLoading,
          contextLabel: widget.chatContextLabel,
          headerTitle: widget.chatHeaderTitle,
          hintText: widget.chatHintText,
          theme: widget.chatTheme,
          followUpMessage: p.latestFollowUpMessage,
          followUpCount: p.queuedFollowUpCount,
        ),
      );
    }

    return AriChatPanel(
      appId: widget.appId,
      onSend: widget.onChatSend,
      onCancel: widget.onChatCancel,
      messages: widget.chatMessages,
      isLoading: widget.isChatLoading,
      contextLabel: widget.chatContextLabel,
      headerTitle: widget.chatHeaderTitle,
      hintText: widget.chatHintText,
      theme: widget.chatTheme,
      followUpMessage: widget.chatFollowUpMessage,
      followUpCount: widget.chatFollowUpCount,
    );
  }
}



