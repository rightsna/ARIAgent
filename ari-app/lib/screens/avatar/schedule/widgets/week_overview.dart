part of '../schedule_tab.dart';

// ── 주간 타임라인 (Y=스케줄, X=요일) ─────────────────────

class WeekOverview extends StatelessWidget {
  final List<List<AriScheduledTask>> dayTaskLists;
  final String? selectedTaskId;
  final ValueChanged<String> onTaskSelected;
  final int today;

  const WeekOverview({
    super.key,
    required this.dayTaskLists,
    required this.selectedTaskId,
    required this.onTaskSelected,
    required this.today,
  });

  @override
  Widget build(BuildContext context) {
    final seen = <String>{};
    final tasks = <AriScheduledTask>[];
    for (final dayList in dayTaskLists) {
      for (final t in dayList) {
        if (seen.add(t.id)) tasks.add(t);
      }
    }

    final activeDays = <String, Set<int>>{};
    for (int d = 0; d < 7; d++) {
      for (final t in dayTaskLists[d]) {
        activeDays.putIfAbsent(t.id, () => {}).add(d);
      }
    }

    if (tasks.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      width: _kWeekViewW,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final task in tasks)
            _TimelineRow(
              task: task,
              activeDays: activeDays[task.id] ?? {},
              today: today,
              isSelected: selectedTaskId == task.id,
              onTap: () => onTaskSelected(task.id),
            ),
        ],
      ),
    );
  }
}

// ── 타임라인 한 행 (라벨 + 점-선) ───────────────────────

class _TimelineRow extends StatelessWidget {
  static const double _rowH = 48.0;

  final AriScheduledTask task;
  final Set<int> activeDays;
  final int today;
  final bool isSelected;
  final VoidCallback onTap;

  const _TimelineRow({
    required this.task,
    required this.activeDays,
    required this.today,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isInterval = _isIntervalType(task.scheduleSpec?['type'] as String?);
    final dotColor = isInterval ? const Color(0xFF4ADE80) : _kAccent;
    final enabled = task.enabled;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: _rowH,
        color: isSelected ? dotColor.withValues(alpha: 0.06) : Colors.transparent,
        child: Row(
          children: [
            // 라벨
            SizedBox(
              width: _kWeekLabelW,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      task.label,
                      style: TextStyle(
                        color: enabled
                            ? Colors.white.withValues(alpha: 0.85)
                            : Colors.white.withValues(alpha: 0.3),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      task.scheduleDescription,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 9,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            // 점-선 타임라인
            SizedBox(
              width: _kCardW * 7,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (activeDays.isNotEmpty)
                    ..._buildLines(activeDays, dotColor, enabled),
                  Row(
                    children: List.generate(7, (d) => SizedBox(
                      width: _kCardW,
                      child: Center(
                        child: _Dot(
                          active: activeDays.contains(d),
                          isToday: d == today,
                          enabled: enabled,
                          color: dotColor,
                          isSelected: isSelected,
                        ),
                      ),
                    )),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildLines(Set<int> active, Color color, bool enabled) {
    final sorted = active.toList()..sort();
    if (sorted.length < 2) return [];
    final lineColor = enabled
        ? color.withValues(alpha: 0.3)
        : Colors.white.withValues(alpha: 0.07);
    return [
      for (int i = 0; i < sorted.length - 1; i++)
        Positioned(
          left: sorted[i] * _kCardW + _kCardW / 2,
          width: (sorted[i + 1] - sorted[i]) * _kCardW,
          top: _rowH / 2 - 0.5,
          height: 1,
          child: Container(color: lineColor),
        ),
    ];
  }
}

// ── 타임라인 점 ──────────────────────────────────────────

class _Dot extends StatelessWidget {
  final bool active;
  final bool isToday;
  final bool enabled;
  final Color color;
  final bool isSelected;

  const _Dot({
    required this.active,
    required this.isToday,
    required this.enabled,
    required this.color,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (!active) {
      return Container(
        width: 4, height: 4,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.08),
        ),
      );
    }
    final size = isSelected ? 14.0 : (isToday ? 12.0 : 10.0);
    final fillColor = enabled ? color : Colors.white.withValues(alpha: 0.2);
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fillColor,
        border: isToday
            ? Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5)
            : null,
        boxShadow: isSelected && enabled
            ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8)]
            : null,
      ),
    );
  }
}
