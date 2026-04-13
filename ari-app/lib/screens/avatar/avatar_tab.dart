import 'package:ari_plugin/ari_plugin.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'tabs/profile_tab.dart';
import 'tabs/memory_tab.dart';
import 'schedule/schedule_tab.dart';
import 'tabs/apps_tab.dart';
import 'tabs/skills_tab.dart';
import 'tabs/tools_tab.dart';
import 'tabs/channels_tab.dart';
import 'tabs/settings_tab.dart';
import 'package:flutter/gestures.dart';
import '../../providers/config_provider.dart';

/// 마우스 드래그로 스크롤 가능하게 하는 커스텀 ScrollBehavior
class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
  };
}

class AvatarTab extends StatefulWidget {
  const AvatarTab({super.key});

  @override
  State<AvatarTab> createState() => _AvatarTabState();
}

class _AvatarTabState extends State<AvatarTab> {
  @override
  Widget build(BuildContext context) {
    final avatar = context.watch<AvatarProvider>();
    final config = context.watch<ConfigProvider>();
    final showAdvanced = config.showAdvancedDeveloperUI;
    final isExperimental = config.isExperimentalEnabled;

    final List<Widget> tabs = [
      const Tab(text: 'Profile'),
      const Tab(text: 'Schedule'),
      const Tab(text: 'Memory'),
      const Tab(text: 'Apps'),
      if (showAdvanced) const Tab(text: 'Skills'),
      if (showAdvanced) const Tab(text: 'Tools'),
      const Tab(text: 'Channels'),
      const Tab(text: 'Settings'),
    ];

    final List<Widget> views = [
      ProfileTab(),
      const ScheduleTab(),
      const MemoryTab(),
      const AppsTab(),
      if (showAdvanced) SkillsTab(),
      if (showAdvanced) ToolsTab(),
      ChannelsTab(),
      SettingsTab(),
    ];

    return DefaultTabController(
      key: ValueKey(showAdvanced), // 고급 기능 표시 상태가 바뀔 때 컨트롤러 초기화
      length: tabs.length,
      child: Column(
        children: [
          Container(
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
            ),
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicator: const UnderlineTabIndicator(
                borderSide: BorderSide(color: Color(0xFF6C63FF), width: 2),
              ),
              indicatorSize: TabBarIndicatorSize.label,
              dividerColor: Colors.transparent,
              labelColor: const Color(0xFF6C63FF),
              unselectedLabelColor: Colors.white.withValues(alpha: 0.4),
              overlayColor: WidgetStateProperty.resolveWith<Color?>((
                Set<WidgetState> states,
              ) {
                if (states.contains(WidgetState.hovered)) {
                  return Colors.white.withValues(alpha: 0.05);
                }
                return Colors.transparent;
              }),
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              tabs: tabs,
            ),
          ),
          Expanded(
            child: ScrollConfiguration(
              behavior: AppScrollBehavior(),
              child: TabBarView(
                children: views,
              ),
            ),
          ),
          _buildBottomSelector(context, avatar),
        ],
      ),
    );
  }

  Widget _buildBottomSelector(BuildContext context, AvatarProvider avatar) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF13132B).withValues(alpha: 0.9), // 배경색을 조금 더 어둡게
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '현재 에이전트',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 10,
                  ),
                ),
                Text(
                  avatar.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _showAvatarGrid(context),
            icon: const Icon(Icons.grid_view_rounded, size: 16),
            label: const Text('목록'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF).withValues(alpha: 0.2),
              foregroundColor: const Color(0xFF6C63FF),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Color(0xFF6C63FF), width: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAvatarGrid(BuildContext context) {
    final avatarProv = context.read<AvatarProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          maxChildSize: 0.9,
          minChildSize: 0.3,
          expand: false,
          builder: (context, scrollController) {
            return ListenableBuilder(
              listenable: avatarProv,
              builder: (context, _) {
                final agents = avatarProv.allAvatars;
                final currentId = avatarProv.currentAvatarId;

                return Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF13132B).withValues(alpha: 0.95),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          '에이전트 선택',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        child: GridView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.all(20),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 0.8,
                              ),
                          itemCount: agents.length + 1,
                          itemBuilder: (context, index) {
                            if (index == agents.length) {
                              // 🔹 신규 추가 버튼
                              return _buildAddButton(context);
                            }
                            final agent = agents[index];
                            final isSelected = agent.id == currentId;
                            return _buildAvatarCard(context, agent, isSelected);
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildAvatarCard(
    BuildContext context,
    dynamic agent,
    bool isSelected,
  ) {
    final imagePath = agent.imagePath?.toString().trim() ?? '';
    final isAssetImage = imagePath.startsWith('assets/');
    final imageFile = imagePath.isNotEmpty && !isAssetImage
        ? File(imagePath)
        : null;
    final hasImage =
        isAssetImage || (imageFile != null && imageFile.existsSync());

    return GestureDetector(
      onTap: () {
        context.read<AvatarProvider>().switchAvatar(agent.id);
        Navigator.pop(context);
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF6C63FF).withValues(alpha: 0.15)
              : const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF6C63FF)
                : Colors.white.withValues(alpha: 0.05),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: const Color(0xFF13132B),
              child: ClipOval(
                child: hasImage
                    ? (isAssetImage
                          ? Image.asset(
                              imagePath,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Image.asset(
                                'assets/images/avatar.png',
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Image.file(
                              imageFile!,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Image.asset(
                                'assets/images/avatar.png',
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                              ),
                            ))
                    : Image.asset(
                        'assets/images/avatar.png',
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              agent.name,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
            if (isSelected)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'ACTIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final id = 'agent_${DateTime.now().millisecondsSinceEpoch}';
        await context.read<AvatarProvider>().createAndSwitchAvatar(id, '아리');
        // 전환 후 시각적 피드백을 위해 바텀시트를 닫거나 유지할 수 있음. 여기서는 닫음.
        if (context.mounted) Navigator.pop(context);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            style: BorderStyle.solid,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_circle_outline_rounded,
              color: Colors.white.withValues(alpha: 0.3),
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              '새로운 아바타',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
