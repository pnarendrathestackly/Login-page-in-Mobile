import 'package:flutter/material.dart';

import '../../../core/platform/modules.dart';
import '../../../main.dart';
import '../../../widgets/common/parts.dart';

/// The screen for a registered module page that has no implementation yet.
///
/// It is deliberately honest rather than decorative: the route, permission and
/// owning service are real and shown as such, and NO business data is invented.
/// A screen that rendered plausible fake employees or invoices would be
/// indistinguishable from a working one, which is how a demo gets mistaken for
/// a product.
///
/// As each module's screens are built, the shell dispatches to them instead and
/// this screen stops being reached for those routes.
class ModulePageScreen extends StatelessWidget {
  const ModulePageScreen({
    super.key,
    required this.module,
    required this.page,
  });

  final PlatformModule module;
  final ModulePage page;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            page.title,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: kInk,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          module.title,
          style: const TextStyle(fontSize: 14, color: kMuted),
        ),
        const SizedBox(height: 20),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                EmptyState(
                  icon: module.icon,
                  title: '${page.title} is not built yet',
                  message:
                      'This page is routed, permission-checked and reachable '
                      'from the sidebar. It is waiting on the '
                      '${module.title} service API.',
                ),
                const Divider(color: kBorder, height: 32),
                // The facts that ARE true about this page, so the wiring is
                // verifiable rather than asserted.
                _Fact(label: 'Route', value: module.pathFor(page)),
                const SizedBox(height: 8),
                _Fact(label: 'Requires', value: page.permission),
                const SizedBox(height: 8),
                _Fact(label: 'Service', value: '${module.id}-service'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One `label: value` row, monospaced so a route or permission id reads
/// exactly as it is written in code.
class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 84,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: kMuted,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: kInk,
            ),
          ),
        ),
      ],
    );
  }
}
