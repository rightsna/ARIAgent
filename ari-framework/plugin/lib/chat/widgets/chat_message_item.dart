import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../theme/ari_chat_theme.dart';
import '../providers/chat_provider.dart';

class AriChatMessageItem extends StatelessWidget {
  final AriChatMessage message;
  final AriChatTheme theme;

  const AriChatMessageItem({
    super.key,
    required this.message,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    if (message.isSystem) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 24, left: 38),
        child: Row(
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.primaryColor.withValues(alpha: 0.5),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              message.text,
              style: TextStyle(
                color: theme.textMain.withValues(alpha: 0.4),
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            Container(
              margin: const EdgeInsets.only(top: 4),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [theme.primaryColor, const Color(0xFF64B5F6)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.smart_toy_rounded,
                size: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: message.isUser ? theme.primaryColor : theme.surfaceColor,
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomLeft: Radius.circular(message.isUser ? 16 : 4),
                  bottomRight: Radius.circular(message.isUser ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: message.isUser
                  ? SelectionArea(
                      child: Text(
                        message.text,
                        style: const TextStyle(
                          color: Colors.white,
                          height: 1.4,
                          fontSize: 13,
                        ),
                      ),
                    )
                  : MarkdownBody(
                      data: message.text,
                      selectable: true,
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(
                          color: theme.textMain,
                          height: 1.4,
                          fontSize: 13,
                        ),
                        h1: TextStyle(
                          color: theme.textMain,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          height: 1.4,
                        ),
                        h2: TextStyle(
                          color: theme.textMain,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          height: 1.4,
                        ),
                        h3: TextStyle(
                          color: theme.textMain,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          height: 1.4,
                        ),
                        strong: TextStyle(
                          color: theme.textMain,
                          fontWeight: FontWeight.bold,
                        ),
                        em: TextStyle(
                          color: theme.textSub,
                          fontStyle: FontStyle.italic,
                        ),
                        code: TextStyle(
                          color: theme.primaryColor,
                          backgroundColor:
                              theme.primaryColor.withValues(alpha: 0.08),
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: theme.primaryColor.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        blockquoteDecoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(
                              color: theme.primaryColor.withValues(alpha: 0.4),
                              width: 3,
                            ),
                          ),
                        ),
                        blockquote: TextStyle(
                          color: theme.textSub,
                          fontSize: 13,
                        ),
                        listBullet: TextStyle(
                          color: theme.textMain,
                          fontSize: 13,
                        ),
                        tableBody: TextStyle(
                          color: theme.textMain,
                          fontSize: 12,
                        ),
                        tableHead: TextStyle(
                          color: theme.textMain,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
