import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/avatar_provider.dart';
import '../../providers/task_provider.dart';
import 'package:ari_agent/screens/schedule/widgets/task_card.dart';

/// 스케줄 탭 - crontab에 등록된 작업 목록 (읽기 전용)
class ScheduleTab extends StatefulWidget {
  const ScheduleTab({super.key});

  @override
  State<ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<ScheduleTab> {
  List<Map<String, dynamic>> _tasks = [];
  bool _isLoading = true;
  String? _expandedTaskId;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    try {
      final taskProvider = context.read<TaskProvider>();
      final allTasks = await taskProvider.fetchTasksFromServer();
      final currentAgentId = context.read<AvatarProvider>().currentAvatarId;

      setState(() {
        _tasks = allTasks.where((t) {
          final aid = t['agentId'] ?? 'default';
          return aid == currentAgentId;
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[Schedule] ❌ 로드 실패: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatar = context.watch<AvatarProvider>();

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
      );
    }

    final List<Widget> items = [];

    // 헤더
    items.add(
      Row(
        children: [
          Text(
            '📅 ${avatar.name}의 스케줄 (${_tasks.length})',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _loadTasks,
            child: Icon(
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

    for (final task in _tasks) {
      items.add(
        TaskCard(
          task: task,
          isExpanded: _expandedTaskId == task['id'],
          onTap: () => setState(
            () => _expandedTaskId = _expandedTaskId == task['id']
                ? null
                : task['id'],
          ),
          onDelete: () {
            // 삭제 로직은 Provider를 통하도록 개선 필요 (현재는 UI 수동 관리 상태)
            setState(() => _tasks.removeWhere((t) => t['id'] == task['id']));
          },
        ),
      );
    }

    if (_tasks.isEmpty) {
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
