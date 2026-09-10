import 'package:flutter/material.dart';

import '../../main.dart';
import '../../widgets.dart';

/// Brand block at the top of the sidebar.
class SidebarHeader extends StatelessWidget {
  const SidebarHeader({super.key, this.collapsed = false});

  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(collapsed ? 0 : 20, 24, 0, 20),
      child: collapsed
          ? const Center(child: Icon(Icons.school, color: kIndigo, size: 26))
          : const BrandMark(),
    );
  }
}
