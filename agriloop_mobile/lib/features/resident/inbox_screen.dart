import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../providers/app_state_provider.dart';

class InboxScreen extends ConsumerWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(agriStateProvider).notifications;
    final unread = notifications.where((n) => n.isUnread).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification inbox'),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: () =>
                  ref.read(agriStateProvider.notifier).markAllNotificationsRead(),
              child: const Text('Mark all read'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: notifications.isEmpty
          ? const Center(
              child: Text('No notifications yet.',
                  style: TextStyle(color: AppTheme.textMuted)),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, idx) {
                final n = notifications[idx];
                final icon = switch (n.type) {
                  'deposit' => '🌱',
                  'alert' => '⚠️',
                  'rewards' => '🎟️',
                  _ => 'ℹ️',
                };

                return GestureDetector(
                  onTap: () => ref
                      .read(agriStateProvider.notifier)
                      .markNotificationRead(n.id),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16221C),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: n.isUnread
                            ? const Color(0xFF22C55E)
                            : const Color(0xFF25392E),
                        width: n.isUnread ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(icon, style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      n.title,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: n.isUnread
                                            ? Colors.white
                                            : AppTheme.textMuted,
                                      ),
                                    ),
                                  ),
                                  if (n.isUnread)
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF22C55E),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                n.message,
                                style: const TextStyle(
                                    fontSize: 11, color: AppTheme.textMuted),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${Fmt.dateTime(n.time)} · ${Fmt.relative(n.time)}',
                                style: const TextStyle(
                                    fontSize: 9, color: AppTheme.textSubtle),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
