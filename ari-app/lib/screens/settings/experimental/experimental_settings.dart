import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/config_provider.dart';

class ExperimentalSettings extends StatefulWidget {
  const ExperimentalSettings({super.key});

  @override
  State<ExperimentalSettings> createState() => _ExperimentalSettingsState();
}

class _ExperimentalSettingsState extends State<ExperimentalSettings> {
  Timer? _modelStatusTimer;

  @override
  void dispose() {
    _modelStatusTimer?.cancel();
    super.dispose();
  }

  void _startModelStatusPolling() {
    _modelStatusTimer?.cancel();
    _modelStatusTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      final status = await ConfigProvider().refreshEmbeddingModelStatus();
      if (status == 'ready') {
        _modelStatusTimer?.cancel();
        _modelStatusTimer = null;
        if (mounted) setState(() {});
      } else if (status == 'error') {
        _modelStatusTimer?.cancel();
        _modelStatusTimer = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<ConfigProvider>();
    final isExperimentalEnabled = config.isExperimentalEnabled;

    // 고급 관계 지능이 켜져 있지만 모델이 아직 준비 중이면 폴링 시작
    final modelStatus = config.embeddingModelStatus;
    if (isExperimentalEnabled &&
        config.useAdvancedMemory &&
        (modelStatus == 'loading' || modelStatus == 'downloading') &&
        _modelStatusTimer == null) {
      _startModelStatusPolling();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Advanced Features'),
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
                '고급 도구 표시',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
              subtitle: Text(
                '스킬, 도구 탭 등 개발자용 고급 기능을 표시합니다.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 11,
                ),
              ),
              value: config.showAdvancedDeveloperUI,
              activeThumbColor: const Color(0xFF6C63FF),
              onChanged: (value) async {
                await config.updateShowAdvancedDeveloperUI(value);
              },
            ),
          ),
          const SizedBox(height: 24),
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
              value: config.isExperimentalEnabled,
              activeThumbColor: const Color(0xFF6C63FF),
              onChanged: (value) async {
                await config.updateIsExperimentalEnabled(value);
              },
            ),
          ),
          if (isExperimentalEnabled) ...[
            const SizedBox(height: 24),
            _sectionTitle('Relationship Intelligence'),
            const SizedBox(height: 8),
            _buildAdvancedMemoryToggle(config),
          ],
        ],
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

  Widget _buildAdvancedMemoryToggle(ConfigProvider config) {
    final enabled = config.useAdvancedMemory;
    final modelStatus = config.embeddingModelStatus;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '고급 관계 지능 활성화',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '의미론적 벡터 기억 및 관계 그래프를 활성화합니다. (아바타 > 메모리 탭에서 확인 가능)',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: enabled,
                onChanged: (val) async {
                  await ConfigProvider().updateAdvancedMemory(val);
                  if (mounted) setState(() {});
                },
                activeThumbColor: const Color(0xFF6C63FF),
                inactiveThumbColor: Colors.white38,
                inactiveTrackColor: Colors.white12,
              ),
            ],
          ),
          if (enabled) ...[
            const SizedBox(height: 10),
            _buildModelStatusBadge(modelStatus),
          ],
        ],
      ),
    );
  }

  Widget _buildModelStatusBadge(String status) {
    switch (status) {
      case 'ready':
        return Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF4ADE80),
              size: 13,
            ),
            const SizedBox(width: 6),
            Text(
              '임베딩 모델 준비 완료',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 11,
              ),
            ),
          ],
        );
      case 'loading':
        return Row(
          children: [
            const SizedBox(
              width: 11,
              height: 11,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: Color(0xFF6C63FF),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '임베딩 모델 로드 중...',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 11,
              ),
            ),
          ],
        );
      case 'downloading':
        return Row(
          children: [
            const SizedBox(
              width: 11,
              height: 11,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: Color(0xFF6C63FF),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '임베딩 모델 다운로드 중... (~280MB)',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 11,
              ),
            ),
          ],
        );
      case 'error':
        return Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFFF6B6B),
              size: 13,
            ),
            const SizedBox(width: 6),
            Text(
              '모델 로드 실패 — 재시작 후 다시 시도',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 11,
              ),
            ),
          ],
        );
      default:
        return Row(
          children: [
            Icon(
              Icons.download_outlined,
              color: Colors.white.withValues(alpha: 0.35),
              size: 13,
            ),
            const SizedBox(width: 6),
            Text(
              '모델 미설치 — 활성화 시 자동 다운로드 (~280MB)',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 11,
              ),
            ),
          ],
        );
    }
  }
}
