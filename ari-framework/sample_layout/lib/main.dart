import 'package:ari_plugin/ari_plugin.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final echoState = EchoState();

  // 1. 소켓 브릿지 초기화
  AriAgent.init();

  // 2. 프로토콜 핸들러 인스턴스 생성 및 시작
  // AppProtocolHandler는 상속 대신 생성자 콜백을 사용합니다.
  final handler = AppProtocolHandler(
    appId: 'sample_echo',
    onCommand: (cmd, params) {
      echoState.update(cmd, params);
      return {'status': 'success', 'echo': params};
    },
  );
  handler.start();

  // 3. 연결 시작
  AriAgent.connect();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AriChatProvider()),
        ChangeNotifierProvider.value(value: echoState),
      ],
      child: const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: SampleHomeScreen(),
      ),
    ),
  );
}

class EchoState extends ChangeNotifier {
  String text = '명령 대기 중...';
  void update(String cmd, Map params) {
    text = '$cmd: $params';
    notifyListeners();
  }
}

class SampleHomeScreen extends StatelessWidget {
  const SampleHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AriBaseLayout(
      appId: 'sample_echo',
      appName: '에코 샘플',
      body: Center(
        child: Text(
          context.watch<EchoState>().text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14),
        ),
      ),
    );
  }
}
