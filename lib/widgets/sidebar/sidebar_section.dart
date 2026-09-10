import 'package:flutter/material.dart';

import '../../dashboard.dart';
import '../../main.dart';
import '../../motion.dart';

/// A sidebar heading. Tappable when the group can collapse, so the chevron
/// and the label are one target.
class SidebarSection extends StatelessWidget {
  const SidebarSection({
    super.key,
    required this.group,
    this.expanded = true,
    this.onToggle,
  });

  final SidebarGroup group;
  final bool expanded;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      group.label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
        color: kMuted,
      ),
    );

    if (onToggle == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: label,
      );
    }

    return Semantics(
      header: true,
      expanded: expanded,
      button: true,
      child: InkWell(
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
          child: Row(
            children: [
              Expanded(child: label),
              AnimatedRotation(
                turns: expanded ? 0 : -0.25,
                duration: Motion.duration(context, Motion.micro),
                curve: Motion.standardCurve,
                child: const Icon(
                  Icons.keyboard_arrow_down,
                  size: 16,
                  color: kMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
