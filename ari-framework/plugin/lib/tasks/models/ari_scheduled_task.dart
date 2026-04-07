/// ARI 프레임워크 - 스케줄된 작업 모델
class AriScheduledTask {
  final String id;
  final String prompt;
  final String cron;
  final String label;
  final bool enabled;
  final DateTime createdAt;
  final DateTime? lastRunAt;
  final String? lastResult;
  final String? agentId;
  final String? appId;
  final bool isOneOff;

  AriScheduledTask({
    required this.id,
    required this.prompt,
    required this.cron,
    required this.label,
    required this.enabled,
    required this.createdAt,
    this.lastRunAt,
    this.lastResult,
    this.agentId,
    this.appId,
    this.isOneOff = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'prompt': prompt,
    'cron': cron,
    'label': label,
    'enabled': enabled,
    'createdAt': createdAt.toIso8601String(),
    'lastRunAt': lastRunAt?.toIso8601String(),
    'lastResult': lastResult,
    'agentId': agentId,
    'appId': appId,
    'isOneOff': isOneOff,
  };

  factory AriScheduledTask.fromMap(Map<String, dynamic> m) => AriScheduledTask(
    id: m['id'] ?? '',
    prompt: m['prompt'] ?? '',
    cron: m['cron'] ?? '',
    label: m['label'] ?? '',
    enabled: m['enabled'] ?? true,
    createdAt: DateTime.tryParse(m['createdAt'] ?? '') ?? DateTime.now(),
    lastRunAt: m['lastRunAt'] != null
        ? DateTime.tryParse(m['lastRunAt'])
        : null,
    lastResult: m['lastResult'],
    agentId: m['agentId'],
    appId: m['appId'],
    isOneOff: m['isOneOff'] ?? false,
  );

  AriScheduledTask copyWith({
    bool? enabled,
    DateTime? lastRunAt,
    String? lastResult,
  }) => AriScheduledTask(
    id: id,
    prompt: prompt,
    cron: cron,
    label: label,
    enabled: enabled ?? this.enabled,
    createdAt: createdAt,
    lastRunAt: lastRunAt ?? this.lastRunAt,
    lastResult: lastResult ?? this.lastResult,
    agentId: agentId,
    appId: appId,
    isOneOff: isOneOff,
  );

  String get cronDescription {
    final parts = cron.split(' ');
    if (parts.length < 5) return cron;

    final minute = parts[0];
    final hour = parts[1];
    final dom = parts[2];
    final month = parts[3];
    final dow = parts[4];

    if (isOneOff) {
      if (dom != '*' && month != '*') {
        return '$month월 $dom일 $hour:${minute.padLeft(2, '0')} (1회성)';
      }
      return '1회성 알림 ($cron)';
    }

    if (dom == '*' && dow == '*') return '매일 $hour:${minute.padLeft(2, '0')}';
    if (dow != '*') {
      const days = ['일', '월', '화', '수', '목', '금', '토'];
      final dayIdx = int.tryParse(dow);
      if (dayIdx != null && dayIdx < 7) {
        return '매주 ${days[dayIdx]} $hour:${minute.padLeft(2, '0')}';
      }
    }
    return cron;
  }
}
