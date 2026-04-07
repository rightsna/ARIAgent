import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AboutSettings extends StatelessWidget {
  const AboutSettings({super.key});

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
            '무한한 가능성의 동반자, ARI',
            'ARI(Avatar AI Assistant)는 단순한 인공지능 그 이상을 지향합니다. '
                '여러분의 데스크탑 환경에서 자연스럽게 대화하고, 도구를 실행하며, '
                '일상의 생산성을 극대화하는 가장 완벽한 AI 에이전트입니다.',
          ),
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
            color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
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
            'Your Next-Gen AI Assistant',
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
              '자연어 대화',
              '인간처럼 대화하고 맥락을 기억합니다.',
            ),
            const SizedBox(width: 12),
            _buildFeatureCard(
              Icons.terminal_rounded,
              '도구 실행',
              'BASH 실행 등 시스템 제어가 가능합니다.',
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildFeatureCard(
              Icons.extension_rounded,
              '멀티 프로바이더',
              'OpenAI, Anthropic 등 최고 모델 지원',
            ),
            const SizedBox(width: 12),
            _buildFeatureCard(
              Icons.memory_rounded,
              '장기 기억',
              '당신과의 추억을 소중히 기록합니다.',
            ),
          ],
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
        _buildUsageItem('“오늘의 주요 뉴스를 요약해줘”', '정보 검색 및 요약'),
        _buildUsageItem('“이 프로젝트 폴더에서 git status 보여줘”', '명령어 실행 및 개발 보조'),
        _buildUsageItem('“30분 뒤에 커피 마시라고 알려줘”', '일정 등록 및 리마인더'),
        _buildUsageItem('“방금 우리 대화 내용 기억해?”', '장기 기억 기반 개인화'),
      ],
    );
  }

  Widget _buildUsageItem(String prompt, String category) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF6C63FF).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.tips_and_updates_rounded,
            color: Color(0xFF6C63FF),
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
            Icon(icon, color: const Color(0xFF6C63FF), size: 24),
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
