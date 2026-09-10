import 'package:flutter/widgets.dart';

import '../dashboard.dart';
import '../router/app_router.dart';

/// One sidebar entry: what it says, how it looks, and where it goes.
///
/// The sidebar renders this list and nothing else — it holds no paths and no
/// per-item tap handlers of its own, so a new destination is one entry here.
@immutable
class MenuItemModel {
  const MenuItemModel({
    required this.section,
    required this.title,
    required this.icon,
    required this.route,
    required this.group,
    this.subtitle,
  });

  /// The destination this item selects. Doubles as its identity, so the
  /// active-item check is a single equality against the route-driven section.
  final DashboardSection section;

  final String title;
  final String? subtitle;
  final IconData icon;

  /// Centralized route, from [AppRoutes] — never a literal path string.
  final String route;

  /// The heading this item sits under.
  final SidebarGroup group;
}

/// The whole menu, derived from [DashboardSection] so the two cannot drift.
/// Grouping and ordering come from the enum's own declaration order.
final List<MenuItemModel> kMenuItems = [
  for (final section in DashboardSection.values)
    MenuItemModel(
      section: section,
      title: section.label,
      icon: section.icon,
      route: pathForSection(section),
      group: section.group,
    ),
];

/// Items under one heading, in declaration order.
List<MenuItemModel> menuItemsFor(SidebarGroup group) =>
    [for (final i in kMenuItems) if (i.group == group) i];
