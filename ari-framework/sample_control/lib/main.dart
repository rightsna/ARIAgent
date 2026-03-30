import 'package:flutter/material.dart';
import 'package:ari_plugin/ari_plugin.dart';
import 'protocol_config.dart';
import 'widgets/app_info_card.dart';
import 'widgets/log_output_view.dart';
import 'widgets/test_button.dart';
import 'widgets/section_header.dart';
import 'providers/log_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  AriAgent.init();
  AriAgent.connect();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AriFramework Sample',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      home: const SampleHome(),
    );
  }
}

class SampleHome extends StatefulWidget {
  const SampleHome({super.key});

  @override
  State<SampleHome> createState() => _SampleHomeState();
}

class _SampleHomeState extends State<SampleHome> {
  late final AppProtocolHandler protocolHandler;
  final TextEditingController _inputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    protocolHandler = ProtocolConfig.createHandler();
    protocolHandler.start();
    LogProvider().add('App initialized with appId: ${ProtocolConfig.appId}');
  }

  @override
  void dispose() {
    protocolHandler.stop();
    _inputController.dispose();
    super.dispose();
  }

  void _sendCommandToAgent() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    // 에이전트가 자연스럽게 인지하도록 보고 형식으로 전송
    AriAgent.emit('/APP.REPORT', {
      'appId': ProtocolConfig.appId,
      'message': text,
      'type': 'info',
    });

    LogProvider().add('SEND TO AGENT: $text');
    _inputController.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('AriFramework Sample'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 7,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- App Info Card ---
                    AppInfoCard(appId: protocolHandler.appId),
                    const SizedBox(height: 20),

                    // --- Agent > App Area ---
                    const SectionHeader(title: 'Agent > App (Incoming)'),
                    ListenableBuilder(
                      listenable: LogProvider(),
                      builder: (context, _) => Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Command: ${LogProvider().lastReceivedCommand}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Params: ${LogProvider().lastReceivedParams}',
                              style: const TextStyle(
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // --- App > Agent Area ---
                    const SectionHeader(title: 'App > Agent (Outgoing)'),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _inputController,
                            decoration: const InputDecoration(
                              hintText: 'Enter command or message...',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: (_) => _sendCommandToAgent(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _sendCommandToAgent,
                          child: const Text('Send'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // --- Test Controls Area ---
                    const SectionHeader(title: 'Test Tools'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        TestButton(
                          label: 'Sync',
                          icon: Icons.sync,
                          color: Colors.blue,
                          onPressed: () => _handleTest(context, 'Sync Data'),
                        ),
                        TestButton(
                          label: 'Notify',
                          icon: Icons.notifications,
                          color: Colors.orange,
                          onPressed: () => _handleTest(context, 'Notify'),
                        ),
                        TestButton(
                          label: 'Settings',
                          icon: Icons.settings,
                          color: Colors.blueGrey,
                          onPressed: () => _handleTest(context, 'Settings'),
                        ),
                         TestButton(
                          label: 'Alert',
                          icon: Icons.warning,
                          color: Colors.redAccent,
                          onPressed: () => _handleTest(context, 'Alert'),
                        ),
                        TestButton(
                          label: 'Report',
                          icon: Icons.send_and_archive,
                          color: Colors.purple,
                          onPressed: () {
                            AriAgent.emit('/APP.REPORT', {
                              'appId': ProtocolConfig.appId,
                              'message': '사용자가 앱에서 직접 보고를 전송했습니다.',
                              'type': 'success',
                            });
                            _handleTest(context, 'Report to Agent');
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // --- Log Output Area (30%) ---
            const Divider(height: 1, thickness: 1),
            const LogOutputView(),
          ],
        ),
      ),
    );
  }

  void _handleTest(BuildContext context, String action) {
    LogProvider().add('TEST ACTION: $action triggered');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$action triggered'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        duration: const Duration(seconds: 1),
      ),
    );
  }
}
