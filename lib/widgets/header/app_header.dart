import 'package:flutter/material.dart';

import '../../auth.dart';
import '../../core/responsive/responsive.dart';
import '../../dashboard.dart';
import '../../features/dashboard/models/dashboard_models.dart';
import '../../main.dart';
import 'compact_search.dart';
import 'notification_button.dart';
import 'profile_menu.dart';

/// Top bar: search on the left; notifications, settings and the account pill
/// on the right. Page titles live in the page body, under the bar.
class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    super.key,
    required this.user,
    required this.controller,
    this.onMenu,
    this.notifications = const [],
    this.notificationsLoading = false,
    this.notificationsError,
    this.onRetryNotifications,
    this.onRead,
    this.onReadAll,
    this.onNavigate,
  });

  final AuthUser user;
  final AuthController controller;

  /// Opens the drawer. Null on desktop, where the rail is permanent.
  final VoidCallback? onMenu;
  final List<AppNotification> notifications;
  final bool notificationsLoading;
  final String? notificationsError;
  final VoidCallback? onRetryNotifications;
  final ValueChanged<AppNotification>? onRead;
  final VoidCallback? onReadAll;
  final ValueChanged<DashboardSection>? onNavigate;

  @override
  Widget build(BuildContext context) {
    final compact = context.isMobile;
    final searchAsField = context.hasHeaderSearchField;

    return Container(
      height: 80,
      padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16),
      decoration: const BoxDecoration(
        color: kSurface,
        border: Border(bottom: BorderSide(color: Color(0xFFE8EAEF))),
      ),
      child: Row(
        children: [
          if (onMenu != null)
            IconButton(
              onPressed: onMenu,
              icon: const Icon(Icons.menu, color: kInk),
              tooltip: 'Open navigation menu',
            ),
          if (searchAsField)
            const Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: CompactSearch(
                  maxWidth: 420,
                  hint: 'Search tenants, users, settings, audit logs...',
                  shortcut: '⌘K',
                ),
              ),
            )
          else ...[
            const Spacer(),
            const CompactSearch(expandable: true),
          ],
          const SizedBox(width: 12),
          _Square(
            child: NotificationButton(
              items: notifications,
              loading: notificationsLoading,
              error: notificationsError,
              onRetry: onRetryNotifications ?? () {},
              onRead: onRead ?? (_) {},
              onReadAll: onReadAll ?? () {},
              onViewAll: () => onNavigate?.call(DashboardSection.notifications),
            ),
          ),
          const SizedBox(width: 12),
          _Square(
            child: IconButton(
              tooltip: 'Settings',
              onPressed: () => onNavigate?.call(DashboardSection.settings),
              icon: const Icon(Icons.settings_outlined, size: 19, color: kInk),
            ),
          ),
          const SizedBox(width: 12),
          ProfileMenu(
            user: user,
            controller: controller,
            compact: compact,
            onNavigate: onNavigate,
          ),
        ],
      ),
    );
  }
}

/// 38px bordered square behind a header icon button.
class _Square extends StatelessWidget {
  const _Square({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorder),
      ),
      child: IconButtonTheme(
        data: IconButtonThemeData(
          style: IconButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(36, 36),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        child: child,
      ),
    );
  }
}
