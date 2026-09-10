import 'package:flutter/material.dart';

import '../../auth.dart';
import '../../dashboard.dart';
import '../../main.dart';

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
        backgroundColor: WidgetStatePropertyAll(Colors.white),
      ),
      menuChildren: [
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
      ],
      builder: (context, menu, _) => InkWell(
        onTap: () => menu.isOpen ? menu.close() : menu.open(),
        borderRadius: BorderRadius.circular(10),
        child: Semantics(
          button: true,
          label: 'Account menu for ${user.name}',
          excludeSemantics: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                UserAvatar(user: user),
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
                          style: const TextStyle(fontSize: 12, color: kMuted),
                        ),
                      ],
                    ),
                  ),
                ],
                const Icon(Icons.expand_more, size: 18, color: kMuted),
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

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,required this.user});
  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    final initials = user.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    return CircleAvatar(
      radius: 16,
      backgroundColor: kIndigo.withValues(alpha: .12),
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: kIndigo,
        ),
      ),
    );
  }
}
