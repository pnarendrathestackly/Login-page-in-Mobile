import 'package:flutter/material.dart';

import '../../auth.dart';
import '../../router/app_router.dart';
import 'module_menu.dart';
import '../header/sign_out_button.dart';
import '../../main.dart';
import 'sidebar_header.dart';
import 'sidebar_menu.dart';

/// The sidebar: brand, grouped menu, sign out.
///
/// Holds no navigation state and no route strings — [SidebarMenu] reads the
/// selection from NavigationProvider and navigates through AppRouter.
class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.controller,
    this.collapsed = false,
  });

  final AuthController controller;

  /// Icon-only rail. Desktop only — the drawer is always full width.
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    // No border/shadow here: the shell's surface provides them on desktop, and
    // the Drawer provides its own on mobile.
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SidebarHeader(collapsed: collapsed),
          const Divider(color: kBorder, height: 1),
          // One scroll view for both menus: the workspace shortcuts, then the
          // OneCloud module tree. Two independently scrolling lists in one rail
          // is exactly the nested scrolling the layout rules forbid.
          // ONE ListView for the whole rail: workspace shortcuts, then the
          // OneCloud module tree. A nested scroll view here would break
          // intrinsic sizing for the menus that overlay it.
          // ONE ListView for the whole rail: workspace shortcuts, then the
          // OneCloud module tree, spliced in as rows rather than nested in a
          // second scroll view. Nested viewports here break intrinsic sizing
          // for the overlays above the shell (the notification panel).
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 8),
              children: [
                ...SidebarMenu.rows(context, collapsed: collapsed),
                ...ModuleMenu(
                  permissions: controller.permissions,
                  currentPath: Router.of(context).routerDelegate is AppRouter
                      ? (Router.of(context).routerDelegate as AppRouter)
                          .location
                      : '',
                  collapsed: collapsed,
                ).rows(context),
              ],
            ),
          ),
          const Divider(color: kBorder, height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SignOutButton(
              controller: controller,
              iconOnly: collapsed,
            ),
          ),
        ],
      ),
    );
  }
}
