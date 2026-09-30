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

/// Leave management: apply, edit or cancel a request; approve or reject a
/// pending one (recording approver + timestamp + audit); type/status filters;
/// per-employee balances shown on the detail view. Approving draws the balance
/// down via the repository.
class LeaveScreen extends StatefulWidget {
  const LeaveScreen({super.key, required this.hrms});

  final HrmsController hrms;

  @override
  State<LeaveScreen> createState() => _LeaveScreenState();
}

class _LeaveScreenState extends State<LeaveScreen>
    with ListViewState<LeaveScreen, LeaveRequest>
    implements HrmsListDelegate<LeaveRequest> {
  List<LeaveRequest> _requests = const [];
  List<LeaveBalance> _balances = const [];
  List<Employee> _employees = const [];
  bool _loading = true;
  String? _error;
  LeaveType? _type;
  RequestStatus? _status;

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
      final r = await (
        widget.hrms.repo.leaveRequests(),
        widget.hrms.repo.leaveBalances(),
        widget.hrms.repo.employees(),
      ).wait;
      if (!mounted) return;
      setState(() {
        _requests = r.$1;
        _balances = r.$2;
        _employees = r.$3;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "We couldn't load leave requests.";
        _loading = false;
      });
    }
  }

  LeaveBalance? _balanceFor(String employeeId) {
    for (final b in _balances) {
      if (b.employeeId == employeeId) return b;
    }
    return null;
  }

  @override
  String get title => 'Leave';
  @override
  String get description => 'Leave requests, approvals and balances.';
  @override
  List<LeaveRequest> get rows => _requests;
  @override
  List<LeaveRequest> get source => _requests;
  @override
  bool get loading => _loading;
  @override
  String? get error => _error;
  @override
  VoidCallback get onRetry => _load;
  @override
  String get searchHint => 'Search employee or reason';
  @override
  IconData get emptyIcon => Icons.event_available_outlined;
  @override
  String? get emptyActionLabel => 'Apply for Leave';
  @override
  VoidCallback? get onEmptyAction => _apply;

  @override
  bool get hasActiveFilters => _type != null || _status != null;
  @override
  bool matchesQuery(LeaveRequest r, String q) =>
      r.employeeName.toLowerCase().contains(q) ||
      r.reason.toLowerCase().contains(q);
  @override
  bool matchesFilters(LeaveRequest r) =>
      (_type == null || r.type == _type) &&
      (_status == null || r.status == _status);

  @override
  List<Widget> filters() => [
        FilterDropdown<LeaveType>(
          label: 'types',
          value: _type,
          options: LeaveType.values,
          labelOf: (t) => t.label,
          onChanged: (v) => onFilterChanged(() => _type = v),
        ),
        FilterDropdown<RequestStatus>(
          label: 'statuses',
          value: _status,
          options: RequestStatus.values,
          labelOf: (s) => s.label,
          onChanged: (v) => onFilterChanged(() => _status = v),
        ),
      ];

  @override
  List<Widget> kpis(List<LeaveRequest> rows) {
    final pending = rows.where((r) => r.status == RequestStatus.pending).length;
    final approved =
        rows.where((r) => r.status == RequestStatus.approved).length;
    final daysOut = rows
        .where((r) => r.status == RequestStatus.approved)
        .fold(0, (s, r) => s + r.days);
    return [
      hrmsKpi(
          'Requests', '${rows.length}', Icons.list_alt_outlined, 'All time'),
      hrmsKpi('Pending', '$pending', Icons.pending_actions_outlined,
          'Awaiting a decision'),
      hrmsKpi(
          'Approved', '$approved', Icons.event_available_outlined, 'Granted'),
      hrmsKpi('Days Booked', '$daysOut', Icons.today_outlined,
          'Approved leave days'),
    ];
  }

  @override
  Widget? primaryAction() => hrmsAddButton('Apply for Leave', _apply);

  Future<void> _apply() async {
    if (_employees.isEmpty) return;
    final employee = await _pickEmployee();
    if (employee == null || !mounted) return;

    final values = await showFormDialog(
      context,
      title: 'Apply for Leave',
      subtitle: employee.name,
      submitLabel: 'Submit request',
      fields: const [
        FormFieldSpec(
            label: 'Leave type',
            icon: Icons.category_outlined,
            options: ['Annual', 'Sick', 'Casual', 'Unpaid', 'Parental']),
        FormFieldSpec(
            label: 'From (YYYY-MM-DD)',
            validator: validateIsoDate,
            crossValidator: validateLeaveStart,
            icon: Icons.date_range_outlined),
        FormFieldSpec(
            label: 'To (YYYY-MM-DD)',
            validator: validateIsoDate,
            crossValidator: validateLeaveEnd,
            icon: Icons.event_outlined),
        FormFieldSpec(label: 'Reason', icon: Icons.notes_outlined),
      ],
    );
    if (values == null || !mounted) return;

    final type = LeaveType.values.firstWhere(
      (t) => t.label.toLowerCase() == values['Leave type']!.toLowerCase(),
      orElse: () => LeaveType.annual,
    );
    // Validated in the dialog (real dates, end on or after start).
    final from = parseIsoDate(values['From (YYYY-MM-DD)']!)!;
    final to = parseIsoDate(values['To (YYYY-MM-DD)']!)!;

    final saved = await widget.hrms.repo.createLeaveRequest(LeaveRequest(
      id: '',
      employeeId: employee.id,
      employeeName: employee.name,
      type: type,
      from: from,
      to: to,
      reason: values['Reason']!,
      status: RequestStatus.pending,
      requestedOn: DateTime.now(),
    ));
    widget.hrms.log(
      action: 'CREATE',
      entity: 'LeaveRequest',
      entityId: saved.id,
      summary: '${employee.name} requested ${saved.days}d ${type.label} leave',
    );
    await _load();
    setState(() => page = 0);
    if (mounted) showToast(context, 'Leave request submitted.');
  }

  Future<void> _edit(LeaveRequest r) async {
    if (r.status != RequestStatus.pending) {
      showToast(context, 'Only pending requests can be edited.', isError: true);
      return;
    }
    final values = await showFormDialog(
      context,
      title: 'Edit Leave Request',
      subtitle: r.employeeName,
      fields: [
        FormFieldSpec(
            label: 'From (YYYY-MM-DD)',
            validator: validateIsoDate,
            crossValidator: validateLeaveStart,
            icon: Icons.date_range_outlined,
            initial: r.from.toIso8601String().split('T').first),
        FormFieldSpec(
            label: 'To (YYYY-MM-DD)',
            validator: validateIsoDate,
            crossValidator: validateLeaveEnd,
            icon: Icons.event_outlined,
            initial: r.to.toIso8601String().split('T').first),
        FormFieldSpec(
            label: 'Reason', icon: Icons.notes_outlined, initial: r.reason),
      ],
    );
    if (values == null || !mounted) return;
    final from = parseIsoDate(values['From (YYYY-MM-DD)']!)!;
    final to = parseIsoDate(values['To (YYYY-MM-DD)']!)!;
    final saved = await widget.hrms.repo.updateLeaveRequest(
      r.copyWith(from: from, to: to, reason: values['Reason']),
    );
    widget.hrms.log(
      action: 'UPDATE',
      entity: 'LeaveRequest',
      entityId: saved.id,
      summary: 'Edited ${r.employeeName}\'s leave request',
    );
    await _load();
    if (mounted) showToast(context, 'Request updated.');
  }

  Future<void> _decide(LeaveRequest r, bool approve) async {
    if (r.status != RequestStatus.pending) return;
    final saved = await widget.hrms.repo.updateLeaveRequest(r.copyWith(
      status: approve ? RequestStatus.approved : RequestStatus.rejected,
      approver: widget.hrms.actor,
      decidedOn: DateTime.now(),
    ));
    widget.hrms.log(
      action: approve ? 'APPROVE' : 'REJECT',
      entity: 'LeaveRequest',
      entityId: saved.id,
      summary: '${widget.hrms.actor} ${approve ? 'approved' : 'rejected'} '
          '${r.employeeName}\'s ${r.type.label} leave',
    );
    await _load();
    if (mounted) {
      showToast(
        context,
        'Request ${approve ? 'approved' : 'rejected'}.',
        isError: !approve,
      );
    }
  }

  Future<void> _cancel(LeaveRequest r) async {
    if (r.status == RequestStatus.cancelled) return;
    final ok = await confirm(
      context,
      title: 'Cancel this request?',
      message: '${r.employeeName}\'s ${r.type.label} leave '
          '(${formatDate(r.from)}–${formatDate(r.to)}) will be cancelled.',
      confirmLabel: 'Cancel request',
    );
    if (!ok || !mounted) return;
    final saved = await widget.hrms.repo
        .updateLeaveRequest(r.copyWith(status: RequestStatus.cancelled));
    widget.hrms.log(
      action: 'UPDATE',
      entity: 'LeaveRequest',
      entityId: saved.id,
      summary: 'Cancelled ${r.employeeName}\'s ${r.type.label} leave',
    );
    await _load();
    if (mounted) showToast(context, 'Request cancelled.', isError: true);
  }

  void _view(LeaveRequest r) {
    final bal = _balanceFor(r.employeeId);
    showDetailDialog(
      context,
      title: r.employeeName,
      subtitle: '${r.type.label} leave',
      fields: {
        'Request ID': r.id.toUpperCase(),
        'Type': r.type.label,
        'From': formatDate(r.from),
        'To': formatDate(r.to),
        'Days': '${r.days}',
        'Reason': r.reason,
        'Status': r.status.label,
        'Approver': r.approver ?? '—',
        'Decided': r.decidedOn == null ? '—' : formatDate(r.decidedOn!),
        'Balance': bal == null
            ? '—'
            : '${bal.remaining} of ${bal.entitlement} days remaining',
      },
    );
  }

  Future<Employee?> _pickEmployee() => showModalBottomSheet<Employee>(
        context: context,
        isScrollControlled: true,
        builder: (context) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.6,
            child: ListView(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Select employee',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                for (final e in _employees)
                  ListTile(
                    leading: InitialsAvatar(name: e.name),
                    title: Text(e.name),
                    subtitle: Text(e.department),
                    onTap: () => Navigator.of(context).pop(e),
                  ),
              ],
            ),
          ),
        ),
      );

  @override
  List<TableColumn<LeaveRequest>> get columns => [
        TableColumn(
          label: 'Employee',
          width: const FlexColumnWidth(1.9),
          sortBy: (r) => r.employeeName,
          cell: (r) => Row(
            children: [
              InitialsAvatar(name: r.employeeName),
              const SizedBox(width: 10),
              Expanded(
                child: Text(r.employeeName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: kInk)),
              ),
            ],
          ),
        ),
        TableColumn(
          label: 'Type',
          width: const FlexColumnWidth(1),
          sortBy: (r) => r.type.label,
          cell: (r) => hrmsMuted(r.type.label),
        ),
        TableColumn(
          label: 'Dates',
          width: const FlexColumnWidth(1.7),
          sortBy: (r) => r.from.millisecondsSinceEpoch,
          cell: (r) => hrmsMuted('${formatDate(r.from)} – ${formatDate(r.to)}'),
        ),
        TableColumn(
          label: 'Days',
          width: const FlexColumnWidth(0.7),
          numeric: true,
          sortBy: (r) => r.days,
          cell: (r) => Align(
            alignment: Alignment.centerRight,
            child: hrmsMuted('${r.days}'),
          ),
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
          width: const FixedColumnWidth(190),
          cell: (r) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (r.status == RequestStatus.pending) ...[
                IconButton(
                  onPressed: () => _decide(r, true),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  tooltip: 'Approve',
                  color: kSuccess,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 6),
                IconButton(
                  onPressed: () => _decide(r, false),
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  tooltip: 'Reject',
                  color: kDanger,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 6),
              ],
              RowActions(
                onView: () => _view(r),
                onEdit: () => _edit(r),
                onDelete: () => _cancel(r),
                extra: const [],
              ),
            ],
          ),
        ),
      ];

  @override
  Widget cardBuilder(LeaveRequest r) => Container(
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
                InitialsAvatar(name: r.employeeName, radius: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(r.employeeName,
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
              '${r.type.label} · ${formatDate(r.from)} – ${formatDate(r.to)} · ${r.days}d',
              style: const TextStyle(fontSize: 12.5, color: kMuted),
            ),
            Text(r.reason, style: const TextStyle(fontSize: 12, color: kMuted)),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (r.status == RequestStatus.pending) ...[
                    TextButton(
                        onPressed: () => _decide(r, true),
                        child: const Text('Approve')),
                    TextButton(
                        onPressed: () => _decide(r, false),
                        child: const Text('Reject')),
                  ],
                  TextButton(
                      onPressed: () => _view(r), child: const Text('View')),
                ],
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) =>
      HrmsListView<LeaveRequest>(delegate: this, state: this);
}
