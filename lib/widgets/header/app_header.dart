import 'package:flutter/material.dart';

import '../../core/responsive/responsive.dart';

import '../../auth.dart';
import '../../dashboard.dart';
import '../../main.dart';
import '../../motion.dart';
import '../../features/dashboard/models/dashboard_models.dart';
import 'compact_search.dart';
import 'notification_button.dart';
import 'profile_menu.dart';
import 'sign_out_button.dart';

class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    super.key,
    required this.title,
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

  final String title;
  final AuthUser user;
  final AuthController controller;
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
    final width = context.screenWidth;
    final compact = context.isMobile;
    // A field only once the header has room for one beside a permanent
    // sidebar and the controls; below that the search is an icon that expands
    // on tap, so it never squeezes the title or the controls.
    final searchAsField = context.hasHeaderSearchField;

    // Three zones so the search box sits centred in the header rather than
    // wherever the title's width happens to leave it: the left and right
    // zones take equal flex, and the search sits between them.
    final left = Row(
      // Not MainAxisSize.min: inside the equal-flex header zones this row is
      // handed a bounded width, and the title has to ellipsize within it
      // rather than claim its natural size and overflow.
      mainAxisSize: MainAxisSize.max,
      children: [
        if (onMenu != null)
          IconButton(
            onPressed: onMenu,
            icon: const Icon(Icons.menu, color: kInk),
            tooltip: 'Open navigation menu',
          ),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title crossfades when the section changes.
              AnimatedSwitcher(
                duration: Motion.duration(context, Motion.standard),
                switchInCurve: Motion.enter,
                switchOutCurve: Motion.exit,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween(
                      begin: const Offset(0, .25),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: Text(
                  title,
                  key: ValueKey(title),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: kInk,
                  ),
                ),
              ),
              if (!compact)
                Text(
                  'Home / $title',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: kMuted),
                ),
            ],
          ),
        ),
      ],
    );

    // Order: notifications, profile, then sign out on the far right — the
    // bell sits to the left of Sign Out.
    final right = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        NotificationButton(
          items: notifications,
          loading: notificationsLoading,
          error: notificationsError,
          onRetry: onRetryNotifications ?? () {},
          onRead: onRead ?? (_) {},
          onReadAll: onReadAll ?? () {},
          onViewAll: () => onNavigate?.call(DashboardSection.notifications),
        ),
        const SizedBox(width: 4),
        ProfileMenu(
          user: user,
          controller: controller,
          compact: compact,
          onNavigate: onNavigate,
        ),
        const SizedBox(width: 4),
        // Runs the same handler as the sidebar and the profile dropdown.
        // Icon-only below a wide viewport, where the label plus the profile
        // block would not fit beside a centred search box.
        SignOutButton(
          controller: controller,
          compact: true,
          iconOnly: width < Breakpoints.wide,
        ),
      ],
    );

    return Container(
      // _Surface supplies the panel chrome; this just sets the padding.
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: Colors.white,
      child: searchAsField
          // Equal flex either side of the search: the two outer zones always
          // get the same width, so the search sits centred in the bar without
          // overlapping the title or the controls.
          ? Row(
              children: [
                Expanded(
                  child: Align(alignment: Alignment.centerLeft, child: left),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: CompactSearch(maxWidth: width >= 1440 ? 240 : 180),
                ),
                Expanded(
                  child: Align(alignment: Alignment.centerRight, child: right),
                ),
              ],
            )
          // Narrow: the search collapses to an icon beside the controls. The
          // controls are a fixed width, so the title is the part that gives —
          // Flexible with no Spacer, or the row overflows once the search
          // icon joins it.
          : Row(
              children: [
                Flexible(child: left),
                const CompactSearch(expandable: true),
                right,
              ],
            ),
    );
  }
}
