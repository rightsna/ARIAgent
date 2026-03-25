import 'package:flutter/material.dart';
import 'package:ari_plugin/ari_plugin.dart';
import 'protocol_config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  WsManager.init();
  WsManager.connect();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AriFramework Basic',
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

  @override
  void initState() {
    super.initState();
    protocolHandler = ProtocolConfig.createHandler();
    protocolHandler.start();
  }

  @override
  void dispose() {
    protocolHandler.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('AriFramework Sample'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Local path dependency import succeeded.'),
            const SizedBox(height: 12),
            Text(
              'appId: ${protocolHandler.appId}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            StreamBuilder<bool>(
              stream: WsManager.connectionStream,
              initialData: WsManager.isConnected,
              builder: (context, snapshot) {
                final isConnected = snapshot.data ?? false;
                return Text('connected: $isConnected');
              },
            ),
          ],
        ),
      ),
    );
  }
}
