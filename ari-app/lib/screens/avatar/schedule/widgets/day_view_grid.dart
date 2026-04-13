part of '../schedule_tab.dart';

// ── 하루보기 헤더 ─────────────────────────────────────────

class _DayViewHeader extends StatelessWidget {
  final DateTime viewDate;
  final double colWidth;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;

  const _DayViewHeader({
    required this.viewDate,
    required this.colWidth,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final isToday = viewDate.year == today.year &&
        viewDate.month == today.month &&
        viewDate.day == today.day;
    final isTomorrow = viewDate.difference(DateTime(today.year, today.month, today.day)).inDays == 1;
    final dayIdx = viewDate.weekday % 7; // 0=일, 1=월, ..., 6=토
    final dayColor = dayIdx == 0
        ? const Color(0xFFFF6B6B)
        : dayIdx == 6
            ? const Color(0xFF6B9EFF)
            : Colors.white;

    String label;
    if (isToday) {
      label = '오늘';
    } else if (isTomorrow) {
      label = '내일';
    } else {
      label = '${viewDate.month}월 ${viewDate.day}일';
    }

    return SizedBox(
      height: 36,
      child: Row(
        children: [
          SizedBox(width: _kTimeColW),
          // 이전 날
          GestureDetector(
            onTap: onPrev,
            child: Icon(Icons.chevron_left,
                size: 20, color: Colors.white.withValues(alpha: 0.4)),
          ),
          const SizedBox(width: 4),
          // 날짜 표시
          GestureDetector(
            onTap: isToday ? null : onToday,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    color: isToday ? _kAccent : Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _kDayNames[dayIdx],
                    style: TextStyle(
                      color: isToday ? Colors.white : dayColor,
                      fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: isToday ? 0.85 : 0.5),
                    fontSize: 12, fontWeight: FontWeight.w600,
                  ),
                ),
                if (!isToday) ...[
                  const SizedBox(width: 4),
                  Text(
                    '(탭하면 오늘)',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.2),
                      fontSize: 9,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 4),
          // 다음 날
          GestureDetector(
            onTap: onNext,
            child: Icon(Icons.chevron_right,
                size: 20, color: Colors.white.withValues(alpha: 0.4)),
          ),
        ],
      ),
    );
  }
}

// ── 하루보기 그리드 (시간축 + 오늘 단일 컬럼) ─────────────

class _DayViewGrid extends StatelessWidget {
  final List<AriScheduledTask> tasks;
  final List<String> selectedTaskIds;
  final void Function(List<AriScheduledTask>) onSlotSelected;
  final double colWidth;
  final DateTime displayDate;

  const _DayViewGrid({
    required this.tasks,
    required this.selectedTaskIds,
    required this.onSlotSelected,
    required this.colWidth,
    required this.displayDate,
  });

  @override
  Widget build(BuildContext context) {
    final now = TimeOfDay.now();
    final nowPx = now.hour * _kHourH + now.minute * _kHourH / 60;
    final today = DateTime.now();
    final isToday = displayDate.year == today.year &&
        displayDate.month == today.month &&
        displayDate.day == today.day;

    return SizedBox(
      width: _kTimeColW + colWidth,
      height: _kTotalH,
      child: Stack(
        children: [
          Positioned(
            left: _kTimeColW, top: 0, right: 0, bottom: 0,
            child: CustomPaint(painter: _GridPainter()),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _TimeAxis(),
              SizedBox(
                width: colWidth,
                child: DayColumn(
                  tasks: tasks,
                  selectedTaskIds: selectedTaskIds,
                  onSlotSelected: onSlotSelected,
                  displayDate: displayDate,
                  isToday: isToday,
                ),
              ),
            ],
          ),
          // 현재 시간선 (오늘만 표시)
          if (isToday) Positioned(
            top: nowPx, left: _kTimeColW, width: colWidth,
            child: Row(
              children: [
                Container(
                  width: 7, height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF6B6B), shape: BoxShape.circle),
                ),
                Expanded(
                  child: Container(
                    height: 1,
                    color: const Color(0xFFFF6B6B).withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 시간축 ────────────────────────────────────────────────

class _TimeAxis extends StatelessWidget {
  const _TimeAxis();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _kTimeColW,
      height: _kTotalH,
      child: Stack(
        children: [
          for (int h = 0; h < 24; h++)
            Positioned(
              top: h * _kHourH, left: 0, right: 4,
              child: Text(
                '${h.toString().padLeft(2, '0')}:00',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: h % 6 == 0 ? 0.5 : 0.2),
                  fontSize: h % 6 == 0 ? 10 : 9,
                  fontWeight: h % 6 == 0 ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── 그리드 라인 Painter ───────────────────────────────────

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final minor = Paint()..color = const Color(0x07FFFFFF)..strokeWidth = 0.5;
    final major = Paint()..color = const Color(0x12FFFFFF)..strokeWidth = 0.5;
    for (int h = 0; h <= 24; h++) {
      final y = h * _kHourH;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), h % 6 == 0 ? major : minor);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
