import 'package:flutter/material.dart';

class HomeTabDefinition {
  final int index;
  final IconData icon;
  final String label;
  final bool requiresServer;

  const HomeTabDefinition({
    required this.index,
    required this.icon,
    required this.label,
    this.requiresServer = false,
  });
}

const homeTabs = <HomeTabDefinition>[
  HomeTabDefinition(
    index: 0,
    icon: Icons.chat_bubble_rounded,
    label: '채팅',
  ),
  HomeTabDefinition(
    index: 1,
    icon: Icons.explore_rounded,
    label: '플레이스',
    requiresServer: true,
  ),
  HomeTabDefinition(
    index: 2,
    icon: Icons.person_rounded,
    label: '아바타',
    requiresServer: true,
  ),
  HomeTabDefinition(
    index: 3,
    icon: Icons.settings_rounded,
    label: '설정',
  ),
];

class HomeTabBar extends StatelessWidget {
  final int currentTab;
  final bool isLight;
  final ValueChanged<int> onTabSelected;

  const HomeTabBar({
    super.key,
    required this.currentTab,
    required this.isLight,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 12, right: 12, top: 10),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isLight
            ? Colors.black.withValues(alpha: 0.05)
            : const Color(0xFF0A0A1A),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: homeTabs
            .map(
              (tab) => _HomeTabItem(
                tab: tab,
                currentTab: currentTab,
                isLight: isLight,
                onTap: onTabSelected,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _HomeTabItem extends StatelessWidget {
  final HomeTabDefinition tab;
  final int currentTab;
  final bool isLight;
  final ValueChanged<int> onTap;

  const _HomeTabItem({
    required this.tab,
    required this.currentTab,
    required this.isLight,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = currentTab == tab.index;
    final unselectedColor = isLight
        ? Colors.black.withValues(alpha: 0.3)
        : Colors.white.withValues(alpha: 0.3);

    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(tab.index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF6C63FF).withValues(alpha: 0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isActive
                ? Border.all(
                    color: const Color(0xFF6C63FF).withValues(alpha: 0.4),
                  )
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                tab.icon,
                size: 14,
                color: isActive ? const Color(0xFF6C63FF) : unselectedColor,
              ),
              const SizedBox(width: 4),
              Text(
                tab.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isActive ? const Color(0xFF6C63FF) : unselectedColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
