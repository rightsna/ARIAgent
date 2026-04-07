import 'package:flutter/material.dart';

class HelpSection extends StatelessWidget {
  const HelpSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF6C63FF).withValues(alpha: 0.1),
            Colors.transparent,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF6C63FF).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Color(0xFF6C63FF)),
              SizedBox(width: 8),
              Text(
                'AI 프로바이더 설정 가이드',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildHelpRow(
            '☁️ OAuth 서비스 연동 (추천)',
            '구독형 서비스를 이미 사용하고 있다면(ChatGPT 등) 별도의 키 발급 없이 편리하게 사용합니다.',
          ),
          const SizedBox(height: 10),
          _buildHelpRow(
            '🔑 API 키 직접 입력',
            '자신이 소유한 API 키를 직접 사용하여 가장 저렴하고 빠른 성능을 보장합니다.',
          ),
          const SizedBox(height: 10),
          _buildHelpRow(
            '🔝 우선순위 오버라이드',
            '상단에 위치한 프로바이더를 먼저 시도하며, 오류 발생 시 아래 순서로 자동 전환됩니다.',
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white12),
          const SizedBox(height: 8),
          const Text(
            '키 발급 주소:',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
          const SizedBox(height: 4),
          const Text(
            '• OpenAI: [platform.openai.com]\n'
            '• Anthropic: [console.anthropic.com]\n'
            '• Gemini: [aistudio.google.com]',
            style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpRow(String title, String desc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF6C63FF),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          desc,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 13,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
