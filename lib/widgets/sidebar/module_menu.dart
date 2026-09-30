import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/platform/modules.dart';
import '../../core/platform/permissions.dart';
import '../../main.dart';
import '../../motion.dart';
import '../../providers/navigation_provider.dart';
import '../../router/app_router.dart';
import 'icon_chip.dart';
import 'sidebar_constants.dart';

/// The OneCloud module tree in the sidebar.
///
/// Renders [kModules], filtered by what the signed-in principal may open, so a
/// user is never shown a module or page that would refuse them. Every row
/// navigates through the centralized router — this widget holds no paths of
/// its own beyond what the registry gives it.
///
/// A module is a *collapsible group of pages*, not a link: tapping the module
/// header expands it. Only the pages navigate, which keeps one rule for what a
/// tap does anywhere in the sidebar.
class ModuleMenu extends StatelessWidget {
  const ModuleMenu({
    super.key,
    required this.permissions,
    required this.currentPath,
    this.collapsed = false,
    this.dark = false,
    this.exclude = const {},
  });

  /// Styled for the navy super-admin rail.
  final bool dark;

  /// Module ids already reachable elsewhere in the rail.
  final Set<String> exclude;

  /// What the principal may open. Filtering happens here rather than in the
  /// router so the sidebar never lists a dead end.
  final PermissionSet permissions;

  /// The active route, used to highlight the current page.
  final String currentPath;

  /// Icon-only rail.
  final bool collapsed;

  /// The module tree's rows, for splicing into the sidebar's single scroll
  /// view. The rail keeps ONE viewport: nesting another inside it breaks
  /// intrinsic sizing for the menus that overlay the shell.
  List<Widget> rows(BuildContext context) {
    final nav = context.watch<NavigationProvider>();
    final allowed = [
      for (final m in visibleModules(permissions))
        if (!exclude.contains(m.id)) m
    ];
    return [
      for (final group in ModuleGroup.values)
        ..._buildGroup(context, group, allowed, nav),
    ];
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows(context),
      );

  List<Widget> _buildGroup(
    BuildContext context,
    ModuleGroup group,
    List<PlatformModule> allowed,
    NavigationProvider nav,
  ) {
    final modules = [
      for (final m in allowed)
        if (m.group == group) m
    ];
    // A heading with nothing under it would be a dead label.
    if (modules.isEmpty) return const [];

    return [
      if (collapsed)
        const SizedBox(height: 12)
      else
        Padding(
          padding: dark
              ? const EdgeInsets.fromLTRB(26, 18, 20, 8)
              : const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text(
            dark ? group.label.toUpperCase() : group.label,
            style: dark
                ? const TextStyle(
                    fontFamily: 'Consolas',
                    fontFamilyFallback: ['Menlo', 'Courier New', 'monospace'],
                    fontSize: 10.5,
                    letterSpacing: 1.6,
                    color: kRailMuted,
                  )
                : const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: kMutedStrong,
                  ),
          ),
        ),
      for (final module in modules)
        _ModuleTile(
          module: module,
          permissions: permissions,
          currentPath: currentPath,
          collapsed: collapsed,
          dark: dark,
          expanded: nav.isModuleExpanded(module.id),
          onToggle: () => nav.toggleModule(module.id),
        ),
    ];
  }
}

/// One module: a header row that expands to reveal the pages the principal
/// may open.
class _ModuleTile extends StatelessWidget {
  const _ModuleTile({
    required this.module,
    required this.permissions,
    required this.currentPath,
    required this.collapsed,
    required this.expanded,
    required this.onToggle,
    this.dark = false,
  });

  final bool dark;
  final PlatformModule module;
  final PermissionSet permissions;
  final String currentPath;
  final bool collapsed;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    var pages = visiblePages(module, permissions);

    // A module whose landing screen is owned by a legacy route (/reports,
    // /notifications) already has that entry in the workspace menu above.
    // Listing it again here would put the same destination in the sidebar
    // twice — and, for Notifications, collide with the header bell's label.
    if (module.legacyPath != null) {
      pages = [
        for (final p in pages)
          if (p.slug != module.pages.first.slug) p
      ];
    }

    if (pages.isEmpty) return const SizedBox.shrink();

    // True when any page of this module is the active route, so a collapsed
    // module still shows where the user is.
    final active = pages.any((p) => module.pathFor(p) == currentPath);

    // Collapsed rail: no room for a page list. The module icon navigates
    // straight to its landing page instead of expanding into nothing.
    if (collapsed) {
      return _Row(
        dark: dark,
        title: module.title,
        icon: module.icon,
        logoAsset: module.logoAsset,
        hue: sidebarHue(module.id),
        selected: active,
        collapsed: true,
        onTap: () => _navigate(context, module.pathFor(pages.first)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Row(
          dark: dark,
          title: module.title,
          icon: module.icon,
          logoAsset: module.logoAsset,
          hue: sidebarHue(module.id),
          selected: active && !expanded,
          collapsed: false,
          trailing: AnimatedRotation(
            turns: expanded ? 0 : -0.25,
            duration: Motion.duration(context, Motion.micro),
            curve: Motion.standardCurve,
            child: Icon(
              Icons.keyboard_arrow_down,
              size: 16,
              color: dark ? kRailMuted : kMuted,
            ),
          ),
          onTap: onToggle,
          isHeader: true,
          expanded: expanded,
        ),
        if (expanded)
          for (final page in pages)
            _Row(
              dark: dark,
              title: page.title,
              icon: page.icon,
              // The module's hue, not a per-page one: the chips colour-code
              // which module a row belongs to, and eleven unrelated hues
              // inside one expanded module would read as noise.
              hue: sidebarHue(module.id),
              indent: true,
              selected: module.pathFor(page) == currentPath,
              collapsed: false,
              onTap: () => _navigate(context, module.pathFor(page)),
            ),
      ],
    );
  }

  void _navigate(BuildContext context, String path) {
    final nav = context.read<NavigationProvider>();
    // The drawer is an overlay, not a page: close it before the route changes
    // so it does not linger over the new screen.
    nav.closeDrawer();
    if (Scaffold.of(context).isDrawerOpen) Navigator.of(context).pop();
    context.go(path);
  }
}

/// A sidebar row. Matches the existing [SidebarMenuItem] visual language —
/// same fill, rail, radius and motion — so the module tree does not read as a
/// second design.
class _Row extends StatefulWidget {
  const _Row({
    required this.title,
    required this.selected,
    required this.collapsed,
    required this.onTap,
    this.icon,
    this.logoAsset,
    this.hue,
    this.trailing,
    this.indent = false,
    this.isHeader = false,
    this.expanded = false,
    this.dark = false,
  });

  final bool dark;
  final String title;
  final IconData? icon;

  /// Bundled logo shown instead of [icon] when set. Falls back to [icon] on a
  /// load error so a missing asset never leaves a blank row.
  final String? logoAsset;

  /// Colour for this row's icon chip. Null falls back to the brand hue.
  final Color? hue;
  final bool selected;
  final bool collapsed;
  final bool indent;
  final bool isHeader;
  final bool expanded;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final micro = Motion.duration(context, Motion.micro);
    final dark = widget.dark;
    final fill = selected
        ? (dark ? kRailSelected : kIndigo.withValues(alpha: .10))
        : _hovered
            ? (dark
                ? Colors.white.withValues(alpha: .05)
                : kIndigo.withValues(alpha: .05))
            : Colors.transparent;

    // Module headers carry the larger mark; nested page rows stay a step
    // smaller so the hierarchy still reads at a glance. Both were bumped up —
    // the sub-page icons were too small to identify at 18.
    final iconSize =
        dark ? (widget.indent ? 20.0 : 24.0) : (widget.indent ? 24.0 : 32.0);
    // Leading mark, always laid out at exactly [iconSize] square so an image's
    // decode timing or source aspect ratio can't nudge the rest of the row.
    final Widget leading = SizedBox(
      width: iconSize,
      height: iconSize,
      // Module logos now sit on the same raised tile as the icon rows, so a
      // module header and its pages read as one family rather than a flat PNG
      // above a set of 3D chips.
      child: (widget.logoAsset != null || widget.icon != null)
          ? SidebarIconChip(
              icon: widget.icon,
              logoAsset: widget.logoAsset,
              color: widget.hue ?? kIndigo,
              selected: selected,
              size: iconSize,
            )
          // Page rows without their own mark keep the text aligned with rows
          // that have one, rather than shifting left.
          : const SizedBox.shrink(),
    );

    // Collapsed rail: just the centred mark. No selection bar, no forced-width
    // row — those only make sense next to a label, and at 76px they overflow
    // and bleed into neighbouring rows.
    if (widget.collapsed) {
      return Padding(
        // Horizontal padding is thin here on purpose: a 76px rail leaves only
        // ~28px of content once the outer 12s are taken, which a 30px mark
        // would overflow. A centred icon needs no side padding anyway.
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: _wrap(context, selected, fill, micro,
            Center(heightFactor: 1, child: leading)),
      );
    }

    final row = Row(
      children: [
        AnimatedContainer(
          duration: micro,
          curve: Motion.standardCurve,
          width: 3,
          height: selected && !dark ? 18 : 0,
          margin: const EdgeInsets.only(right: 9),
          decoration: BoxDecoration(
            color: kIndigo,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        leading,
        const SizedBox(width: 12),
        Expanded(
          child: AnimatedDefaultTextStyle(
            duration: micro,
            curve: Motion.standardCurve,
            style: TextStyle(
              fontSize: widget.indent ? 14 : 15,
              fontWeight: selected
                  ? FontWeight.w700
                  : widget.isHeader
                      ? FontWeight.w600
                      : FontWeight.w500,
              color: dark
                  ? (selected ? Colors.white : kRailText)
                  : (selected ? kIndigo : kInk),
            ),
            child: Text(
              widget.title,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            ),
          ),
        ),
        if (widget.trailing != null) widget.trailing!,
      ],
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(widget.indent ? 24 : 12, 0, 12, 2),
      child: _wrap(
        context,
        selected,
        fill,
        micro,
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: widget.indent ? 9 : 11,
          ),
          child: row,
        ),
      ),
    );
  }

  /// Shared row chrome: hover/selected fill, ripple, semantics and the
  /// collapsed-rail tooltip. Both the collapsed mark and the full label row
  /// go through here so they stay visually identical.
  Widget _wrap(
    BuildContext context,
    bool selected,
    Color fill,
    Duration micro,
    Widget child,
  ) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: micro,
        curve: Motion.standardCurve,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(10),
          // Matches SidebarMenuItem: a tinted edge so the active row reads at
          // the low contrast a .10 fill has against the navy rail.
          border: Border.all(
            color: selected
                ? (widget.dark
                    ? kRailSelectedBorder
                    : kIndigo.withValues(alpha: .30))
                : Colors.transparent,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(10),
            child: Semantics(
              selected: selected,
              button: true,
              header: widget.isHeader,
              expanded: widget.isHeader ? widget.expanded : null,
              // The wrapper speaks for the whole row; the inner Text would
              // otherwise appear as a second node with the same name, making
              // a module header indistinguishable from a real destination of
              // that name.
              excludeSemantics: true,
              // A module header expands a group rather than navigating. It
              // is announced as a section toggle so it never competes with a
              // real destination of the same name — the Notifications bell
              // in the header, for instance.
              label: widget.isHeader
                  ? '${widget.title} section, ${widget.expanded ? "expanded" : "collapsed"}'
                  : widget.title,
              child: Tooltip(
                message: widget.collapsed ? widget.title : '',
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
