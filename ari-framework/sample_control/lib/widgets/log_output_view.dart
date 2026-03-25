import 'package:flutter/material.dart';
import '../providers/log_provider.dart';

class LogOutputView extends StatelessWidget {
  const LogOutputView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LogProvider(),
      builder: (context, _) {
        final logs = LogProvider().logs;
        return Container(
          padding: const EdgeInsets.all(12),
          color: Colors.grey[900],
          height: MediaQuery.of(context).size.height * 0.3,
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.terminal, color: Colors.green, size: 16),
                  SizedBox(width: 8),
                  Text('System Log Output',
                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
              const Divider(color: Colors.grey, height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Text(
                        logs[index],
                        style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontFamily: 'monospace'),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
