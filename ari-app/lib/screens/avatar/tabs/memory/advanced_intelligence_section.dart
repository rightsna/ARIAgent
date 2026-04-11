import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ari_plugin/ari_plugin.dart';

class AdvancedIntelligenceSection extends StatefulWidget {
  final VoidCallback onRefresh;

  const AdvancedIntelligenceSection({
    super.key,
    required this.onRefresh,
  });

  @override
  State<AdvancedIntelligenceSection> createState() =>
      _AdvancedIntelligenceSectionState();
}

class _AdvancedIntelligenceSectionState extends State<AdvancedIntelligenceSection> {
  Map<String, dynamic>? _stats;
  bool _isLoadingStats = false;
  String? _lastAvatarId;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    if (!mounted) return;
    setState(() => _isLoadingStats = true);
    try {
      final stats = await context.read<AvatarProvider>().getMemoryStats();
      if (mounted) {
        setState(() {
          _stats = stats;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingStats = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatar = context.watch<AvatarProvider>();

    if (_lastAvatarId != avatar.currentAvatarId) {
      _lastAvatarId = avatar.currentAvatarId;
      _fetchStats();
    }

    if (_isLoadingStats) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
        ),
      );
    }

    if (_stats == null || _stats!['enabled'] == false) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Text(
            '통계를 불러올 수 없습니다.',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3), fontSize: 13),
          ),
        ),
      );
    }

    final s = _stats!;
    final int coreCount = (s['coreCount'] as num?)?.toInt() ?? 0;
    final int dailyCount = (s['dailyCount'] as num?)?.toInt() ?? 0;
    final int entityCount = (s['entityCount'] as num?)?.toInt() ?? 0;
    final int topicCount = (s['topicCount'] as num?)?.toInt() ?? 0;
    final int mentionsCount = (s['mentionsCount'] as num?)?.toInt() ?? 0;
    final int aboutCount = (s['aboutCount'] as num?)?.toInt() ?? 0;
    final int followsCount = (s['followsCount'] as num?)?.toInt() ?? 0;
    final int totalRels = mentionsCount + aboutCount + followsCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeaderSection(
          'Memory Graph',
          '에이전트 메모리의 관계 그래프 현황입니다.',
          icon: Icons.hub_rounded,
          action: IconButton(
            onPressed: _fetchStats,
            icon: Icon(Icons.refresh_rounded,
                color: Colors.white.withValues(alpha: 0.4), size: 18),
            tooltip: '새로고침',
          ),
        ),
        const SizedBox(height: 16),

        _buildStatCard(
          title: '메모리 노드',
          icon: Icons.memory_rounded,
          color: const Color(0xFF6C63FF),
          children: [
            _buildStatRow('핵심 기억 (Core)', coreCount, const Color(0xFF6C63FF)),
            const SizedBox(height: 8),
            _buildStatRow('일일 로그 (Daily)', dailyCount, const Color(0xFF4ADE80)),
            const Divider(color: Colors.white12, height: 20),
            _buildStatRow(
                '합계', coreCount + dailyCount, Colors.white54, isBold: true),
          ],
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _buildCompactStatCard(
                title: '엔티티',
                icon: Icons.person_outline_rounded,
                value: entityCount,
                color: const Color(0xFFFF9F43),
                subtitle: '사람, 도구, 개념...',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildCompactStatCard(
                title: '토픽',
                icon: Icons.label_outline_rounded,
                value: topicCount,
                color: const Color(0xFF48CAE4),
                subtitle: '주제 카테고리',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        _buildStatCard(
          title: '관계 (Relationships)',
          icon: Icons.account_tree_rounded,
          color: const Color(0xFFFF6B6B),
          children: [
            _buildStatRow('MENTIONS (기억 → 엔티티)', mentionsCount,
                const Color(0xFFFF9F43)),
            const SizedBox(height: 8),
            _buildStatRow(
                'ABOUT (기억 → 토픽)', aboutCount, const Color(0xFF48CAE4)),
            const SizedBox(height: 8),
            _buildStatRow(
                'FOLLOWS (시간 순서 체인)', followsCount, Colors.white38),
            const Divider(color: Colors.white12, height: 20),
            _buildStatRow('총 관계 수', totalRels, Colors.white54, isBold: true),
          ],
        ),
      ],
    );
  }

  Widget _buildHeaderSection(String title, String subtitle,
      {required IconData icon, Widget? action}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF6C63FF), size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  )),
              Text(subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 11,
                  )),
            ],
          ),
        ),
        if (action != null) action,
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 8),
            Text(title,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                )),
          ]),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildCompactStatCard({
    required String title,
    required IconData icon,
    required int value,
    required Color color,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 6),
            Text(title,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                )),
          ]),
          const SizedBox(height: 12),
          Text(
            '$value',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(subtitle,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 10,
              )),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, int value, Color valueColor,
      {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: isBold ? 0.6 : 0.45),
              fontSize: 12,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
            )),
        Text(
          '$value',
          style: TextStyle(
            color: valueColor,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
