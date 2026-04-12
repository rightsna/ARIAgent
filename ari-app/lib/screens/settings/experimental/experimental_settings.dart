import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/config_provider.dart';

class ExperimentalSettings extends StatelessWidget {
  const ExperimentalSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Consumer<ConfigProvider>(
        builder: (context, configProvider, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Experimental Features'),
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
                    '실험기능 활성화',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  subtitle: Text(
                    '정식 배포 전에 테스트 중인 기능을 미리 표시합니다.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                  ),
                  value: configProvider.isExperimentalEnabled,
                  activeThumbColor: const Color(0xFF6C63FF),
                  onChanged: (value) async {
                    await configProvider.updateIsExperimentalEnabled(value);
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
