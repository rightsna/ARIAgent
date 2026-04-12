import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// 채팅 말풍선 위젯
class ChatBubble extends StatelessWidget {
  final String message;
  final bool isUser;
  final bool isError;
  final bool isSystem;
  final bool isNotice;

  const ChatBubble({
    super.key,
    required this.message,
    this.isUser = true,
    this.isError = false,
    this.isSystem = false,
    this.isNotice = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isNotice) {
      return SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Divider(
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.25),
                  height: 1,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.notifications_rounded,
                size: 11,
                color: Color(0xFF9D8FFF),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFF9D8FFF),
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Divider(
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.25),
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      );
    }

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
    final showCopyButton = isAssistant;
    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * (showCopyButton ? 0.72 : 0.8),
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
    );

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            bubble,
            if (showCopyButton) ...[
              const SizedBox(width: 4),
              _CopyButton(message: message),
            ],
          ],
        ),
      ),
    );
  }
}

class _CopyButton extends StatelessWidget {
  final String message;

  const _CopyButton({required this.message});

  Future<void> _handleCopy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: message));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('메시지를 복사했습니다.')));
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleCopy(context),
        borderRadius: BorderRadius.circular(10),
        child: const SizedBox(
          width: 26,
          height: 26,
          child: Icon(
            Icons.copy_rounded,
            size: 13,
            color: Colors.white70,
          ),
        ),
      ),
    );
  }
}
