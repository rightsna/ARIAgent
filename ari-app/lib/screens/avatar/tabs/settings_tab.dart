import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ari_plugin/ari_plugin.dart';
import 'token_management_screen.dart';
import '../widgets/tab_section_header.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Navigator(
      onGenerateRoute: (settings) => MaterialPageRoute(
        builder: (context) => const _SettingsTabContent(),
      ),
    );
  }
}

class _SettingsTabContent extends StatelessWidget {
  const _SettingsTabContent();

  @override
  Widget build(BuildContext context) {
    final avatar = context.watch<AvatarProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TabSectionHeader(
            icon: Icons.folder_outlined,
            title: '데이터 관리',
            description: '에이전트의 기억과 대화 기록, 토큰을 관리해요.',
          ),
          _buildNavigationButton(
            context,
            icon: Icons.token_outlined,
            title: '토큰 관리',
            description: '이 아바타의 AI 모델 토큰 사용량을 확인하고 한도를 설정합니다.',
            destination: TokenManagementScreen(agentId: avatar.currentAvatarId),
            destinationTitle: '토큰 관리',
          ),
          const SizedBox(height: 12),
          _buildSettingsButton(
            context,
            icon: Icons.psychology_outlined,
            title: '기억 초기화',
            description:
                '이 아바타가 학습하고 기억한 벡터 데이터를 초기화합니다.\n장기 기억이 삭제되지만 페르소나는 유지됩니다.',
            onPressed: () => _confirmAction(
              context,
              '기억 초기화',
              '정말로 이 아바타의 모든 기억을 초기화하시겠습니까?\n이 작업은 되돌릴 수 없습니다.',
              () => avatar.initializeMemory(),
            ),
          ),
          const SizedBox(height: 12),
          _buildSettingsButton(
            context,
            icon: Icons.chat_bubble_outline_rounded,
            title: '대화 초기화',
            description: '이 아바타와 나눈 모든 채팅 로그를 삭제합니다.\n기록 탭의 내용이 모두 비워집니다.',
            onPressed: () => _confirmAction(
              context,
              '대화 초기화',
              '현재 아바타와의 모든 대화 내용을 삭제하시겠습니까?',
              () async {
                final avatarId = avatar.currentAvatarId;
                if (context.mounted) {
                  await context.read<AriChatProvider>().clearServerHistory(
                    avatarId,
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 24),
          const TabSectionHeader(
            icon: Icons.warning_amber_outlined,
            title: '위험 구역',
            description: '한 번 실행하면 되돌릴 수 없어요. 신중하게 눌러주세요.',
          ),
          _buildSettingsButton(
            context,
            icon: Icons.delete_forever_outlined,
            title: '아바타 삭제',
            description:
                '이 아바타의 모든 데이터(프로필, 로그, 설정)를 영구히 삭제합니다.\n기본 아바타(ARI)는 삭제할 수 없습니다.',
            isCritical: true,
            onPressed: avatar.currentAvatarId == 'default'
                ? null
                : () => _confirmAction(
                    context,
                    '아바타 삭제',
                    '정말로 "${avatar.name}" 아바타를 영구 삭제하시겠습니까?\n모든 관련 데이터가 즉시 삭제됩니다.',
                    () => avatar.deleteAvatar(),
                  ),
          ),
          const SizedBox(height: 12),
          _buildSettingsButton(
            context,
            icon: Icons.folder_open_outlined,
            title: '설정 폴더 열기',
            description: '모든 아바타 정보와 로그가 저장된 .ari-agent 폴더를 탐색기에서 엽니다.',
            isCritical: true,
            onPressed: () async {
              final home =
                  Platform.environment['HOME'] ??
                  Platform.environment['USERPROFILE'];

              if (home != null) {
                final path = '$home/.ari-agent';
                final uri = Uri.file(path);

                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                } else {
                  // Fallback for directories on some platforms
                  await launchUrl(Uri.parse('file://$path'));
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('사용자 홈 디렉토리를 찾을 수 없습니다.')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButton(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required Widget destination,
    required String destinationTitle,
  }) {
    const color = Color(0xFF6C63FF);

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => _AvatarSettingsSubPage(
              title: destinationTitle,
              child: destination,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withValues(alpha: 0.2),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildSettingsButton(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback? onPressed,
    bool isCritical = false,
  }) {
    final bool isDisabled = onPressed == null;
    final color = isCritical
        ? const Color(0xFFFF6B6B)
        : const Color(0xFF6C63FF);

    return Opacity(
      opacity: isDisabled ? 0.4 : 1.0,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withOpacity(isDisabled ? 0.05 : 0.2),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isDisabled ? Colors.white54 : Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 11,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isDisabled)
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withOpacity(0.2),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmAction(
    BuildContext context,
    String title,
    String message,
    Future<void> Function() action,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await action();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$title 완료되었습니다.'),
                    backgroundColor: const Color(0xFF6C63FF),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white, // 텍스트 컬러 명시
            ),
            child: const Text(
              '확인',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarSettingsSubPage extends StatelessWidget {
  final String title;
  final Widget child;

  const _AvatarSettingsSubPage({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
