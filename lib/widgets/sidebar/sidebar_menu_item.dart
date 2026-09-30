import 'package:flutter/material.dart';

import '../../main.dart';
import '../../models/menu_item_model.dart';
import '../../motion.dart';
import 'icon_chip.dart';
import 'sidebar_constants.dart';

/// One tappable subheading row. Presentation only — it is told whether it is
/// selected and what to do when tapped; it decides neither.
class SidebarMenuItem extends StatefulWidget {
  const SidebarMenuItem({
    super.key,
    required this.item,
    required this.selected,
    required this.onTap,
    this.collapsed = false,
  });

  final MenuItemModel item;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  State<SidebarMenuItem> createState() => _SidebarMenuItemState();
}

class _SidebarMenuItemState extends State<SidebarMenuItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final micro = Motion.duration(context, Motion.micro);
    final fill = selected
        ? kIndigo.withValues(alpha: .10)
        : _hovered
            ? kIndigo.withValues(alpha: .05)
            : Colors.transparent;

    final row = Row(
      // Collapsed, the row is just the icon and is centred in the rail, so it
      // must not claim the full width the way the labelled row does.
      mainAxisSize: widget.collapsed ? MainAxisSize.min : MainAxisSize.max,
      children: [
        // Active rail: grows in rather than appearing abruptly. Dropped in the
        // collapsed rail — its 12px would overflow the 27px of content width a
        // 76px rail leaves, and the fill already shows selection there.
        if (!widget.collapsed)
          AnimatedContainer(
            duration: micro,
            curve: Motion.standardCurve,
            width: 3,
            height: selected ? 18 : 0,
            margin: const EdgeInsets.only(right: 9),
            decoration: BoxDecoration(
              color: kIndigo,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        AnimatedSlide(
          duration: micro,
          curve: Motion.standardCurve,
          offset: Offset(selected ? 0 : 0.06, 0),
          child: SidebarIconChip(
            icon: widget.item.icon,
            color: sidebarHue(widget.item.section.name),
            selected: selected,
            // The collapsed rail budget is exactly 24px: 76 wide, less the
            // outer 12s, the inner 12s and the 1px selected border. A chip
            // larger than that overflows the row.
            size: widget.collapsed ? 24 : 28,
          ),
        ),
        if (!widget.collapsed) ...[
          const SizedBox(width: 12),
          Flexible(
            child: AnimatedDefaultTextStyle(
              duration: micro,
              curve: Motion.standardCurve,
              style: TextStyle(
                fontSize: 15,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? kIndigo : kInk,
              ),
              child: Text(
                widget.item.title,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
              ),
            ),
          ),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: micro,
          curve: Motion.standardCurve,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(10),
            // Tinted edge on the active item, so selection survives at the
            // low contrast a .10 fill has against the navy rail.
            border: Border.all(
              color: selected
                  ? kIndigo.withValues(alpha: .30)
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
                label: widget.item.title,
                child: Tooltip(
                  // Collapsed rail has no text, so the tooltip carries the name.
                  message: widget.collapsed ? widget.item.title : '',
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    // Collapsed: just the centred icon, sized to the rail so
                    // neighbouring rows' fills can't overlap. Expanded: the
                    // full-width row, clipped (not overflowing) mid-animation
                    // when it's briefly wider than the rail.
                    child: widget.collapsed
                        ? Center(child: row)
                        : ClipRect(
                            child: UnconstrainedBox(
                              alignment: Alignment.centerLeft,
                              constrainedAxis: Axis.vertical,
                              clipBehavior: Clip.hardEdge,
                              child: SizedBox(
                                  width: kSidebarWidth - 46, child: row),
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
