import 'package:flutter/material.dart';
import 'package:ari_plugin/ari_plugin.dart';

/// 채팅 입력 위젯
class ChatInput extends StatefulWidget {
  final Function(String) onSubmit;
  final VoidCallback? onCancel;
  final bool isLoading;

  const ChatInput({
    super.key,
    required this.onSubmit,
    this.onCancel,
    this.isLoading = false,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final TextEditingController _controller = TextEditingController();

  void _handleSubmit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSubmit(text);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const theme = AriChatTheme(
      primaryColor: Color(0xFF6C63FF),
      surfaceColor: Colors.transparent,
      backgroundColor: Colors.transparent,
      textMain: Colors.white,
      textSub: Color(0xFF9E9EB8),
      borderColor: Colors.transparent,
      borderWidth: 0,
      hintColor: Color(0x66FFFFFF),
    );

    return ChatInputArea(
      controller: _controller,
      onSend: _handleSubmit,
      theme: theme,
      hintText: 'ARI에게 물어보세요...',
      isLoading: widget.isLoading,
      onCancel: widget.onCancel,
      actionButtonBuilder: (context, onPressed, isLoading) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: GestureDetector(
          onTap: onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: isLoading
                  ? null
                  : const LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFF9D4EDD)],
                    ),
              color: isLoading ? const Color(0xFF333344) : null,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              child: isLoading
                  ? const Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF6C63FF),
                          ),
                        ),
                        Icon(Icons.stop_rounded, color: Colors.white, size: 16),
                      ],
                    )
                  : const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
            ),
          ),
        ),
      ),
      layoutBuilder: (context, textField, actionButton) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E).withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: textField,
              ),
            ),
            const SizedBox(width: 8),
            actionButton,
          ],
        ),
      ),
    );
  }
}
