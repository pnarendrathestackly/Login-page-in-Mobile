import 'package:flutter/material.dart';

import '../../main.dart';
import '../../motion.dart';
import '../../widgets/common/notifications_panel.dart';
import '../../features/dashboard/models/dashboard_models.dart';

class NotificationButton extends StatelessWidget {
  const NotificationButton({
    super.key,
    required this.items,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onRead,
    required this.onReadAll,
    required this.onViewAll,
  });

  final List<AppNotification> items;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final ValueChanged<AppNotification> onRead;
  final VoidCallback onReadAll;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final unread = items.where((n) => !n.read).length;
    return MenuAnchor(
      style: const MenuStyle(
        backgroundColor: WidgetStatePropertyAll(kSurfaceElevated),
        padding: WidgetStatePropertyAll(EdgeInsets.zero),
      ),
      menuChildren: [
        // StatefulBuilder so "mark as read" repaints the open popover.
        StatefulBuilder(
          builder: (context, setLocal) => FadeIn(
            offset: -Motion.enterOffset,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * .7,
              ),
              child: NotificationPanel(
                items: items,
                loading: loading,
                error: error,
                onRetry: onRetry,
                now: DateTime.now(),
                onRead: (n) {
                  onRead(n);
                  setLocal(() {});
                },
                onReadAll: () {
                  onReadAll();
                  setLocal(() {});
                },
                onViewAll: () {
                  Navigator.of(context).maybePop();
                  onViewAll();
                },
              ),
            ),
          ),
        ),
      ],
      builder: (context, controller, _) => IconButton(
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        tooltip: unread > 0 ? 'Notifications, $unread unread' : 'Notifications',
        // A dot, not a count: the count is in the tooltip and the panel.
        icon: Badge(
          isLabelVisible: unread > 0,
          smallSize: 7,
          backgroundColor: kDanger,
          child: const Icon(Icons.notifications_none, size: 19, color: kInk),
        ),
      ),
    );
  }
}
