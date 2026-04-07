import 'package:flutter/material.dart';
import '../../theme/ari_chat_theme.dart';

class ChatEmptyState extends StatelessWidget {
  final AriChatTheme theme;
  final String message;
  final IconData icon;

  const ChatEmptyState({
    super.key,
    required this.theme,
    this.message = '무엇을 도와드릴까요?',
    this.icon = Icons.forum_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: theme.primaryColor.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: theme.primaryColor.withValues(alpha: 0.3)),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: theme.textMain,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
