import 'package:flutter/material.dart';

import '../../core/platform/tenant.dart';
import '../../main.dart';

/// The tenant (organization) the current session is scoped to.
///
/// On a multi-tenant platform the single most dangerous ambiguity is not
/// knowing which organization you are acting in — an admin who administers
/// several tenants can otherwise change the wrong one's settings. This chip
/// keeps that answer on screen at all times.
///
/// Read-only: switching tenants is a re-authentication, not a UI toggle, so
/// there is deliberately nothing to click here.
class TenantChip extends StatelessWidget {
  const TenantChip({super.key, required this.tenant, this.compact = false});

  final Tenant tenant;

  /// Narrow layouts show only the initials, so the chip never squeezes the
  /// header's other controls off screen.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '${tenant.name} · ${tenant.plan} · ${tenant.region}',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: kIndigo.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kIndigo.withValues(alpha: .18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.apartment_outlined, size: 15, color: kIndigo),
            if (!compact) ...[
              const SizedBox(width: 6),
              // Bounded so a long organization name ellipsizes instead of
              // pushing the header's controls out of the viewport.
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Text(
                  tenant.name,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: kIndigo,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
