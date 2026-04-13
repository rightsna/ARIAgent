part of '../schedule_tab.dart';

// ── 하루보기 헤더 ─────────────────────────────────────────

class _TodayHeader extends StatelessWidget {
  final int today;
  final double colWidth;
  const _TodayHeader({required this.today, required this.colWidth});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          SizedBox(width: _kTimeColW),
          SizedBox(
            width: colWidth,
            child: Row(
              children: [
                Container(
                  width: 22, height: 22,
                  decoration: const BoxDecoration(color: _kAccent, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text(
                    _kDayNames[today],
                    style: const TextStyle(
                      color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${now.month}월 ${now.day}일',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11, fontWeight: FontWeight.w600,
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

// ── 하루보기 그리드 (시간축 + 오늘 단일 컬럼) ─────────────

class _DayViewGrid extends StatelessWidget {
  final List<AriScheduledTask> tasks;
  final String? selectedTaskId;
  final ValueChanged<String> onTaskSelected;
  final double colWidth;

  const _DayViewGrid({
    required this.tasks,
    required this.selectedTaskId,
    required this.onTaskSelected,
    required this.colWidth,
  });

  @override
  Widget build(BuildContext context) {
    final now = TimeOfDay.now();
    final nowPx = now.hour * _kHourH + now.minute * _kHourH / 60;

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
                  selectedTaskId: selectedTaskId,
                  onTaskSelected: onTaskSelected,
                  isToday: true,
                ),
              ),
            ],
          ),
          Positioned(
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
