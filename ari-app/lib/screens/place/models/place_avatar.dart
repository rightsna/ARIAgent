import 'package:flutter/material.dart';
import 'package:ari_plugin/ari_plugin.dart';

class PlaceAvatar {
  final AgentProfile profile;
  final Offset position;
  final String status;

  PlaceAvatar({
    required this.profile,
    required this.position,
    required this.status,
  });

  PlaceAvatar copyWith({
    AgentProfile? profile,
    Offset? position,
    String? status,
  }) {
    return PlaceAvatar(
      profile: profile ?? this.profile,
      position: position ?? this.position,
      status: status ?? this.status,
    );
  }

  // --- 헬퍼 로직 추가 ---

  /// 아바타별 현재 상태 텍스트를 결정합니다.
  static String calculateStatus({
    required String avatarId,
    required String currentAvatarId,
    required bool isWorking,
    required Set<String> scheduledWorkingIds,
  }) {
    if (scheduledWorkingIds.contains(avatarId)) return '작업중';
    if (avatarId == currentAvatarId) return isWorking ? '작업중' : '대기중';
    return '쉬는중';
  }

  /// 스케줄 작업 중인 아바타 ID들을 찾아냅니다.
  static Set<String> getScheduledWorkingIds(AriTaskProvider taskProvider) {
    if (!taskProvider.isInitialized) return const <String>{};
    final now = DateTime.now();
    return taskProvider.tasks
        .where((task) => task.enabled && !_isCompletedOneOffTask(task, now))
        .map((task) => (task.agentId?.trim().isEmpty ?? true) ? 'default' : task.agentId!.trim())
        .toSet();
  }

  static bool _isCompletedOneOffTask(AriScheduledTask task, DateTime now) {
    if (task.isOneOff != true) return false;
    final scheduledAt = _parseOneOffDateTime(task.cron);
    return scheduledAt != null && (task.lastRunAt != null || scheduledAt.isBefore(now));
  }

  static DateTime? _parseOneOffDateTime(String cron) {
    final parts = cron.split(' ');
    if (parts.length < 5) return null;
    final minute = int.tryParse(parts[0]);
    final hour = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    final month = int.tryParse(parts[3]);
    if (minute == null || hour == null || day == null || month == null) return null;
    try {
      return DateTime(DateTime.now().year, month, day, hour, minute);
    } catch (_) { return null; }
  }
}
