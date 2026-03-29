import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/avatar_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/server_provider.dart';
import '../../providers/config_provider.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/chat_input.dart';

import 'views/chat_header.dart';
import 'views/chat_suggestions.dart';
import 'views/server_stopped_view.dart';
import 'views/model_setup_view.dart';

class ChatTab extends StatefulWidget {
  final VoidCallback? onSettingsTap;

  const ChatTab({super.key, this.onSettingsTap});

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    // Fetch initial health to check API key
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ServerProvider().isRunning) {
        Provider.of<ConfigProvider>(context, listen: false).getServerHealth();
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    final chatProvider = context.read<ChatProvider>();
    final avatarProvider = context.read<AvatarProvider>();

    await chatProvider.sendMessage(text, avatarProvider.currentAvatarId);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (!mounted) return;
    
    // reverse: true 모드에서는 0이 가장 아래입니다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();

    return Column(
      children: [
        ChatHeader(isLoading: chatProvider.isLoading),

        // 채팅 메시지 및 입력 영역
        Expanded(
          child: ListenableBuilder(
            listenable: Listenable.merge([
              ServerProvider(),
              Provider.of<ConfigProvider>(context, listen: false),
            ]),
            builder: (context, _) {
              if (!ServerProvider().isRunning) {
                return const ServerStoppedView();
              }

              if (!Provider.of<ConfigProvider>(
                context,
                listen: false,
              ).hasApiKey) {
                return ModelSetupView(onSettingsTap: widget.onSettingsTap);
              }

              final messages = chatProvider.messages;

              return Column(
                children: [
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: const BoxDecoration(
                        color: Colors.transparent,
                      ),
                      child: messages.isEmpty
                          ? Center(
                              child: Text(
                                '💬 ARI에게 무엇이든 물어보세요!',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  fontSize: 13,
                                ),
                              ),
                            )
                          : SelectionArea(
                              child: ListView.builder(
                                reverse: true, // 최신 메시지가 아래에 오도록 설정
                                controller: _scrollController,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                itemCount: messages.length,
                                itemBuilder: (context, index) {
                                  // 역순이므로 뒤에서부터 가져옴
                                  final msg = messages[messages.length - 1 - index];
                                  return ChatBubble(
                                    message: msg.text,
                                    isUser: msg.isUser,
                                    isError: msg.isError,
                                    isSystem: msg.isSystem,
                                  );
                                },
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 튜토리얼 버튼
                  if (messages.isEmpty)
                    ChatSuggestions(onSuggestionTap: _sendMessage),

                  // 채팅 입력
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 12,
                      right: 12,
                      bottom: 12,
                    ),
                    child: ChatInput(
                      onSubmit: _sendMessage,
                      onCancel: chatProvider.cancelSendMessage,
                      isLoading: chatProvider.isLoading,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
