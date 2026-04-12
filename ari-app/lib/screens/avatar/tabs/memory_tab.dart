import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/config_provider.dart';
import '../memory/standard_memory_section.dart';
import '../memory/advanced_intelligence_section.dart';

class MemoryTab extends StatefulWidget {
  const MemoryTab({super.key});

  @override
  State<MemoryTab> createState() => _MemoryTabState();
}

class _MemoryTabState extends State<MemoryTab> {
  // 모델 로드 대기 폴링용 글로벌 트리거
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
        if (mounted) setState(() {}); // UI 갱신 (Advanced 섹션 노출 위해)
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
    final useAdvanced =
        isExperimentalEnabled &&
        config.useAdvancedMemory &&
        config.embeddingModelStatus == 'ready';

    // 고급 관계 지능이 켜져 있지만 모델이 아직 준비 중이면 폴링 시작
    final modelStatus = config.embeddingModelStatus;
    if (isExperimentalEnabled &&
        config.useAdvancedMemory &&
        (modelStatus == 'loading' || modelStatus == 'downloading') &&
        _modelStatusTimer == null) {
      _startModelStatusPolling();
    }

    return RefreshIndicator(
      onRefresh: () async {
        setState(
          () {},
        ); // 각 섹션은 내부적으로 AvatarProvider를 watch하고 있으므로 여기서 갱신 신호만 주면 됨
      },
      color: const Color(0xFF6C63FF),
      backgroundColor: const Color(0xFF1F1F3D),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (isExperimentalEnabled) ...[
            _buildAdvancedMemoryToggle(config),
            const SizedBox(height: 20),
          ],
          if (useAdvanced)
            AdvancedIntelligenceSection(onRefresh: () => setState(() {}))
          else
            StandardMemorySection(onRefresh: () => setState(() {})),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ── 상단 토글 카드 ──────────────────────────────────────────────

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
                      '고급 관계 지능',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '의미론적 벡터 기억 및 관계 그래프를 활성화합니다.',
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
