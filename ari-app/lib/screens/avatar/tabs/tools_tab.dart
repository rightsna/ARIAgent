import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/ari_app_provider.dart';

class ToolsTab extends StatefulWidget {
  const ToolsTab({super.key});

  @override
  State<ToolsTab> createState() => _ToolsTabState();
}

class _ToolsTabState extends State<ToolsTab> {
  Future<Map<String, dynamic>?>? _pluginsFuture;

  @override
  void initState() {
    super.initState();
    _refreshPlugins();
  }

  void _refreshPlugins() {
    setState(() {
      _pluginsFuture = context.read<AriAppProvider>().getPlugins();
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

        final tools = snapshot.data!['tools'] as List? ?? [];

        if (tools.isEmpty) {
          return _buildEmptyState();
        }

        return RefreshIndicator(
          onRefresh: () async => _refreshPlugins(),
          color: const Color(0xFF6C63FF),
          backgroundColor: const Color(0xFF1A1A2E),
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: tools.length,
            itemBuilder: (context, index) {
              final tool = tools[index] as Map<String, dynamic>;
              return _buildToolCard(tool);
            },
          ),
        );
      },
    );
  }

  Widget _buildToolCard(Map<String, dynamic> tool) {
    return _ToolCard(tool: tool);
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
            '도구 정보를 가져오지 못했습니다.',
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
            Icons.terminal_rounded,
            color: Colors.white.withOpacity(0.2),
            size: 48,
          ),
          const SizedBox(height: 16),
          const Text(
            '등록된 도구가 없습니다.',
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            '에이전트의 tools 폴더를 확인해주세요.',
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

class _ToolCard extends StatefulWidget {
  final Map<String, dynamic> tool;
  const _ToolCard({required this.tool});

  @override
  State<_ToolCard> createState() => _ToolCardState();
}

class _ToolCardState extends State<_ToolCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final name = widget.tool['name'] ?? 'Unknown Tool';
    final description =
        widget.tool['description'] ?? 'No description provided.';
    const accentColor = Color(0xFF4ADE80);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withOpacity(0.1)),
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
              child: Container(color: accentColor),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(16).copyWith(left: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
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
                                    color: accentColor,
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
