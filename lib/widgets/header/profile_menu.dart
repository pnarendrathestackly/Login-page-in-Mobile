import 'package:flutter/material.dart';

import '../../auth.dart';
import '../../dashboard.dart';
import '../../main.dart';
import '../../motion.dart';
import '../sidebar/app_sidebar.dart';

class ProfileMenu extends StatelessWidget {
  const ProfileMenu({
    super.key,
    required this.user,
    required this.controller,
    required this.compact,
    required this.onNavigate,
  });

  final AuthUser user;
  final AuthController controller;
  final bool compact;
  final ValueChanged<DashboardSection>? onNavigate;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      style: const MenuStyle(
        backgroundColor: WidgetStatePropertyAll(kSurfaceElevated),
      ),
      // MenuAnchor opens without animation; stagger the rows in instead.
      menuChildren: [
        for (final (i, item) in [
          ProfileMenuItem(
            icon: Icons.person_outline,
            label: 'My Profile',
            onTap: () => onNavigate?.call(DashboardSection.profile),
          ),
          ProfileMenuItem(
            icon: Icons.settings_outlined,
            label: 'Account Settings',
            onTap: () => onNavigate?.call(DashboardSection.settings),
          ),
          ProfileMenuItem(
            icon: Icons.help_outline,
            label: 'Help & Support',
            onTap: () => onNavigate?.call(DashboardSection.help),
          ),
          const Divider(color: kBorder, height: 1),
          // Runs the same handler as every other sign-out in the app.
          ProfileMenuItem(
            icon: Icons.logout,
            label: 'Sign Out',
            onTap: () => controller.signOut(),
          ),
        ].indexed)
          FadeIn(delay: Motion.stagger * i, offset: -4, child: item),
      ],
      builder: (context, menu, _) => InkWell(
        onTap: () => menu.isOpen ? menu.close() : menu.open(),
        borderRadius: BorderRadius.circular(22),
        customBorder: const StadiumBorder(),
        child: Semantics(
          button: true,
          label: 'Account menu for ${user.name}',
          excludeSemantics: true,
          child: Container(
            padding: const EdgeInsets.fromLTRB(6, 5, 12, 5),
            decoration: ShapeDecoration(
              shape: StadiumBorder(side: BorderSide(color: kBorder)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                RailAvatar(size: 30, email: user.email),
                if (!compact) ...[
                  const SizedBox(width: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          user.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: kInk,
                          ),
                        ),
                        Text(
                          user.role,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11.5, color: kMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                const Icon(Icons.expand_more, size: 18, color: kInk),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ProfileMenuItem extends StatelessWidget {
  const ProfileMenuItem({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MenuItemButton(
      onPressed: onTap,
      leadingIcon: Icon(icon, size: 18, color: kMuted),
      child: Text(
        label,
        style: const TextStyle(fontSize: 14, color: kInk),
      ),
    );
  }
}
