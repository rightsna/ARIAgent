/// ARI 프레임워크 - 스케줄된 작업 모델
class AriScheduledTask {
  final String id;
  final String prompt;
  final Map<String, dynamic>? scheduleSpec;
  final String label;
  final bool enabled;
  final DateTime createdAt;
  final DateTime? lastRunAt;
  final String? lastResult;
  final String? agentId;
  final String? appId;
  final bool isOneOff;
  final DateTime startAt;
  final DateTime? endAt;
  final String? lastError;

  AriScheduledTask({
    required this.id,
    required this.prompt,
    this.scheduleSpec,
    required this.label,
    required this.enabled,
    required this.createdAt,
    this.lastRunAt,
    this.lastResult,
    this.agentId,
    this.appId,
    this.isOneOff = false,
    DateTime? startAt,
    this.endAt,
    this.lastError,
  }) : startAt = startAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'prompt': prompt,
        'scheduleSpec': scheduleSpec,
        'label': label,
        'enabled': enabled,
        'createdAt': createdAt.toIso8601String(),
        'lastRunAt': lastRunAt?.toIso8601String(),
        'lastResult': lastResult,
        'agentId': agentId,
        'appId': appId,
        'isOneOff': isOneOff,
        'startAt': startAt.toIso8601String(),
        'endAt': endAt?.toIso8601String(),
        'lastError': lastError,
      };

  factory AriScheduledTask.fromMap(Map<String, dynamic> m) => AriScheduledTask(
        id: m['id'] ?? '',
        prompt: m['prompt'] ?? '',
        scheduleSpec: m['scheduleSpec'] is Map<String, dynamic>
            ? m['scheduleSpec'] as Map<String, dynamic>
            : null,
        label: m['label'] ?? '',
        enabled: m['enabled'] ?? true,
        createdAt: DateTime.tryParse(m['createdAt'] ?? '') ?? DateTime.now(),
        lastRunAt:
            m['lastRunAt'] != null ? DateTime.tryParse(m['lastRunAt']) : null,
        lastResult: m['lastResult'],
        agentId: m['agentId'],
        appId: m['appId'],
        isOneOff: m['isOneOff'] ?? false,
        startAt: m['startAt'] != null ? DateTime.tryParse(m['startAt']) : null,
        endAt: m['endAt'] != null ? DateTime.tryParse(m['endAt']) : null,
        lastError: m['lastError'],
      );

  AriScheduledTask copyWith({
    bool? enabled,
    DateTime? lastRunAt,
    String? lastResult,
    DateTime? startAt,
    DateTime? endAt,
    String? lastError,
  }) =>
      AriScheduledTask(
        id: id,
        prompt: prompt,
        scheduleSpec: scheduleSpec,
        label: label,
        enabled: enabled ?? this.enabled,
        createdAt: createdAt,
        lastRunAt: lastRunAt ?? this.lastRunAt,
        lastResult: lastResult ?? this.lastResult,
        agentId: agentId,
        appId: appId,
        isOneOff: isOneOff,
        startAt: startAt ?? this.startAt,
        endAt: endAt ?? this.endAt,
        lastError: lastError,
      );

  static const _dayNamesKo = ['일', '월', '화', '수', '목', '금', '토'];

  String get scheduleDescription {
    if (isOneOff) {
      final local = startAt.toLocal();
      final mm = local.minute.toString().padLeft(2, '0');
      return '${local.month}월 ${local.day}일 ${local.hour}:$mm (1회성)';
    }

    final spec = scheduleSpec;
    if (spec == null) return '알 수 없음';
    return _describeSpec(spec);
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');

  static String _describeSpec(Map<String, dynamic> spec) {
    final type = spec['type'] as String?;
    switch (type) {
      case 'every_n_minutes':
        final every = (spec['every'] as num?)?.toInt() ?? 1;
        return every == 1 ? '매분' : '$every분마다';
      case 'every_n_hours':
        final every = (spec['every'] as num?)?.toInt() ?? 1;
        return every == 1 ? '매시간' : '$every시간마다';
      case 'daily':
        final h = (spec['hour'] as num?)?.toInt() ?? 0;
        final m = (spec['minute'] as num?)?.toInt() ?? 0;
        return '매일 $h:${_pad(m)}';
      case 'weekly':
        final h = (spec['hour'] as num?)?.toInt() ?? 0;
        final m = (spec['minute'] as num?)?.toInt() ?? 0;
        final rawDays = spec['days'];
        final days = rawDays is List
            ? rawDays
                .map((d) => (d as num).toInt())
                .map((d) => d < _dayNamesKo.length ? _dayNamesKo[d] : '$d')
                .join('·')
            : '';
        return '매주 $days $h:${_pad(m)}';
      case 'monthly':
        final h = (spec['hour'] as num?)?.toInt() ?? 0;
        final m = (spec['minute'] as num?)?.toInt() ?? 0;
        final day = (spec['day'] as num?)?.toInt() ?? 1;
        return '매월 ${day}일 $h:${_pad(m)}';
      case 'yearly':
        final yh = (spec['hour'] as num?)?.toInt() ?? 0;
        final ym = (spec['minute'] as num?)?.toInt() ?? 0;
        final yday = (spec['day'] as num?)?.toInt() ?? 1;
        final ymonth = (spec['month'] as num?)?.toInt() ?? 1;
        return '매년 ${ymonth}월 ${yday}일 $yh:${_pad(ym)}';
      default:
        return type ?? '알 수 없음';
    }
  }
}
