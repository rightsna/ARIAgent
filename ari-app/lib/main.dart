import 'dart:io';
import 'dart:async';
import 'package:path/path.dart' as p;

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:system_tray/system_tray.dart';

import 'screens/home_screen.dart';
import 'repositories/config_repository.dart';
import 'providers/config_provider.dart';
import 'providers/home_assistant_provider.dart';
import 'providers/ari_app_provider.dart';
import 'providers/server_provider.dart';
import 'services/desktop_notification_service.dart';
import 'screens/place/providers/place_agent_status_provider.dart';

import 'package:ari_plugin/ari_plugin.dart';
import 'package:flutter/gestures.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Hive 저장 경로 설정 (~/.ari-agent/hive)
  final String home =
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '';
  final hivePath = p.join(home, '.ari-agent', 'hive');
  final hiveDir = Directory(hivePath);
  if (!hiveDir.existsSync()) {
    hiveDir.createSync(recursive: true);
  }
  Hive.init(hivePath);

  // PackageInfo 초기화
  final packageInfo = await PackageInfo.fromPlatform();
  final version = packageInfo.version;

  // Repository 초기화
  final configRepo = ConfigRepository();
  await configRepo.init();

  // Provider 초기화
  await ConfigProvider().init();
  await AvatarProvider().init();
  await AriAppProvider().init();
  await PlaceAgentStatusProvider().init();

  // AriAgent 초기화 (Repository에서 URL 가져옴)
  AriAgent.init(url: configRepo.wsUrl);

  // 에이전트 시작 (비동기)
  unawaited(ServerProvider().start(version: version));

  unawaited(AriTaskProvider().init());

  // window_manager 초기화
  await windowManager.ensureInitialized();

  const windowSize = Size(450, 720);

  WindowOptions windowOptions = const WindowOptions(
    size: windowSize,
    minimumSize: Size(300, 400),
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: true,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    if (Platform.isWindows) {
      await windowManager.setAsFrameless();
    }
    await windowManager.setAlwaysOnTop(ConfigProvider().isPinned);
    await windowManager.setHasShadow(false);
    await windowManager.setResizable(true);
    await windowManager.setMaximumSize(const Size(1200, 2000));
    await windowManager.setPosition(const Offset(20, 100));
    await windowManager.setPreventClose(true);
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const ARIApp());
}

class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
  };
}

class ARIApp extends StatefulWidget {
  const ARIApp({super.key});

  @override
  State<ARIApp> createState() => _ARIAppState();
}

class _ARIAppState extends State<ARIApp> with WindowListener {
  final SystemTray _systemTray = SystemTray();
  final Menu _menu = Menu();
  bool _isShuttingDown = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _initSystemTray();
    windowManager.setPreventClose(true);
    unawaited(DesktopNotificationService.instance.init());
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    unawaited(DesktopNotificationService.instance.dispose());
    super.dispose();
  }

  Future<void> _initSystemTray() async {
    String iconPath = Platform.isWindows
        ? 'assets/images/app_icon.ico'
        : 'assets/images/logo_tray.png';
    await _systemTray.initSystemTray(iconPath: iconPath);

    await _menu.buildFrom([
      MenuItemLabel(
        label: 'ARI 열기',
        onClicked: (menuItem) => windowManager.show(),
      ),
      MenuItemLabel(
        label: 'ARI 숨기기',
        onClicked: (menuItem) => windowManager.hide(),
      ),
      MenuSeparator(),
      MenuItemLabel(label: '종료', onClicked: (menuItem) async => _shutdownApp()),
    ]);

    await _systemTray.setContextMenu(_menu);

    _systemTray.registerSystemTrayEventHandler((eventName) {
      if (eventName == kSystemTrayEventClick) {
        Platform.isMacOS
            ? _systemTray.popUpContextMenu()
            : windowManager.show();
      } else if (eventName == kSystemTrayEventRightClick) {
        Platform.isMacOS
            ? windowManager.show()
            : _systemTray.popUpContextMenu();
      }
    });
  }

  @override
  void onWindowClose() async {
    await windowManager.hide();
  }

  @override
  void onWindowRestore() {
    windowManager.show();
    windowManager.focus();
  }

  Future<void> _shutdownApp() async {
    if (_isShuttingDown) {
      return;
    }
    _isShuttingDown = true;

    try {
      await DesktopNotificationService.instance.dispose();
    } catch (_) {}

    try {
      await ServerProvider().stop();
    } catch (_) {}

    try {
      await windowManager.setPreventClose(false);
    } catch (_) {}

    try {
      await windowManager.destroy();
    } catch (_) {}

    exit(0);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ConfigProvider>.value(value: ConfigProvider()),
        ChangeNotifierProvider<AvatarProvider>.value(value: AvatarProvider()),
        ChangeNotifierProvider<ServerProvider>.value(value: ServerProvider()),
        ChangeNotifierProvider<AriTaskProvider>.value(value: AriTaskProvider()),
        ChangeNotifierProvider<HomeAssistantProvider>.value(
          value: HomeAssistantProvider(),
        ),
        ChangeNotifierProvider<AriAppProvider>.value(value: AriAppProvider()),
        ChangeNotifierProvider<PlaceAgentStatusProvider>.value(
          value: PlaceAgentStatusProvider(),
        ),
        ChangeNotifierProxyProvider<ConfigProvider, AriChatProvider>(
          create: (_) {
            final chatProvider = AriChatProvider();
            chatProvider.showTaskMessages = ConfigProvider().showTaskMessages;
            return chatProvider;
          },
          update: (_, config, chatProvider) {
            final provider = chatProvider ?? AriChatProvider();
            provider.showTaskMessages = config.showTaskMessages;
            return provider;
          },
        ),
      ],
      child: MaterialApp(
        title: 'ARI Agent',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          fontFamily: 'Pretendard',
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF6C63FF),
            secondary: Color(0xFF9D4EDD),
            surface: Color(0xFF12122A),
          ),
          scaffoldBackgroundColor: Colors.transparent,
        ),
        scrollBehavior: AppScrollBehavior(),
        home: const HomeScreen(),
      ),
    );
  }
}
