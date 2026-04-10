import 'package:flutter/material.dart';

class ChatSuggestions extends StatelessWidget {
  final Function(String) onSuggestionTap;
  final bool isSetupMode;

  const ChatSuggestions({
    super.key,
    required this.onSuggestionTap,
    this.isSetupMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final chips = isSetupMode ? _setupChips : _normalChips;

    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: chips.map(_suggestionChip).toList(),
      ),
    );
  }

  static const _setupChips = [
    '👋 안녕',
    '🛠️ 사용법을 알려줘',
    '🔑 API 키가 뭐야?',
    '💳 어떤 방식이 제일 저렴해?',
    '⭐ ChatGPT로 연결하고 싶어',
    '🔓 OAuth가 뭐야?',
  ];

  static const _normalChips = [
    '👋 안녕 ARI!',
    '💾 디스크 용량 확인',
    '🔍 파일 찾아줘',
    '1분뒤 알려줘!',
    '🎵 감성적인 노래 들려줘!',
    '비트코인 거래앱 설치해줘!',
    '주식 자동매매 하고 싶어!',
  ];

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
