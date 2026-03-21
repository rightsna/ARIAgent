import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/config_provider.dart';

class SkillsTab extends StatefulWidget {
  const SkillsTab({super.key});

  @override
  State<SkillsTab> createState() => _SkillsTabState();
}

class _SkillsTabState extends State<SkillsTab> {
  Future<Map<String, dynamic>?>? _pluginsFuture;

  @override
  void initState() {
    super.initState();
    _refreshPlugins();
  }

  void _refreshPlugins() {
    setState(() {
      _pluginsFuture = context.read<ConfigProvider>().getPlugins();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _pluginsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return _buildErrorState();
        }

        final skills = snapshot.data!['skills'] as List? ?? [];

        if (skills.isEmpty) {
          return _buildEmptyState();
        }

        return RefreshIndicator(
          onRefresh: () async => _refreshPlugins(),
          color: const Color(0xFF6C63FF),
          backgroundColor: const Color(0xFF1A1A2E),
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: skills.length,
            itemBuilder: (context, index) {
              final skill = skills[index] as Map<String, dynamic>;
              return _buildSkillCard(skill, _refreshPlugins);
            },
          ),
        );
      },
    );
  }

  Widget _buildSkillCard(Map<String, dynamic> skill, VoidCallback onRefresh) {
    return _SkillCard(skill: skill, onRefresh: onRefresh);
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: Colors.redAccent.withOpacity(0.5),
            size: 48,
          ),
          const SizedBox(height: 16),
          const Text(
            '스킬 정보를 가져오지 못했습니다.',
            style: TextStyle(color: Colors.white70),
          ),
          TextButton(
            onPressed: _refreshPlugins,
            child: const Text(
              '다시 시도',
              style: TextStyle(color: Color(0xFF6C63FF)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_fix_high_rounded,
            color: Colors.white.withOpacity(0.2),
            size: 48,
          ),
          const SizedBox(height: 16),
          const Text(
            '등록된 스킬이 없습니다.',
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            '에이전트의 skills 폴더를 확인해주세요.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _SkillCard extends StatefulWidget {
  final Map<String, dynamic> skill;
  final VoidCallback onRefresh;
  const _SkillCard({required this.skill, required this.onRefresh});

  @override
  State<_SkillCard> createState() => _SkillCardState();
}

class _SkillCardState extends State<_SkillCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final name = widget.skill['name'] ?? 'Unknown Skill';
    final description =
        widget.skill['description'] ?? 'No description provided.';
    final tools = (widget.skill['tools'] as List?)?.length ?? 0;
    final isCustom = widget.skill['isCustom'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Side Accent Bar
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 6,
              child: Container(color: const Color(0xFF6C63FF)),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(16).copyWith(left: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C63FF).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$tools Tools',
                          style: const TextStyle(
                            color: Color(0xFF6C63FF),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (isCustom)
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.redAccent.withOpacity(0.7),
                            size: 18,
                          ),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor: const Color(0xFF1A1A2E),
                                title: const Text(
                                  '스킬 삭제',
                                  style: TextStyle(color: Colors.white),
                                ),
                                content: Text(
                                  '"$name" 스킬을 삭제하시겠습니까?',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('취소'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text(
                                      '삭제',
                                      style: TextStyle(color: Colors.redAccent),
                                    ),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              if (mounted) {
                                final success = await context
                                    .read<ConfigProvider>()
                                    .deleteSkill(name);
                                if (success) {
                                  widget.onRefresh();
                                }
                              }
                            }
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final span = TextSpan(
                        text: description,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 13,
                          height: 1.5,
                        ),
                      );
                      final tp = TextPainter(
                        text: span,
                        maxLines: 3,
                        textDirection: TextDirection.ltr,
                      );
                      tp.layout(maxWidth: constraints.maxWidth);
                      final isOverflowing = tp.didExceedMaxLines;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(
                            span,
                            maxLines: _isExpanded ? null : 3,
                            overflow: _isExpanded
                                ? TextOverflow.visible
                                : TextOverflow.ellipsis,
                          ),
                          if (isOverflowing)
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _isExpanded = !_isExpanded),
                              child: Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  _isExpanded ? '접기' : '더보기',
                                  style: const TextStyle(
                                    color: Color(0xFF6C63FF),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
