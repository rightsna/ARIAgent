/// 스케줄된 작업 모델
class ScheduledTask {
  final String id;
  final String prompt;
  final String cron;
  final String label;
  final bool enabled;
  final DateTime createdAt;
  final DateTime? lastRunAt;
  final String? lastResult;
  final String? agentId;
  final bool isOneOff;

  ScheduledTask({
    required this.id,
    required this.prompt,
    required this.cron,
    required this.label,
    required this.enabled,
    required this.createdAt,
    this.lastRunAt,
    this.lastResult,
    this.agentId,
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
    'isOneOff': isOneOff,
  };

  factory ScheduledTask.fromMap(Map<String, dynamic> m) => ScheduledTask(
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
    isOneOff: m['isOneOff'] ?? false,
  );

  ScheduledTask copyWith({
    bool? enabled,
    DateTime? lastRunAt,
    String? lastResult,
  }) => ScheduledTask(
    id: id,
    prompt: prompt,
    cron: cron,
    label: label,
    enabled: enabled ?? this.enabled,
    createdAt: createdAt,
    lastRunAt: lastRunAt ?? this.lastRunAt,
    lastResult: lastResult ?? this.lastResult,
    agentId: agentId,
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
