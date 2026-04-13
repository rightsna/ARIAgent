part of '../schedule_tab.dart';

class _TaskDetailBar extends StatelessWidget {
  final List<AriScheduledTask> tasks;
  final VoidCallback onClose;
  final void Function(AriScheduledTask) onDelete;
  final void Function(AriScheduledTask) onToggle;

  const _TaskDetailBar({
    required this.tasks,
    required this.onClose,
    required this.onDelete,
    required this.onToggle,
  });

  static String _fmt(DateTime? dt) {
    if (dt == null) return '';
    final l = dt.toLocal();
    return '${l.year}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')} '
        '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF252545),
        border: Border(top: BorderSide(color: _kAccent.withValues(alpha: 0.5), width: 1.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 20, offset: const Offset(0, -6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 상단: 슬롯 헤더 + 닫기
          Row(
            children: [
              Text(
                tasks.length > 1 ? '${tasks.length}개의 루틴' : '루틴 상세',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onClose,
                child: Icon(Icons.close, size: 16,
                    color: Colors.white.withValues(alpha: 0.3)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // task 목록
          for (final task in tasks) ...[
            _TaskRow(task: task, onDelete: onDelete, onToggle: onToggle),
            if (task != tasks.last) const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

// ── 개별 task 행 ──────────────────────────────────────────

class _TaskRow extends StatelessWidget {
  final AriScheduledTask task;
  final void Function(AriScheduledTask) onDelete;
  final void Function(AriScheduledTask) onToggle;

  const _TaskRow({
    required this.task,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 7, height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: task.enabled
                      ? const Color(0xFF4ADE80)
                      : Colors.white.withValues(alpha: 0.2),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(task.label,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
              Text(task.scheduleDescription,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 10)),
              const SizedBox(width: 8),
              SizedBox(
                width: 30, height: 18,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: Switch(
                    value: task.enabled,
                    onChanged: (_) => onToggle(task),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    activeThumbColor: const Color(0xFF4ADE80),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => onDelete(task),
                child: Icon(Icons.delete_outline, size: 15,
                    color: Colors.red.withValues(alpha: 0.5)),
              ),
            ],
          ),
          // 프롬프트
          const SizedBox(height: 6),
          Text(task.prompt,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 10, height: 1.4),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          // 마지막 실행
          if (task.lastResult != null) ...[
            const SizedBox(height: 4),
            Text('마지막 실행: ${_TaskDetailBar._fmt(task.lastRunAt)}',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.2),
                    fontSize: 9)),
          ],
        ],
      ),
    );
  }
}
