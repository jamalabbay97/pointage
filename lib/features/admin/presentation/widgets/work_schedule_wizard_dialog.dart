import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/user_model.dart';
import '../../../../core/services/app_translations.dart';

class WorkScheduleWizardDialog extends ConsumerStatefulWidget {
  const WorkScheduleWizardDialog({
    super.key,
    required this.managerUser,
  });

  final UserModel managerUser;

  static Future<void> show(BuildContext context, UserModel managerUser) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => WorkScheduleWizardDialog(managerUser: managerUser),
    );
  }

  @override
  ConsumerState<WorkScheduleWizardDialog> createState() =>
      _WorkScheduleWizardDialogState();
}

class _WorkScheduleWizardDialogState
    extends ConsumerState<WorkScheduleWizardDialog> {
  String _selectedSchedule = 'days_20_10';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.managerUser.scheduleType == 'standard') {
      _selectedSchedule = 'standard';
    }
  }

  Future<void> _applySchedule() async {
    setState(() => _saving = true);
    try {
      final db = FirebaseFirestore.instance;
      final managerUid = widget.managerUser.uid;

      // 1. Update Manager document
      await db.collection('users').doc(managerUid).update({
        'scheduleType': _selectedSchedule,
        'isFirstLogin': false,
      });

      // 2. Fetch and update all employees under this Manager
      final createdByQuery = await db
          .collection('users')
          .where('createdBy', isEqualTo: managerUid)
          .get();

      final managerIdQuery = await db
          .collection('users')
          .where('managerId', isEqualTo: managerUid)
          .get();

      final docsToUpdate = <String, DocumentReference>{};
      for (final doc in createdByQuery.docs) {
        if (doc.id != managerUid) {
          docsToUpdate[doc.id] = doc.reference;
        }
      }
      for (final doc in managerIdQuery.docs) {
        if (doc.id != managerUid) {
          docsToUpdate[doc.id] = doc.reference;
        }
      }

      final batch = db.batch();
      for (final ref in docsToUpdate.values) {
        batch.update(ref, {'scheduleType': _selectedSchedule});
      }
      if (docsToUpdate.isNotEmpty) {
        await batch.commit();
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ref.tr('scheduleApplied')),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error setting work schedule: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          width: 520,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.calendar_month_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ref.tr('scheduleSetupTitle'),
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          ref.tr('setupWorkSchedule'),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                ref.tr('scheduleSetupSubtitle'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),

              // Option 1: 20 Working Days + 10 Days Off
              _ScheduleOptionTile(
                title: ref.tr('schedule2010Title'),
                subtitle: ref.tr('schedule2010Sub'),
                icon: Icons.date_range_rounded,
                color: Colors.indigo,
                isSelected: _selectedSchedule == 'days_20_10',
                isDark: isDark,
                onTap: () {
                  setState(() => _selectedSchedule = 'days_20_10');
                },
              ),
              const SizedBox(height: 12),

              // Option 2: Standard Schedule
              _ScheduleOptionTile(
                title: ref.tr('scheduleStandardTitle'),
                subtitle: ref.tr('scheduleStandardSub'),
                icon: Icons.work_history_rounded,
                color: Colors.teal,
                isSelected: _selectedSchedule == 'standard',
                isDark: isDark,
                onTap: () {
                  setState(() => _selectedSchedule = 'standard');
                },
              ),
              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _applySchedule,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_rounded),
                  label: Text(
                    _saving
                        ? ref.tr('savingSchedule')
                        : ref.tr('confirmSchedule'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleOptionTile extends StatelessWidget {
  const _ScheduleOptionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected
        ? Theme.of(context).colorScheme.primary
        : (isDark ? Colors.grey.shade800 : Colors.grey.shade300);
    final bgColor = isSelected
        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
        : (isDark ? const Color(0xFF262626) : Colors.grey.shade50);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? color : Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
