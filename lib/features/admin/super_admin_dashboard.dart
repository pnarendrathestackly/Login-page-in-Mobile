import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../auth.dart';
import '../../core/platform/modules.dart';
import '../../motion.dart';
import '../../router/app_router.dart';
import '../../widgets.dart';
import '../../widgets/common/dialogs.dart';
import '../../widgets/common/file_export.dart';

part 'feature_management.dart';
part 'global_dashboard.dart';
part 'license_management.dart';
part 'platform_branding.dart';
part 'platform_configuration.dart';

/// Page background behind the shell's content area.
const kPageCanvas = Color(0xFFFBFBFD);

const _ink = Color(0xFF0F172A);
const _body = Color(0xFF334155);
const _muted = Color(0xFF64748B);
const _line = Color(0xFFE5E7EB);
const _green = Color(0xFF16A34A);
const _amber = Color(0xFFE08A1E);
const _brand = Color(0xFF2A3FE5);
const _mono = TextStyle(
  fontFamily: 'Consolas',
  fontFamilyFallback: ['Menlo', 'Courier New', 'monospace'],
);

String _modulePath(String id, String slug) {
  final m = kModules.firstWhere((m) => m.id == id);
  return m.pathFor(m.pages.firstWhere((p) => p.slug == slug));
}

/// Breadcrumb over a page title, as every page in the shell starts.
class PageHeading extends StatelessWidget {
  const PageHeading({
    super.key,
    required this.breadcrumb,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  /// Trail segments; the last is the current page and is emphasised.
  final List<String> breadcrumb;
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              for (var i = 0; i < breadcrumb.length; i++) ...[
                if (i > 0) const TextSpan(text: '  /  '),
                TextSpan(
                  text: breadcrumb[i],
                  style: i == breadcrumb.length - 1
                      ? const TextStyle(
                          fontWeight: FontWeight.w600, color: _ink)
                      : null,
                ),
              ],
            ],
          ),
          style: const TextStyle(fontSize: 13, color: _muted),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            letterSpacing: -.3,
            color: _ink,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(subtitle!,
              style: const TextStyle(fontSize: 14.5, color: _muted)),
        ],
      ],
    );
    if (actions.isEmpty) return text;
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.start,
      runSpacing: 12,
      children: [
        text,
        Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Wrap(spacing: 10, runSpacing: 10, children: actions),
        ),
      ],
    );
  }
}

// ponytail: static demo figures. There is no platform-metrics API yet; swap
// these consts for a repository call when one exists.
const _kpis = [
  (
    label: 'TOTAL USERS',
    value: '96,412',
    note: '1.8% this month',
    icon: Icons.people_outline,
    tint: Color(0xFF16A34A),
    trend: true,
  ),
  (
    label: 'ACTIVE USERS',
    value: '78,930',
    note: '4,215 online now',
    icon: Icons.published_with_changes,
    tint: Color(0xFF3B5BDB),
    trend: false,
  ),
  (
    label: 'ORGANIZATIONS',
    value: '1,842',
    note: '4.2% this month',
    icon: Icons.apartment_outlined,
    tint: Color(0xFFE08A1E),
    trend: true,
  ),
];

const _status = [
  (label: 'SERVER STATUS', value: 'Healthy', ok: true),
  (label: 'DATABASE', value: 'Connected', ok: true),
  (label: 'API GATEWAY', value: 'Running', ok: true),
  (label: 'STORAGE', value: '68% used', ok: false),
];

const _usage = [
  (label: 'CPU usage', pct: 42, color: Color(0xFF274C83)),
  (label: 'Memory usage', pct: 57, color: Color(0xFF2E5A94)),
  (label: 'Storage', pct: 68, color: Color(0xFF5CC8A0)),
];

/// Super-admin landing page: platform KPIs, system health, shortcuts, security
/// alerts and recent sign-ins.
class SuperAdminDashboard extends StatelessWidget implements OwnsPageHeading {
  const SuperAdminDashboard({super.key, required this.user});

  final AuthUser user;

  List<({String title, String sub, IconData icon, String path})> get _links => [
        (
          title: 'User Management',
          sub: 'Manage accounts & roles',
          icon: Icons.people_outline,
          path: _modulePath('admin', 'users'),
        ),
        (
          title: 'Platform Settings',
          sub: 'Global configuration',
          icon: Icons.settings_outlined,
          path: _modulePath('admin', 'settings'),
        ),
        (
          title: 'License Management',
          sub: 'Renewals & seat usage',
          icon: Icons.description_outlined,
          path: _modulePath('admin', 'licenses'),
        ),
        (
          title: 'Audit Logs',
          sub: 'Track admin actions',
          icon: Icons.article_outlined,
          path: _modulePath('security', 'audit'),
        ),
        (
          title: 'Notifications',
          sub: 'Notification centre',
          icon: Icons.notifications_none,
          path: AppRoutes.notifications,
        ),
        (
          title: 'Backup & Recovery',
          sub: 'Snapshots & restore',
          icon: Icons.inventory_2_outlined,
          // ponytail: closest existing page until a backups screen exists.
          path: _modulePath('security', 'retention'),
        ),
        (
          title: 'Reports',
          sub: 'Platform analytics',
          icon: Icons.show_chart,
          path: AppRoutes.reports,
        ),
        (
          title: 'Security Center',
          sub: 'Threats & policies',
          icon: Icons.shield_outlined,
          path: _modulePath('security', 'overview'),
        ),
      ];

  void _export(BuildContext context) => exportCsv(
        context,
        fileName: 'super-admin-dashboard.csv',
        csv: csvOf([
          'metric',
          'value'
        ], [
          for (final k in _kpis) [k.label, k.value],
          ['LICENSES ACTIVE', '2,140'],
          for (final s in _status) [s.label, s.value],
          for (final u in _usage) [u.label, '${u.pct}%'],
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final cols = w >= 960 ? 4 : (w >= 560 ? 2 : 1);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeading(
              breadcrumb: const ['Platform Administration', 'Dashboard'],
              title: 'Super Admin Dashboard',
              subtitle: 'Welcome back, ${user.role}',
              actions: [
                _Button(
                  label: 'Refresh',
                  icon: Icons.refresh,
                  onTap: () => showToast(context,
                      "Live metrics aren't connected yet, so these demo figures can't be refreshed."),
                ),
                _Button(
                  label: 'Export report',
                  icon: Icons.file_download_outlined,
                  primary: true,
                  onTap: () => _export(context),
                ),
              ],
            ),
            const _Label('PLATFORM OVERVIEW'),
            _Grid(
              cols: cols,
              children: [
                for (final k in _kpis)
                  _KpiCard(
                    label: k.label,
                    value: k.value,
                    note: k.note,
                    icon: k.icon,
                    tint: k.tint,
                    trend: k.trend,
                  ),
                const _HeroCard(
                  label: 'LICENSES ACTIVE',
                  value: '2,140',
                  note: '27 expiring < 30 days',
                  icon: Icons.description_outlined,
                ),
              ],
            ),
            const _Label('SYSTEM STATUS'),
            _Grid(
              cols: cols,
              children: [
                for (final s in _status)
                  _Card(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Caption(s.label),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _Dot(s.ok ? _green : _amber),
                            const SizedBox(width: 8),
                            Text(
                              s.value,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _ink,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            _Card(
              padding: const EdgeInsets.fromLTRB(24, 26, 24, 34),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'RESOURCE UTILIZATION',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: .8,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _Grid(
                    cols: w >= 760 ? 3 : 1,
                    gap: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [for (final u in _usage) _UsageBar(u)],
                  ),
                ],
              ),
            ),
            const _Label('QUICK NAVIGATION'),
            _Grid(
              cols: cols,
              children: [
                for (final l in _links)
                  _NavCard(
                    title: l.title,
                    sub: l.sub,
                    icon: l.icon,
                    onTap: () => context.go(l.path),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            if (w >= 900)
              const IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 52, child: _SecurityAlerts()),
                    SizedBox(width: 22),
                    Expanded(flex: 48, child: _RecentLogins()),
                  ],
                ),
              )
            else ...const [
              _SecurityAlerts(),
              SizedBox(height: 18),
              _RecentLogins(),
            ],
          ],
        );
      },
    );
  }
}

/// Platform Administration landing (`/admin/overview`): headline KPIs, then a
/// card for every admin area with what it covers.
class PlatformAdminScreen extends StatelessWidget implements OwnsPageHeading {
  const PlatformAdminScreen({super.key});

  List<({String title, String body, IconData icon, String path})> get _manage =>
      [
        (
          title: 'Super Admin Dashboard',
          body: 'Platform KPIs, system status, security alerts, and '
              'recent sign-in activity.',
          icon: Icons.grid_view_outlined,
          path: AppRoutes.dashboard,
        ),
        (
          title: 'Global Dashboard',
          body: 'Platform-wide KPIs across every organization — tenants '
              'by plan, onboarding trends.',
          icon: Icons.language,
          path: _modulePath('admin', 'global'),
        ),
        (
          title: 'Platform Configuration',
          body: 'Platform name, timezone, session limits, upload size, '
              'and environment defaults.',
          icon: Icons.settings_outlined,
          path: _modulePath('admin', 'settings'),
        ),
        (
          title: 'Settings',
          body: 'Your preferences, notification defaults, security, and '
              'active sessions.',
          icon: Icons.tune,
          path: AppRoutes.settings,
        ),
        (
          title: 'Platform Branding',
          body: 'Logo, brand colors, login background, and custom domain '
              'for the platform shell.',
          icon: Icons.brush_outlined,
          path: _modulePath('admin', 'branding'),
        ),
        (
          title: 'Feature Management',
          body: 'Roll features out by plan tier, and track rollout '
              'percentage across tenants.',
          icon: Icons.layers_outlined,
          path: _modulePath('admin', 'features'),
        ),
        (
          title: 'License Management',
          body: 'Seats, renewals, and license status across every '
              'organization.',
          icon: Icons.description_outlined,
          path: _modulePath('admin', 'licenses'),
        ),
        (
          title: 'Platform Health Overview',
          body: 'Live status per service — auth, API gateway, database, '
              'queue, storage, AI engine.',
          icon: Icons.monitor_heart_outlined,
          path: _modulePath('admin', 'health'),
        ),
      ];

  List<({String title, String body, IconData icon, String path})>
      get _organization => [
            (
              title: 'Company Setup',
              body: 'Business units, departments, branches, and legal entity '
                  'details.',
              icon: Icons.business_outlined,
              path: _modulePath('admin', 'organizations'),
            ),
            (
              title: 'User Management',
              body: 'Invite, deactivate, and manage roles for every user '
                  'across the organization.',
              icon: Icons.people_outline,
              path: _modulePath('admin', 'users'),
            ),
          ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final kpiCols = w >= 960 ? 4 : (w >= 560 ? 2 : 1);
        final cols = w >= 900 ? 3 : (w >= 560 ? 2 : 1);

        List<Widget> cards(
          List<({String title, String body, IconData icon, String path})> l,
        ) =>
            [
              for (final c in l)
                _FeatureCard(
                  title: c.title,
                  body: c.body,
                  icon: c.icon,
                  // The dashboard is a separate landing, not a sub-area.
                  external: c.path == AppRoutes.dashboard,
                  onTap: () => context.go(c.path),
                ),
            ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeading(
              breadcrumb: const ['Platform Administration', 'Overview'],
              title: 'Platform Administration',
              subtitle: 'Configure the platform, its tenants, and who can '
                  'use it.',
              actions: [
                _Button(
                  label: 'Refresh',
                  icon: Icons.refresh,
                  onTap: () => showToast(context,
                      "Live metrics aren't connected yet, so these demo figures can't be refreshed."),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _Grid(
              cols: kpiCols,
              children: const [
                _KpiCard(
                  label: 'ORGANIZATIONS',
                  value: '1,842',
                  note: '4.2% this month',
                  icon: Icons.apartment_outlined,
                  tint: _green,
                  trend: true,
                ),
                _KpiCard(
                  label: 'TOTAL USERS',
                  value: '96,412',
                  note: '1.8% this month',
                  icon: Icons.people_outline,
                  tint: Color(0xFF3B5BDB),
                  trend: true,
                ),
                _KpiCard(
                  label: 'LICENSES ACTIVE',
                  value: '2,140',
                  note: '27 expiring < 30 days',
                  icon: Icons.description_outlined,
                  tint: Color(0xFFDC2626),
                  trend: false,
                  dot: false,
                ),
                _HeroCard(
                  label: 'PLATFORM UPTIME',
                  value: '99.98%',
                  note: 'Healthy — all regions',
                  icon: Icons.monitor_heart_outlined,
                ),
              ],
            ),
            const _Label('SUPER ADMIN MANAGEMENT'),
            _Grid(cols: cols, children: cards(_manage)),
            const _Label('ORGANIZATION'),
            _Grid(cols: cols, children: cards(_organization)),
          ],
        );
      },
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.title,
    required this.body,
    required this.icon,
    required this.onTap,
    this.external = false,
  });

  final String title;
  final String body;
  final IconData icon;
  final VoidCallback onTap;

  /// Shows a ↗ corner mark for a link that leaves this section.
  final bool external;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: _line),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _IconChip(icon, const Color(0xFF4F46E5), size: 40),
                  const Spacer(),
                  if (external)
                    const Icon(Icons.north_east, size: 14, color: _muted),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                body,
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.5,
                  color: _muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 16),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
          letterSpacing: .8,
          color: Color(0xFF475569),
        ),
      ),
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption(this.text, {this.color = _muted});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: _mono.copyWith(fontSize: 11, letterSpacing: 1.6, color: color),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.color, {this.size = 9});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

/// Equal-width cells, [cols] per row.
class _Grid extends StatelessWidget {
  const _Grid({
    required this.cols,
    required this.children,
    this.gap = 18,
    this.padding = EdgeInsets.zero,
  });

  final int cols;
  final double gap;
  final EdgeInsets padding;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i += cols) ...[
            if (i > 0) SizedBox(height: gap),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var j = i; j < i + cols; j++) ...[
                    if (j > i) SizedBox(width: gap),
                    Expanded(
                      child: j < children.length
                          ? FadeIn(
                              delay: Motion.stagger * j,
                              child: children[j],
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(20)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _line),
      ),
      child: child,
    );
  }
}

class _IconChip extends StatelessWidget {
  const _IconChip(this.icon, this.tint, {this.size = 34});

  final IconData icon;
  final Color tint;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 18, color: tint),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.note,
    required this.icon,
    required this.tint,
    required this.trend,
    this.dot,
  });

  final String label;
  final String value;
  final String note;
  final IconData icon;
  final Color tint;

  /// Green trend line; otherwise plain body text.
  final bool trend;

  /// Green live dot before the note. Defaults to on for non-trend notes.
  final bool? dot;

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _Caption(label),
                ),
              ),
              _IconChip(icon, tint),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: _ink,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (dot ?? !trend) ...[
                const _Dot(_green, size: 6),
                const SizedBox(width: 6),
              ],
              // An icon, not a "↑" character: that glyph comes from a
              // fallback font whose taller line box overflowed the card.
              if (trend) ...[
                const Icon(Icons.arrow_upward, size: 13, color: _green),
                const SizedBox(width: 3),
              ],
              Flexible(
                child: Text(
                  note,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: trend ? _green : _body,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The gradient KPI card that closes each KPI row.
class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.label,
    required this.value,
    required this.note,
    required this.icon,
  });

  final String label;
  final String value;
  final String note;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2433E6), Color(0xFF18208F), Color(0xFF0E1250)],
          stops: [0, .55, 1],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _Caption(label, color: Colors.white),
                ),
              ),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: const Color(0xFF18208F)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            note,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _UsageBar extends StatelessWidget {
  const _UsageBar(this.u);

  final ({String label, int pct, Color color}) u;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                u.label,
                style: const TextStyle(fontSize: 14, color: _ink),
              ),
            ),
            Text(
              '${u.pct}%',
              style: const TextStyle(fontSize: 13.5, color: _ink),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: u.pct / 100,
            minHeight: 7,
            color: u.color,
            backgroundColor: const Color(0xFFEEF0F4),
          ),
        ),
      ],
    );
  }
}

class _NavCard extends StatelessWidget {
  const _NavCard({
    required this.title,
    required this.sub,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String sub;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: _line),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconChip(icon, const Color(0xFF4F46E5), size: 36),
              const SizedBox(height: 18),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(sub, style: const TextStyle(fontSize: 12.5, color: _muted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecurityAlerts extends StatelessWidget {
  const _SecurityAlerts();

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Security alerts',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: _ink,
            ),
          ),
          const SizedBox(height: 14),
          const _Alert(
            icon: Icons.warning_amber_rounded,
            title: '27 licenses expiring within 30 days',
            body: 'Review renewals before Sep 22.',
            warn: true,
          ),
          const SizedBox(height: 12),
          const _Alert(
            icon: Icons.info_outline,
            title: '3 organizations awaiting activation approval',
            body: 'Submitted via self-signup, pending review.',
            warn: false,
          ),
          const SizedBox(height: 12),
          const _Alert(
            icon: Icons.lock_outline,
            title: 'Unusual login pattern detected',
            body: 'Delta Retail Group — 3 logins from new locations.',
            warn: true,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 34,
            child: OutlinedButton(
              onPressed: () => context.go(AppRoutes.notifications),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _line),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: const Text(
                'View all alerts',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: _ink,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Alert extends StatelessWidget {
  const _Alert({
    required this.icon,
    required this.title,
    required this.body,
    required this.warn,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final fg = warn ? const Color(0xFF9A5B13) : const Color(0xFF1D4ED8);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: warn ? const Color(0xFFFDF3E1) : const Color(0xFFEAF1FE),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 18, color: fg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
                const SizedBox(height: 2),
                Text(body, style: TextStyle(fontSize: 14.5, color: fg)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _Outcome { ok, warn, failed }

class _RecentLogins extends StatelessWidget {
  const _RecentLogins();

  static const _rows = [
    (
      bold: 'Ana Ferreira',
      rest: ' signed in from Lisbon, PT',
      bold2: '',
      when: '14 minutes ago',
      outcome: _Outcome.ok,
    ),
    (
      bold: 'Unrecognized device',
      rest: ' signed in to ',
      bold2: 'Delta Retail Group',
      when: '52 minutes ago',
      outcome: _Outcome.warn,
    ),
    (
      bold: 'Renu Kapoor',
      rest: ' (Super Admin) signed in',
      bold2: '',
      when: '3 hours ago',
      outcome: _Outcome.ok,
    ),
    (
      bold: 'Renu Kapoor',
      rest: ' (Super Admin) signed in',
      bold2: '',
      when: '3 hours ago',
      outcome: _Outcome.ok,
    ),
    (
      bold: '5 failed attempts',
      rest: ' on account ',
      bold2: 'j.mehta@acmecorp.com',
      when: 'locked · 5 hours ago',
      outcome: _Outcome.failed,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(22, 20, 22, 18),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Recent login activities',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: _ink,
                    ),
                  ),
                ),
                Text(
                  'Last 24 hours',
                  style: TextStyle(fontSize: 12.5, color: _muted),
                ),
              ],
            ),
          ),
          for (final r in _rows) ...[
            const Divider(height: 1, color: _line),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _OutcomeBadge(r.outcome),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: r.bold,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              TextSpan(text: r.rest),
                              TextSpan(
                                text: r.bold2,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          style: const TextStyle(fontSize: 14, color: _ink),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          r.when,
                          style: const TextStyle(fontSize: 12.5, color: _muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OutcomeBadge extends StatelessWidget {
  const _OutcomeBadge(this.outcome);

  final _Outcome outcome;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (outcome) {
      _Outcome.ok => (_green, Icons.check),
      _Outcome.warn => (_amber, null),
      _Outcome.failed => (const Color(0xFFDC2626), Icons.close),
    };
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        shape: BoxShape.circle,
      ),
      child: icon == null
          ? _Dot(color, size: 4)
          : Icon(icon, size: 16, color: color),
    );
  }
}

class _Button extends StatelessWidget {
  const _Button({
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
    this.height = 32,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;
  final double height;

  @override
  Widget build(BuildContext context) {
    final fg = primary ? Colors.white : _ink;
    final big = height > 40;
    return SizedBox(
      height: height,
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16, color: fg),
        label: Text(
          label,
          style: TextStyle(
            fontSize: big ? 14.5 : 13.5,
            fontWeight: FontWeight.w600,
            color: fg,
          ),
        ),
        style: TextButton.styleFrom(
          backgroundColor: primary ? _brand : Colors.white,
          padding: EdgeInsets.symmetric(horizontal: big ? 18 : 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(big ? 8 : 6),
            side: primary ? BorderSide.none : const BorderSide(color: _line),
          ),
        ),
      ),
    );
  }
}
