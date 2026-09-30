part of 'super_admin_dashboard.dart';

enum LicenseStatus {
  active('Active', Color(0xFF15803D), Color(0xFFE7F6EC)),
  expiring('Expiring', Color(0xFFD99A00), Color(0xFFFEF6D8)),
  suspended('Suspended', Color(0xFF475569), Color(0xFFEEF0F3)),
  rejected('Rejected', Color(0xFFDC2626), Color(0xFFFDECEC));

  const LicenseStatus(this.label, this.fg, this.bg);
  final String label;
  final Color fg;
  final Color bg;
}

typedef License = ({
  String key,
  String org,
  String plan,
  int seats,
  DateTime expiry,
  LicenseStatus status,
});

const _licensePlans = ['Standard', 'Premium', 'Enterprise'];
const _orgs = [
  '123 Inc', 'Acme Corp', 'Delta Retail Group', 'Northwind Traders',
  'Globex Systems', 'Initech', 'Umbrella Health', 'Stark Logistics',
  'Wayne Finance', 'Techcorp Solutions', 'Blue Harbor Bank',
  'Summit Foods', 'Orion Labs', 'Pioneer Energy', 'Vertex Media', //
];

/// 2,458 licenses: 2,104 active, 142 expiring, 36 suspended, 176 rejected —
/// the figures in the design. Deterministic, so a restart shows the same list.
List<License> _seedLicenses() {
  final today = DateTime.now();
  const letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
  final out = <License>[];
  for (var i = 0; i < 2458; i++) {
    // The first four rows are the ones in the design.
    final status = i < 4
        ? const [
            LicenseStatus.active,
            LicenseStatus.expiring,
            LicenseStatus.expiring,
            LicenseStatus.rejected,
          ][i]
        : switch (i % 100) {
            < 6 => LicenseStatus.expiring,
            < 7 when i % 3 == 0 => LicenseStatus.suspended,
            >= 93 => LicenseStatus.rejected,
            _ => LicenseStatus.active,
          };
    final n = 1000 + (i * 7919) % 9000;
    final code = [
      for (var k = 0; k < 4; k++) letters[(i * 31 + k * 17) % letters.length],
    ].join();
    out.add((
      key: i == 0 ? 'LIC-4421-MNPR' : 'LIC-$n-$code',
      org: i < 4 ? '123 Inc' : _orgs[i % _orgs.length],
      plan: i < 4
          ? 'Standard'
          : _licensePlans[i % 7 == 0 ? 2 : (i % 5 == 0 ? 1 : 0)],
      seats: i < 4 ? 50 : const [50, 25, 100, 250, 10][i % 5],
      expiry: status == LicenseStatus.expiring
          ? today.add(Duration(days: 1 + i % 29))
          : today.add(Duration(days: 45 + (i * 13) % 330)),
      status: status,
    ));
  }
  // Tune the tail so the counts land exactly on the design's figures.
  return _fitCounts(out);
}

List<License> _fitCounts(List<License> all) {
  const want = {
    LicenseStatus.expiring: 142,
    LicenseStatus.suspended: 36,
    LicenseStatus.rejected: 176,
  };
  final list = [...all];
  for (final MapEntry(key: status, value: target) in want.entries) {
    var have = list.where((l) => l.status == status).length;
    for (var i = list.length - 1; i >= 4 && have != target; i--) {
      final l = list[i];
      if (have < target && l.status == LicenseStatus.active) {
        list[i] = _withStatus(l, status);
        have++;
      } else if (have > target && l.status == status) {
        list[i] = _withStatus(l, LicenseStatus.active);
        have--;
      }
    }
  }
  return list;
}

License _withStatus(License l, LicenseStatus s, {DateTime? expiry}) => (
      key: l.key,
      org: l.org,
      plan: l.plan,
      seats: l.seats,
      expiry: expiry ?? l.expiry,
      status: s,
    );

// ponytail: in-memory for the session, like the other admin pages.
final platformLicenses = ValueNotifier<List<License>>(_seedLicenses());

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
String _date(DateTime d) =>
    '${_months[d.month - 1]} ${d.day.toString().padLeft(2, '0')}, ${d.year}';

const _licBlue = Color(0xFF1976D2);
const _licPageSize = 5;

/// License Management (`/admin/licenses`): every license with search,
/// filters, bulk renew / suspend / activate and creation.
class LicenseManagementScreen extends StatefulWidget
    implements OwnsPageHeading {
  const LicenseManagementScreen({super.key});

  @override
  State<LicenseManagementScreen> createState() => _LicenseManagementState();
}

class _LicenseManagementState extends State<LicenseManagementScreen> {
  final _search = TextEditingController();
  String? _org, _plan;
  LicenseStatus? _status;
  int _page = 0;
  final _selected = <String>{};

  @override
  void initState() {
    super.initState();
    platformLicenses.addListener(_changed);
  }

  @override
  void dispose() {
    platformLicenses.removeListener(_changed);
    _search.dispose();
    super.dispose();
  }

  void _changed() => setState(() {});

  List<License> get _filtered {
    final q = _search.text.trim().toLowerCase();
    return [
      for (final l in platformLicenses.value)
        if ((q.isEmpty ||
                l.key.toLowerCase().contains(q) ||
                l.org.toLowerCase().contains(q)) &&
            (_org == null || l.org == _org) &&
            (_plan == null || l.plan == _plan) &&
            (_status == null || l.status == _status))
          l,
    ];
  }

  void _filter(VoidCallback change) => setState(() {
        change();
        _page = 0;
      });

  /// Applies [change] to every selected license, then clears the selection.
  void _bulk(String verb, License Function(License) change) {
    final n = _selected.length;
    platformLicenses.value = [
      for (final l in platformLicenses.value)
        _selected.contains(l.key) ? change(l) : l,
    ];
    setState(_selected.clear);
    showToast(context, '$verb $n license${n == 1 ? '' : 's'}.');
  }

  void _renew() => _bulk(
        'Renewed',
        (l) => _withStatus(
          l,
          l.status == LicenseStatus.rejected ? l.status : LicenseStatus.active,
          expiry: DateTime(l.expiry.year + 1, l.expiry.month, l.expiry.day),
        ),
      );

  Future<void> _suspend() async {
    final n = _selected.length;
    if (!await confirm(
      context,
      title: 'Suspend $n license${n == 1 ? '' : 's'}?',
      message: 'Their organizations lose access until the licenses are '
          'activated again.',
      confirmLabel: 'Suspend',
    )) {
      return;
    }
    if (mounted) {
      _bulk('Suspended', (l) => _withStatus(l, LicenseStatus.suspended));
    }
  }

  void _activate() =>
      _bulk('Activated', (l) => _withStatus(l, LicenseStatus.active));

  Future<void> _create() async {
    final result = await showFormDialog(
      context,
      title: 'Create License',
      subtitle: 'Issue a new license to an organization.',
      submitLabel: 'Create',
      fields: [
        FormFieldSpec(
          label: 'Organization',
          icon: Icons.business_outlined,
          validator: (v) =>
              v.length > 100 ? 'Use at most 100 characters.' : null,
        ),
        const FormFieldSpec(
          label: 'Plan',
          icon: Icons.workspace_premium_outlined,
          initial: 'Standard',
          options: _licensePlans,
        ),
        FormFieldSpec(
          label: 'Seats',
          icon: Icons.event_seat_outlined,
          initial: '50',
          keyboardType: TextInputType.number,
          validator: (v) {
            final n = int.tryParse(v);
            return n == null || n < 1 || n > 100000
                ? 'Seats must be a whole number from 1 to 100000.'
                : null;
          },
        ),
        FormFieldSpec(
          label: 'Term in months',
          icon: Icons.calendar_month_outlined,
          initial: '12',
          keyboardType: TextInputType.number,
          validator: (v) {
            final n = int.tryParse(v);
            return n == null || n < 1 || n > 60
                ? 'Term must be a whole number from 1 to 60.'
                : null;
          },
        ),
      ],
    );
    if (result == null || !mounted) return;
    final org = result['Organization']!;
    final plan = result['Plan']!;
    final seats = int.parse(result['Seats']!);
    final months = int.parse(result['Term in months']!);
    final now = DateTime.now();
    final taken = {for (final l in platformLicenses.value) l.key};
    var key = '';
    for (var i = now.millisecondsSinceEpoch;
        key.isEmpty || taken.contains(key);
        i++) {
      key = 'LIC-${1000 + i % 9000}-NEW${String.fromCharCode(65 + i % 26)}';
    }
    platformLicenses.value = [
      (
        key: key,
        org: org,
        plan: plan,
        seats: seats,
        expiry: DateTime(now.year, now.month + months, now.day),
        status: LicenseStatus.active,
      ),
      ...platformLicenses.value,
    ];
    _filter(() {});
    showToast(context, 'License $key created.');
  }

  /// Exports the rows the current search and filters select.
  void _export() => exportCsv(
        context,
        fileName: 'licenses.csv',
        csv: csvOf(
          ['license_key', 'organization', 'plan', 'seats', 'expiry', 'status'],
          [
            for (final l in _filtered)
              [
                l.key,
                l.org,
                l.plan,
                l.seats,
                l.expiry.toIso8601String().substring(0, 10),
                l.status.label,
              ],
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final all = platformLicenses.value;
    int count(LicenseStatus s) => all.where((l) => l.status == s).length;
    final active = count(LicenseStatus.active);
    final rows = _filtered;
    final pages = (rows.length / _licPageSize).ceil();
    final page = pages == 0 ? 0 : _page.clamp(0, pages - 1);
    final visible = rows.skip(page * _licPageSize).take(_licPageSize).toList();
    final picked = _selected.isNotEmpty;
    String n(int v) => v
        .toString()
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

    return LayoutBuilder(
      builder: (context, box) {
        final cols = box.maxWidth >= 960 ? 4 : (box.maxWidth >= 560 ? 2 : 1);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'License Management',
              style: TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.w600,
                letterSpacing: -.5,
                color: _ink,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Manage platform licenses across organizations and tenants',
              style: TextStyle(fontSize: 17, color: _body),
            ),
            const SizedBox(height: 24),
            _Grid(
              cols: cols,
              gap: 20,
              children: [
                _LicenseStat(
                  label: 'Total Licenses',
                  value: n(all.length),
                  icon: Icons.key_outlined,
                  tint: const Color(0xFF2563EB),
                  // ponytail: fixed demo trend; the counts are live.
                  note: const Text.rich(
                    TextSpan(
                      children: [
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Icon(
                            Icons.arrow_upward,
                            size: 13,
                            color: _green,
                          ),
                        ),
                        TextSpan(
                          text: ' 12%',
                          style: TextStyle(color: _green),
                        ),
                        TextSpan(text: ' vs last month'),
                      ],
                    ),
                  ),
                ),
                _LicenseStat(
                  label: 'Active Licenses',
                  value: n(active),
                  icon: Icons.check_circle_outline,
                  tint: _green,
                  note: Text(
                    '${(active * 100 / all.length).toStringAsFixed(1)}% '
                    'utilization rate',
                  ),
                ),
                _LicenseStat(
                  label: 'Expired licenses',
                  value: n(count(LicenseStatus.expiring)),
                  icon: Icons.warning_amber_rounded,
                  tint: const Color(0xFFD99A00),
                  note: const Text('Within next 30 days'),
                ),
                _LicenseStat(
                  label: 'Suspended licenses',
                  value: n(count(LicenseStatus.suspended)),
                  icon: Icons.block,
                  tint: const Color(0xFFDC2626),
                  note: const Text('Requires admin review'),
                ),
              ],
            ),
            const SizedBox(height: 30),
            const Text(
              'License List',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w600,
                color: _ink,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Wrap(
                        spacing: 16,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: 300,
                            height: 46,
                            child: TextField(
                              controller: _search,
                              onChanged: (_) => _filter(() {}),
                              style: const TextStyle(fontSize: 17, color: _ink),
                              decoration: InputDecoration(
                                hintText: 'Search',
                                hintStyle: const TextStyle(
                                  fontSize: 19,
                                  color: _body,
                                ),
                                prefixIcon: const Icon(
                                  Icons.search,
                                  size: 20,
                                  color: _body,
                                ),
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                border: _configBorder(_line),
                                enabledBorder: _configBorder(_line),
                                focusedBorder: _configBorder(_licBlue),
                              ),
                            ),
                          ),
                          _FilterMenu(
                            large: true,
                            label: _org ?? 'Organization',
                            options: _orgs,
                            onSelected: (v) => _filter(() => _org = v),
                          ),
                          _FilterMenu(
                            large: true,
                            label: _plan ?? 'License Type',
                            options: _licensePlans,
                            onSelected: (v) => _filter(() => _plan = v),
                          ),
                          _FilterMenu(
                            large: true,
                            label: _status?.label ?? 'Status',
                            options: [
                              for (final s in LicenseStatus.values) s.label,
                            ],
                            onSelected: (v) => _filter(
                              () => _status = LicenseStatus.values
                                  .where((s) => s.label == v)
                                  .firstOrNull,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                        height: 46,
                        child: FilledButton.icon(
                          onPressed: _create,
                          icon: const Icon(Icons.create_new_folder_outlined,
                              size: 18),
                          label: const Text(
                            'Create License',
                            style: TextStyle(fontSize: 17),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: _licBlue,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  LayoutBuilder(
                    builder: (context, c) {
                      final w = c.maxWidth < 980 ? 980.0 : c.maxWidth;
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Container(
                          width: w,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _line),
                          ),
                          child: Column(
                            children: [
                              const _LicenseRow.header(),
                              if (visible.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(40),
                                  child: Text(
                                    'No licenses match these filters.',
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: _muted,
                                    ),
                                  ),
                                ),
                              for (final l in visible) ...[
                                _LicenseRow(
                                  license: l,
                                  selected: _selected.contains(l.key),
                                  onSelect: (on) => setState(() => on
                                      ? _selected.add(l.key)
                                      : _selected.remove(l.key)),
                                ),
                                if (l != visible.last)
                                  const Divider(height: 1, color: _line),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.end,
              runSpacing: 16,
              spacing: 16,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 18),
                  child: Wrap(
                    spacing: 24,
                    runSpacing: 12,
                    children: [
                      _BulkButton('Renew', Icons.sync, picked ? _renew : null),
                      _BulkButton('Suspend', Icons.pause_circle_outline,
                          picked ? _suspend : null),
                      _BulkButton('Activate', Icons.play_circle_outline,
                          picked ? _activate : null),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      rows.isEmpty
                          ? 'Showing 0 entries'
                          : 'Showing ${page * _licPageSize + 1} to '
                              '${page * _licPageSize + visible.length} of '
                              '${n(rows.length)} entries',
                      style: _mono.copyWith(fontSize: 14.5, color: _muted),
                    ),
                    const SizedBox(height: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: _LicensePager(
                        page: page,
                        pages: pages,
                        onPage: (p) => setState(() => _page = p),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 28),
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
                      showToast(context, 'License list reloaded.');
                    },
                  ),
                  _Button(
                    label: 'Export report',
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

class _LicenseStat extends StatelessWidget {
  const _LicenseStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.tint,
    required this.note,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color tint;
  final Widget note;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
                  style: _mono.copyWith(
                    fontSize: 17,
                    letterSpacing: .5,
                    color: _body,
                  ),
                ),
              ),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: .14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: tint),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 10),
          DefaultTextStyle.merge(
            style: const TextStyle(fontSize: 14, color: _body),
            child: note,
          ),
        ],
      ),
    );
  }
}

class _LicenseRow extends StatelessWidget {
  const _LicenseRow({
    required License this.license,
    required this.selected,
    required ValueChanged<bool> this.onSelect,
  });

  const _LicenseRow.header()
      : license = null,
        selected = false,
        onSelect = null;

  final License? license;
  final bool selected;
  final ValueChanged<bool>? onSelect;

  static const _flex = [20, 25, 20, 20, 15];

  Widget _cells(List<Widget> cells, {List<Alignment>? align}) => Row(
        children: [
          for (var i = 0; i < cells.length; i++)
            Expanded(
              flex: _flex[i],
              child: Align(
                alignment: align?[i] ?? Alignment.centerLeft,
                child: FittedBox(fit: BoxFit.scaleDown, child: cells[i]),
              ),
            ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final l = license;
    if (l == null) {
      const style = TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        letterSpacing: 1,
        color: Colors.white,
      );
      return Container(
        height: 80,
        color: _navy,
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 0),
        child: _cells(const [
          Text('LICENSE KEY', style: style),
          Text('ORGANIZATION PLAN', style: style),
          Text('LICENSE TYPE', style: style),
          Text('EXPIRY DATE', style: style),
          Text('LICENSE STATUS', style: style),
        ], align: const [
          Alignment.centerLeft,
          Alignment.centerLeft,
          Alignment.centerLeft,
          Alignment.centerLeft,
          Alignment.centerRight,
        ]),
      );
    }
    return Container(
      height: 88,
      color: selected ? const Color(0xFFF3F7FD) : Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 0, 28, 0),
      child: _cells(
        [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Checkbox(
                value: selected,
                onChanged: (v) => onSelect!(v ?? false),
                activeColor: _licBlue,
                side: const BorderSide(color: Color(0xFFC4C9D2)),
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                l.key,
                style: _mono.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _ink,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 52),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l.plan,
                    style: const TextStyle(fontSize: 16.5, color: _ink)),
                Text('${l.seats} Seats',
                    style: const TextStyle(fontSize: 14.5, color: _body)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 36),
            child: Text(l.org,
                style: const TextStyle(fontSize: 16.5, color: _ink)),
          ),
          Text(
            _date(l.expiry),
            style: _mono.copyWith(fontSize: 16, color: _ink),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: l.status.bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Dot(l.status.fg, size: 6),
                const SizedBox(width: 6),
                Text(
                  l.status.label,
                  style: _mono.copyWith(fontSize: 14, color: l.status.fg),
                ),
              ],
            ),
          ),
        ],
        align: const [
          Alignment.centerLeft,
          Alignment.centerLeft,
          Alignment.centerLeft,
          Alignment.centerLeft,
          Alignment.centerRight,
        ],
      ),
    );
  }
}

class _BulkButton extends StatelessWidget {
  const _BulkButton(this.label, this.icon, this.onTap);

  final String label;
  final IconData icon;

  /// Null (disabled) until at least one row is selected.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = onTap == null ? _licBlue.withValues(alpha: .45) : _licBlue;
    return Tooltip(
      message: onTap == null ? 'Select licenses first' : '',
      child: SizedBox(
        height: 38,
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 18, color: color),
          label: Text(label, style: TextStyle(fontSize: 15, color: color)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            side: BorderSide(color: color),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      ),
    );
  }
}

/// ‹ 1 2 3 › with the current page filled blue.
class _LicensePager extends StatelessWidget {
  const _LicensePager({
    required this.page,
    required this.pages,
    required this.onPage,
  });

  final int page;
  final int pages;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    if (pages <= 1) return const SizedBox.shrink();
    final start = (page - 1).clamp(0, (pages - 3).clamp(0, pages));

    Widget box(Widget child, {bool on = false, VoidCallback? onTap}) => Padding(
          padding: const EdgeInsets.only(left: 6),
          child: Material(
            color: on ? _licBlue : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
              side: BorderSide(color: on ? _licBlue : _line),
            ),
            child: InkWell(
              onTap: onTap,
              child:
                  SizedBox(width: 38, height: 38, child: Center(child: child)),
            ),
          ),
        );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        box(
          Icon(Icons.chevron_left, size: 16, color: page > 0 ? _ink : _line),
          onTap: page > 0 ? () => onPage(page - 1) : null,
        ),
        for (var i = start; i < start + 3 && i < pages; i++)
          box(
            Text(
              '${i + 1}',
              style: TextStyle(
                fontSize: 17,
                color: i == page ? Colors.white : _ink,
              ),
            ),
            on: i == page,
            onTap: () => onPage(i),
          ),
        box(
          Icon(Icons.chevron_right,
              size: 16, color: page < pages - 1 ? _ink : _line),
          onTap: page < pages - 1 ? () => onPage(page + 1) : null,
        ),
      ],
    );
  }
}
