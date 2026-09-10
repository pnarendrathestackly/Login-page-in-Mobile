import 'package:flutter/material.dart';

import '../../main.dart';
import '../../models/menu_item_model.dart';
import '../../motion.dart';
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
      children: [
        // Active rail: grows in rather than appearing abruptly.
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
          child: Icon(
            widget.item.icon,
            size: 20,
            color: selected ? kIndigo : kMuted,
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
                    // Clipped rather than overflowing during the collapse
                    // animation, when the row is briefly wider than the rail.
                    // Width-only override: the row keeps its natural height,
                    // which an OverflowBox here would try to make infinite.
                    child: ClipRect(
                      child: UnconstrainedBox(
                        alignment: Alignment.centerLeft,
                        constrainedAxis: Axis.vertical,
                        clipBehavior: Clip.hardEdge,
                        child: SizedBox(width: kSidebarWidth - 46, child: row),
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
