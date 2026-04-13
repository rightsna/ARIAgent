part of '../schedule_tab.dart';

class _TaskDetailBar extends StatelessWidget {
  final AriScheduledTask task;
  final VoidCallback onClose;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

  const _TaskDetailBar({
    required this.task,
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
        color: const Color(0xFF13132B),
        border: Border(top: BorderSide(color: _kAccent.withValues(alpha: 0.35))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 12, offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: task.enabled
                      ? const Color(0xFF4ADE80)
                      : Colors.white.withValues(alpha: 0.2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(task.label,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
              ),
              Text(task.scheduleDescription,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10)),
              const SizedBox(width: 8),
              SizedBox(
                width: 32, height: 20,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: Switch(
                    value: task.enabled,
                    onChanged: (_) => onToggle(),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    activeThumbColor: const Color(0xFF4ADE80),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onDelete,
                child: Icon(Icons.delete_outline, size: 16,
                    color: Colors.red.withValues(alpha: 0.5)),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onClose,
                child: Icon(Icons.close, size: 16,
                    color: Colors.white.withValues(alpha: 0.3)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(task.prompt,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6), fontSize: 11, height: 1.4),
                maxLines: 3,
                overflow: TextOverflow.ellipsis),
          ),
          if (task.lastResult != null) ...[
            const SizedBox(height: 4),
            Text('마지막 실행: ${_fmt(task.lastRunAt)}',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.25), fontSize: 9)),
          ],
        ],
      ),
    );
  }
}
