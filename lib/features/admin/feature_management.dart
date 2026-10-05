part of 'super_admin_dashboard.dart';

/// One platform feature flag.
typedef Feature = ({
  String key,
  String name,
  String module,
  String plan,
  bool enabled,
  int rollout,
});

/// 13 modules × 5 features. Built once; the first five rows match the design.
List<Feature> _seedFeatures() {
  const byModule = {
    'Identity': [
      'User Management', 'Single Sign-On', 'MFA Enforcement', //
      'Password Policies', 'Session Controls',
    ],
    'Workflow': [
      'Workflow Engine', 'Approval Chains', 'SLA Timers', //
      'Escalation Rules', 'Form Builder',
    ],
    'AI Services': [
      'AI Assistant', 'Smart Search', 'Document Summaries', //
      'Anomaly Detection', 'Forecasting',
    ],
    'Analytics': [
      'Reports', 'Custom Dashboards', 'Scheduled Exports', //
      'Data Explorer', 'KPI Alerts',
    ],
    'Integration': [
      'API Access', 'Webhooks', 'Data Connectors', //
      'Event Streaming', 'SCIM Provisioning',
    ],
    'HRMS': [
      'Payroll Runs', 'Leave Tracking', 'Recruitment Pipeline', //
      'Performance Reviews', 'Employee Self-Service',
    ],
    'CRM': [
      'Lead Scoring', 'Opportunity Pipeline', 'Customer 360', //
      'Email Campaigns', 'Support Tickets',
    ],
    'ERP': [
      'Inventory Control', 'Purchase Orders', 'Vendor Portal', //
      'Warehouse Transfers', 'Demand Planning',
    ],
    'Finance': [
      'General Ledger', 'Invoicing', 'Expense Claims', //
      'Budget Planning', 'Multi-Currency',
    ],
    'Documents': [
      'Document Vault', 'E-Signatures', 'Version History', //
      'Retention Policies', 'OCR Capture',
    ],
    'Notifications': [
      'Email Alerts', 'SMS Alerts', 'Push Notifications', //
      'Digest Emails', 'In-App Inbox',
    ],
    'Security': [
      'Audit Trail', 'IP Allowlists', 'Data Masking', //
      'Threat Monitoring', 'Encryption Keys',
    ],
    'Platform': [
      'Custom Branding', 'Custom Domains', 'Sandbox Tenants', //
      'Feature Previews', 'Usage Metering',
    ],
  };
  const plans = [
    'Enterprise',
    'Enterprise',
    'Premium',
    'Standard',
    'Enterprise'
  ];
  final modules = byModule.keys.toList();
  final out = <Feature>[];
  // Round-robin across modules, so page 1 shows one feature per module.
  for (var j = 0; j < 5; j++) {
    for (var m = 0; m < modules.length; m++) {
      final i = out.length;
      final name = byModule[modules[m]]![j];
      // Every fifth row is off — 13 of 65, starting with AI Assistant.
      final enabled = i % 5 != 2;
      out.add((
        key: name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_'),
        name: name,
        module: modules[m],
        plan: plans[(m + j) % plans.length],
        enabled: enabled,
        rollout: enabled ? 100 - (i * 7 % 40) : 0,
      ));
    }
  }
  return out;
}

// ponytail: in-memory for the session, like the other admin pages.
final platformFeatures = ValueNotifier<List<Feature>>(_seedFeatures());

const _pageSize = 5;
const _navy = Color(0xFF1E2459);
const _red = Color(0xFFDC2626);

/// Feature Management (`/admin/features`): every feature flag, filterable,
/// with enable/disable, rollout configuration and usage.
class FeatureManagementScreen extends StatefulWidget
    implements OwnsPageHeading {
  const FeatureManagementScreen({super.key});

  @override
  State<FeatureManagementScreen> createState() => _FeatureManagementState();
}

class _FeatureManagementState extends State<FeatureManagementScreen> {
  final _search = TextEditingController();
  String? _module, _plan;
  bool? _enabled;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    platformFeatures.addListener(_changed);
  }

  @override
  void dispose() {
    platformFeatures.removeListener(_changed);
    _search.dispose();
    super.dispose();
  }

  void _changed() => setState(() {});

  List<Feature> get _filtered {
    final q = _search.text.trim().toLowerCase();
    return [
      for (final f in platformFeatures.value)
        if ((q.isEmpty ||
                f.name.toLowerCase().contains(q) ||
                f.module.toLowerCase().contains(q)) &&
            (_module == null || f.module == _module) &&
            (_plan == null || f.plan == _plan) &&
            (_enabled == null || f.enabled == _enabled))
          f,
    ];
  }

  void _filter(VoidCallback change) => setState(() {
        change();
        _page = 0;
      });

  void _replace(Feature f) {
    platformFeatures.value = [
      for (final x in platformFeatures.value) x.key == f.key ? f : x,
    ];
  }

  Future<void> _toggle(Feature f) async {
    if (f.enabled &&
        !await confirm(
          context,
          title: 'Disable ${f.name}?',
          message: 'Tenants on the ${f.plan} plan lose access to this '
              'feature immediately.',
          confirmLabel: 'Disable',
        )) {
      return;
    }
    _replace((
      key: f.key,
      name: f.name,
      module: f.module,
      plan: f.plan,
      enabled: !f.enabled,
      rollout: f.enabled ? 0 : 100,
    ));
    if (mounted) {
      showToast(context, '${f.name} ${f.enabled ? 'disabled' : 'enabled'}.');
    }
  }

  Future<void> _configure(Feature f) async {
    final result = await showFormDialog(
      context,
      title: 'Configure ${f.name}',
      subtitle: '${f.module} · ${f.plan}',
      submitLabel: 'Apply',
      fields: [
        FormFieldSpec(
          label: 'Rollout percentage',
          icon: Icons.percent,
          initial: '${f.rollout}',
          keyboardType: TextInputType.number,
          validator: (v) {
            final n = int.tryParse(v);
            return n == null || n < 0 || n > 100
                ? 'Rollout must be a whole number from 0 to 100.'
                : null;
          },
        ),
        FormFieldSpec(
          label: 'License plan',
          icon: Icons.workspace_premium_outlined,
          initial: f.plan,
          options: const ['Standard', 'Premium', 'Enterprise'],
        ),
      ],
    );
    if (result == null || !mounted) return;
    final rollout = int.parse(result['Rollout percentage']!);
    final plan = result['License plan']!;
    _replace((
      key: f.key,
      name: f.name,
      module: f.module,
      plan: plan,
      enabled: rollout > 0,
      rollout: rollout,
    ));
    showToast(context, '${f.name} updated.');
  }

  void _usage(Feature f) {
    // ponytail: derived from the feature, not measured — no usage API yet.
    final seed = f.name.length * 37 + f.module.length * 11;
    final tenants = f.enabled ? (seed % 120) + 12 : 0;
    showDetailDialog(
      context,
      title: '${f.name} usage',
      subtitle: 'Last 30 days',
      fields: {
        'Status': f.enabled ? 'Enabled' : 'Disabled',
        'Rollout': '${f.rollout}%',
        'Tenants using': '$tenants',
        'Active users': '${tenants * (seed % 90 + 40)}',
        'Feature key': f.key,
      },
    );
  }

  /// Exports the rows the current search and filters select.
  void _export() => exportCsv(
        context,
        fileName: 'features.csv',
        csv: csvOf(
          ['feature', 'key', 'module', 'license_plan', 'status', 'rollout'],
          [
            for (final f in _filtered)
              [
                f.name,
                f.key,
                f.module,
                f.plan,
                f.enabled ? 'enabled' : 'disabled',
                f.rollout,
              ],
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final all = platformFeatures.value;
    final enabled = all.where((f) => f.enabled).length;
    final rows = _filtered;
    final pages = (rows.length / _pageSize).ceil();
    final page = pages == 0 ? 0 : _page.clamp(0, pages - 1);
    final visible = rows.skip(page * _pageSize).take(_pageSize).toList();
    final modules = {for (final f in all) f.module}.toList();

    return LayoutBuilder(
      builder: (context, box) {
        final cols = box.maxWidth >= 900 ? 3 : 1;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'PLATFORM ADMINISTRATION',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                letterSpacing: 1,
                color: _body,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Feature Management',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w700,
                letterSpacing: -.5,
                color: _ink,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Control platform feature availability, configuration, and '
              'access across the enterprise.',
              style: TextStyle(fontSize: 17, color: _body),
            ),
            const SizedBox(height: 22),
            // ponytail: the month-on-month deltas are fixed demo figures;
            // the counts are live.
            _Grid(
              cols: cols,
              gap: 20,
              children: [
                _FeatureStat(
                  label: 'Total Features',
                  value: '${all.length}',
                  delta: '+4.2%',
                  up: true,
                  icon: Icons.tune,
                  iconColor: _ink,
                ),
                _FeatureStat(
                  label: 'Enabled',
                  value: '$enabled',
                  delta: '+3.6%',
                  up: true,
                  icon: Icons.check_circle_outline,
                  iconColor: _green,
                ),
                _FeatureStat(
                  label: 'Disabled',
                  value: '${all.length - enabled}',
                  delta: '-7.1%',
                  up: false,
                  icon: Icons.block,
                  iconColor: _red,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                    child: Wrap(
                      spacing: 14,
                      runSpacing: 12,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: 236,
                          height: 60,
                          child: TextField(
                            controller: _search,
                            onChanged: (_) => _filter(() {}),
                            style: const TextStyle(fontSize: 17, color: _ink),
                            decoration: InputDecoration(
                              hintText: 'Search features...',
                              hintStyle: const TextStyle(
                                fontSize: 17,
                                color: _muted,
                              ),
                              prefixIcon: const Icon(
                                Icons.search,
                                size: 24,
                                color: _muted,
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF1F3F6),
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 18),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        Wrap(
                          spacing: 14,
                          runSpacing: 10,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _FilterMenu(
                              label: _module ?? 'All Modules',
                              options: modules,
                              onSelected: (v) => _filter(() => _module = v),
                            ),
                            _FilterMenu(
                              label: _plan ?? 'All License Plans',
                              options: const [
                                'Standard',
                                'Premium',
                                'Enterprise',
                              ],
                              onSelected: (v) => _filter(() => _plan = v),
                            ),
                            _FilterMenu(
                              label: switch (_enabled) {
                                null => 'All Statuses',
                                true => 'Enabled',
                                false => 'Disabled',
                              },
                              options: const ['Enabled', 'Disabled'],
                              onSelected: (v) => _filter(
                                () => _enabled =
                                    v == null ? null : v == 'Enabled',
                              ),
                            ),
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () => _filter(() {
                                  _search.clear();
                                  _module = _plan = null;
                                  _enabled = null;
                                }),
                                child: const Text(
                                  'Clear Filters',
                                  style: TextStyle(
                                    fontSize: 15.5,
                                    color: _navy,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  LayoutBuilder(
                    builder: (context, c) {
                      // Wide enough for every column; narrower screens
                      // scroll the table sideways instead of crushing it.
                      final w = c.maxWidth < 1100 ? 1100.0 : c.maxWidth;
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: w,
                          child: Column(
                            children: [
                              const _FeatureRow.header(),
                              if (visible.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(40),
                                  child: Text(
                                    'No features match these filters.',
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: _muted,
                                    ),
                                  ),
                                ),
                              for (final f in visible)
                                _FeatureRow(
                                  feature: f,
                                  onToggle: () => _toggle(f),
                                  onConfigure: () => _configure(f),
                                  onUsage: () => _usage(f),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, color: _line),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      runSpacing: 10,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(text: 'Showing '),
                              TextSpan(
                                text: rows.isEmpty
                                    ? '0'
                                    : '${page * _pageSize + 1}-'
                                        '${page * _pageSize + visible.length}',
                                style: const TextStyle(color: _ink),
                              ),
                              const TextSpan(text: ' of '),
                              TextSpan(
                                text: '${rows.length}',
                                style: const TextStyle(color: _ink),
                              ),
                              const TextSpan(text: ' features'),
                            ],
                          ),
                          style: const TextStyle(fontSize: 16, color: _muted),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: _Pager(
                            page: page,
                            pages: pages,
                            onPage: (p) => setState(() => _page = p),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _Button(
                    label: 'Refresh',
                    icon: Icons.refresh,
                    height: 58,
                    onTap: () {
                      setState(() {});
                      showToast(context, 'Feature list reloaded.');
                    },
                  ),
                  _Button(
                    label: 'Export',
                    icon: Icons.file_download_outlined,
                    primary: true,
                    height: 58,
                    onTap: _export,
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

class _FeatureStat extends StatelessWidget {
  const _FeatureStat({
    required this.label,
    required this.value,
    required this.delta,
    required this.up,
    required this.icon,
    required this.iconColor,
  });

  final String label;
  final String value;
  final String delta;
  final bool up;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final tone = up ? _green : _red;
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 26, 26, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: _body,
                  ),
                ),
              ),
              Icon(icon, size: 24, color: iconColor),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(
                up ? Icons.arrow_upward : Icons.arrow_downward,
                size: 13,
                color: tone,
              ),
              const SizedBox(width: 3),
              Text(
                delta,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: tone,
                ),
              ),
              const SizedBox(width: 14),
              const Text(
                'this month',
                style: TextStyle(fontSize: 12.5, color: _muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Bordered dropdown button for a table filter. Picking the first ("All")
/// entry clears the filter.
class _FilterMenu extends StatelessWidget {
  const _FilterMenu({
    required this.label,
    required this.options,
    required this.onSelected,
    this.large = false,
  });

  final String label;
  final List<String> options;
  final ValueChanged<String?> onSelected;

  /// The taller, muted, up/down-chevron variant (License Management).
  final bool large;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: '',
      position: PopupMenuPosition.under,
      onSelected: (v) => onSelected(v.isEmpty ? null : v),
      itemBuilder: (_) => [
        const PopupMenuItem(value: '', child: Text('All')),
        for (final o in options) PopupMenuItem(value: o, child: Text(o)),
      ],
      child: Container(
        height: large ? 46 : 40,
        padding: EdgeInsets.fromLTRB(large ? 10 : 14, 0, 10, 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: _line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: large ? 19 : 15.5,
                  color: large ? _body : _ink,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              large ? Icons.unfold_more : Icons.expand_more,
              size: 18,
              color: _ink,
            ),
          ],
        ),
      ),
    );
  }
}

/// One table row, or the navy header when [feature] is null.
class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required Feature this.feature,
    required VoidCallback this.onToggle,
    required VoidCallback this.onConfigure,
    required VoidCallback this.onUsage,
  });

  const _FeatureRow.header()
      : feature = null,
        onToggle = null,
        onConfigure = null,
        onUsage = null;

  final Feature? feature;
  final VoidCallback? onToggle;
  final VoidCallback? onConfigure;
  final VoidCallback? onUsage;

  static const _flex = [19, 12, 17, 12, 14, 13, 11, 3];

  /// Name and module ellipsize; every other cell scales down if its column
  /// is too narrow rather than overflowing.
  Widget _cells(List<Widget> cells, {bool header = false}) => Row(
        children: [
          for (var i = 0; i < cells.length; i++)
            Expanded(
              flex: _flex[i],
              child: Align(
                alignment: i == 0 || i == 1 || i == 2
                    ? Alignment.centerLeft
                    : Alignment.center,
                child: header || i >= 2
                    ? FittedBox(fit: BoxFit.scaleDown, child: cells[i])
                    : cells[i],
              ),
            ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final f = feature;
    if (f == null) {
      const style = TextStyle(
        fontSize: 15.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 1,
        color: Colors.white,
      );
      return Container(
        height: 66,
        color: _navy,
        padding: const EdgeInsets.only(left: 24),
        child: _cells(header: true, const [
          Text('FEATURE NAME', style: style),
          Text('MODULE', style: style),
          Text('LICENSE PLAN', style: style),
          Text('STATUS', style: style),
          Text('CONFIGURE', style: style),
          Text('USAGE', style: style),
          Text('ACTION', style: style),
          SizedBox.shrink(),
        ]),
      );
    }

    const cell = TextStyle(fontSize: 18.5, color: _ink);
    final tone = f.enabled ? _red : _green;
    return Container(
      height: 73,
      padding: const EdgeInsets.only(left: 26),
      child: _cells([
        Text(f.name, overflow: TextOverflow.ellipsis, style: cell),
        Text(f.module, overflow: TextOverflow.ellipsis, style: cell),
        Text(f.plan, style: cell),
        _StatusPill(enabled: f.enabled),
        SizedBox(
          height: 34,
          child: OutlinedButton.icon(
            onPressed: onConfigure,
            icon: const Icon(Icons.tune, size: 16, color: _ink),
            label: const Text(
              'Configure',
              style: TextStyle(fontSize: 14.5, color: _ink),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              side: const BorderSide(color: _line),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onUsage,
            child: const Text(
              'View Usage',
              style: TextStyle(
                fontSize: 15,
                color: _navy,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
        SizedBox(
          height: 30,
          child: OutlinedButton(
            onPressed: onToggle,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 13),
              side: BorderSide(color: tone),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            child: Text(
              f.enabled ? 'Disable' : 'Enable',
              style: TextStyle(fontSize: 14, color: tone),
            ),
          ),
        ),
        PopupMenuButton<String>(
          tooltip: 'More actions',
          icon: const Icon(Icons.more_vert, size: 20, color: _ink),
          onSelected: (_) {
            Clipboard.setData(ClipboardData(text: f.key));
            showToast(context, 'Feature key copied: ${f.key}');
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'key', child: Text('Copy feature key')),
          ],
        ),
      ]),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final fg = enabled ? const Color(0xFF15803D) : _red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: enabled ? const Color(0xFFE7F6EC) : const Color(0xFFFDECEC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Dot(fg, size: 6),
          const SizedBox(width: 5),
          Text(
            enabled ? 'Enabled' : 'Disabled',
            style: TextStyle(fontSize: 13.5, color: fg),
          ),
        ],
      ),
    );
  }
}

/// ‹ 1 2 3 … N pager; the current page is a navy square.
class _Pager extends StatelessWidget {
  const _Pager({required this.page, required this.pages, required this.onPage});

  final int page;
  final int pages;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    if (pages <= 1) return const SizedBox.shrink();
    // First three around the current page, then an ellipsis and the last.
    final start = (page - 1).clamp(0, (pages - 3).clamp(0, pages));
    final shown = [for (var i = start; i < start + 3 && i < pages; i++) i];
    if (!shown.contains(pages - 1)) shown.add(pages - 1);

    Widget box(Widget child, {bool on = false, VoidCallback? onTap}) => InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: 32,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? _navy : null,
              borderRadius: BorderRadius.circular(6),
            ),
            child: child,
          ),
        );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: _line),
            borderRadius: BorderRadius.circular(6),
          ),
          child: box(
            const Icon(Icons.chevron_left, size: 18, color: _ink),
            onTap: page > 0 ? () => onPage(page - 1) : null,
          ),
        ),
        const SizedBox(width: 12),
        for (var i = 0; i < shown.length; i++) ...[
          if (i > 0 && shown[i] != shown[i - 1] + 1)
            const SizedBox(
              width: 28,
              child: Text('…', textAlign: TextAlign.center),
            ),
          box(
            Text(
              '${shown[i] + 1}',
              style: TextStyle(
                fontSize: 15,
                color: shown[i] == page ? Colors.white : _ink,
              ),
            ),
            on: shown[i] == page,
            onTap: () => onPage(shown[i]),
          ),
          const SizedBox(width: 12),
        ],
        box(
          const Icon(Icons.chevron_right, size: 18, color: _ink),
          onTap: page < pages - 1 ? () => onPage(page + 1) : null,
        ),
      ],
    );
  }
}
