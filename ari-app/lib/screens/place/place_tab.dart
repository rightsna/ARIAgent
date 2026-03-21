import 'dart:io';
import 'dart:math';

import 'package:ari_agent/models/agent_profile.dart';
import 'package:ari_agent/models/scheduled_task.dart';
import 'package:ari_agent/providers/avatar_provider.dart';
import 'package:ari_agent/providers/chat_provider.dart';
import 'package:ari_agent/providers/task_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PlaceTab extends StatefulWidget {
  const PlaceTab({super.key});

  @override
  State<PlaceTab> createState() => _PlaceTabState();
}

class _PlaceTabState extends State<PlaceTab> {
  final Random _random = Random();
  final Map<String, Offset> _avatarPositions = {};

  @override
  Widget build(BuildContext context) {
    final avatarProvider = context.watch<AvatarProvider>();
    final avatars = avatarProvider.allAvatars;
    final currentAvatarId = avatarProvider.currentAvatarId;
    final isWorking = context.watch<ChatProvider>().isLoading;
    final scheduledWorkingIds = _scheduledWorkingAvatarIds(context);
    _syncAvatarPositions(avatars);

    return LayoutBuilder(
      builder: (context, constraints) {
        final avatarWidgets = <Widget>[];

        for (final avatar in avatars) {
          final ratio = _avatarPositions[avatar.id] ?? const Offset(0.5, 0.72);
          final xPos = constraints.maxWidth * ratio.dx;
          final yPos = constraints.maxHeight * ratio.dy;

          avatarWidgets.add(
            Positioned(
              left: xPos - 48,
              top: yPos - 62,
              child: _buildAvatar(
                avatar,
                _statusForAvatar(
                  avatarId: avatar.id,
                  currentAvatarId: currentAvatarId,
                  isWorking: isWorking,
                  scheduledWorkingIds: scheduledWorkingIds,
                ),
              ),
            ),
          );
        }

        return Stack(
          children: [
            Positioned.fill(
              child: Image.asset('assets/images/room.png', fit: BoxFit.cover),
            ),
            ...avatarWidgets,
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton(
                mini: true,
                backgroundColor: const Color(0xFF6C63FF).withValues(alpha: 0.8),
                onPressed: () {
                  setState(() {
                    _randomizeAvatarPositions(avatars);
                  });
                },
                child: const Icon(Icons.refresh, color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _syncAvatarPositions(List<AgentProfile> avatars) {
    final activeIds = avatars.map((avatar) => avatar.id).toSet();
    _avatarPositions.removeWhere((id, _) => !activeIds.contains(id));

    for (var i = 0; i < avatars.length; i++) {
      final avatar = avatars[i];
      _avatarPositions.putIfAbsent(
        avatar.id,
        () => _seededPosition(i, avatars.length),
      );
    }
  }

  void _randomizeAvatarPositions(List<AgentProfile> avatars) {
    for (final avatar in avatars) {
      _avatarPositions[avatar.id] = _randomPosition();
    }
  }

  Offset _seededPosition(int index, int total) {
    if (total <= 1) {
      return const Offset(0.5, 0.72);
    }

    final spacing = 0.7 / (total - 1);
    final x = 0.15 + (spacing * index);
    final y = 0.66 + ((index % 2) * 0.08);
    return Offset(x.clamp(0.15, 0.85), y.clamp(0.6, 0.82));
  }

  Offset _randomPosition() {
    final x = 0.12 + _random.nextDouble() * 0.76;
    final y = 0.6 + _random.nextDouble() * 0.22;
    return Offset(x, y);
  }

  String _statusForAvatar({
    required String avatarId,
    required String currentAvatarId,
    required bool isWorking,
    required Set<String> scheduledWorkingIds,
  }) {
    if (scheduledWorkingIds.contains(avatarId)) {
      return '작업중';
    }
    if (avatarId == currentAvatarId) {
      return isWorking ? '작업중' : '대기중';
    }
    return '쉬는중';
  }

  Set<String> _scheduledWorkingAvatarIds(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
    if (!taskProvider.isInitialized) {
      return const <String>{};
    }

    final now = DateTime.now();
    return taskProvider.tasks
        .where((task) => task.enabled)
        .where((task) => !_isCompletedOneOffTask(task, now))
        .map(
          (task) => (task.agentId == null || task.agentId!.trim().isEmpty)
              ? 'default'
              : task.agentId!.trim(),
        )
        .toSet();
  }

  bool _isCompletedOneOffTask(ScheduledTask task, DateTime now) {
    if (task.isOneOff != true) {
      return false;
    }

    final scheduledAt = _parseOneOffDateTime(task.cron);
    if (scheduledAt == null) {
      return false;
    }

    if (task.lastRunAt != null) {
      return true;
    }

    return scheduledAt.isBefore(now);
  }

  DateTime? _parseOneOffDateTime(String cron) {
    final parts = cron.split(' ');
    if (parts.length < 5) {
      return null;
    }

    final minute = int.tryParse(parts[0]);
    final hour = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    final month = int.tryParse(parts[3]);

    if (minute == null || hour == null || day == null || month == null) {
      return null;
    }

    final year = DateTime.now().year;
    try {
      return DateTime(year, month, day, hour, minute);
    } catch (_) {
      return null;
    }
  }

  Widget _buildAvatar(AgentProfile avatar, String statusText) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF13132B),
            border: Border.all(color: const Color(0xFF6C63FF), width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipOval(child: _buildAvatarImage(avatar)),
        ),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(minWidth: 76, maxWidth: 116),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xCC13132B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFF6C63FF).withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                avatar.name.trim().isEmpty ? 'ARI' : avatar.name.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                statusText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.68),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarImage(AgentProfile avatar) {
    if (avatar.imagePath.isNotEmpty) {
      final file = File(avatar.imagePath);
      if (file.existsSync()) {
        return Image.file(file, width: 96, height: 96, fit: BoxFit.cover);
      }
    }

    return Image.asset(
      'assets/images/avatar.png',
      width: 96,
      height: 96,
      fit: BoxFit.cover,
    );
  }
}
