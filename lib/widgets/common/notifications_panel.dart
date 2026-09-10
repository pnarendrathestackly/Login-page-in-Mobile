import 'package:flutter/material.dart';

import '../../main.dart';
import '../../features/dashboard/models/dashboard_models.dart';
import './parts.dart';

/// Contents of the notification popover. The bell owns the fetching; this only
/// renders and reports taps.
class NotificationPanel extends StatelessWidget {
  const NotificationPanel({
    super.key,
    required this.items,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onRead,
    required this.onReadAll,
    required this.onViewAll,
    required this.now,
  });

  final List<AppNotification> items;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final ValueChanged<AppNotification> onRead;
  final VoidCallback onReadAll;
  final VoidCallback onViewAll;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final unread = items.where((n) => !n.read).length;
    return SizedBox(
      width: 340,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      'Notifications${unread > 0 ? ' ($unread)' : ''}',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: kInk,
                      ),
                    ),
                  ),
                ),
                if (unread > 0)
                  TextButton(
                    onPressed: onReadAll,
                    style: TextButton.styleFrom(
                      foregroundColor: kIndigo,
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                    ),
                    child: const Text(
                      'Mark all as read',
                      style: TextStyle(fontSize: 12.5),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(color: kBorder, height: 1),
          if (error != null)
            ErrorState(message: error!, onRetry: onRetry)
          else if (loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Skeleton(height: 40, radius: 10),
                  SizedBox(height: 10),
                  Skeleton(height: 40, radius: 10),
                  SizedBox(height: 10),
                  Skeleton(height: 40, radius: 10),
                ],
              ),
            )
          else if (items.isEmpty)
            const EmptyState(
              icon: Icons.notifications_none,
              title: "You're all caught up",
              message: 'New alerts and reminders will appear here.',
            )
          else
            // ConstrainedBox rather than Flexible: this panel renders inside a
            // MenuAnchor, whose _MenuPanel wraps its children in
            // IntrinsicWidth. A Flexible here forwards that intrinsic query
            // into the viewport below, which cannot answer it and asserts —
            // a bounded box stops the query at this level instead.
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: items.length,
                separatorBuilder: (_, __) =>
                    const Divider(color: kBorder, height: 1),
                itemBuilder: (context, i) => _Row(
                  item: items[i],
                  now: now,
                  onRead: () => onRead(items[i]),
                ),
              ),
            ),
          const Divider(color: kBorder, height: 1),
          TextButton(
            onPressed: onViewAll,
            style: TextButton.styleFrom(
              foregroundColor: kIndigo,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text(
              'View all notifications',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.item, required this.now, required this.onRead});

  final AppNotification item;
  final DateTime now;
  final VoidCallback onRead;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.read ? null : onRead,
      child: Semantics(
        label: item.read ? null : 'Unread. Activate to mark as read.',
        child: Container(
          color: item.read ? null : kIndigo.withValues(alpha: .04),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(item.icon, size: 18, color: item.read ? kMuted : kIndigo),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight:
                            item.read ? FontWeight.w500 : FontWeight.w700,
                        color: kInk,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.body,
                      style: const TextStyle(fontSize: 12.5, color: kMuted),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      relativeTime(item.at, now),
                      style: const TextStyle(fontSize: 11.5, color: kMuted),
                    ),
                  ],
                ),
              ),
              if (!item.read)
                Container(
                  margin: const EdgeInsets.only(top: 4, left: 8),
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: kIndigo,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
