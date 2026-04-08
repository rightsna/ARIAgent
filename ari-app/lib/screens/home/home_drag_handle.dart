import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class HomeDragHandle extends StatelessWidget {
  final bool isLight;

  const HomeDragHandle({
    super.key,
    required this.isLight,
  });

  @override
  Widget build(BuildContext context) {
    final handleColor = (isLight ? Colors.black : Colors.white).withValues(
      alpha: 0.2,
    );

    return SizedBox(
      height: 32,
      child: Stack(
        children: [
          DragToMoveArea(
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: handleColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          if (Platform.isWindows)
            Positioned(
              top: 4,
              right: 6,
              child: IconButton(
                tooltip: '닫기',
                onPressed: () => windowManager.close(),
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: (isLight ? Colors.black : Colors.white).withValues(
                    alpha: 0.75,
                  ),
                ),
                style: IconButton.styleFrom(
                  minimumSize: const Size(24, 24),
                  padding: const EdgeInsets.all(4),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: Colors.transparent,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
