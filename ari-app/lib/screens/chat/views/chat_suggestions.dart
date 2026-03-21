import 'package:flutter/material.dart';

class ChatSuggestions extends StatelessWidget {
  final Function(String) onSuggestionTap;

  const ChatSuggestions({super.key, required this.onSuggestionTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          _suggestionChip('👋 안녕 ARI!'),
          _suggestionChip('💾 디스크 용량 확인'),
          _suggestionChip('🔍 파일 찾아줘'),
          _suggestionChip('1분뒤 알려줘!'),
          _suggestionChip('🎵 감성적인 노래 들려줘!'),
          _suggestionChip('쓰레드에 안녕이라고 포스팅해줘'),
          _suggestionChip('메모장에 일기 써줘!'),
        ],
      ),
    );
  }

  Widget _suggestionChip(String text) {
    return GestureDetector(
      onTap: () => onSuggestionTap(text),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}
