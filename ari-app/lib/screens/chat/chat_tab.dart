import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ari_plugin/ari_plugin.dart';

import '../../providers/server_provider.dart';
import '../../providers/config_provider.dart';

import 'views/chat_header.dart';
import 'views/chat_suggestions.dart';
import 'views/server_stopped_view.dart';
import 'views/model_setup_view.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/chat_input.dart';

const _chatPanelBackgroundColor = Color(0xFF12122A);

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
    if (AriAgent.isConnected) {
      if (_lastAgentId != null) {
        context.read<AriChatProvider>().loadServerHistory(_lastAgentId!);
      }
      context.read<ConfigProvider>().getServerHealth();
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
      if (!isConnected) {
        // 연결 끊김: tracking만 업데이트, 로드 없음
        _lastAgentId = avatarId;
        _lastConnected = false;
      } else if (!chatProvider.isLoading) {
        // 연결됨 + 요청 없음: 히스토리 로드
        _lastAgentId = avatarId;
        _lastConnected = isConnected;
        Future.microtask(() => chatProvider.loadServerHistory(avatarId));
      }
      // 연결됨 + 요청 진행 중: tracking 업데이트 안 함 → isLoading이 false가 되면 재시도
    }

    // 조건부 오버레이 결정
    // isSetupMode: ari-cloud 프록시로 setup agent가 활성화된 상태 → 오버레이 없이 채팅 허용
    Widget? overlay;
    if (!isServerRunning) {
      overlay = const ServerStoppedView();
    } else if (!hasApiKey && !config.isSetupMode) {
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
      onCancel: () =>
          chatProvider.cancelAgentMessage(agentId: avatar.currentAvatarId),
      isLoading: chatProvider.isLoading,
      followUpMessage: chatProvider.latestFollowUpMessage,
      followUpCount: chatProvider.queuedFollowUpCount,
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
            isSetupMode: config.isSetupMode,
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
      inputAreaBuilder: (onSend, onCancel, isLoading) {
        if (!isServerRunning) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
          child: ChatInput(
            onSubmit: onSend,
            onCancel: onCancel,
            isLoading: isLoading,
          ),
        );
      },
      followUpBannerTopOffset: -68,
      theme: const AriChatTheme(
        primaryColor: Color(0xFF6C63FF),
        surfaceColor: _chatPanelBackgroundColor,
        backgroundColor: _chatPanelBackgroundColor,
        textMain: Colors.white,
        textSub: Color(0xFF9E9EB8),
        borderColor: Colors.transparent,
        borderWidth: 0,
        hintColor: Color(0x66FFFFFF),
      ),
    );
  }
}
