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
/// [appId]와 선택적 커스터마이징 파라미터만으로 어느 앱에서든 사용 가능하며,
/// [AriChatProvider]를 내부에서 직접 생성하여 관리합니다.
///
/// 사용 예시:
/// ```dart
/// AriChatPanel(
///   appId: 'myapp',
///   contextLabel: '현재 탭 이름',
///   theme: AriChatTheme(primaryColor: Colors.indigo),
/// )
/// ```
class AriChatPanel extends StatelessWidget {
  final String appId;

  /// 헤더 서브타이틀에 표시될 현재 컨텍스트 레이블 (예: 현재 탭 이름).
  final String? contextLabel;

  /// 헤더 타이틀. 기본값: 'AI 에이전트'
  final String headerTitle;

  /// 입력창 힌트 텍스트.
  final String hintText;

  /// 테마 커스터마이징. 미제공 시 기본 ARI 디자인 적용.
  final AriChatTheme theme;

  /// 메시지가 없을 때 표시할 위젯 오버라이드.
  final Widget? emptyStateWidget;

  const AriChatPanel({
    super.key,
    required this.appId,
    this.contextLabel,
    this.headerTitle = 'AI 에이전트',
    this.hintText = '메시지를 입력하세요...',
    this.theme = const AriChatTheme(),
    this.emptyStateWidget,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AriChatProvider(),
      child: _AriChatPanelBody(
        appId: appId,
        contextLabel: contextLabel,
        headerTitle: headerTitle,
        hintText: hintText,
        theme: theme,
        emptyStateWidget: emptyStateWidget,
      ),
    );
  }
}

class _AriChatPanelBody extends StatefulWidget {
  final String appId;
  final String? contextLabel;
  final String headerTitle;
  final String hintText;
  final AriChatTheme theme;
  final Widget? emptyStateWidget;

  const _AriChatPanelBody({
    required this.appId,
    required this.contextLabel,
    required this.headerTitle,
    required this.hintText,
    required this.theme,
    required this.emptyStateWidget,
  });

  @override
  State<_AriChatPanelBody> createState() => _AriChatPanelBodyState();
}

class _AriChatPanelBodyState extends State<_AriChatPanelBody> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int _lastMessageCount = 0;
  late final AriChatProvider _chatProvider;

  @override
  void initState() {
    super.initState();
    _chatProvider = context.read<AriChatProvider>();
    _lastMessageCount = _chatProvider.messages.length;
    _chatProvider.addListener(_onMessagesChanged);
  }

  @override
  void dispose() {
    _chatProvider.removeListener(_onMessagesChanged);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onMessagesChanged() {
    if (!mounted) return;
    final messages = _chatProvider.messages;
    if (messages.length > _lastMessageCount) {
      _lastMessageCount = messages.length;
      _scrollToBottom();
    }
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

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
      details: widget.contextLabel != null
          ? {'currentTab': widget.contextLabel}
          : {},
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutQuart,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<AriChatProvider>();
    final theme = widget.theme;

    return Container(
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        border: Border(
          left: BorderSide(color: theme.borderColor, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
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
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 18,
                    color: theme.primaryColor,
                  ),
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
                          style: TextStyle(
                            color: theme.textSub,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => chatProvider.clearMessages(),
                  icon: Icon(
                    Icons.refresh_rounded,
                    size: 20,
                    color: theme.textSub,
                  ),
                ),
              ],
            ),
          ),

          // Message List
          Expanded(
            child: Container(
              color: theme.backgroundColor.withValues(alpha: 0.3),
              child: chatProvider.messages.isEmpty
                  ? (widget.emptyStateWidget ??
                      ChatEmptyState(theme: theme))
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(20),
                      itemCount: chatProvider.messages.length,
                      itemBuilder: (context, index) {
                        return AriChatMessageItem(
                          message: chatProvider.messages[index],
                          theme: theme,
                        );
                      },
                    ),
            ),
          ),

          // Input
          ChatInputArea(
            controller: _controller,
            onSend: _sendMessage,
            theme: theme,
            hintText: widget.hintText,
          ),
        ],
      ),
    );
  }
}
