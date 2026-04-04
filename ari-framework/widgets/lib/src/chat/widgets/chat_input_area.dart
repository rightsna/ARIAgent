import 'package:flutter/material.dart';
import '../../theme/ari_chat_theme.dart';

class ChatInputArea extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final AriChatTheme theme;
  final String hintText;

  const ChatInputArea({
    super.key,
    required this.controller,
    required this.onSend,
    required this.theme,
    this.hintText = '메시지를 입력하세요...',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        16 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: theme.backgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.borderColor),
              ),
              child: TextField(
                controller: controller,
                style: TextStyle(color: theme.textMain, fontSize: 13),
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: TextStyle(color: theme.hintColor, fontSize: 13),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.primaryColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: onSend,
              icon: const Icon(Icons.send_rounded, size: 20, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
