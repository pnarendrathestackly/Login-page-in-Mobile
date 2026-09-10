import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../dashboard.dart';
import '../../models/menu_item_model.dart';
import '../../providers/navigation_provider.dart';
import '../../router/app_router.dart';
import 'sidebar_menu_item.dart';
import 'sidebar_section.dart';

/// Headings and their subheadings, driven entirely by [kMenuItems].
///
/// Tapping a subheading goes through the centralized router; the highlight
/// comes back from [NavigationProvider], which the router updates from the
/// URL. There is no local selection state here to fall out of sync.
class SidebarMenu extends StatelessWidget {
  const SidebarMenu({super.key, this.collapsed = false});

  final bool collapsed;

  /// The menu's rows, for splicing into the sidebar's single scroll view.
  /// Exposed so the rail needs only one ListView: nesting a second viewport
  /// inside it breaks intrinsic sizing for the overlays above it.
  static List<Widget> rows(BuildContext context, {bool collapsed = false}) =>
      _build(context, collapsed);

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 8),
      children: _build(context, collapsed),
    );
  }

  static List<Widget> _build(BuildContext context, bool collapsed) {
    // Only these rows rebuild when the selection or a group toggles — not the
    // whole shell.
    final nav = context.watch<NavigationProvider>();

    final children = <Widget>[
      for (final group in SidebarGroup.values) ...[
        if (collapsed)
          const SizedBox(height: 12)
        else
          SidebarSection(
            group: group,
            expanded: nav.isGroupExpanded(group),
            onToggle: () => nav.toggleGroup(group),
          ),
        // A collapsed rail shows every icon: hiding them would leave no way
        // to reach those destinations at all.
        if (collapsed || nav.isGroupExpanded(group))
          for (final item in menuItemsFor(group))
            SidebarMenuItem(
              item: item,
              collapsed: collapsed,
              selected: nav.selectedSection == item.section,
              onTap: () {
                // Drawer is a UI overlay, not a page: close it before the
                // route changes so it does not linger over the new screen.
                nav.closeDrawer();
                if (Scaffold.of(context).isDrawerOpen) {
                  Navigator.of(context).pop();
                }
                // Centralized routing owns the navigation itself.
                context.go(item.route);
              },
            ),
      ],
    ];

    return children;
  }
}
