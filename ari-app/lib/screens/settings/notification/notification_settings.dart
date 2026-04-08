import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/config_provider.dart';

class NotificationSettings extends StatelessWidget {
  const NotificationSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Consumer<ConfigProvider>(
        builder: (context, configProvider, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Desktop Notifications'),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: SwitchListTile(
                  title: const Text(
                    '데몬 상태 메시지 알림',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  subtitle: Text(
                    '창이 숨겨진 상태에서 새 응답이 오면 macOS/Windows 알림을 표시합니다.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                  ),
                  value: configProvider.isNotificationEnabled,
                  activeThumbColor: const Color(0xFF6C63FF),
                  onChanged: (val) async {
                    await configProvider.updateIsNotificationEnabled(val);
                  },
                ),
              ),
              const SizedBox(height: 16),
              _sectionTitle('Scheduled Tasks'),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: SwitchListTile(
                  title: const Text(
                    '자동 작업 결과 채팅창 표시',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  subtitle: Text(
                    '자동 작업이 완료되면 결과를 채팅창에 표시합니다.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                  ),
                  value: configProvider.showTaskMessages,
                  activeThumbColor: const Color(0xFF6C63FF),
                  onChanged: (val) async {
                    await configProvider.updateShowTaskMessages(val);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.6),
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.0,
      ),
    );
  }
}
