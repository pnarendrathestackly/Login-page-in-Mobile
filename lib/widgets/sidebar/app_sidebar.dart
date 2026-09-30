import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth.dart';
import '../../core/platform/modules.dart';
import '../../core/platform/permissions.dart';
import '../../providers/navigation_provider.dart';
import '../../router/app_router.dart';
import 'module_menu.dart';
import 'sidebar_constants.dart';

const _mono = TextStyle(
  fontFamily: 'Consolas',
  fontFamilyFallback: ['Menlo', 'Courier New', 'monospace'],
);

/// One fixed destination in the super-admin rail.
typedef _Entry = ({String label, IconData icon, String path, String? perm});

PlatformModule get _admin => kModules.firstWhere((m) => m.id == 'admin');

String _adminPath(String slug) =>
    _admin.pathFor(_admin.pages.firstWhere((p) => p.slug == slug));

final List<_Entry> _superAdmin = [
  (
    label: 'Super Admin Dashboard',
    icon: Icons.grid_view_outlined,
    path: AppRoutes.dashboard,
    perm: null,
  ),
  (
    label: 'Platform Administration',
    icon: Icons.language,
    path: _adminPath('overview'),
    perm: Perm.adminView,
  ),
  (
    label: 'Global Dashboard',
    icon: Icons.public,
    path: _adminPath('global'),
    perm: Perm.adminView,
  ),
  (
    label: 'Platform Configuration',
    icon: Icons.settings_outlined,
    path: _adminPath('settings'),
    perm: Perm.adminSettings,
  ),
  (
    label: 'Platform Branding',
    icon: Icons.brush_outlined,
    path: _adminPath('branding'),
    perm: Perm.adminSettings,
  ),
  (
    label: 'Feature Management',
    icon: Icons.layers_outlined,
    path: _adminPath('features'),
    perm: Perm.adminSettings,
  ),
  (
    label: 'License Management',
    icon: Icons.description_outlined,
    path: _adminPath('licenses'),
    perm: Perm.adminSettings,
  ),
  (
    label: 'Settings',
    icon: Icons.tune,
    path: AppRoutes.settings,
    perm: null,
  ),
];

final List<_Entry> _organization = [
  (
    label: 'Company Setup',
    icon: Icons.business_outlined,
    path: _adminPath('organizations'),
    perm: Perm.adminTenants,
  ),
  (
    label: 'User Management',
    icon: Icons.people_outline,
    path: _adminPath('users'),
    perm: Perm.adminUsers,
  ),
];

/// The navy rail: brand, super-admin menu, the service modules, language,
/// log out and the signed-in user.
///
/// Holds no navigation state — the highlight comes from the router's current
/// location, and every tap goes through [AppRouter].
class AppSidebar extends StatelessWidget {
  const AppSidebar({super.key, required this.controller, this.onClose});

  final AuthController controller;

  /// Set only in the mobile drawer, where the panel needs a way to dismiss
  /// itself; the desktop rail is permanent and passes null.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final delegate = Router.of(context).routerDelegate;
    final location = delegate is AppRouter ? delegate.location : '';
    // Rebuild when the route changes (the provider mirrors the URL).
    context.watch<NavigationProvider>();
    final perms = controller.permissions;
    final user = controller.user;

    List<Widget> section(String title, List<_Entry> entries) {
      final visible = [
        for (final e in entries)
          if (e.perm == null || perms.can(e.perm!)) e
      ];
      if (visible.isEmpty) return const [];
      return [
        _Heading(title),
        for (final e in visible)
          _Item(
            label: e.label,
            icon: e.icon,
            selected: location == e.path,
            onTap: (_) => _go(context, e.path),
          ),
      ];
    }

    return Container(
      color: kRail,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 26, 20, 0),
            child: onClose == null
                ? const StacklyLogo()
                : Row(
                    children: [
                      const Expanded(child: StacklyLogo()),
                      IconButton(
                        onPressed: onClose,
                        icon: const Icon(Icons.close, size: 20),
                        color: Colors.white,
                        tooltip: 'Close menu',
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 22, 20, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF4FD1C5).withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF4FD1C5).withValues(alpha: .30),
                  ),
                ),
                child: Text(
                  'PLATFORM ADMINISTRATION',
                  style: _mono.copyWith(
                    fontSize: 10.5,
                    letterSpacing: 1.5,
                    color: const Color(0xFF4FD1C5),
                  ),
                ),
              ),
            ),
          ),
          // One scroll view for the whole menu. Nested viewports here break
          // intrinsic sizing for the overlays above the shell.
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 12),
              children: [
                ...section('SUPER ADMIN MANAGEMENT', _superAdmin),
                ...section('ORGANIZATION', _organization),
                ...ModuleMenu(
                  permissions: perms,
                  currentPath: location,
                  dark: true,
                  // Already listed above as the super-admin entries.
                  exclude: const {'admin'},
                ).rows(context),
              ],
            ),
          ),
          const Divider(height: 1, color: kRailDivider),
          const SizedBox(height: 10),
          _Item(
            label: 'Language',
            icon: Icons.language,
            selected: false,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'English',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: kRailText.withValues(alpha: .7),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.expand_more, size: 16, color: kRailMuted),
              ],
            ),
            // ponytail: English is the only locale shipped, so the menu lists
            // just it. Add entries here once translations exist.
            onTap: (anchor) => showMenu<String>(
              context: anchor,
              position: _menuPosition(anchor),
              items: const [
                CheckedPopupMenuItem(
                  value: 'en',
                  checked: true,
                  child: Text('English'),
                ),
              ],
            ),
          ),
          _Item(
            label: 'Log out',
            icon: Icons.logout,
            selected: false,
            onTap: (_) => controller.signOut(),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: kRailDivider),
          if (user != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 16, 20, 18),
              child: Row(
                children: [
                  RailAvatar(size: 34, email: user.email),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          user.role,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: kRailMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Opens a menu just above [anchor]'s bottom-left corner.
  static RelativeRect _menuPosition(BuildContext anchor) {
    final box = anchor.findRenderObject()! as RenderBox;
    final overlay = Overlay.of(anchor).context.findRenderObject()! as RenderBox;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    return RelativeRect.fromRect(
      topLeft & box.size,
      Offset.zero & overlay.size,
    );
  }

  static void _go(BuildContext context, String path) {
    // The drawer is an overlay, not a page: close it before the route changes.
    context.read<NavigationProvider>().closeDrawer();
    if (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
    context.go(path);
  }
}

/// Profile photos uploaded this session, keyed by account email.
// ponytail: in memory — there is no media storage API. Resets on restart.
final profilePhotos = ValueNotifier<Map<String, Uint8List>>({});

/// The user's photo when one was uploaded, otherwise the blue-indigo disc from
/// the mock. Shared by the rail footer and the header's profile pill.
class RailAvatar extends StatelessWidget {
  const RailAvatar({super.key, this.size = 30, this.email});

  final double size;
  final String? email;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: profilePhotos,
      builder: (context, photos, _) {
        final photo = email == null ? null : photos[email];
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: photo != null
                ? null
                : const RadialGradient(
                    center: Alignment(-.3, -.4),
                    colors: [Color(0xFF4F5BFF), Color(0xFF1E238F)],
                  ),
            image: photo == null
                ? null
                : DecorationImage(image: MemoryImage(photo), fit: BoxFit.cover),
          ),
        );
      },
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 18, 20, 8),
      child: Text(
        text,
        style: _mono.copyWith(
          fontSize: 10.5,
          letterSpacing: 1.6,
          color: kRailMuted,
        ),
      ),
    );
  }
}

class _Item extends StatefulWidget {
  const _Item({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.trailing,
  });

  final String label;
  final IconData icon;
  final bool selected;

  /// Receives the row's context, so a row can anchor a menu to itself.
  final void Function(BuildContext anchor) onTap;
  final Widget? trailing;

  @override
  State<_Item> createState() => _ItemState();
}

class _ItemState extends State<_Item> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 3),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Material(
          color: selected
              ? kRailSelected
              : _hovered
                  ? Colors.white.withValues(alpha: .05)
                  : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: BorderSide(
              color: selected ? kRailSelectedBorder : Colors.transparent,
            ),
          ),
          child: InkWell(
            onTap: () => widget.onTap(context),
            borderRadius: BorderRadius.circular(6),
            child: Semantics(
              selected: selected,
              button: true,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                child: Row(
                  children: [
                    Icon(
                      widget.icon,
                      size: 18,
                      color: selected ? Colors.white : kRailText,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.label,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight:
                              selected ? FontWeight.w500 : FontWeight.w400,
                          color: selected ? Colors.white : kRailText,
                        ),
                      ),
                    ),
                    if (widget.trailing != null) widget.trailing!,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "STACKLY" wordmark with the bolt-S glyph.
/// The brand logo (glyph + STACKLY wordmark), white on transparent.
// ponytail: the supplied PNG is 193×58, so it softens on 2× screens.
// Replace Assets/stackly_logo.png with an SVG or a 4× PNG when available.
class StacklyLogo extends StatelessWidget {
  const StacklyLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Image.asset(
        'assets/stackly_logo.png',
        height: 52,
        filterQuality: FilterQuality.medium,
        semanticLabel: 'Stackly',
      ),
    );
  }
}
