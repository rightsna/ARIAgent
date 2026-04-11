import 'package:flutter/material.dart';
import '../../theme/ari_chat_theme.dart';

class ChatDefaultHeader extends StatelessWidget {
  final String headerTitle;
  final String? contextLabel;
  final AriChatTheme theme;
  final VoidCallback? onReset;

  const ChatDefaultHeader({
    super.key,
    required this.headerTitle,
    required this.contextLabel,
    required this.theme,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
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
                  headerTitle,
                  style: TextStyle(
                    color: theme.textMain,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                if (contextLabel != null)
                  Text(
                    contextLabel!,
                    style: TextStyle(color: theme.textSub, fontSize: 11),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: onReset,
            icon: Icon(Icons.refresh_rounded, size: 20, color: theme.textSub),
          ),
        ],
      ),
    );
  }
}
