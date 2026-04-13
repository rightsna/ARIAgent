part of '../schedule_tab.dart';

// ── 시간 슬롯 데이터 ──────────────────────────────────────

class _HourSlot {
  final int hour;
  final int minute; // 슬롯 내 첫 발화 시각의 분
  final List<AriScheduledTask> tasks;

  const _HourSlot(this.hour, this.minute, this.tasks);

  double get topPx => hour * _kHourH + minute * _kHourH / 60 + _kCardTopPad;
}

// ── DayColumn ────────────────────────────────────────────

class DayColumn extends StatelessWidget {
  final List<AriScheduledTask> tasks;
  final List<String> selectedTaskIds;
  final void Function(List<AriScheduledTask>) onSlotSelected;
  final bool isToday;
  final DateTime displayDate; // 어떤 날짜를 표시 중인지

  const DayColumn({
    super.key,
    required this.tasks,
    required this.selectedTaskIds,
    required this.onSlotSelected,
    required this.displayDate,
    this.isToday = false,
  });

  static int _hour(AriScheduledTask t) {
    if (t.isOneOff) return t.startAt.toLocal().hour;
    final type = t.scheduleSpec?['type'] as String?;
    if (_isIntervalType(type)) return 0;
    return (t.scheduleSpec?['hour'] as num?)?.toInt() ?? 0;
  }

  static int _minute(AriScheduledTask t) {
    if (t.isOneOff) return t.startAt.toLocal().minute;
    final type = t.scheduleSpec?['type'] as String?;
    if (_isIntervalType(type)) return 0;
    return (t.scheduleSpec?['minute'] as num?)?.toInt() ?? 0;
  }

  /// displayDate 기준으로 발화 시각을 생성하고 startAt/endAt 범위 내 것만 반환
  static List<(AriScheduledTask, int hour, int minute)> _expandTask(
      AriScheduledTask t, DateTime displayDate) {
    final type = t.scheduleSpec?['type'] as String?;
    final startAt = t.startAt.toLocal();
    final endAt   = t.endAt?.toLocal();

    final startDay = DateTime(startAt.year, startAt.month, startAt.day);
    final viewDay  = DateTime(displayDate.year, displayDate.month, displayDate.day);

    // 특정 날짜 + 시:분 → DateTime
    DateTime occAt(int h, int m) =>
        DateTime(displayDate.year, displayDate.month, displayDate.day, h, m);

    // 발화 시각이 유효 범위인지 확인
    bool inRange(int h, int m) {
      if (viewDay.isBefore(startDay)) return false;
      // startAt 당일: 지정된 시각 이후만
      if (viewDay == startDay && occAt(h, m).isBefore(startAt)) return false;
      if (endAt != null) {
        final endDay = DateTime(endAt.year, endAt.month, endAt.day);
        if (viewDay.isAfter(endDay)) return false;
        if (viewDay == endDay && !occAt(h, m).isBefore(endAt)) return false;
      }
      return true;
    }

    if (t.isOneOff) {
      final local = t.startAt.toLocal();
      final sameDay = local.year == displayDate.year &&
          local.month == displayDate.month &&
          local.day == displayDate.day;
      return sameDay ? [(t, local.hour, local.minute)] : [];
    }

    if (type == 'every_n_hours') {
      final every = (t.scheduleSpec!['every'] as num).toInt().clamp(1, 24);
      return [
        for (int h = 0; h < 24; h += every)
          if (inRange(h, 0)) (t, h, 0),
      ];
    }

    if (type == 'every_n_minutes') {
      final every = (t.scheduleSpec!['every'] as num).toInt().clamp(1, 1440);
      return [
        for (int m = 0; m < 1440; m += every)
          if (inRange(m ~/ 60, m % 60)) (t, m ~/ 60, m % 60),
      ];
    }

    // weekly: 해당 요일인지 확인
    if (type == 'weekly') {
      final displayWd = displayDate.weekday % 7; // 0=일, 1=월, ..., 6=토
      final rawDays = t.scheduleSpec?['days'] as List?;
      final days = rawDays?.map((d) => (d as num).toInt()).toList() ?? [];
      if (!days.contains(displayWd)) return [];
    }

    // daily / monthly / yearly 등 고정 시각
    final h = _hour(t);
    final m = _minute(t);
    return inRange(h, m) ? [(t, h, m)] : [];
  }

  @override
  Widget build(BuildContext context) {
    // task별 시간당 1개 dedup 후 → hour 기준으로 슬롯 묶기
    final slotMap = <int, _HourSlotBuilder>{};

    for (final task in tasks) {
      final seen = <int>{};
      for (final (t, h, m) in _expandTask(task, displayDate)) {
        if (seen.add(h)) {
          slotMap.putIfAbsent(h, () => _HourSlotBuilder(h)).add(t, m);
        }
      }
    }

    final slots = slotMap.values
        .map((b) => b.build())
        .toList()
      ..sort((a, b) => a.topPx.compareTo(b.topPx));

    return SizedBox(
      height: _kTotalH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (isToday)
            Positioned.fill(
              child: Container(color: _kAccent.withValues(alpha: 0.04)),
            ),
          for (final slot in slots)
            Positioned(
              top: slot.topPx,
              left: 0,
              right: 1,
              height: _kCardH,
              child: _HourSlotCard(
                slot: slot,
                isSelected: slot.tasks.any((t) => selectedTaskIds.contains(t.id)),
                onTap: () => onSlotSelected(slot.tasks),
              ),
            ),
        ],
      ),
    );
  }
}

// ── 슬롯 빌더 헬퍼 ───────────────────────────────────────

class _HourSlotBuilder {
  final int hour;
  final List<AriScheduledTask> _tasks = [];
  int _firstMinute = 0;

  _HourSlotBuilder(this.hour);

  void add(AriScheduledTask task, int minute) {
    if (_tasks.isEmpty) _firstMinute = minute;
    _tasks.add(task);
  }

  _HourSlot build() => _HourSlot(hour, _firstMinute, List.unmodifiable(_tasks));
}

// ── _HourSlotCard ─────────────────────────────────────────

class _HourSlotCard extends StatelessWidget {
  final _HourSlot slot;
  final bool isSelected;
  final VoidCallback onTap;

  const _HourSlotCard({
    required this.slot,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tasks = slot.tasks;
    final anyEnabled = tasks.any((t) => t.enabled);
    final hasInterval = tasks.any(
      (t) => _isIntervalType(t.scheduleSpec?['type'] as String?));

    final accentCol = hasInterval ? const Color(0xFF4ADE80) : _kAccent;
    final borderCol = isSelected
        ? Colors.white.withValues(alpha: 0.6)
        : (anyEnabled ? accentCol.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.1));
    final bgCol = isSelected
        ? Colors.white.withValues(alpha: 0.12)
        : (anyEnabled ? accentCol.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.04));

    final label = tasks.map((t) => t.label).join(', ');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: _kCardH,
        decoration: BoxDecoration(
          color: bgCol,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: borderCol, width: 1),
          boxShadow: isSelected && anyEnabled
              ? [BoxShadow(color: accentCol.withValues(alpha: 0.25), blurRadius: 6)]
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Row(
          children: [
            if (tasks.length > 1) ...[
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: accentCol.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(3),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${tasks.length}',
                  style: TextStyle(
                    color: accentCol,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ] else if (tasks.first.isOneOff) ...[
              Icon(Icons.access_time_rounded, size: 8,
                  color: Colors.orange.withValues(alpha: 0.8)),
              const SizedBox(width: 3),
            ] else if (hasInterval) ...[
              Icon(Icons.repeat_rounded, size: 8,
                  color: accentCol.withValues(alpha: 0.8)),
              const SizedBox(width: 3),
            ],
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: anyEnabled
                      ? Colors.white.withValues(alpha: 0.85)
                      : Colors.white.withValues(alpha: 0.25),
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
