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
import 'home/home_constants.dart';
import 'home/home_drag_handle.dart';
import 'home/home_server_required_overlay.dart';
import 'home/home_tab_bar.dart';
import 'home/home_update_banner.dart';
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
    final isWindows = Platform.isWindows;
    final isLight =
        theme == 'light_obsolete'; // Medium gray is dark enough for white icons

    final backgroundColor = homeBackgroundColorForTheme(theme);

    final windowContent = Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: null,
        boxShadow: isWindows
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
      ),
      child: Column(
        children: [
          HomeDragHandle(isLight: isLight),
          if (_availableUpdate != null)
            HomeUpdateBanner(
              update: _availableUpdate!,
              onUpdatePressed: _doUpdate,
            ),
          HomeTabBar(
            currentTab: _currentTab,
            isLight: isLight,
            onTabSelected: (index) {
              setState(() {
                _currentTab = index;
              });
            },
          ),
          Expanded(child: _buildTabContent()),
        ],
      ),
    );

    final windowShell = ClipRRect(
      borderRadius: BorderRadius.circular(homeWindowRadius),
      child: ColoredBox(
        color: backgroundColor,
        child: Padding(
          padding: const EdgeInsets.all(homeWindowResizePadding),
          child: windowContent,
        ),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: isWindows
          ? DragToResizeArea(resizeEdgeSize: 8, child: windowShell)
          : windowContent,
    );
  }

  Widget _buildTabContent() {
    final activeTab = homeTabs.firstWhere((tab) => tab.index == _currentTab);

    if (activeTab.requiresServer) {
      return ListenableBuilder(
        listenable: ServerProvider(),
        builder: (context, _) {
          if (!ServerProvider().isRunning) {
            return HomeServerRequiredOverlay(
              onGoToSettings: () {
                setState(() {
                  _currentTab = 3;
                });
              },
            );
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
}
