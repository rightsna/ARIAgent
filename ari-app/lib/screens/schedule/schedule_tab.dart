import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ari_plugin/ari_plugin.dart';
import 'package:ari_agent/screens/schedule/widgets/task_card.dart';

/// 스케줄 탭 - 서버에 등록된 작업 목록
class ScheduleTab extends StatefulWidget {
  const ScheduleTab({super.key});

  @override
  State<ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<ScheduleTab> {
  String? _expandedTaskId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _refreshTasks();
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

  @override
  Widget build(BuildContext context) {
    final avatar = context.watch<AvatarProvider>();
    final taskProvider = context.watch<AriTaskProvider>();
    final currentAgentId = avatar.currentAvatarId;

    // 현재 아바타의 작업만 필터
    final filteredTasks = taskProvider.tasksForAgent(currentAgentId);

    final List<Widget> items = [];

    // 헤더
    items.add(
      Row(
        children: [
          Text(
            '📅 ${avatar.name}의 스케줄 (${filteredTasks.length})',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _refreshTasks,
            child: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: Color(0xFF6C63FF),
                    ),
                  )
                : Icon(
                    Icons.refresh,
                    size: 16,
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
          ),
        ],
      ),
    );
    items.add(const SizedBox(height: 8));

    // 안내
    items.add(
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF6C63FF).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
          ),
        ),
        child: Text(
          '💡 채팅에서 "매일 9시에 뉴스 요약해줘" 같이 말하면\n자동으로 스케줄이 등록됩니다!',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 11,
            height: 1.5,
          ),
        ),
      ),
    );
    items.add(const SizedBox(height: 12));

    for (final task in filteredTasks) {
      final taskMap = task.toMap();
      items.add(
        TaskCard(
          task: taskMap,
          isExpanded: _expandedTaskId == task.id,
          onTap: () => setState(
            () => _expandedTaskId = _expandedTaskId == task.id
                ? null
                : task.id,
          ),
          onDelete: () async {
            await taskProvider.deleteTask(task.id);
          },
        ),
      );
    }

    if (filteredTasks.isEmpty) {
      items.add(
        Padding(
          padding: const EdgeInsets.only(top: 40),
          child: Center(
            child: Text(
              '등록된 스케줄이 없습니다',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.25),
                fontSize: 13,
              ),
            ),
          ),
        ),
      );
    }

    return ListView(padding: const EdgeInsets.all(16), children: items);
  }
}
