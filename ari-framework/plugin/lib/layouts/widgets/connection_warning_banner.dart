import 'package:flutter/material.dart';
import '../../bridge/ws/AriAgent.dart';

class ConnectionWarningBanner extends StatelessWidget {
  const ConnectionWarningBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: AriAgent.connectionStream,
      initialData: AriAgent.isConnected,
      builder: (context, snapshot) {
        final isConnected = snapshot.data ?? false;
        if (isConnected) return const SizedBox.shrink();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          decoration: const BoxDecoration(
            color: Color(0xFFE53935),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text(
                'AI 에이전트 서버와의 연결이 원활하지 않습니다.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
