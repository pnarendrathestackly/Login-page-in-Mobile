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

/// Employee management: KPIs, search, department/status filters, a sortable
/// paged table, and the row actions — view (with audit history and documents),
/// edit, change status, upload/remove document, delete. Every mutation goes to
/// [HrmsController.repo] and records an audit entry.
class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key, required this.hrms});

  final HrmsController hrms;

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen>
    with ListViewState<EmployeesScreen, Employee>
    implements HrmsListDelegate<Employee> {
  List<Employee> _employees = const [];
  bool _loading = true;
  String? _error;

  String? _department;
  EmployeeStatus? _status;

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
      final list = await widget.hrms.repo.employees();
      if (!mounted) return;
      setState(() {
        _employees = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "We couldn't load employees.";
        _loading = false;
      });
    }
  }

  // --- HrmsListDelegate ---------------------------------------------------

  @override
  String get title => 'Employees';
  @override
  String get description => 'Everyone employed across the organization.';
  @override
  List<Employee> get rows => _employees;
  @override
  bool get loading => _loading;
  @override
  String? get error => _error;
  @override
  VoidCallback get onRetry => _load;
  @override
  String get searchHint => 'Search name, email, title or department';
  @override
  IconData get emptyIcon => Icons.badge_outlined;
  @override
  String? get emptyActionLabel => 'Add Employee';
  @override
  VoidCallback? get onEmptyAction => _add;

  @override
  List<Employee> get source => _employees;

  @override
  bool get hasActiveFilters => _department != null || _status != null;

  @override
  bool matchesQuery(Employee e, String q) =>
      e.name.toLowerCase().contains(q) ||
      e.email.toLowerCase().contains(q) ||
      e.jobTitle.toLowerCase().contains(q) ||
      e.department.toLowerCase().contains(q);

  @override
  bool matchesFilters(Employee e) =>
      (_department == null || e.department == _department) &&
      (_status == null || e.status == _status);

  List<String> get _departments =>
      {for (final e in _employees) e.department}.toList()..sort();

  @override
  List<Widget> filters() => [
        FilterDropdown<String>(
          label: 'departments',
          value: _department,
          options: _departments,
          labelOf: (d) => d,
          onChanged: (v) => onFilterChanged(() => _department = v),
        ),
        FilterDropdown<EmployeeStatus>(
          label: 'statuses',
          value: _status,
          options: EmployeeStatus.values,
          labelOf: (s) => s.label,
          onChanged: (v) => onFilterChanged(() => _status = v),
        ),
      ];

  @override
  List<Widget> kpis(List<Employee> rows) {
    final active = rows.where((e) => e.status == EmployeeStatus.active).length;
    final onLeave =
        rows.where((e) => e.status == EmployeeStatus.onLeave).length;
    final probation =
        rows.where((e) => e.status == EmployeeStatus.probation).length;
    return [
      hrmsKpi('Total Employees', '${rows.length}', Icons.groups_outlined,
          'Headcount across all departments'),
      hrmsKpi(
          'Active', '$active', Icons.check_circle_outline, 'Currently working'),
      hrmsKpi(
          'On Leave', '$onLeave', Icons.beach_access_outlined, 'Away today'),
      hrmsKpi('On Probation', '$probation', Icons.hourglass_bottom_outlined,
          'In their first months'),
    ];
  }

  @override
  Widget? primaryAction() => hrmsAddButton('Add Employee', _add);

  // --- Mutations --------------------------------------------------------

  Future<void> _add() async {
    final values = await showFormDialog(
      context,
      title: 'Add Employee',
      subtitle: 'Create a new employee record.',
      submitLabel: 'Create',
      fields: const [
        FormFieldSpec(label: 'Full name', icon: Icons.person_outline),
        FormFieldSpec(
          label: 'Email address',
          icon: Icons.mail_outline,
          email: true,
          keyboardType: TextInputType.emailAddress,
        ),
        FormFieldSpec(label: 'Job title', icon: Icons.work_outline),
        FormFieldSpec(label: 'Department', icon: Icons.apartment_outlined),
        FormFieldSpec(
            label: 'Manager',
            icon: Icons.supervisor_account_outlined,
            required: false),
        FormFieldSpec(label: 'Location', icon: Icons.place_outlined),
        FormFieldSpec(
          label: 'Annual salary',
          validator: validatePositiveAmount,
          icon: Icons.payments_outlined,
          keyboardType: TextInputType.number,
        ),
      ],
    );
    if (values == null || !mounted) return;

    final salary = int.tryParse(
        values['Annual salary']!.replaceAll(RegExp(r'[^0-9]'), ''));
    if (salary == null || salary <= 0) {
      showToast(context, 'Annual salary must be a positive number.',
          isError: true);
      return;
    }

    try {
      final saved = await widget.hrms.repo.createEmployee(Employee(
        id: '',
        name: values['Full name']!,
        email: values['Email address']!,
        jobTitle: values['Job title']!,
        department: values['Department']!,
        manager: values['Manager'] ?? '',
        location: values['Location']!,
        status: EmployeeStatus.probation,
        hiredOn: DateTime.now(),
        annualSalary: salary,
      ));
      widget.hrms.log(
        action: 'CREATE',
        entity: 'Employee',
        entityId: saved.id,
        summary: 'Created employee ${saved.name} (${saved.department})',
      );
      await _load();
      setState(() => page = 0);
      if (mounted) showToast(context, '${saved.name} added.');
    } catch (_) {
      if (mounted) {
        showToast(context, 'Employee could not be saved.', isError: true);
      }
    }
  }

  Future<void> _edit(Employee e) async {
    final values = await showFormDialog(
      context,
      title: 'Edit Employee',
      subtitle: e.email,
      fields: [
        FormFieldSpec(
            label: 'Full name', icon: Icons.person_outline, initial: e.name),
        FormFieldSpec(
          label: 'Email address',
          icon: Icons.mail_outline,
          initial: e.email,
          email: true,
          keyboardType: TextInputType.emailAddress,
        ),
        FormFieldSpec(
            label: 'Job title', icon: Icons.work_outline, initial: e.jobTitle),
        FormFieldSpec(
            label: 'Department',
            icon: Icons.apartment_outlined,
            initial: e.department),
        FormFieldSpec(
            label: 'Manager',
            icon: Icons.supervisor_account_outlined,
            initial: e.manager,
            required: false),
        FormFieldSpec(
            label: 'Location', icon: Icons.place_outlined, initial: e.location),
        FormFieldSpec(
          label: 'Annual salary',
          validator: validatePositiveAmount,
          icon: Icons.payments_outlined,
          initial: '${e.annualSalary}',
          keyboardType: TextInputType.number,
        ),
      ],
    );
    if (values == null || !mounted) return;

    final salary = int.tryParse(
        values['Annual salary']!.replaceAll(RegExp(r'[^0-9]'), ''));
    if (salary == null || salary <= 0) {
      showToast(context, 'Annual salary must be a positive number.',
          isError: true);
      return;
    }

    try {
      final saved = await widget.hrms.repo.updateEmployee(e.copyWith(
        name: values['Full name'],
        email: values['Email address'],
        jobTitle: values['Job title'],
        department: values['Department'],
        manager: values['Manager'] ?? '',
        location: values['Location'],
        annualSalary: salary,
      ));
      widget.hrms.log(
        action: 'UPDATE',
        entity: 'Employee',
        entityId: saved.id,
        summary: 'Updated employee ${saved.name}',
      );
      await _load();
      if (mounted) showToast(context, '${saved.name} updated.');
    } catch (_) {
      if (mounted) {
        showToast(context, 'Changes could not be saved.', isError: true);
      }
    }
  }

  Future<void> _changeStatus(Employee e) async {
    final next = await showModalBottomSheet<EmployeeStatus>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final s in EmployeeStatus.values)
              ListTile(
                leading: Icon(Icons.circle, size: 14, color: s.color),
                title: Text(s.label),
                trailing: e.status == s ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(context).pop(s),
              ),
          ],
        ),
      ),
    );
    if (next == null || next == e.status || !mounted) return;

    if (next == EmployeeStatus.terminated) {
      final ok = await confirm(
        context,
        title: 'Terminate ${e.name}?',
        message: 'They will be marked terminated and excluded from payroll.',
        confirmLabel: 'Terminate',
      );
      if (!ok || !mounted) return;
    }

    final saved =
        await widget.hrms.repo.updateEmployee(e.copyWith(status: next));
    widget.hrms.log(
      action: 'UPDATE',
      entity: 'Employee',
      entityId: saved.id,
      summary: 'Status of ${saved.name} → ${next.label}',
    );
    await _load();
    if (mounted) showToast(context, '${saved.name} is now ${next.label}.');
  }

  Future<void> _uploadDocument(Employee e) async {
    final values = await showFormDialog(
      context,
      title: 'Upload Document',
      subtitle: 'Attach a file to ${e.name}.',
      submitLabel: 'Attach',
      fields: const [
        FormFieldSpec(label: 'File name', icon: Icons.attach_file_outlined),
      ],
    );
    if (values == null || !mounted) return;
    final name = values['File name']!;
    final saved = await widget.hrms.repo
        .updateEmployee(e.copyWith(documents: [...e.documents, name]));
    widget.hrms.log(
      action: 'UPDATE',
      entity: 'Employee',
      entityId: saved.id,
      summary: 'Attached document "$name" to ${saved.name}',
    );
    await _load();
    if (mounted) showToast(context, 'Document attached.');
  }

  Future<void> _delete(Employee e) async {
    final ok = await confirm(
      context,
      title: 'Delete ${e.name}?',
      message: 'This permanently removes the employee record and cannot be '
          'undone.',
    );
    if (!ok || !mounted) return;
    await widget.hrms.repo.deleteEmployee(e.id);
    widget.hrms.log(
      action: 'DELETE',
      entity: 'Employee',
      entityId: e.id,
      summary: 'Deleted employee ${e.name}',
    );
    await _load();
    if (mounted) showToast(context, '${e.name} deleted.', isError: true);
  }

  void _view(Employee e) {
    final history = widget.hrms.audit.forEntity('Employee', e.id);
    showDetailDialog(
      context,
      title: e.name,
      subtitle: e.jobTitle,
      leading: InitialsAvatar(name: e.name, radius: 22),
      fields: {
        'Employee ID': e.id.toUpperCase(),
        'Email': e.email,
        'Department': e.department,
        'Manager': e.manager.isEmpty ? '—' : e.manager,
        'Location': e.location,
        'Status': e.status.label,
        'Hired': formatDate(e.hiredOn),
        'Annual salary': money(e.annualSalary),
        'Documents': e.documents.isEmpty ? 'None' : e.documents.join(', '),
        'Audit history': history.isEmpty
            ? 'No changes recorded this session'
            : history
                .take(5)
                .map((a) => '${a.action}: ${a.summary}')
                .join('\n'),
      },
    );
  }

  @override
  List<TableColumn<Employee>> get columns => [
        TableColumn(
          label: 'Employee',
          width: const FlexColumnWidth(2.4),
          sortBy: (e) => e.name,
          cell: (e) => Row(
            children: [
              InitialsAvatar(name: e.name),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      e.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: kInk,
                      ),
                    ),
                    Text(
                      e.email,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: kMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        TableColumn(
          label: 'Title',
          width: const FlexColumnWidth(1.6),
          sortBy: (e) => e.jobTitle,
          cell: (e) => hrmsMuted(e.jobTitle),
        ),
        TableColumn(
          label: 'Department',
          width: const FlexColumnWidth(1.3),
          sortBy: (e) => e.department,
          cell: (e) => hrmsMuted(e.department),
        ),
        TableColumn(
          label: 'Location',
          width: const FlexColumnWidth(1.1),
          sortBy: (e) => e.location,
          cell: (e) => hrmsMuted(e.location),
        ),
        TableColumn(
          label: 'Status',
          width: const FlexColumnWidth(1.1),
          sortBy: (e) => e.status.index,
          cell: (e) => Align(
            alignment: Alignment.centerLeft,
            child: StatusPill(label: e.status.label, color: e.status.color),
          ),
        ),
        TableColumn(
          label: 'Hired',
          width: const FlexColumnWidth(1.1),
          sortBy: (e) => e.hiredOn.millisecondsSinceEpoch,
          cell: (e) => hrmsMuted(formatDate(e.hiredOn)),
        ),
        TableColumn(
          label: 'Actions',
          width: const FixedColumnWidth(120),
          cell: (e) => RowActions(
            onView: () => _view(e),
            onEdit: () => _edit(e),
            onDelete: () => _delete(e),
            extra: [
              (
                label: 'Change status',
                icon: Icons.swap_horiz,
                onTap: () => _changeStatus(e),
              ),
              (
                label: 'Upload document',
                icon: Icons.upload_file_outlined,
                onTap: () => _uploadDocument(e),
              ),
            ],
          ),
        ),
      ];

  @override
  Widget cardBuilder(Employee e) => Container(
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InitialsAvatar(name: e.name, radius: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.name,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: kInk,
                        ),
                      ),
                      Text(
                        e.email,
                        style: const TextStyle(fontSize: 12.5, color: kMuted),
                      ),
                    ],
                  ),
                ),
                StatusPill(label: e.status.label, color: e.status.color),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${e.jobTitle} · ${e.department} · ${e.location}',
              style: const TextStyle(fontSize: 12.5, color: kMuted),
            ),
            const SizedBox(height: 2),
            Text(
              'Hired ${formatDate(e.hiredOn)} · ${money(e.annualSalary)}/yr',
              style: const TextStyle(fontSize: 12, color: kMuted),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: RowActions(
                onView: () => _view(e),
                onEdit: () => _edit(e),
                onDelete: () => _delete(e),
                extra: [
                  (
                    label: 'Change status',
                    icon: Icons.swap_horiz,
                    onTap: () => _changeStatus(e),
                  ),
                  (
                    label: 'Upload document',
                    icon: Icons.upload_file_outlined,
                    onTap: () => _uploadDocument(e),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) =>
      HrmsListView<Employee>(delegate: this, state: this);
}
