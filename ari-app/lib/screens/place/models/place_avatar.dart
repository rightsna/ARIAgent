import 'package:flutter/material.dart';
import 'package:ari_plugin/ari_plugin.dart';

class PlaceAvatar {
  final AgentInfo profile;
  final Offset position;
  final String status;

  PlaceAvatar({
    required this.profile,
    required this.position,
    required this.status,
  });

  PlaceAvatar copyWith({AgentInfo? profile, Offset? position, String? status}) {
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
  }) {
    if (avatarId == currentAvatarId) return isWorking ? '작업중' : '대기중';
    return '쉬는중';
  }
}
