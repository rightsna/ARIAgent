import 'package:flutter/material.dart';

class ThinkingGlowOverlay extends StatefulWidget {
  final bool isLoading;
  final Color color;
  final double thickness;

  const ThinkingGlowOverlay({
    super.key,
    required this.isLoading,
    required this.color,
    this.thickness = 40.0,
  });

  @override
  State<ThinkingGlowOverlay> createState() => _ThinkingGlowOverlayState();
}

class _ThinkingGlowOverlayState extends State<ThinkingGlowOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.isLoading) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(ThinkingGlowOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading && !oldWidget.isLoading) {
      _controller.repeat(reverse: true);
    } else if (!widget.isLoading && oldWidget.isLoading) {
      _controller.stop();
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLoading && _animation.value <= 0) return const SizedBox.shrink();

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final opacity = _animation.value * 0.4;
          final glowColor = widget.color.withOpacity(opacity);

          return CustomPaint(
            size: Size.infinite,
            painter: _InnerGlowPainter(
              glowColor: glowColor,
              thickness: widget.thickness,
            ),
          );
        },
      ),
    );
  }
}

class _InnerGlowPainter extends CustomPainter {
  final Color glowColor;
  final double thickness;

  _InnerGlowPainter({
    required this.glowColor,
    required this.thickness,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (glowColor.opacity <= 0) return;

    final outerRect = Offset.zero & size;
    final innerRect = outerRect.deflate(thickness);

    // Create a frame path (Outer - Inner)
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(outerRect)
      ..addRect(innerRect);

    final paint = Paint()
      ..color = glowColor
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, thickness / 2);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _InnerGlowPainter oldDelegate) {
    return oldDelegate.glowColor != glowColor ||
        oldDelegate.thickness != thickness;
  }
}
