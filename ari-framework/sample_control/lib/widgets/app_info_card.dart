import 'package:flutter/material.dart';
import 'package:ari_plugin/ari_plugin.dart';

class AppInfoCard extends StatelessWidget {
  final String appId;

  const AppInfoCard({super.key, required this.appId});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.badge, size: 16, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text('ID: $appId', style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                StreamBuilder<bool>(
                  stream: WsManager.connectionStream,
                  initialData: WsManager.isConnected,
                  builder: (context, snapshot) {
                    final isConnected = snapshot.data ?? false;
                    return Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: isConnected ? Colors.green : Colors.red),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isConnected ? 'Connected' : 'Disconnected',
                          style: TextStyle(
                            fontSize: 12,
                            color: isConnected ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
