import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../providers/ari_app_provider.dart';

class PlaceAppBar extends StatelessWidget {
  final List<Map<String, dynamic>> apps;
  final bool isLoading;
  final List<String> connectedAppIds;

  const PlaceAppBar({
    super.key,
    required this.apps,
    required this.isLoading,
    required this.connectedAppIds,
  });

  IconData _getIconData(String? iconName) {
    // 하드코딩된 아이콘 매핑을 제거하고 기본 아이콘만 반환하도록 수정 (추후 유연한 아이콘 시스템 도입 가능)
    return Icons.extension_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          // 아리 스토어 버튼 (고정)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                final uri = Uri.parse('https://ariwith.me/store');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF6C63FF).withValues(alpha: 0.4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.storefront_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                    SizedBox(width: 8),
                    Text(
                      '스토어',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 수직 구분선
          Container(
            width: 1,
            height: 20,
            color: Colors.white.withValues(alpha: 0.1),
          ),

          const SizedBox(width: 12),

          // 설치된 앱 아이콘 목록 (가로 스크롤)
          Expanded(
            child: isLoading
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white24,
                      ),
                    ),
                  )
                : apps.isEmpty
                ? Text(
                    '등록된 앱이 없습니다.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 11,
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: apps.map((app) {
                        final iconName = app['icon'] as String?;
                        final appId = app['id'] as String;
                        final isConnected = connectedAppIds.contains(appId);

                        return Padding(
                          key: ValueKey(appId),
                          padding: const EdgeInsets.only(right: 10),
                          child: Tooltip(
                            message:
                                '${app['title'] ?? appId}${isConnected ? ' (연결됨)' : ''}',
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  context.read<AriAppProvider>().launchApp(
                                    appId,
                                  );
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Stack(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: isConnected
                                            ? const Color(
                                                0xFF6C63FF,
                                              ).withValues(alpha: 0.15)
                                            : Colors.white.withValues(
                                                alpha: 0.1,
                                              ),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: isConnected
                                              ? const Color(
                                                  0xFF63FF88,
                                                ).withValues(alpha: 0.4)
                                              : Colors.white.withValues(
                                                  alpha: 0.05,
                                                ),
                                          width: isConnected ? 1.5 : 1.0,
                                        ),
                                      ),
                                      child: app['iconPath'] != null
                                          ? ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Image.file(
                                                File(app['iconPath'] as String),
                                                width: 36,
                                                height: 36,
                                                fit: BoxFit.cover,
                                              ),
                                            )
                                          : Icon(
                                              _getIconData(iconName),
                                              size: 18,
                                              color: isConnected
                                                  ? Colors.white
                                                  : Colors.white.withValues(
                                                      alpha: 0.8,
                                                    ),
                                            ),
                                    ),
                                    if (isConnected)
                                      Positioned(
                                        right: 4,
                                        top: 4,
                                        child: Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF63FF88),
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(
                                                  0xFF63FF88,
                                                ).withValues(alpha: 0.5),
                                                blurRadius: 4,
                                                spreadRadius: 1,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
