part of '../schedule_tab.dart';

class RoutineCard extends StatelessWidget {
  static const double kHeight = _kCardH;

  final AriScheduledTask task;
  final bool isSelected;
  final VoidCallback onTap;

  const RoutineCard({
    super.key,
    required this.task,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = task.enabled;
    final isInterval = _isIntervalType(task.scheduleSpec?['type'] as String?);
    final accentCol = isInterval ? const Color(0xFF4ADE80) : _kAccent;

    final borderCol = enabled
        ? accentCol.withValues(alpha: isSelected ? 0.9 : 0.4)
        : Colors.white.withValues(alpha: 0.1);
    final bgCol = isSelected
        ? accentCol.withValues(alpha: 0.15)
        : Colors.white.withValues(alpha: 0.04);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: kHeight,
        decoration: BoxDecoration(
          color: bgCol,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: borderCol, width: 1),
          boxShadow: isSelected && enabled
              ? [BoxShadow(color: accentCol.withValues(alpha: 0.25), blurRadius: 6)]
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Row(
          children: [
            if (task.isOneOff)
              Icon(Icons.access_time_rounded, size: 8,
                  color: Colors.orange.withValues(alpha: 0.8))
            else if (isInterval)
              Icon(Icons.repeat_rounded, size: 8,
                  color: accentCol.withValues(alpha: 0.8)),
            if (task.isOneOff || isInterval) const SizedBox(width: 3),
            Expanded(
              child: Text(
                task.label,
                style: TextStyle(
                  color: enabled
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
