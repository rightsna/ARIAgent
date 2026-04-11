import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AboutSettings extends StatelessWidget {
  const AboutSettings({super.key});

  static const Color _accentColor = Color(0xFF6C63FF);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeroSection(),
          const SizedBox(height: 32),
          _buildInfoSection(
            '함께 일하고, 함께 쉬는 AI',
            'ARI Agent는 사용자의 작업과 놀이 환경을 이해하고, '
                '기억과 실행을 바탕으로 함께하는 AI 동반자입니다. '
                '질문에 답하는 데서 멈추지 않고, 사용자의 흐름 안에서 자연스럽게 이어지는 경험을 지향합니다.',
          ),
          const SizedBox(height: 24),
          _buildPhilosophySection(),
          const SizedBox(height: 24),
          _buildFeaturesGrid(),
          const SizedBox(height: 32),
          _buildUsageSection(),
          const SizedBox(height: 32),
          const Divider(color: Colors.white12),
          const SizedBox(height: 16),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              final version = snapshot.data?.version ?? '0.0.0';
              final buildNumber = snapshot.data?.buildNumber ?? '0';
              return Center(
                child: Text(
                  'Version $version (Build $buildNumber)\n© 2026 ARI Team',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6C63FF), Color(0xFF9D4EDD)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _accentColor.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              size: 48,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'ARI Agent',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          Text(
            'Work, Play, Stay Together',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          content,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 14,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturesGrid() {
    return Column(
      children: [
        Row(
          children: [
            _buildFeatureCard(
              Icons.chat_bubble_rounded,
              '기억하는 대화',
              '이전 맥락을 바탕으로 더 자연스럽게 이어집니다.',
            ),
            const SizedBox(width: 12),
            _buildFeatureCard(
              Icons.play_circle_outline_rounded,
              '실행으로 이어짐',
              '말만 하지 않고 필요한 행동과 흐름으로 이어집니다.',
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildFeatureCard(
              Icons.apps_rounded,
              '앱과 함께 움직임',
              '여러 앱을 오가며 하나의 경험처럼 연결합니다.',
            ),
            const SizedBox(width: 12),
            _buildFeatureCard(
              Icons.sports_esports_rounded,
              '일과 놀이를 함께',
              '집중하는 시간도 쉬는 시간도 같은 흐름 안에서 함께합니다.',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPhilosophySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ARI가 중요하게 생각하는 것',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildPhilosophyItem(
          '사용자의 공간 안에 머무르기',
          '멀리 있는 서비스처럼 느껴지기보다, 내 자리에 함께 있는 존재처럼 작동합니다.',
        ),
        _buildPhilosophyItem(
          '대화보다 실제 도움',
          '좋은 말보다 다음 행동으로 이어지는 도움을 더 중요하게 생각합니다.',
        ),
        _buildPhilosophyItem(
          '생산성만이 아닌 사용감',
          '일할 때만 유용한 도구가 아니라, 쉬고 놀 때도 자연스럽게 곁에 두는 동반자를 지향합니다.',
        ),
      ],
    );
  }

  Widget _buildUsageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '이렇게 사용해보세요!',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildUsageItem('“오늘 할 일 같이 정리해줘”', '일상 정리'),
        _buildUsageItem('“30분 뒤에 커피 마시라고 알려줘”', '리마인더'),
        _buildUsageItem('“지금 하던 작업 맥락 이어서 도와줘”', '업무 흐름 이어가기'),
        _buildUsageItem('“게임하기 전에 필요한 것들 같이 챙겨줘”', '놀이 준비'),
        _buildUsageItem('“방금 우리 대화 내용 기억해?”', '개인화된 관계'),
      ],
    );
  }

  Widget _buildPhilosophyItem(String title, String description) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsageItem(String prompt, String category) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _accentColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accentColor.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.tips_and_updates_rounded,
            color: _accentColor,
            size: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prompt,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  category,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(IconData icon, String title, String desc) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        height: 140,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: _accentColor, size: 24),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              desc,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
