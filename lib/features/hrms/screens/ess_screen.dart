import 'package:flutter/material.dart';

import '../../../main.dart';
import '../../../widgets.dart';
import '../../../widgets/common/data_table.dart';
import '../../../widgets/common/dialogs.dart';
import '../../../widgets/common/parts.dart';
import '../hrms_controller.dart';
import '../models/hrms_models.dart';
import 'hrms_list_scaffold.dart';

/// Employee / Manager self-service. Picks the signed-in user (matched by name,
/// falling back to the first employee) and shows their profile, leave balance,
/// recent attendance, payslip line and — for managers — the pending leave of
/// their reports, with approve/reject that writes through the repository.
class EssScreen extends StatefulWidget {
  const EssScreen({super.key, required this.hrms});

  final HrmsController hrms;

  @override
  State<EssScreen> createState() => _EssScreenState();
}

class _EssScreenState extends State<EssScreen> {
  bool _loading = true;
  String? _error;

  Employee? _me;
  LeaveBalance? _balance;
  List<AttendanceRecord> _myAttendance = const [];
  List<LeaveRequest> _myLeave = const [];
  List<LeaveRequest> _teamPending = const [];
  PayrollRun? _lastRun;

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
        widget.hrms.repo.employees(),
        widget.hrms.repo.leaveBalances(),
        widget.hrms.repo.attendance(),
        widget.hrms.repo.leaveRequests(),
        widget.hrms.repo.payrollRuns(),
      ).wait;
      final employees = r.$1;
      final me = employees.firstWhere(
        (e) => e.name.toLowerCase() == widget.hrms.actor.toLowerCase(),
        orElse: () => employees.isEmpty
            ? throw StateError('no employees')
            : employees.first,
      );
      if (!mounted) return;
      setState(() {
        _me = me;
        _balance = r.$2.firstWhere(
          (b) => b.employeeId == me.id,
          orElse: () => LeaveBalance(
            employeeId: me.id,
            employeeName: me.name,
            entitlement: 25,
            taken: 0,
          ),
        );
        _myAttendance = r.$3.where((a) => a.employeeId == me.id).toList()
          ..sort((a, b) => b.date.compareTo(a.date));
        _myLeave = r.$4.where((l) => l.employeeId == me.id).toList()
          ..sort((a, b) => b.requestedOn.compareTo(a.requestedOn));
        _teamPending = r.$4
            .where((l) =>
                l.status == RequestStatus.pending &&
                employees
                    .any((e) => e.id == l.employeeId && e.manager == me.name))
            .toList();
        final paid = r.$5.where((p) => p.status == PayrollStatus.paid).toList();
        _lastRun = paid.isEmpty ? null : paid.first;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "We couldn't load your self-service data.";
        _loading = false;
      });
    }
  }

  Future<void> _applyLeave() async {
    final me = _me;
    if (me == null) return;
    final values = await showFormDialog(
      context,
      title: 'Request Leave',
      subtitle: 'Submitted as ${me.name}',
      submitLabel: 'Submit',
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
      employeeId: me.id,
      employeeName: me.name,
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
      summary: '${me.name} requested ${saved.days}d ${type.label} leave (ESS)',
    );
    await _load();
    if (mounted) showToast(context, 'Leave request submitted.');
  }

  Future<void> _decide(LeaveRequest r, bool approve) async {
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
          '${r.employeeName}\'s leave (MSS)',
    );
    await _load();
    if (mounted) {
      showToast(context, approve ? 'Approved.' : 'Rejected.',
          isError: !approve);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return DirectoryScaffold(
        title: 'ESS / MSS',
        description: 'Your profile, leave, attendance and payslip.',
        kpis: const [],
        child: ErrorState(message: _error!, onRetry: _load),
      );
    }
    if (_loading || _me == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          Text('ESS / MSS',
              style: TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w800, color: kInk)),
          SizedBox(height: 20),
          SkeletonPanel(lines: 4, height: 200),
          SizedBox(height: 16),
          SkeletonPanel(lines: 6, height: 260),
        ],
      );
    }

    final me = _me!;
    final bal = _balance!;
    final recentPresent = _myAttendance
        .take(10)
        .where((a) =>
            a.status == AttendanceStatus.present ||
            a.status == AttendanceStatus.remote)
        .length;

    return DirectoryScaffold(
      title: 'ESS / MSS',
      description: 'Your profile, leave, attendance and payslip.',
      action: hrmsAddButton('Request Leave', _applyLeave),
      kpis: [
        hrmsKpi('Leave Remaining', '${bal.remaining}',
            Icons.event_available_outlined, 'of ${bal.entitlement} days'),
        hrmsKpi(
            'Pending Requests',
            '${_myLeave.where((l) => l.status == RequestStatus.pending).length}',
            Icons.pending_actions_outlined,
            'Awaiting a decision'),
        hrmsKpi('Recent Attendance', '$recentPresent/10',
            Icons.how_to_reg_outlined, 'Last 10 working days'),
        hrmsKpi(
            'Last Payslip Net',
            _lastRun == null
                ? '—'
                : money(me.annualSalary ~/ 12 - (me.annualSalary ~/ 12 ~/ 4)),
            Icons.receipt_long_outlined,
            _lastRun?.period ?? 'No run yet'),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle('My profile'),
          _kv({
            'Name': me.name,
            'Job title': me.jobTitle,
            'Department': me.department,
            'Manager': me.manager.isEmpty ? '—' : me.manager,
            'Location': me.location,
            'Status': me.status.label,
            'Hired': formatDate(me.hiredOn),
          }),
          const SizedBox(height: 24),
          _sectionTitle('My leave requests'),
          if (_myLeave.isEmpty)
            const EmptyState(
              icon: Icons.event_note_outlined,
              title: 'No leave requests',
              message: 'Requests you submit will appear here.',
            )
          else
            ..._myLeave.take(6).map((l) => _leaveRow(l, actions: false)),
          const SizedBox(height: 24),
          _sectionTitle('Recent attendance'),
          if (_myAttendance.isEmpty)
            const EmptyState(
              icon: Icons.schedule_outlined,
              title: 'No attendance records',
              message: 'Your check-ins will appear here.',
            )
          else
            ..._myAttendance.take(6).map((a) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      SizedBox(
                          width: 120, child: hrmsMuted(formatDate(a.date))),
                      Expanded(
                        child: hrmsMuted(
                            'in ${clock(a.checkIn)} · out ${clock(a.checkOut)}'),
                      ),
                      StatusPill(label: a.status.label, color: a.status.color),
                    ],
                  ),
                )),
          if (_teamPending.isNotEmpty) ...[
            const SizedBox(height: 24),
            _sectionTitle('Team approvals (${_teamPending.length})'),
            ..._teamPending.map((l) => _leaveRow(l, actions: true)),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(t,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, color: kInk)),
      );

  Widget _kv(Map<String, String> m) => Column(
        children: [
          for (final e in m.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                      width: 120,
                      child: Text(e.key,
                          style: const TextStyle(fontSize: 13, color: kMuted))),
                  Expanded(
                    child: Text(e.value,
                        style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: kInk)),
                  ),
                ],
              ),
            ),
        ],
      );

  Widget _leaveRow(LeaveRequest l, {required bool actions}) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kInset,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    actions
                        ? '${l.employeeName} · ${l.type.label}'
                        : l.type.label,
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: kInk),
                  ),
                  Text(
                      '${formatDate(l.from)} – ${formatDate(l.to)} · ${l.days}d',
                      style: const TextStyle(fontSize: 12, color: kMuted)),
                ],
              ),
            ),
            if (actions && l.status == RequestStatus.pending) ...[
              IconButton(
                onPressed: () => _decide(l, true),
                icon: const Icon(Icons.check_circle_outline, size: 20),
                color: kSuccess,
                tooltip: 'Approve',
              ),
              IconButton(
                onPressed: () => _decide(l, false),
                icon: const Icon(Icons.cancel_outlined, size: 20),
                color: kDanger,
                tooltip: 'Reject',
              ),
            ] else
              StatusPill(label: l.status.label, color: l.status.color),
          ],
        ),
      );
}
