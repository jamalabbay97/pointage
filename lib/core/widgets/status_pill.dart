import 'package:flutter/material.dart';

enum AttendanceStatusType {
  checkedIn,
  checkedOut,
  absent,
  notCheckedIn,
  offlinePending,
}

class StatusPill extends StatefulWidget {
  const StatusPill({
    super.key,
    required this.statusType,
    required this.label,
    this.compact = false,
  });

  final AttendanceStatusType statusType;
  final String label;
  final bool compact;

  @override
  State<StatusPill> createState() => _StatusPillState();
}

class _StatusPillState extends State<StatusPill>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color get _baseColor {
    switch (widget.statusType) {
      case AttendanceStatusType.checkedIn:
        return const Color(0xFF10B981);
      case AttendanceStatusType.checkedOut:
        return const Color(0xFF3B82F6);
      case AttendanceStatusType.absent:
        return const Color(0xFFEF4444);
      case AttendanceStatusType.notCheckedIn:
        return const Color(0xFFF59E0B);
      case AttendanceStatusType.offlinePending:
        return const Color(0xFF8B5CF6);
    }
  }

  IconData get _icon {
    switch (widget.statusType) {
      case AttendanceStatusType.checkedIn:
        return Icons.check_circle_rounded;
      case AttendanceStatusType.checkedOut:
        return Icons.done_all_rounded;
      case AttendanceStatusType.absent:
        return Icons.cancel_rounded;
      case AttendanceStatusType.notCheckedIn:
        return Icons.pending_actions_rounded;
      case AttendanceStatusType.offlinePending:
        return Icons.cloud_sync_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = _baseColor;
    final bgColor =
        isDark ? color.withValues(alpha: 0.18) : color.withValues(alpha: 0.12);
    final borderColor =
        isDark ? color.withValues(alpha: 0.35) : color.withValues(alpha: 0.3);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: widget.compact ? 8 : 12,
        vertical: widget.compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, _) => Container(
              width: widget.compact ? 6 : 8,
              height: widget.compact ? 6 : 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: _pulseAnimation.value),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: _pulseAnimation.value * 0.6),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 7),
          Icon(_icon, size: widget.compact ? 12 : 14, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              widget.label,
              style: TextStyle(
                color: color,
                fontSize: widget.compact ? 11 : 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
