part of '../schedule_tab.dart';

class _Occurrence {
  final AriScheduledTask task;
  final int hour;
  final int minute;

  const _Occurrence(this.task, this.hour, this.minute);

  double get topPx => hour * _kHourH + minute * _kHourH / 60 + _kCardTopPad;
}

class DayColumn extends StatelessWidget {
  final List<AriScheduledTask> tasks;
  final String? selectedTaskId;
  final ValueChanged<String> onTaskSelected;
  final bool isToday;

  const DayColumn({
    super.key,
    required this.tasks,
    required this.selectedTaskId,
    required this.onTaskSelected,
    this.isToday = false,
  });

  static int _hour(AriScheduledTask t) {
    if (t.isOneOff && t.scheduledFor != null) return t.scheduledFor!.toLocal().hour;
    final type = t.scheduleSpec?['type'] as String?;
    if (_isIntervalType(type)) return 0;
    return (t.scheduleSpec?['hour'] as num?)?.toInt() ?? 0;
  }

  static int _minute(AriScheduledTask t) {
    if (t.isOneOff && t.scheduledFor != null) return t.scheduledFor!.toLocal().minute;
    final type = t.scheduleSpec?['type'] as String?;
    if (_isIntervalType(type)) return 0;
    return (t.scheduleSpec?['minute'] as num?)?.toInt() ?? 0;
  }

  static List<_Occurrence> _expand(AriScheduledTask t) {
    final type = t.scheduleSpec?['type'] as String?;
    if (t.isOneOff && t.scheduledFor != null) {
      final local = t.scheduledFor!.toLocal();
      return [_Occurrence(t, local.hour, local.minute)];
    }
    if (type == 'every_n_hours') {
      final every = (t.scheduleSpec!['every'] as num).toInt().clamp(1, 24);
      return [for (int h = 0; h < 24; h += every) _Occurrence(t, h, 0)];
    }
    if (type == 'every_n_minutes') {
      final every = (t.scheduleSpec!['every'] as num).toInt().clamp(1, 1440);
      return [for (int m = 0; m < 1440; m += every) _Occurrence(t, m ~/ 60, m % 60)];
    }
    return [_Occurrence(t, _hour(t), _minute(t))];
  }

  @override
  Widget build(BuildContext context) {
    final occurrences = [for (final t in tasks) ..._expand(t)];
    final byHour = <int, List<_Occurrence>>{};
    for (final o in occurrences) {
      byHour.putIfAbsent(o.hour, () => []).add(o);
    }

    return SizedBox(
      height: _kTotalH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (isToday)
            Positioned.fill(
              child: Container(color: _kAccent.withValues(alpha: 0.04)),
            ),
          for (final o in occurrences)
            Positioned(
              top: o.topPx,
              left: _indentOf(o, byHour),
              right: 1,
              height: _kCardH,
              child: RoutineCard(
                task: o.task,
                isSelected: selectedTaskId == o.task.id,
                onTap: () => onTaskSelected(o.task.id),
              ),
            ),
        ],
      ),
    );
  }

  double _indentOf(_Occurrence o, Map<int, List<_Occurrence>> byHour) {
    final siblings = byHour[o.hour] ?? [];
    return siblings.indexOf(o) * 5.0;
  }
}
