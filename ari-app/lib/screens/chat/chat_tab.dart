import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ari_plugin/ari_plugin.dart';

import '../../providers/avatar_provider.dart';
import '../../providers/server_provider.dart';
import '../../providers/config_provider.dart';

import 'views/chat_header.dart';
import 'views/chat_suggestions.dart';
import 'views/server_stopped_view.dart';
import 'views/model_setup_view.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/chat_input.dart';

class ChatTab extends StatefulWidget {
  final VoidCallback? onSettingsTap;

  const ChatTab({super.key, this.onSettingsTap});

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  String? _lastAgentId;
  bool _lastConnected = false;

  @override
  void initState() {
    super.initState();
    AriAgent.connectionNotifier.addListener(_onConnectionChanged);
  }

  @override
  void dispose() {
    AriAgent.connectionNotifier.removeListener(_onConnectionChanged);
    super.dispose();
  }

  void _onConnectionChanged() {
    if (AriAgent.isConnected && _lastAgentId != null) {
      context.read<AriChatProvider>().loadServerHistory(_lastAgentId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<AriChatProvider>();
    final server = context.watch<ServerProvider>();
    final config = context.watch<ConfigProvider>();
    final avatar = context.watch<AvatarProvider>();

    final isServerRunning = server.isRunning;
    final hasApiKey = config.hasApiKey;
    final isConnected = AriAgent.isConnected;
    final avatarId = avatar.currentAvatarId;

    // 아바타가 변경되었거나, 서버가 방금 연결된 경우 히스토리 다시 불러오기
    if (avatarId != _lastAgentId || (isConnected && !_lastConnected)) {
      _lastAgentId = avatarId;
      _lastConnected = isConnected;
      if (isConnected) {
        Future.microtask(() => context.read<AriChatProvider>().loadServerHistory(avatarId));
      }
    }

    // 조건부 오버레이 결정
    Widget? overlay;
    if (!isServerRunning) {
      overlay = const ServerStoppedView();
    } else if (!hasApiKey) {
      overlay = ModelSetupView(onSettingsTap: widget.onSettingsTap);
    }

    return AriChatPanel(
      appId: 'ari_agent',
      messages: chatProvider.messages,
      onSend: (text) => chatProvider.sendAgentMessage(
        text,
        agentId: avatar.currentAvatarId,
        persona: avatar.persona.trim(),
        avatarName: avatar.name,
      ),
      onCancel: () => chatProvider.cancelAgentMessage(agentId: avatar.currentAvatarId),
      isLoading: chatProvider.isLoading,
      hintText: 'ARI에게 물어보세요...',
      reverseMessages: true,
      headerBuilder: (_) => ChatHeader(isLoading: chatProvider.isLoading),
      overlayWidget: overlay,
      emptyStateWidget: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(
            child: Center(
              child: Text(
                '💬 ARI에게 무엇이든 물어보세요!',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 13,
                ),
              ),
            ),
          ),
          ChatSuggestions(
            onSuggestionTap: (text) => chatProvider.sendAgentMessage(
              text,
              agentId: avatar.currentAvatarId,
              persona: avatar.persona.trim(),
              avatarName: avatar.name,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
      messageBubbleBuilder: (msg) => ChatBubble(
        message: msg.text,
        isUser: msg.isUser,
        isError: msg.isError,
        isSystem: msg.isSystem,
      ),
      inputAreaBuilder: (onSend, onCancel, isLoading) => Padding(
        padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
        child: ChatInput(
          onSubmit: onSend,
          onCancel: onCancel,
          isLoading: isLoading,
        ),
      ),
      theme: const AriChatTheme(
        primaryColor: Color(0xFF6C63FF),
        surfaceColor: Colors.transparent,
        backgroundColor: Colors.transparent,
        textMain: Colors.white,
        textSub: Color(0xFF9E9EB8),
        borderColor: Colors.transparent,
        borderWidth: 0,
        hintColor: Color(0x66FFFFFF),
      ),
    );
  }
}
