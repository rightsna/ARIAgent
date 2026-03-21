import 'package:flutter/material.dart';
import '../../../providers/server_provider.dart';

/// 서버 제어 패널 - Start / Stop / Restart 버튼 + 상태 + 로그
class ServerControlPanel extends StatelessWidget {
  final ServerProvider serverProvider;
  final VoidCallback? onStatusChanged;

  const ServerControlPanel({
    super.key,
    required this.serverProvider,
    this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: serverProvider,
      builder: (context, _) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _statusColor.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 헤더: 상태 표시
              Row(
                children: [
                  _statusDot,
                  const SizedBox(width: 8),
                  Text(
                    _statusLabel,
                    style: TextStyle(
                      color: _statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Engine Server',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // 버튼 행
              Row(
                children: [
                  _controlButton(
                    icon: Icons.play_arrow_rounded,
                    label: 'Start',
                    color: const Color(0xFF4ADE80),
                    enabled:
                        serverProvider.status == ServerStatus.stopped ||
                        serverProvider.status == ServerStatus.error,
                    onTap: () async {
                      await serverProvider.start();
                      onStatusChanged?.call();
                    },
                  ),
                  const SizedBox(width: 8),
                  _controlButton(
                    icon: Icons.stop_rounded,
                    label: 'Stop',
                    color: const Color(0xFFFF6B6B),
                    enabled: serverProvider.status == ServerStatus.running,
                    onTap: () async {
                      await serverProvider.stop();
                      onStatusChanged?.call();
                    },
                  ),
                  const SizedBox(width: 8),
                  _controlButton(
                    icon: Icons.refresh_rounded,
                    label: 'Restart',
                    color: const Color(0xFFFBBF24),
                    enabled: serverProvider.status == ServerStatus.running,
                    onTap: () async {
                      await serverProvider.restart();
                      onStatusChanged?.call();
                    },
                  ),
                ],
              ),

              // 마지막 로그 1줄 표시
              if (serverProvider.logs.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    serverProvider.logs.last,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 10,
                      fontFamily: 'Courier',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _controlButton({
    required IconData icon,
    required String label,
    required Color color,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    final isLoading =
        serverProvider.status == ServerStatus.starting ||
        serverProvider.status == ServerStatus.stopping;

    return Expanded(
      child: GestureDetector(
        onTap: enabled && !isLoading ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: enabled
                ? color.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: enabled
                  ? color.withValues(alpha: 0.4)
                  : Colors.white.withValues(alpha: 0.05),
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: enabled ? color : Colors.white.withValues(alpha: 0.15),
                size: 18,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: enabled ? color : Colors.white.withValues(alpha: 0.15),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget get _statusDot {
    final isAnimating =
        serverProvider.status == ServerStatus.starting ||
        serverProvider.status == ServerStatus.stopping;

    if (isAnimating) {
      return SizedBox(
        width: 10,
        height: 10,
        child: CircularProgressIndicator(strokeWidth: 2, color: _statusColor),
      );
    }

    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: _statusColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: _statusColor.withValues(alpha: 0.5), blurRadius: 6),
        ],
      ),
    );
  }

  Color get _statusColor {
    switch (serverProvider.status) {
      case ServerStatus.running:
        return const Color(0xFF4ADE80);
      case ServerStatus.starting:
      case ServerStatus.stopping:
        return const Color(0xFFFBBF24);
      case ServerStatus.error:
        return const Color(0xFFFF6B6B);
      case ServerStatus.stopped:
        return const Color(0xFF6B7280);
    }
  }

  String get _statusLabel {
    switch (serverProvider.status) {
      case ServerStatus.running:
        return 'Running';
      case ServerStatus.starting:
        return 'Starting...';
      case ServerStatus.stopping:
        return 'Stopping...';
      case ServerStatus.error:
        return 'Error';
      case ServerStatus.stopped:
        return 'Stopped';
    }
  }
}
