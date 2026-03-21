import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// 채팅 말풍선 위젯
class ChatBubble extends StatelessWidget {
  final String message;
  final bool isUser;
  final bool isError;
  final bool isSystem;

  const ChatBubble({
    super.key,
    required this.message,
    this.isUser = true,
    this.isError = false,
    this.isSystem = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Center(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFAEDFF7),
              fontSize: 12,
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
          ),
        ),
      );
    }

    final isAssistant = !isUser && !isSystem;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          gradient: isUser
              ? const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF9D4EDD)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isUser
              ? null
              : isError
                  ? const Color(0xFF3D1F1F)
                  : const Color(0xFF232340),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: isError
              ? Border.all(
                  color: const Color(0xFFFF6B6B).withValues(alpha: 0.5),
                )
              : null,
        ),
        child: MarkdownBody(
          data: message,
          styleSheet: MarkdownStyleSheet(
            p: TextStyle(
              color: isError
                  ? const Color(0xFFFF6B6B)
                  : Colors.white.withValues(alpha: 0.9),
              fontSize: 13,
              fontStyle: FontStyle.normal,
              fontWeight: isAssistant ? FontWeight.w400 : FontWeight.w500,
              height: 1.4,
            ),
            strong: TextStyle(
              color: isError
                  ? const Color(0xFFFF6B6B)
                  : Colors.white.withValues(alpha: 1.0),
              fontWeight: FontWeight.bold,
            ),
            em: const TextStyle(fontStyle: FontStyle.italic),
            code: TextStyle(
              backgroundColor: Colors.black.withValues(alpha: 0.3),
              fontFamily: 'monospace',
              fontSize: 12,
            ),
            codeblockDecoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }
}
