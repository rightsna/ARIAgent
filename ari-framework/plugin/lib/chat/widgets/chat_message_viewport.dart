import 'package:flutter/material.dart';
import '../../theme/ari_chat_theme.dart';
import '../models/ari_chat_message.dart';
import 'chat_empty_state.dart';
import 'chat_message_item.dart';

class ChatMessageViewport extends StatelessWidget {
  final List<AriChatMessage> messages;
  final AriChatTheme theme;
  final bool reverseMessages;
  final ScrollController scrollController;
  final Widget? overlayWidget;
  final Widget? emptyStateWidget;
  final Widget Function(AriChatMessage)? messageBubbleBuilder;
  final bool showScrollToBottomButton;
  final VoidCallback onScrollToBottom;

  const ChatMessageViewport({
    super.key,
    required this.messages,
    required this.theme,
    required this.reverseMessages,
    required this.scrollController,
    required this.overlayWidget,
    required this.emptyStateWidget,
    required this.messageBubbleBuilder,
    required this.showScrollToBottomButton,
    required this.onScrollToBottom,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Positioned.fill(
          child: overlayWidget != null
              ? overlayWidget!
              : Container(
                  color: theme.backgroundColor,
                  child: messages.isEmpty
                      ? (emptyStateWidget ?? ChatEmptyState(theme: theme))
                      : ListView.builder(
                          controller: scrollController,
                          reverse: reverseMessages,
                          padding: const EdgeInsets.all(20),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final msg = reverseMessages
                                ? messages[messages.length - 1 - index]
                                : messages[index];
                            return messageBubbleBuilder != null
                                ? messageBubbleBuilder!(msg)
                                : AriChatMessageItem(
                                    message: msg,
                                    theme: theme,
                                  );
                          },
                        ),
                ),
        ),
        Positioned(
          bottom: 14,
          child: AnimatedSlide(
            offset:
                showScrollToBottomButton ? Offset.zero : const Offset(0, 0.35),
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            child: AnimatedOpacity(
              opacity: showScrollToBottomButton ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: IgnorePointer(
                ignoring: !showScrollToBottomButton,
                child: GestureDetector(
                  onTap: onScrollToBottom,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: theme.primaryColor,
                      borderRadius: BorderRadius.circular(19),
                      border: Border.all(
                        color: theme.primaryColor.withValues(alpha: 0.1),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.primaryColor.withValues(alpha: 0.24),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
