import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/web_layout.dart';
import '../../auth/domain/auth_provider.dart';
import '../../notifications/data/notification_provider.dart';

class SendNotificationScreen extends ConsumerStatefulWidget {
  const SendNotificationScreen({super.key});

  @override
  ConsumerState<SendNotificationScreen> createState() =>
      _SendNotificationScreenState();
}

class _SendNotificationScreenState
    extends ConsumerState<SendNotificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _linkCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _linkCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);

    final authUser = ref.read(authStateProvider).valueOrNull;
    final userModel = ref.read(currentUserModelProvider).valueOrNull;
    if (authUser == null || userModel == null) {
      setState(() => _sending = false);
      return;
    }

    final service = ref.read(notificationServiceProvider);

    try {
      final link = _linkCtrl.text.trim();
      final finalLink = link.isEmpty ? null : link;

      if (userModel.isAdmin) {
        // Admin → system broadcast, no sender name, no target manager
        await service.send(
          title: _titleCtrl.text.trim(),
          body: _bodyCtrl.text.trim(),
          type: 'admin',
          senderId: authUser.uid,
          senderName: null,
          targetManagerId: null,
          link: finalLink,
        );
      } else if (userModel.isManager) {
        // Manager → targeted to their own employees
        await service.send(
          title: _titleCtrl.text.trim(),
          body: _bodyCtrl.text.trim(),
          type: 'manager',
          senderId: authUser.uid,
          senderName: userModel.displayName,
          targetManagerId: authUser.uid,
          link: finalLink,
        );
      }

      if (mounted) {
        _titleCtrl.clear();
        _bodyCtrl.clear();
        _linkCtrl.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                SizedBox(width: 10),
                Text('Notification sent successfully!'),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send: $e'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }

    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final userModel = ref.watch(currentUserModelProvider).valueOrNull;
    final isAdmin = userModel?.isAdmin ?? false;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final accentColor =
        isAdmin ? const Color(0xFF00BFA5) : const Color(0xFF246BFD);

    return Scaffold(
      appBar: AppBar(
        title: Text(isAdmin ? 'Send System Notification' : 'Send Notification'),
      ),
      body: WebLayout(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isAdmin
                            ? Icons.campaign_rounded
                            : Icons.people_alt_outlined,
                        color: accentColor,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isAdmin
                                  ? 'Broadcast to All Users'
                                  : 'Send to Your Employees',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: accentColor,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              isAdmin
                                  ? 'This message will appear as a system notification to all users. Your name will not be shown.'
                                  : 'This message will only be visible to employees you have registered. Your name will appear as the sender.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Title field
                const Text(
                  'Notification Title',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _titleCtrl,
                  maxLength: 80,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'e.g. Important announcement',
                    prefixIcon: const Icon(Icons.title_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF1E1E1E)
                        : const Color(0xFFF8F8F8),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Please enter a title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Body field
                const Text(
                  'Message',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _bodyCtrl,
                  maxLines: 5,
                  maxLength: 500,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Write your message here...',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF1E1E1E)
                        : const Color(0xFFF8F8F8),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Please enter a message';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // URL field
                const Text(
                  'URL (Optional)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _linkCtrl,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    hintText: 'e.g. https://example.com/update',
                    prefixIcon: const Icon(Icons.link_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF1E1E1E)
                        : const Color(0xFFF8F8F8),
                  ),
                  validator: (v) {
                    if (v != null && v.trim().isNotEmpty) {
                      final uri = Uri.tryParse(v.trim());
                      if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
                        return 'Please enter a valid URL (e.g. https://...)';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 28),

                // Send button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: accentColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded),
                    label: Text(_sending ? 'Sending...' : 'Send Notification'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
