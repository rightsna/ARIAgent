import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ari_plugin/ari_plugin.dart';
import '../widgets/tab_section_header.dart';

part 'widgets/schedule_constants.dart';
part 'widgets/routine_card.dart';
part 'widgets/day_column.dart';
part 'widgets/day_view_grid.dart';
part 'widgets/week_overview.dart';
part 'widgets/task_detail_bar.dart';

// ── View mode ─────────────────────────────────────────────
enum _ViewMode { day, week }

// ─────────────────────────────────────────────────────────────────────────────
//  ScheduleTab
// ─────────────────────────────────────────────────────────────────────────────

class ScheduleTab extends StatefulWidget {
  const ScheduleTab({super.key});

  @override
  State<ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<ScheduleTab> {
  bool _isLoading = false;
  String? _selectedTaskId;
  _ViewMode _viewMode = _ViewMode.day;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _refreshTasks();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToNow());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshTasks() async {
    setState(() => _isLoading = true);
    try {
      await context.read<AriTaskProvider>().refresh();
    } catch (e) {
      debugPrint('[Schedule] ❌ 갱신 실패: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _scrollToNow() {
    final now = TimeOfDay.now();
    final targetPx =
        (now.hour * _kHourH + now.minute * _kHourH / 60).clamp(0.0, _kTotalH - 200);
    if (_scrollController.hasClients) _scrollController.jumpTo(targetPx);
  }

  void _onTaskSelected(String id) {
    setState(() => _selectedTaskId = _selectedTaskId == id ? null : id);
  }

  @override
  Widget build(BuildContext context) {
    final avatar = context.watch<AvatarProvider>();
    final taskProvider = context.watch<AriTaskProvider>();
    final allTasks = taskProvider.tasks;

    final dayTaskLists = List.generate(7, (_) => <AriScheduledTask>[]);
    for (final task in allTasks) {
      _assignToDays(task, dayTaskLists);
    }

    AriScheduledTask? selectedTask;
    if (_selectedTaskId != null) {
      for (final t in allTasks) {
        if (t.id == _selectedTaskId) { selectedTask = t; break; }
      }
    }

    final today = DateTime.now().weekday % 7;

    return Column(
      children: [
        // ── 헤더 ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: TabSectionHeader(
            icon: Icons.calendar_month_outlined,
            title: '${avatar.name}의 스케줄',
            description: '에이전트가 정해진 시간에 알아서 처리하는 일들이에요.',
            trailing: GestureDetector(
              onTap: _refreshTasks,
              child: _isLoading
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 1.5, color: _kAccent),
                    )
                  : Icon(Icons.refresh, size: 16,
                      color: Colors.white.withValues(alpha: 0.3)),
            ),
          ),
        ),

        // ── 뷰 토글 ───────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              _ViewToggleBtn(
                label: '하루보기',
                active: _viewMode == _ViewMode.day,
                onTap: () {
                  setState(() => _viewMode = _ViewMode.day);
                  WidgetsBinding.instance
                      .addPostFrameCallback((_) => _scrollToNow());
                },
              ),
              const SizedBox(width: 6),
              _ViewToggleBtn(
                label: '주간보기',
                active: _viewMode == _ViewMode.week,
                onTap: () => setState(() => _viewMode = _ViewMode.week),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // ── 시간표 ────────────────────────────────────────
        Expanded(
          child: allTasks.isEmpty
              ? Center(
                  child: Text(
                    '등록된 스케줄이 없습니다\n채팅에서 "매일 9시에 뉴스 요약해줘" 라고 말해보세요',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.25),
                      fontSize: 12, height: 1.6,
                    ),
                  ),
                )
              : _viewMode == _ViewMode.week
                  ? SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: _kWeekViewW + 32,
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _DayHeader(today: today, leftWidth: _kWeekLabelW),
                                Container(
                                  height: 1, width: _kWeekViewW,
                                  color: Colors.white.withValues(alpha: 0.07),
                                ),
                                WeekOverview(
                                  dayTaskLists: dayTaskLists,
                                  selectedTaskId: _selectedTaskId,
                                  onTaskSelected: _onTaskSelected,
                                  today: today,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  // ── 하루보기: 전체 너비 사용 ──────────────
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final colW = constraints.maxWidth - 32 - _kTimeColW;
                        return SingleChildScrollView(
                          controller: _scrollController,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _TodayHeader(today: today, colWidth: colW),
                                Container(
                                  height: 1,
                                  width: _kTimeColW + colW,
                                  color: Colors.white.withValues(alpha: 0.07),
                                ),
                                _DayViewGrid(
                                  tasks: dayTaskLists[today],
                                  selectedTaskId: _selectedTaskId,
                                  onTaskSelected: _onTaskSelected,
                                  colWidth: colW,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),

        // ── 선택 상세 ─────────────────────────────────────
        if (selectedTask != null)
          _TaskDetailBar(
            task: selectedTask,
            onClose: () => setState(() => _selectedTaskId = null),
            onDelete: () async {
              await taskProvider.deleteTask(selectedTask!.id);
              setState(() => _selectedTaskId = null);
            },
            onToggle: () async {
              await taskProvider.toggleTask(selectedTask!.id);
            },
          ),
      ],
    );
  }

  static void _assignToDays(
    AriScheduledTask task,
    List<List<AriScheduledTask>> dayLists,
  ) {
    if (task.isOneOff) {
      final wd = task.startAt.toLocal().weekday % 7;
      dayLists[wd].add(task);
      return;
    }
    final type = task.scheduleSpec?['type'] as String?;
    if (type == 'daily') {
      for (int d = 0; d < 7; d++) { dayLists[d].add(task); }
    } else if (type == 'weekly') {
      final rawDays = task.scheduleSpec?['days'];
      if (rawDays is List) {
        for (final d in rawDays) { dayLists[(d as num).toInt()].add(task); }
      }
    } else {
      for (int d = 0; d < 7; d++) { dayLists[d].add(task); }
    }
  }
}

// ── 요일 헤더 ────────────────────────────────────────────

class _DayHeader extends StatelessWidget {
  final int today;
  final double leftWidth;

  const _DayHeader({required this.today, this.leftWidth = _kTimeColW});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          SizedBox(width: leftWidth),
          ...List.generate(7, (i) {
            final isToday = i == today;
            final color = i == 0
                ? const Color(0xFFFF6B6B)
                : i == 6
                    ? const Color(0xFF6B9EFF)
                    : Colors.white.withValues(alpha: 0.5);
            return SizedBox(
              width: _kCardW,
              child: Center(
                child: isToday
                    ? Container(
                        width: 22, height: 22,
                        decoration: const BoxDecoration(
                            color: _kAccent, shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: Text(_kDayNames[i],
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800)),
                      )
                    : Text(_kDayNames[i],
                        style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── 뷰 토글 버튼 ─────────────────────────────────────────

class _ViewToggleBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ViewToggleBtn(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active ? _kAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? _kAccent : Colors.white.withValues(alpha: 0.15),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.white.withValues(alpha: 0.4),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
