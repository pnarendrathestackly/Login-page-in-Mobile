import 'package:flutter/material.dart';

import '../../../main.dart';
import '../../../widgets.dart';
import '../../../widgets/common/dialogs.dart';
import '../../dashboard/models/dashboard_models.dart';
import '../../../widgets/common/parts.dart';

/// The full notification centre: category tabs with counts, then the list.
///
/// The popover in the header stays as it is — this is the "View all" surface,
/// with filtering, per-item delete and bulk clear.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({
    super.key,
    required this.items,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onRead,
    required this.onReadAll,
    required this.onDelete,
    required this.onClearAll,
  });

  final List<AppNotification> items;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final ValueChanged<AppNotification> onRead;
  final VoidCallback onReadAll;
  final ValueChanged<AppNotification> onDelete;
  final VoidCallback onClearAll;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

/// "All" and "Unread" sit alongside the [NotificationKind] values.
enum _Filter { all, unread, mentions, tasks, projects, system }

class _NotificationsPageState extends State<NotificationsPage> {
  _Filter _filter = _Filter.all;

  bool _matches(AppNotification n) => switch (_filter) {
        _Filter.all => true,
        _Filter.unread => !n.read,
        _Filter.mentions => n.kind == NotificationKind.mention,
        _Filter.tasks => n.kind == NotificationKind.task,
        _Filter.projects => n.kind == NotificationKind.project,
        _Filter.system => n.kind == NotificationKind.system,
      };

  int _count(_Filter f) {
    final saved = _filter;
    _filter = f;
    final n = widget.items.where(_matches).length;
    _filter = saved;
    return n;
  }

  static String _label(_Filter f) => switch (f) {
        _Filter.all => 'All',
        _Filter.unread => 'Unread',
        _Filter.mentions => 'Mentions',
        _Filter.tasks => 'Tasks',
        _Filter.projects => 'Projects',
        _Filter.system => 'System',
      };

  Future<void> _clearAll() async {
    final ok = await confirm(
      context,
      title: 'Clear all notifications?',
      message: 'This removes every notification from your inbox. It cannot '
          'be undone.',
      confirmLabel: 'Clear all',
    );
    if (!ok || !mounted) return;
    widget.onClearAll();
    if (mounted) showToast(context, 'Notifications cleared.');
  }

  @override
  Widget build(BuildContext context) {
    final shown = widget.items.where(_matches).toList()
      ..sort((a, b) => b.at.compareTo(a.at));
    final unread = widget.items.where((n) => !n.read).length;
    final now = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 12,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  header: true,
                  child: const Text(
                    'Notifications',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: kInk,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  unread == 0
                      ? 'You have no unread notifications.'
                      : 'You have $unread unread '
                          '${unread == 1 ? 'notification' : 'notifications'}.',
                  style: const TextStyle(fontSize: 14.5, color: kMuted),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              children: [
                if (unread > 0)
                  OutlinedButton.icon(
                    onPressed: widget.onReadAll,
                    icon: const Icon(Icons.done_all, size: 18),
                    label: const Text('Mark all as read'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kIndigo,
                      side: const BorderSide(color: kBorder),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                if (widget.items.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: _clearAll,
                    icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                    label: const Text('Clear all'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kDanger,
                      side: const BorderSide(color: kBorder),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),

        // --- Category tabs ---------------------------------------------------
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final f in _Filter.values) ...[
                _FilterTab(
                  label: _label(f),
                  count: _count(f),
                  selected: f == _filter,
                  onTap: () => setState(() => _filter = f),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Panel(
            padding: EdgeInsets.zero,
            child: Builder(
              builder: (context) {
                if (widget.error != null) {
                  return ErrorState(
                    message: widget.error!,
                    onRetry: widget.onRetry,
                  );
                }
                if (widget.loading) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Skeleton(height: 56, radius: 10),
                        SizedBox(height: 10),
                        Skeleton(height: 56, radius: 10),
                        SizedBox(height: 10),
                        Skeleton(height: 56, radius: 10),
                      ],
                    ),
                  );
                }
                if (shown.isEmpty) {
                  return EmptyState(
                    icon: _filter == _Filter.all
                        ? Icons.notifications_none
                        : Icons.filter_alt_off_outlined,
                    title: _filter == _Filter.all
                        ? "You're all caught up"
                        : 'Nothing in ${_label(_filter)}',
                    message: _filter == _Filter.all
                        ? 'New alerts and reminders will appear here.'
                        : 'Try another category to see more notifications.',
                  );
                }
                return Column(
                  children: [
                    for (final (i, n) in shown.indexed) ...[
                      if (i > 0) const Divider(color: kBorder, height: 1),
                      _NotificationRow(
                        item: n,
                        now: now,
                        onRead: () => widget.onRead(n),
                        onDelete: () => widget.onDelete(n),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterTab extends StatelessWidget {
  const _FilterTab({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? kIndigo.withValues(alpha: .10) : kSurface,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: selected ? kIndigo : kBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? kIndigo : kInk,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected ? kIndigo : kMuted,
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

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    required this.item,
    required this.now,
    required this.onRead,
    required this.onDelete,
  });

  final AppNotification item;
  final DateTime now;
  final VoidCallback onRead;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.read ? null : onRead,
      child: Semantics(
        label: item.read ? null : 'Unread. Activate to mark as read.',
        child: Container(
          color: item.read ? null : kIndigo.withValues(alpha: .04),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kIndigo.withValues(alpha: item.read ? .05 : .10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  item.icon,
                  size: 18,
                  color: item.read ? kMuted : kIndigo,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            item.read ? FontWeight.w500 : FontWeight.w700,
                        color: kInk,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.body,
                      style: const TextStyle(
                        fontSize: 13,
                        color: kMuted,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        StatusPill(label: item.kind.label, color: kMuted),
                        Text(
                          relativeTime(item.at, now),
                          style: const TextStyle(fontSize: 11.5, color: kMuted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.close, size: 16),
                    tooltip: 'Delete notification',
                    color: kMuted,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(),
                  ),
                  if (!item.read)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: kIndigo,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
