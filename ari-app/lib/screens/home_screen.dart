import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../providers/config_provider.dart';

import '../providers/server_provider.dart';
import '../services/app_update_service.dart';
import 'avatar/avatar_tab.dart';
import 'chat/chat_tab.dart';
import 'place/place_tab.dart';
import 'settings/settings_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String _launcherInstallFolderName = 'ARIAgent Launcher';
  static const String _launcherExecutableName = 'ARI_Launcher.exe';

  final AppUpdateService _appUpdateService = const AppUpdateService();
  int _currentTab = 0;
  AppUpdateInfo? _availableUpdate;
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdates();
      _updateTimer = Timer.periodic(const Duration(hours: 3), (timer) {
        _checkForUpdates();
      });
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkForUpdates() async {
    try {
      final update = await _appUpdateService.checkForUpdate();
      if (!mounted) {
        return;
      }

      setState(() {
        _availableUpdate = update;
      });
    } catch (e) {
      debugPrint('Update check error: $e');
    }
  }

  Future<void> _doUpdate() async {
    try {
      if (Platform.isWindows) {
        final launcherPath = _installedWindowsLauncherPath();
        if (launcherPath != null && await File(launcherPath).exists()) {
          await Process.start(
            launcherPath,
            const [],
            mode: ProcessStartMode.detached,
            workingDirectory: File(launcherPath).parent.path,
          );
          exit(0);
        }

        final update = _availableUpdate;
        if (update != null) {
          await _appUpdateService.openDownloadUrl(update);
        }
        return;
      }

      final appPath = '/Applications/ARIAgent.app';
      if (await Directory(appPath).exists()) {
        await Process.run('open', [appPath]);
        exit(0);
      }

      if (!mounted) {
        return;
      }

      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2A),
          title: const Text(
            '앱을 찾을 수 없음',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            '"ARIAgent" 앱을 찾을 수 없습니다.\n앱을 수동으로 종료하신 뒤 다시 실행해 주세요.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                '확인',
                style: TextStyle(color: Color(0xFF6C63FF)),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Update fail: $e');
      exit(0);
    }
  }

  String? _installedWindowsLauncherPath() {
    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData == null || localAppData.isEmpty) {
      return null;
    }

    return '$localAppData\\Programs\\$_launcherInstallFolderName\\$_launcherExecutableName';
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<ConfigProvider>();
    final theme = config.backgroundTheme;
    final isLight = theme == 'light_obsolete'; // Medium gray is dark enough for white icons

    List<Color> gradientColors;
    switch (theme) {
      case 'gray':
        gradientColors = [const Color(0xEE4B4B4B), const Color(0xEE333333)];
        break;
      case 'blue':
        gradientColors = [const Color(0xDD0A1931), const Color(0xEE185ADB)];
        break;
      case 'purple':
        gradientColors = [const Color(0xDD240046), const Color(0xEE5A189A)];
        break;
      case 'dark':
      default:
        gradientColors = [const Color(0xDD0D0D1A), const Color(0xEE12122A)];
        break;
    }

    final borderColor = isLight 
        ? Colors.black.withValues(alpha: 0.05)
        : const Color(0xFF6C63FF).withValues(alpha: 0.15);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: gradientColors,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: borderColor,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            children: [
              _buildDragHandle(isLight),
              if (_availableUpdate != null) _buildUpdateBanner(),
              _buildTabBar(isLight),
              Expanded(child: _buildTabContent()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDragHandle(bool isLight) {
    return DragToMoveArea(
      child: Container(
        height: 24,
        width: double.infinity,
        alignment: Alignment.center,
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: (isLight ? Colors.black : Colors.white).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  Widget _buildUpdateBanner() {
    final update = _availableUpdate!;
    final accentColor = update.mandatory
        ? Colors.orange.shade200
        : const Color(0xFFA7A1FF);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: update.mandatory
            ? const Color(0xFF3A2316)
            : const Color(0xFF241C42),
      ),
      child: Row(
        children: [
          Icon(Icons.system_update_alt_rounded, size: 16, color: accentColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '새 버전 ${update.latestVersion} 사용 가능${update.mandatory ? " · 필수 업데이트" : ""}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.88),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: _doUpdate,
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: accentColor,
            ),
            child: Text(
              '업데이트',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: accentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(bool isLight) {
    return Container(
      margin: const EdgeInsets.only(left: 12, right: 12, top: 10),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isLight ? Colors.black.withValues(alpha: 0.05) : const Color(0xFF0A0A1A),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _tabItem(0, Icons.chat_bubble_rounded, '채팅', isLight),
          _tabItem(1, Icons.explore_rounded, '플레이스', isLight),
          _tabItem(2, Icons.person_rounded, '아바타', isLight),
          _tabItem(3, Icons.settings_rounded, '설정', isLight),
        ],
      ),
    );
  }

  Widget _tabItem(int index, IconData icon, String label, bool isLight) {
    final isActive = _currentTab == index;
    final unselectedColor = isLight ? Colors.black.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.3);
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _currentTab = index;
        }),
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
                icon,
                size: 14,
                color: isActive
                    ? const Color(0xFF6C63FF)
                    : unselectedColor,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isActive
                      ? const Color(0xFF6C63FF)
                      : unselectedColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    // 채팅(0)과 설정(3) 탭을 제외한 나머지 탭(플레이스, 아바타 등)은 서버 연결이 필수이므로 체크
    if (_currentTab == 1 || _currentTab == 2) {
      return ListenableBuilder(
        listenable: ServerProvider(),
        builder: (context, _) {
          if (!ServerProvider().isRunning) {
            return _buildServerRequiredOverlay();
          }
          return _buildActiveTabContent();
        },
      );
    }
    return _buildActiveTabContent();
  }

  Widget _buildActiveTabContent() {
    switch (_currentTab) {
      case 0:
        return ChatTab(
          onSettingsTap: () {
            setState(() {
              _currentTab = 3;
            });
          },
        );
      case 1:
        return const PlaceTab();
      case 2:
        return const AvatarTab();
      case 3:
        return const SettingsTab();
      default:
        return ChatTab(
          onSettingsTap: () {
            setState(() {
              _currentTab = 3;
            });
          },
        );
    }
  }

  Widget _buildServerRequiredOverlay() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: Colors.white.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              '에이전트 연결 필요',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '이 기능을 사용하려면 에이전트 실행이 필요합니다.\n설정 탭에서 에이전트를 켜 주세요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _currentTab = 3;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text(
                '설정으로 이동',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
