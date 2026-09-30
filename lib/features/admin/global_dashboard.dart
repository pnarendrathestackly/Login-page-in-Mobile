part of 'super_admin_dashboard.dart';

// ponytail: static demo figures, like the other admin pages. Swap for a
// repository call once a platform-metrics API exists.
const _gdStats = [
  (
    label: 'Total Tenants',
    value: '132',
    note: '8% this month',
    icon: Icons.people_outline
  ),
  (
    label: 'Total Users',
    value: '48,920',
    note: '13% this month',
    icon: Icons.published_with_changes
  ),
  (
    label: 'Active Subscriptions',
    value: '1,233',
    note: '10% this month',
    icon: Icons.visibility_outlined
  ),
  (
    label: 'Active Sessions',
    value: '789',
    note: '6% this month',
    icon: Icons.trending_up
  ),
];

const _orange = Color(0xFFF59E0B);
const _deepGreen = Color(0xFF1E7A46);

const _gdHealth = [
  (label: 'CPU Usage', pct: 67, warn: true),
  (label: 'Memory Utilization', pct: 54, warn: false),
  (label: 'Disk I/O', pct: 32, warn: false),
  (label: 'Network Bandwidth', pct: 78, warn: true),
];

/// Services per state over the last seven days, in thousands.
const _gdSeries = [
  (
    label: 'Operational',
    color: Color(0xFF8B5CF6),
    values: [15.2, 16.9, 16.4, 19.6, 19.6, 17.9, 20.1],
  ),
  (
    label: 'Degraded',
    color: Color(0xFF3B82F6),
    values: [10.2, 11.8, 12.0, 13.8, 12.4, 12.0, 14.0],
  ),
  (
    label: 'Down',
    color: Color(0xFF22C55E),
    values: [5.2, 6.0, 6.0, 7.0, 7.0, 7.0, 7.3],
  ),
];
const _gdDays = [
  'May 12', 'May 13', 'May 14', 'May 15', 'May 16', 'May 17', 'May 18', //
];

/// Global Dashboard (`/admin/global`): platform-wide KPIs, shortcuts,
/// resource health, service status trend, alerts and recent activity.
class GlobalDashboardScreen extends StatelessWidget implements OwnsPageHeading {
  const GlobalDashboardScreen({super.key});

  void _export(BuildContext context) => exportCsv(
        context,
        fileName: 'global-dashboard.csv',
        csv: csvOf([
          'metric',
          'value'
        ], [
          for (final s in _gdStats) [s.label, s.value],
          for (final h in _gdHealth) [h.label, '${h.pct}%'],
          for (final s in _gdSeries)
            for (var i = 0; i < _gdDays.length; i++)
              ['${s.label} services ${_gdDays[i]}', '${s.values[i]}K'],
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final links = [
      (
        title: 'Manage Tenants',
        sub: 'Manage accounts & roles',
        icon: Icons.people_outline,
        path: _modulePath('admin', 'tenants'),
      ),
      (
        title: 'Platform Settings',
        sub: 'Global configuration',
        icon: Icons.settings_outlined,
        path: _modulePath('admin', 'settings'),
      ),
      (
        title: 'Generate Report',
        sub: 'Renewals & seat usage',
        icon: Icons.description_outlined,
        path: AppRoutes.reports,
      ),
      (
        title: 'System Monitoring',
        sub: 'Track admin actions',
        icon: Icons.insights,
        path: _modulePath('admin', 'health'),
      ),
    ];

    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final cols = w >= 960 ? 4 : (w >= 560 ? 2 : 1);
        final sideBySide = w >= 900;

        Widget pair(Widget a, Widget b) => sideBySide
            ? IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: a),
                    const SizedBox(width: 20),
                    Expanded(child: b),
                  ],
                ),
              )
            : Column(children: [a, const SizedBox(height: 18), b]);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Global Dashboard',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                letterSpacing: -.3,
                color: _ink,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Track performance, engagement, and growth across all your '
              'social platforms in one place.',
              style: TextStyle(fontSize: 15, color: _muted),
            ),
            const _Label('PLATFORM OVERVIEW'),
            _Grid(
              cols: cols,
              children: [
                for (final s in _gdStats)
                  _StatCard(
                    label: s.label,
                    value: s.value,
                    note: s.note,
                    icon: s.icon,
                  ),
              ],
            ),
            const _Label('QUICK NAVIGATION'),
            _Grid(
              cols: cols,
              children: [
                for (final l in links)
                  _NavCard(
                    title: l.title,
                    sub: l.sub,
                    icon: l.icon,
                    onTap: () => context.go(l.path),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            pair(const _HealthStatus(), const _SystemHealth()),
            const SizedBox(height: 18),
            pair(const _GdAlerts(), const _GdActivity()),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _Button(
                    label: 'Refresh',
                    icon: Icons.refresh,
                    height: 48,
                    onTap: () => showToast(context,
                        "Live metrics aren't connected yet, so these demo figures can't be refreshed."),
                  ),
                  _Button(
                    label: 'Export report',
                    icon: Icons.file_download_outlined,
                    primary: true,
                    height: 48,
                    onTap: () => _export(context),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
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
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontSize: 15, color: Color(0xFF475569)),
                ),
                const SizedBox(height: 14),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.arrow_upward, size: 13, color: _green),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        note,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _green,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _IconChip(icon, const Color(0xFF3B5BDB)),
        ],
      ),
    );
  }
}

/// White panel with a title row: an optional trailing widget on the right.
class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child, this.trailing});

  final String title;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: _ink,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

/// "Last 7 Days" range chip.
// ponytail: the only range the demo data has, so it is a label, not a menu.
// Make it a dropdown when a metrics API can return other ranges.
class _RangeChip extends StatelessWidget {
  const _RangeChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 3, 5, 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _line),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Last 7 Days', style: TextStyle(fontSize: 12.5, color: _body)),
          SizedBox(width: 2),
          Icon(Icons.expand_more, size: 15, color: _body),
        ],
      ),
    );
  }
}

class _HealthStatus extends StatelessWidget {
  const _HealthStatus();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Platform Health Status',
      trailing: const _RangeChip(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final h in _gdHealth) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    h.label,
                    style: const TextStyle(fontSize: 15.5, color: _ink),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: h.warn
                        ? const Color(0xFFFEF3E2)
                        : const Color(0xFFE7F6EC),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${h.pct}%',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: h.warn
                          ? const Color(0xFFD97706)
                          : const Color(0xFF15803D),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: h.pct / 100,
              minHeight: 10,
              color: h.warn ? _orange : _deepGreen,
              backgroundColor: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2),
            ),
            if (h != _gdHealth.last) const SizedBox(height: 22),
          ],
        ],
      ),
    );
  }
}

class _SystemHealth extends StatelessWidget {
  const _SystemHealth();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'System Health',
      trailing: const _RangeChip(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              for (final s in _gdSeries)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Dot(s.color, size: 10),
                    const SizedBox(width: 6),
                    Text(
                      s.label,
                      style: const TextStyle(fontSize: 14, color: _body),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          const SizedBox(
            height: 220,
            child: CustomPaint(painter: _LinePainter()),
          ),
        ],
      ),
    );
  }
}

/// Three-series line chart, 5K–25K on the y axis, one point per day.
class _LinePainter extends CustomPainter {
  const _LinePainter();

  static const _min = 5.0, _max = 25.0, _left = 28.0, _bottom = 18.0;

  @override
  void paint(Canvas canvas, Size size) {
    final plotH = size.height - _bottom - 6;
    final plotW = size.width - _left - 8;
    double y(double v) => 6 + plotH * (1 - (v - _min) / (_max - _min));
    double x(int i) => _left + 8 + (plotW - 8) * i / (_gdDays.length - 1);

    void label(String s, Offset at, {bool right = false}) {
      final tp = TextPainter(
        text: TextSpan(
          text: s,
          style: const TextStyle(fontSize: 9, color: _muted),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(right ? at.dx - tp.width : at.dx - tp.width / 2,
            at.dy - tp.height / 2),
      );
    }

    // Axes: a light rule on the left and bottom, K labels, day labels.
    final axis = Paint()..color = const Color(0xFFE5E7EB);
    canvas.drawLine(Offset(_left, 6), Offset(_left, 6 + plotH), axis);
    canvas.drawLine(
        Offset(_left, 6 + plotH), Offset(size.width, 6 + plotH), axis);
    for (var v = 5; v <= 25; v += 5) {
      label('${v}K', Offset(_left - 6, y(v.toDouble())), right: true);
    }
    for (var i = 0; i < _gdDays.length; i++) {
      label(_gdDays[i], Offset(x(i), size.height - 6));
    }

    for (final s in _gdSeries) {
      final line = Paint()
        ..color = s.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      final path = Path();
      for (var i = 0; i < s.values.length; i++) {
        final p = Offset(x(i), y(s.values[i]));
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, line);
      for (var i = 0; i < s.values.length; i++) {
        canvas.drawCircle(
            Offset(x(i), y(s.values[i])), 4.5, Paint()..color = s.color);
      }
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) => false;
}

/// Small blue text link in a panel header.
class _PanelLink extends StatelessWidget {
  const _PanelLink(this.text, this.onTap);

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Text(
          text,
          style: const TextStyle(fontSize: 13.5, color: Color(0xFF2563EB)),
        ),
      ),
    );
  }
}

class _GdAlerts extends StatelessWidget {
  const _GdAlerts();

  static const _alerts = [
    (
      icon: Icons.warning_amber_rounded,
      title: 'High CPU Usage',
      body: 'Database server CPU usage is high',
      when: '1 hour ago',
      fg: Color(0xFF9A5B13),
      bodyFg: Color(0xFF9A5B13),
      bg: Color(0xFFFDF3E1),
    ),
    (
      icon: Icons.warning_amber_rounded,
      title: 'Storage Threshold',
      body: 'Storage utilization reached 80%',
      when: '2 hour ago',
      fg: Color(0xFF1D4ED8),
      bodyFg: Color(0xFF475569),
      bg: Color(0xFFEAF1FE),
    ),
    (
      icon: Icons.info_outline,
      title: 'New Tenant Registration',
      body: 'Techcorp solutions registered',
      when: '2 hour ago',
      fg: Color(0xFFE0A800),
      bodyFg: Color(0xFF475569),
      bg: Color(0xFFFEF9E7),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Security alerts',
      trailing: _PanelLink(
        'View all alerts',
        () => context.go(AppRoutes.notifications),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final a in _alerts) ...[
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
              decoration: BoxDecoration(
                color: a.bg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(a.icon, size: 18, color: a.fg),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: a.fg,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          a.body,
                          style: TextStyle(fontSize: 15, color: a.bodyFg),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(a.when, style: TextStyle(fontSize: 12.5, color: a.fg)),
                ],
              ),
            ),
            if (a != _alerts.last) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _GdActivity extends StatelessWidget {
  const _GdActivity();

  static const _items = [
    (
      icon: Icons.warning_amber_rounded,
      tint: Color(0xFF9A5B13),
      title: 'New Tenant Created',
      sub: 'by Admin users',
      when: '10 min ago',
    ),
    (
      icon: Icons.warning_amber_rounded,
      tint: Color(0xFFE0A800),
      title: 'License Updated',
      sub: 'by Admin users.',
      when: '1 hour ago',
    ),
    (
      icon: Icons.info_outline,
      tint: Color(0xFF3B82F6),
      title: 'User Added',
      sub: 'Superadmin granted access to monitoring module.',
      when: '3 hours ago',
    ),
    (
      icon: Icons.info_outline,
      tint: Color(0xFF16A34A),
      title: 'Backup Completed',
      sub: 'Daily snapshot of primary database cluster successfull.',
      when: 'Yesterday',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Recent activities',
      trailing: _PanelLink(
        'View All',
        () => context.go(AppRoutes.notifications),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final a in _items) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: a.tint.withValues(alpha: .10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(a.icon, size: 17, color: a.tint),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        a.sub,
                        style: const TextStyle(fontSize: 13, color: _muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  a.when,
                  style: const TextStyle(fontSize: 12.5, color: _muted),
                ),
              ],
            ),
            if (a != _items.last) const SizedBox(height: 22),
          ],
        ],
      ),
    );
  }
}
