import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ari_plugin/ari_plugin.dart';
import '../../../providers/config_provider.dart';

/// 메인 아바타 위젯 - 이미지와 상태 표시등을 포함.
class AvatarWidget extends StatefulWidget {
  final bool isConnected;
  final bool isThinking;
  final String? avatarSize;
  final bool showStatusIndicator;
  final VoidCallback? onTap;

  const AvatarWidget({
    super.key,
    this.isConnected = false,
    this.isThinking = false,
    this.avatarSize,
    this.showStatusIndicator = true,
    this.onTap,
  });

  @override
  State<AvatarWidget> createState() => _AvatarWidgetState();
}

class _AvatarWidgetState extends State<AvatarWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(covariant AvatarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isThinking) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final avatarSizeSetting = widget.avatarSize ?? context.watch<ConfigProvider>().avatarSize;

    double imageSize = 140;
    double glowSize = 160;

    switch (avatarSizeSetting) {
      case 'small':
        imageSize = 80;
        glowSize = 100;
        break;
      case 'large':
        imageSize = 140;
        glowSize = 160;
        break;
      case 'medium':
      default:
        imageSize = 110;
        glowSize = 130;
        break;
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          final scale = widget.isThinking ? _pulseAnimation.value : 1.0;
          return Transform.scale(scale: scale, child: child);
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 글로우 효과
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: glowSize,
              height: glowSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.isConnected
                        ? const Color(0xFF6C63FF).withValues(alpha: 0.4)
                        : const Color(0xFFFF6B6B).withValues(alpha: 0.3),
                    blurRadius: glowSize * 0.2,
                    spreadRadius: 5,
                  ),
                ],
              ),
            ),
            // 아바타 이미지
            ClipOval(
              child: Builder(
                builder: (context) {
                  final avatar = context.watch<AvatarProvider>();
                  if (avatar.imagePath.isNotEmpty) {
                    final file = File(avatar.imagePath);
                    if (file.existsSync()) {
                      return Image.file(
                        file,
                        width: imageSize,
                        height: imageSize,
                        fit: BoxFit.cover,
                      );
                    }
                  }
                  return Image.asset(
                    'assets/images/avatar.png',
                    width: imageSize,
                    height: imageSize,
                    fit: BoxFit.cover,
                  );
                },
              ),
            ),
            // 연결 상태 표시등
            if (widget.showStatusIndicator)
              Positioned(
                bottom: imageSize * 0.05 + (glowSize - imageSize) / 2,
                right: imageSize * 0.05 + (glowSize - imageSize) / 2,
                child: Container(
                  width: imageSize * 0.12,
                  height: imageSize * 0.12,
                  decoration: BoxDecoration(
                    color: widget.isConnected
                        ? const Color(0xFF4ADE80)
                        : const Color(0xFFFF6B6B),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF1A1A2E), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color:
                            (widget.isConnected
                                    ? const Color(0xFF4ADE80)
                                    : const Color(0xFFFF6B6B))
                                .withValues(alpha: 0.6),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
