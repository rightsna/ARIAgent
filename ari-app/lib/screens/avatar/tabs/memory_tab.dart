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
          if (useAdvanced)
            AdvancedIntelligenceSection(onRefresh: () => setState(() {}))
          else
            StandardMemorySection(onRefresh: () => setState(() {})),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
