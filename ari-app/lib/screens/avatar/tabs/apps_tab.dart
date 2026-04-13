import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/ari_app_provider.dart';
import '../widgets/tab_section_header.dart';

class AppsTab extends StatefulWidget {
  const AppsTab({super.key});

  @override
  State<AppsTab> createState() => _AppsTabState();
}

class _AppsTabState extends State<AppsTab> {
  Future<List<Map<String, dynamic>>>? _appsFuture;
  int _lastAppsVersion = -1;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _appsFuture = context.read<AriAppProvider>().getApps();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AriAppProvider>();
    final connectedIds = provider.connectedAppIds;

    // 앱 설치/삭제 시 자동 리프레시
    if (provider.installedAppsVersion != _lastAppsVersion) {
      _lastAppsVersion = provider.installedAppsVersion;
      if (_appsFuture != null) {
        // initState 이후 변경분만 리프레시
        _appsFuture = provider.getApps();
      }
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _appsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
          );
        }

        if (snapshot.hasError) {
          return _buildErrorState();
        }

        final apps = snapshot.data ?? [];

        if (apps.isEmpty) {
          return _buildEmptyState();
        }

        return RefreshIndicator(
          onRefresh: () async => _refresh(),
          color: const Color(0xFF6C63FF),
          backgroundColor: const Color(0xFF1A1A2E),
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: apps.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return const TabSectionHeader(
                  icon: Icons.apps_rounded,
                  title: '앱',
                  description: '에이전트가 연동해서 활용하는 앱들이에요.',
                );
              }
              final app = apps[index - 1];
              final isConnected = connectedIds.contains(app['name']);
              return _AppCard(
                app: app,
                isConnected: isConnected,
                onRefresh: _refresh,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: Colors.redAccent.withValues(alpha: 0.5),
            size: 48,
          ),
          const SizedBox(height: 16),
          const Text(
            '앱 정보를 가져오지 못했습니다.',
            style: TextStyle(color: Colors.white70),
          ),
          TextButton(
            onPressed: _refresh,
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
            Icons.apps_rounded,
            color: Colors.white.withValues(alpha: 0.2),
            size: 48,
          ),
          const SizedBox(height: 16),
          const Text(
            '설치된 앱이 없습니다.',
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            '~/.ari-agent/apps 폴더를 확인해주세요.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _AppCard extends StatelessWidget {
  final Map<String, dynamic> app;
  final bool isConnected;
  final VoidCallback onRefresh;

  const _AppCard({
    required this.app,
    required this.isConnected,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final appId = app['name'] as String;
    final title = (app['title'] as String?) ?? appId;
    final description = app['description'] as String?;
    final icon = app['icon'] as String?;
    final iconPath = app['iconPath'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isConnected
              ? const Color(0xFF4CAF50).withValues(alpha: 0.3)
              : const Color(0xFF6C63FF).withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Side accent bar
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 6,
              child: Container(
                color: isConnected
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFF6C63FF).withValues(alpha: 0.4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16).copyWith(left: 22),
              child: Row(
                children: [
                  _buildIcon(iconPath, icon),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: isConnected
                                    ? const Color(
                                        0xFF4CAF50,
                                      ).withValues(alpha: 0.15)
                                    : Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                isConnected ? '연결됨' : '오프라인',
                                style: TextStyle(
                                  color: isConnected
                                      ? const Color(0xFF4CAF50)
                                      : Colors.white.withValues(alpha: 0.3),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (description != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!isConnected)
                    IconButton(
                      icon: Icon(
                        Icons.play_circle_outline_rounded,
                        color: const Color(0xFF6C63FF).withValues(alpha: 0.7),
                        size: 24,
                      ),
                      onPressed: () async {
                        await context.read<AriAppProvider>().launchApp(appId);
                      },
                    ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.redAccent.withValues(alpha: 0.7),
                      size: 18,
                    ),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: const Color(0xFF1A1A2E),
                          title: const Text(
                            '앱 삭제',
                            style: TextStyle(color: Colors.white),
                          ),
                          content: Text(
                            '"$title" 앱을 삭제하시겠습니까?',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('취소'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text(
                                '삭제',
                                style: TextStyle(color: Colors.redAccent),
                              ),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true && context.mounted) {
                        final success = await context
                            .read<AriAppProvider>()
                            .deleteApp(appId);
                        if (success) onRefresh();
                      }
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

  Widget _buildIcon(String? iconPath, String? icon) {
    if (iconPath != null) {
      final file = File(iconPath);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.file(file, width: 44, height: 44, fit: BoxFit.cover),
        );
      }
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: icon != null
            ? Text(icon, style: const TextStyle(fontSize: 22))
            : Icon(
                Icons.extension_rounded,
                color: const Color(0xFF6C63FF).withValues(alpha: 0.5),
                size: 22,
              ),
      ),
    );
  }
}
