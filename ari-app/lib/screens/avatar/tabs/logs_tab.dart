import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import '../../../providers/avatar_provider.dart';
import '../../../repositories/log_repository.dart';

class LogsTab extends StatelessWidget {
  const LogsTab({super.key});

  String _formatTime(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    return '${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final avatar = context.watch<AvatarProvider>();
    final currentAgentId = avatar.currentAvatarId;

    return ValueListenableBuilder<Box>(
      valueListenable: LogRepository().chatLogsListenable,
      builder: (context, chatBox, _) {
        return ValueListenableBuilder<Box>(
          valueListenable: LogRepository().taskLogsListenable,
          builder: (context, taskBox, _) {
            final logs = <Map<String, dynamic>>[];

            for (final e in chatBox.values) {
              final map = Map<String, dynamic>.from(e);
              final agentId = map['agentId'] ?? 'default';
              if (agentId == currentAgentId) {
                map['type'] = 'chat';
                logs.add(map);
              }
            }

            for (final e in taskBox.values) {
              final map = Map<String, dynamic>.from(e);
              final agentId = map['agentId'] ?? 'default';
              if (agentId == currentAgentId) {
                map['type'] = 'task';
                logs.add(map);
              }
            }

            logs.sort((a, b) {
              final tA =
                  DateTime.tryParse(a['timestamp'] ?? '') ?? DateTime.now();
              final tB =
                  DateTime.tryParse(b['timestamp'] ?? '') ?? DateTime.now();
              return tB.compareTo(tA);
            });

            if (logs.isEmpty) {
              return Center(
                child: Text(
                  '${avatar.name}의 기록이 없습니다.',
                  style: TextStyle(color: Colors.white.withOpacity(0.4)),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: logs.length,
              itemBuilder: (context, index) {
                final log = logs[index];
                final isChat = log['type'] == 'chat';

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isChat
                                ? (log['isUser'] == true ? '👤 USER' : '🤖 AI')
                                : '🕒 TASK: ${log['label']}',
                            style: const TextStyle(
                              color: Color(0xFF6C63FF),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _formatTime(log['timestamp']),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.3),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isChat ? (log['message'] ?? '') : (log['result'] ?? ''),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
