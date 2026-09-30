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

/// Attendance: check-in / check-out for today, correction of any record,
/// status filter, and CSV export of the current view.
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key, required this.hrms});

  final HrmsController hrms;

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen>
    with ListViewState<AttendanceScreen, AttendanceRecord>
    implements HrmsListDelegate<AttendanceRecord> {
  List<AttendanceRecord> _records = const [];
  List<Employee> _employees = const [];
  bool _loading = true;
  String? _error;
  AttendanceStatus? _status;

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
      final results = await (
        widget.hrms.repo.attendance(),
        widget.hrms.repo.employees(),
      ).wait;
      if (!mounted) return;
      setState(() {
        _records = results.$1;
        _employees = results.$2;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "We couldn't load attendance.";
        _loading = false;
      });
    }
  }

  @override
  String get title => 'Attendance';
  @override
  String get description => 'Daily check-in and check-out records.';
  @override
  List<AttendanceRecord> get rows => _records;
  @override
  List<AttendanceRecord> get source => _records;
  @override
  bool get loading => _loading;
  @override
  String? get error => _error;
  @override
  VoidCallback get onRetry => _load;
  @override
  String get searchHint => 'Search employee name';
  @override
  IconData get emptyIcon => Icons.schedule_outlined;
  @override
  String? get emptyActionLabel => null;
  @override
  VoidCallback? get onEmptyAction => null;

  @override
  bool get hasActiveFilters => _status != null;
  @override
  bool matchesQuery(AttendanceRecord r, String q) =>
      r.employeeName.toLowerCase().contains(q);
  @override
  bool matchesFilters(AttendanceRecord r) =>
      _status == null || r.status == _status;

  @override
  List<Widget> filters() => [
        FilterDropdown<AttendanceStatus>(
          label: 'statuses',
          value: _status,
          options: AttendanceStatus.values,
          labelOf: (s) => s.label,
          onChanged: (v) => onFilterChanged(() => _status = v),
        ),
      ];

  @override
  List<Widget> kpis(List<AttendanceRecord> rows) {
    final today = DateTime.now();
    bool isToday(DateTime d) =>
        d.year == today.year && d.month == today.month && d.day == today.day;
    final todays = rows.where((r) => isToday(r.date)).toList();
    final present = todays
        .where((r) =>
            r.status == AttendanceStatus.present ||
            r.status == AttendanceStatus.remote)
        .length;
    final late = todays.where((r) => r.status == AttendanceStatus.late).length;
    final open =
        rows.where((r) => r.checkIn != null && r.checkOut == null).length;
    return [
      hrmsKpi('Records', '${rows.length}', Icons.event_note_outlined,
          'Across the last working days'),
      hrmsKpi('Present Today', '$present', Icons.how_to_reg_outlined,
          'Checked in today'),
      hrmsKpi('Late Today', '$late', Icons.running_with_errors_outlined,
          'Arrived after start'),
      hrmsKpi('Open Sessions', '$open', Icons.timer_outlined,
          'Checked in, not out'),
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
          hrmsAddButton('Check In / Out', _checkInOut),
        ],
      );

  Future<void> _checkInOut() async {
    if (_employees.isEmpty) return;
    final employee = await _pickEmployee('Check in / out');
    if (employee == null || !mounted) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final existing = _records.firstWhere(
      (r) =>
          r.employeeId == employee.id &&
          r.date.year == today.year &&
          r.date.month == today.month &&
          r.date.day == today.day,
      orElse: () => AttendanceRecord(
        id: '',
        employeeId: employee.id,
        employeeName: employee.name,
        date: today,
        checkIn: null,
        checkOut: null,
        status: AttendanceStatus.present,
      ),
    );

    final AttendanceRecord updated;
    final String verb;
    if (existing.checkIn == null) {
      updated = existing.copyWith(
        checkIn: now,
        status: now.hour >= 9
            ? (now.hour == 9 && now.minute <= 15
                ? AttendanceStatus.present
                : AttendanceStatus.late)
            : AttendanceStatus.present,
      );
      verb = 'checked in';
    } else if (existing.checkOut == null) {
      updated = existing.copyWith(checkOut: now);
      verb = 'checked out';
    } else {
      if (mounted) {
        showToast(context, '${employee.name} already checked out today.');
      }
      return;
    }

    final saved = await widget.hrms.repo.saveAttendance(updated);
    widget.hrms.log(
      action: 'UPDATE',
      entity: 'Attendance',
      entityId: saved.id,
      summary: '${employee.name} $verb at ${clock(now)}',
    );
    await _load();
    if (mounted) showToast(context, '${employee.name} $verb.');
  }

  Future<void> _correct(AttendanceRecord r) async {
    final values = await showFormDialog(
      context,
      title: 'Correct Attendance',
      subtitle: '${r.employeeName} · ${formatDate(r.date)}',
      submitLabel: 'Save correction',
      fields: [
        FormFieldSpec(
          label: 'Check-in (HH:MM)',
          validator: validateTime,
          icon: Icons.login_outlined,
          initial: r.checkIn == null
              ? ''
              : '${r.checkIn!.hour.toString().padLeft(2, '0')}:'
                  '${r.checkIn!.minute.toString().padLeft(2, '0')}',
          required: false,
        ),
        FormFieldSpec(
          label: 'Check-out (HH:MM)',
          validator: validateTime,
          crossValidator: validateCheckOut,
          icon: Icons.logout_outlined,
          initial: r.checkOut == null
              ? ''
              : '${r.checkOut!.hour.toString().padLeft(2, '0')}:'
                  '${r.checkOut!.minute.toString().padLeft(2, '0')}',
          required: false,
        ),
      ],
    );
    if (values == null || !mounted) return;

    DateTime? parse(String? hhmm) {
      final v = (hhmm ?? '').trim();
      if (v.isEmpty) return null;
      final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(v);
      if (m == null) return null;
      final h = int.parse(m[1]!), min = int.parse(m[2]!);
      if (h > 23 || min > 59) return null;
      return DateTime(r.date.year, r.date.month, r.date.day, h, min);
    }

    final ci = parse(values['Check-in (HH:MM)']);
    final co = parse(values['Check-out (HH:MM)']);
    if ((values['Check-in (HH:MM)']?.trim().isNotEmpty ?? false) &&
        ci == null) {
      showToast(context, 'Check-in must be HH:MM.', isError: true);
      return;
    }
    if ((values['Check-out (HH:MM)']?.trim().isNotEmpty ?? false) &&
        co == null) {
      showToast(context, 'Check-out must be HH:MM.', isError: true);
      return;
    }
    if (ci != null && co != null && !co.isAfter(ci)) {
      showToast(context, 'Check-out must be after check-in.', isError: true);
      return;
    }

    final saved = await widget.hrms.repo.saveAttendance(
      AttendanceRecord(
        id: r.id,
        employeeId: r.employeeId,
        employeeName: r.employeeName,
        date: r.date,
        checkIn: ci,
        checkOut: co,
        status: r.status,
      ),
    );
    widget.hrms.log(
      action: 'UPDATE',
      entity: 'Attendance',
      entityId: saved.id,
      summary: 'Corrected ${r.employeeName} on ${formatDate(r.date)}',
    );
    await _load();
    if (mounted) showToast(context, 'Attendance corrected.');
  }

  void _view(AttendanceRecord r) => showDetailDialog(
        context,
        title: r.employeeName,
        subtitle: formatDate(r.date),
        fields: {
          'Date': formatDate(r.date),
          'Check-in': clock(r.checkIn),
          'Check-out': clock(r.checkOut),
          'Worked': r.worked == null
              ? '—'
              : '${r.worked!.inHours}h ${r.worked!.inMinutes % 60}m',
          'Status': r.status.label,
        },
      );

  void _export() {
    final csv = toCsv(
      const ['Employee', 'Date', 'Check-in', 'Check-out', 'Status'],
      filtered.map((r) => [
            r.employeeName,
            formatDate(r.date),
            clock(r.checkIn),
            clock(r.checkOut),
            r.status.label,
          ]),
    );
    widget.hrms.log(
      action: 'EXPORT',
      entity: 'Attendance',
      entityId: '-',
      summary: 'Exported ${filtered.length} attendance rows to CSV',
    );
    showToast(context,
        'CSV generated (${csv.split('\n').length - 2} rows). Download wiring is pending a platform target.');
  }

  Future<Employee?> _pickEmployee(String titleText) =>
      showModalBottomSheet<Employee>(
        context: context,
        isScrollControlled: true,
        builder: (context) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.6,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(titleText,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                Expanded(
                  child: ListView(
                    children: [
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
              ],
            ),
          ),
        ),
      );

  @override
  List<TableColumn<AttendanceRecord>> get columns => [
        TableColumn(
          label: 'Employee',
          width: const FlexColumnWidth(2),
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
          label: 'Date',
          width: const FlexColumnWidth(1.3),
          sortBy: (r) => r.date.millisecondsSinceEpoch,
          cell: (r) => hrmsMuted(formatDate(r.date)),
        ),
        TableColumn(
          label: 'Check-in',
          width: const FlexColumnWidth(1),
          sortBy: (r) => r.checkIn?.millisecondsSinceEpoch ?? 0,
          cell: (r) => hrmsMuted(clock(r.checkIn)),
        ),
        TableColumn(
          label: 'Check-out',
          width: const FlexColumnWidth(1),
          sortBy: (r) => r.checkOut?.millisecondsSinceEpoch ?? 0,
          cell: (r) => hrmsMuted(clock(r.checkOut)),
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
          width: const FixedColumnWidth(96),
          cell: (r) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () => _view(r),
                icon: const Icon(Icons.visibility_outlined, size: 18),
                tooltip: 'View',
                color: kMuted,
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                onPressed: () => _correct(r),
                icon: const Icon(Icons.edit_outlined, size: 18),
                tooltip: 'Correct',
                color: kMuted,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ];

  @override
  Widget cardBuilder(AttendanceRecord r) => Container(
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
              '${formatDate(r.date)} · in ${clock(r.checkIn)} · out ${clock(r.checkOut)}',
              style: const TextStyle(fontSize: 12.5, color: kMuted),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                      onPressed: () => _view(r), child: const Text('View')),
                  TextButton(
                      onPressed: () => _correct(r),
                      child: const Text('Correct')),
                ],
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) =>
      HrmsListView<AttendanceRecord>(delegate: this, state: this);
}
