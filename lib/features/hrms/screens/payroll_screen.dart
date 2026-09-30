import 'package:flutter/material.dart';

import '../../../main.dart';
import '../../../widgets.dart';
import '../../../widgets/common/data_table.dart';
import '../../../widgets/common/dialogs.dart';
import '../../../widgets/common/list_view_state.dart';
import '../../../widgets/common/parts.dart';
import '../hrms_controller.dart';
import '../models/hrms_models.dart';
import 'hrms_list_scaffold.dart';

/// Payroll: create a run for a period, process a draft (draft → processing →
/// paid), view the payslip summary, export the register as CSV. Status filter
/// and history are the table itself.
class PayrollScreen extends StatefulWidget {
  const PayrollScreen({super.key, required this.hrms});

  final HrmsController hrms;

  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen>
    with ListViewState<PayrollScreen, PayrollRun>
    implements HrmsListDelegate<PayrollRun> {
  List<PayrollRun> _runs = const [];
  bool _loading = true;
  String? _error;
  PayrollStatus? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await widget.hrms.repo.payrollRuns();
      if (!mounted) return;
      setState(() {
        _runs = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "We couldn't load payroll runs.";
        _loading = false;
      });
    }
  }

  @override
  String get title => 'Payroll';
  @override
  String get description => 'Payroll runs, processing and history.';
  @override
  List<PayrollRun> get rows => _runs;
  @override
  List<PayrollRun> get source => _runs;
  @override
  bool get loading => _loading;
  @override
  String? get error => _error;
  @override
  VoidCallback get onRetry => _load;
  @override
  String get searchHint => 'Search period';
  @override
  IconData get emptyIcon => Icons.payments_outlined;
  @override
  String? get emptyActionLabel => 'New Payroll Run';
  @override
  VoidCallback? get onEmptyAction => _create;

  @override
  bool get hasActiveFilters => _status != null;
  @override
  bool matchesQuery(PayrollRun r, String q) =>
      r.period.toLowerCase().contains(q);
  @override
  bool matchesFilters(PayrollRun r) => _status == null || r.status == _status;

  @override
  List<Widget> filters() => [
        FilterDropdown<PayrollStatus>(
          label: 'statuses',
          value: _status,
          options: PayrollStatus.values,
          labelOf: (s) => s.label,
          onChanged: (v) => onFilterChanged(() => _status = v),
        ),
      ];

  @override
  List<Widget> kpis(List<PayrollRun> rows) {
    final paid = rows.where((r) => r.status == PayrollStatus.paid).toList();
    final lastNet = paid.isEmpty ? 0 : paid.first.netTotal;
    final drafts = rows.where((r) => r.status == PayrollStatus.draft).length;
    final ytdNet = paid.fold(0, (s, r) => s + r.netTotal);
    return [
      hrmsKpi('Runs', '${rows.length}', Icons.history_outlined, 'All periods'),
      hrmsKpi(
          'Drafts', '$drafts', Icons.edit_note_outlined, 'Not yet processed'),
      hrmsKpi('Last Net Paid', money(lastNet), Icons.account_balance_outlined,
          'Most recent completed run'),
      hrmsKpi('Paid To Date', money(ytdNet), Icons.savings_outlined,
          'Sum of completed runs'),
    ];
  }

  @override
  Widget? primaryAction() => Wrap(
        spacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: _export,
            icon: const Icon(Icons.download_outlined, size: 18),
            label: const Text('Export CSV'),
          ),
          hrmsAddButton('New Payroll Run', _create),
        ],
      );

  Future<void> _create() async {
    final values = await showFormDialog(
      context,
      title: 'New Payroll Run',
      subtitle: 'Create a draft run for a pay period.',
      submitLabel: 'Create draft',
      fields: [
        FormFieldSpec(
          label: 'Period (e.g. April 2026)',
          icon: Icons.calendar_month_outlined,
          validator: validatePayPeriod,
          crossValidator: (v, _) =>
              _runs.any((r) => r.period.toLowerCase() == v.toLowerCase())
                  ? 'A payroll run for $v already exists.'
                  : null,
        ),
      ],
    );
    if (values == null || !mounted) return;
    final period = values['Period (e.g. April 2026)']!;
    final saved = await widget.hrms.repo.createPayrollRun(PayrollRun(
      id: '',
      period: period,
      status: PayrollStatus.draft,
      employeeCount: 0,
      grossTotal: 0,
      deductionsTotal: 0,
      processedOn: null,
    ));
    widget.hrms.log(
      action: 'CREATE',
      entity: 'PayrollRun',
      entityId: saved.id,
      summary: 'Created draft payroll run for ${saved.period}',
    );
    await _load();
    setState(() => page = 0);
    if (mounted) showToast(context, 'Draft run created for $period.');
  }

  Future<void> _process(PayrollRun r) async {
    if (r.status != PayrollStatus.draft) {
      showToast(context, 'Only draft runs can be processed.', isError: true);
      return;
    }
    final ok = await confirm(
      context,
      title: 'Process ${r.period}?',
      message: 'This calculates salaries and deductions for '
          '${r.employeeCount} employees and marks the run paid.',
      confirmLabel: 'Process',
      destructive: false,
    );
    if (!ok || !mounted) return;

    await widget.hrms.repo
        .updatePayrollRun(r.copyWith(status: PayrollStatus.processing));
    widget.hrms.log(
      action: 'UPDATE',
      entity: 'PayrollRun',
      entityId: r.id,
      summary: 'Started processing payroll for ${r.period}',
    );
    await _load();

    final paid = await widget.hrms.repo.updatePayrollRun(
      r.copyWith(status: PayrollStatus.paid, processedOn: DateTime.now()),
    );
    widget.hrms.log(
      action: 'UPDATE',
      entity: 'PayrollRun',
      entityId: paid.id,
      summary:
          'Completed payroll for ${paid.period} — net ${money(paid.netTotal)}',
    );
    await _load();
    if (mounted) showToast(context, '${r.period} processed and paid.');
  }

  void _view(PayrollRun r) => showDetailDialog(
        context,
        title: r.period,
        subtitle: 'Payroll run',
        fields: {
          'Run ID': r.id.toUpperCase(),
          'Status': r.status.label,
          'Employees': '${r.employeeCount}',
          'Gross total': money(r.grossTotal),
          'Deductions': money(r.deductionsTotal),
          'Net total': money(r.netTotal),
          'Processed': r.processedOn == null ? '—' : formatDate(r.processedOn!),
        },
      );

  void _export() {
    final csv = toCsv(
      const ['Period', 'Status', 'Employees', 'Gross', 'Deductions', 'Net'],
      filtered.map((r) => [
            r.period,
            r.status.label,
            r.employeeCount,
            r.grossTotal,
            r.deductionsTotal,
            r.netTotal,
          ]),
    );
    widget.hrms.log(
      action: 'EXPORT',
      entity: 'PayrollRun',
      entityId: '-',
      summary: 'Exported ${filtered.length} payroll rows to CSV',
    );
    showToast(context,
        'CSV generated (${csv.split('\n').length - 2} rows). Download wiring is pending a platform target.');
  }

  @override
  List<TableColumn<PayrollRun>> get columns => [
        TableColumn(
          label: 'Period',
          width: const FlexColumnWidth(1.6),
          sortBy: (r) => r.period,
          cell: (r) => Text(r.period,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w600, color: kInk)),
        ),
        TableColumn(
          label: 'Employees',
          width: const FlexColumnWidth(1),
          numeric: true,
          sortBy: (r) => r.employeeCount,
          cell: (r) => Align(
              alignment: Alignment.centerRight,
              child: hrmsMuted('${r.employeeCount}')),
        ),
        TableColumn(
          label: 'Gross',
          width: const FlexColumnWidth(1.2),
          numeric: true,
          sortBy: (r) => r.grossTotal,
          cell: (r) => Align(
              alignment: Alignment.centerRight,
              child: hrmsMuted(money(r.grossTotal))),
        ),
        TableColumn(
          label: 'Net',
          width: const FlexColumnWidth(1.2),
          numeric: true,
          sortBy: (r) => r.netTotal,
          cell: (r) => Align(
              alignment: Alignment.centerRight,
              child: hrmsMuted(money(r.netTotal))),
        ),
        TableColumn(
          label: 'Status',
          width: const FlexColumnWidth(1),
          sortBy: (r) => r.status.index,
          cell: (r) => Align(
            alignment: Alignment.centerLeft,
            child: StatusPill(label: r.status.label, color: r.status.color),
          ),
        ),
        TableColumn(
          label: 'Actions',
          width: const FixedColumnWidth(110),
          cell: (r) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 32,
                height: 32,
                child: IconButton(
                  onPressed: () => _view(r),
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  tooltip: 'View',
                  color: kMuted,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(),
                ),
              ),
              if (r.status == PayrollStatus.draft)
                SizedBox(
                  width: 32,
                  height: 32,
                  child: IconButton(
                    onPressed: () => _process(r),
                    icon: const Icon(Icons.play_circle_outline, size: 18),
                    tooltip: 'Process run',
                    color: kIndigo,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(),
                  ),
                ),
            ],
          ),
        ),
      ];

  @override
  Widget cardBuilder(PayrollRun r) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kInset,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(r.period,
                      style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: kInk)),
                ),
                StatusPill(label: r.status.label, color: r.status.color),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${r.employeeCount} employees · gross ${money(r.grossTotal)} · net ${money(r.netTotal)}',
              style: const TextStyle(fontSize: 12.5, color: kMuted),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                      onPressed: () => _view(r), child: const Text('View')),
                  if (r.status == PayrollStatus.draft)
                    TextButton(
                        onPressed: () => _process(r),
                        child: const Text('Process')),
                ],
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) =>
      HrmsListView<PayrollRun>(delegate: this, state: this);
}
