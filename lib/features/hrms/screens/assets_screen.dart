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

/// Asset management: create an asset, assign to an employee, transfer, return,
/// update condition, retire, delete. Category/condition filters; audit on each
/// change.
class AssetsScreen extends StatefulWidget {
  const AssetsScreen({super.key, required this.hrms});

  final HrmsController hrms;

  @override
  State<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends State<AssetsScreen>
    with ListViewState<AssetsScreen, HrAsset>
    implements HrmsListDelegate<HrAsset> {
  List<HrAsset> _assets = const [];
  List<Employee> _employees = const [];
  bool _loading = true;
  String? _error;
  String? _category;
  AssetCondition? _condition;

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
        widget.hrms.repo.assets(),
        widget.hrms.repo.employees(),
      ).wait;
      if (!mounted) return;
      setState(() {
        _assets = r.$1;
        _employees = r.$2;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "We couldn't load assets.";
        _loading = false;
      });
    }
  }

  @override
  String get title => 'Assets';
  @override
  String get description => 'Company equipment and who holds it.';
  @override
  List<HrAsset> get rows => _assets;
  @override
  List<HrAsset> get source => _assets;
  @override
  bool get loading => _loading;
  @override
  String? get error => _error;
  @override
  VoidCallback get onRetry => _load;
  @override
  String get searchHint => 'Search tag, name or holder';
  @override
  IconData get emptyIcon => Icons.devices_other_outlined;
  @override
  String? get emptyActionLabel => 'Add Asset';
  @override
  VoidCallback? get onEmptyAction => _add;

  @override
  bool get hasActiveFilters => _category != null || _condition != null;
  @override
  bool matchesQuery(HrAsset a, String q) =>
      a.tag.toLowerCase().contains(q) ||
      a.name.toLowerCase().contains(q) ||
      a.assignedTo.toLowerCase().contains(q);
  @override
  bool matchesFilters(HrAsset a) =>
      (_category == null || a.category == _category) &&
      (_condition == null || a.condition == _condition);

  List<String> get _categories =>
      {for (final a in _assets) a.category}.toList()..sort();

  @override
  List<Widget> filters() => [
        FilterDropdown<String>(
          label: 'categories',
          value: _category,
          options: _categories,
          labelOf: (c) => c,
          onChanged: (v) => onFilterChanged(() => _category = v),
        ),
        FilterDropdown<AssetCondition>(
          label: 'conditions',
          value: _condition,
          options: AssetCondition.values,
          labelOf: (c) => c.label,
          onChanged: (v) => onFilterChanged(() => _condition = v),
        ),
      ];

  @override
  List<Widget> kpis(List<HrAsset> rows) {
    final assigned = rows.where((a) => a.assignedTo.isNotEmpty).length;
    final retired =
        rows.where((a) => a.condition == AssetCondition.retired).length;
    return [
      hrmsKpi('Assets', '${rows.length}', Icons.inventory_2_outlined,
          'Total tracked'),
      hrmsKpi('Assigned', '$assigned', Icons.assignment_ind_outlined,
          'In someone\'s hands'),
      hrmsKpi('Unassigned', '${rows.length - assigned - retired}',
          Icons.inventory_outlined, 'Available to assign'),
      hrmsKpi(
          'Retired', '$retired', Icons.delete_sweep_outlined, 'Out of service'),
    ];
  }

  @override
  Widget? primaryAction() => hrmsAddButton('Add Asset', _add);

  Future<void> _add() async {
    final values = await showFormDialog(
      context,
      title: 'Add Asset',
      subtitle: 'Register a new piece of equipment.',
      submitLabel: 'Add',
      fields: const [
        FormFieldSpec(label: 'Asset tag', icon: Icons.qr_code_2_outlined),
        FormFieldSpec(label: 'Name', icon: Icons.devices_outlined),
        FormFieldSpec(label: 'Category', icon: Icons.category_outlined),
      ],
    );
    if (values == null || !mounted) return;
    if (_assets.any((a) =>
        a.tag.toLowerCase() == values['Asset tag']!.trim().toLowerCase())) {
      showToast(context, 'That asset tag is already in use.', isError: true);
      return;
    }
    final saved = await widget.hrms.repo.createAsset(HrAsset(
      id: '',
      tag: values['Asset tag']!,
      name: values['Name']!,
      category: values['Category']!,
      assignedTo: '',
      condition: AssetCondition.good,
      purchasedOn: DateTime.now(),
    ));
    widget.hrms.log(
      action: 'CREATE',
      entity: 'HrAsset',
      entityId: saved.id,
      summary: 'Registered asset ${saved.tag} (${saved.name})',
    );
    await _load();
    setState(() => page = 0);
    if (mounted) showToast(context, 'Asset added.');
  }

  Future<void> _edit(HrAsset a) async {
    final values = await showFormDialog(
      context,
      title: 'Edit Asset',
      subtitle: a.tag,
      fields: [
        FormFieldSpec(
            label: 'Asset tag', icon: Icons.qr_code_2_outlined, initial: a.tag),
        FormFieldSpec(
            label: 'Name', icon: Icons.devices_outlined, initial: a.name),
        FormFieldSpec(
            label: 'Category',
            icon: Icons.category_outlined,
            initial: a.category),
      ],
    );
    if (values == null || !mounted) return;
    final saved = await widget.hrms.repo.updateAsset(a.copyWith(
      tag: values['Asset tag'],
      name: values['Name'],
      category: values['Category'],
    ));
    widget.hrms.log(
      action: 'UPDATE',
      entity: 'HrAsset',
      entityId: saved.id,
      summary: 'Updated asset ${saved.tag}',
    );
    await _load();
    if (mounted) showToast(context, 'Asset updated.');
  }

  Future<void> _assign(HrAsset a) async {
    if (_employees.isEmpty) return;
    final employee = await showModalBottomSheet<Employee>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.6,
          child: ListView(
            children: [
              ListTile(
                leading: const Icon(Icons.person_off_outlined),
                title: const Text('Unassigned'),
                onTap: () => Navigator.of(context).pop(_unassigned),
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
    if (employee == null || !mounted) return;

    final wasHeldBy = a.assignedTo;
    final saved = await widget.hrms.repo
        .updateAsset(a.copyWith(assignedTo: employee.name));
    final action = employee.name.isEmpty
        ? 'REVOKE'
        : (wasHeldBy.isEmpty ? 'ASSIGN' : 'ASSIGN');
    final summary = employee.name.isEmpty
        ? 'Returned asset ${a.tag}'
        : (wasHeldBy.isEmpty
            ? 'Assigned ${a.tag} to ${employee.name}'
            : 'Transferred ${a.tag} from $wasHeldBy to ${employee.name}');
    widget.hrms.log(
      action: action,
      entity: 'HrAsset',
      entityId: saved.id,
      summary: summary,
    );
    await _load();
    if (mounted) showToast(context, summary);
  }

  Future<void> _condition_(HrAsset a) async {
    final next = await showModalBottomSheet<AssetCondition>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final c in AssetCondition.values)
              ListTile(
                leading: Icon(Icons.circle, size: 14, color: c.color),
                title: Text(c.label),
                trailing: a.condition == c ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(context).pop(c),
              ),
          ],
        ),
      ),
    );
    if (next == null || next == a.condition || !mounted) return;

    if (next == AssetCondition.retired) {
      final ok = await confirm(
        context,
        title: 'Retire ${a.tag}?',
        message: 'It will be marked retired and unassigned.',
        confirmLabel: 'Retire',
      );
      if (!ok || !mounted) return;
    }

    final saved = await widget.hrms.repo.updateAsset(a.copyWith(
      condition: next,
      assignedTo: next == AssetCondition.retired ? '' : a.assignedTo,
    ));
    widget.hrms.log(
      action: next == AssetCondition.retired ? 'ARCHIVE' : 'UPDATE',
      entity: 'HrAsset',
      entityId: saved.id,
      summary: 'Condition of ${a.tag} → ${next.label}',
    );
    await _load();
    if (mounted) showToast(context, '${a.tag} is now ${next.label}.');
  }

  Future<void> _delete(HrAsset a) async {
    final ok = await confirm(
      context,
      title: 'Delete ${a.tag}?',
      message: 'This permanently removes the asset record.',
    );
    if (!ok || !mounted) return;
    await widget.hrms.repo.deleteAsset(a.id);
    widget.hrms.log(
      action: 'DELETE',
      entity: 'HrAsset',
      entityId: a.id,
      summary: 'Deleted asset ${a.tag}',
    );
    await _load();
    if (mounted) showToast(context, 'Asset deleted.', isError: true);
  }

  void _view(HrAsset a) => showDetailDialog(
        context,
        title: a.name,
        subtitle: a.tag,
        fields: {
          'Asset ID': a.id.toUpperCase(),
          'Tag': a.tag,
          'Category': a.category,
          'Assigned to': a.assignedTo.isEmpty ? 'Unassigned' : a.assignedTo,
          'Condition': a.condition.label,
          'Purchased': formatDate(a.purchasedOn),
        },
      );

  @override
  List<TableColumn<HrAsset>> get columns => [
        TableColumn(
          label: 'Tag',
          width: const FlexColumnWidth(1),
          sortBy: (a) => a.tag,
          cell: (a) => Text(a.tag,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13, fontFamily: 'monospace', color: kInk)),
        ),
        TableColumn(
          label: 'Name',
          width: const FlexColumnWidth(1.8),
          sortBy: (a) => a.name,
          cell: (a) => Text(a.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w600, color: kInk)),
        ),
        TableColumn(
          label: 'Category',
          width: const FlexColumnWidth(1),
          sortBy: (a) => a.category,
          cell: (a) => hrmsMuted(a.category),
        ),
        TableColumn(
          label: 'Holder',
          width: const FlexColumnWidth(1.4),
          sortBy: (a) => a.assignedTo,
          cell: (a) =>
              hrmsMuted(a.assignedTo.isEmpty ? 'Unassigned' : a.assignedTo),
        ),
        TableColumn(
          label: 'Condition',
          width: const FlexColumnWidth(1),
          sortBy: (a) => a.condition.index,
          cell: (a) => Align(
            alignment: Alignment.centerLeft,
            child:
                StatusPill(label: a.condition.label, color: a.condition.color),
          ),
        ),
        TableColumn(
          label: 'Actions',
          width: const FixedColumnWidth(120),
          cell: (a) => RowActions(
            onView: () => _view(a),
            onEdit: () => _edit(a),
            onDelete: () => _delete(a),
            extra: [
              (
                label: a.assignedTo.isEmpty ? 'Assign' : 'Transfer / Return',
                icon: Icons.swap_horiz,
                onTap: () => _assign(a),
              ),
              (
                label: 'Change condition',
                icon: Icons.build_outlined,
                onTap: () => _condition_(a),
              ),
            ],
          ),
        ),
      ];

  @override
  Widget cardBuilder(HrAsset a) => Container(
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
                  child: Text('${a.name}  ·  ${a.tag}',
                      style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: kInk)),
                ),
                StatusPill(label: a.condition.label, color: a.condition.color),
              ],
            ),
            const SizedBox(height: 8),
            Text(
                '${a.category} · ${a.assignedTo.isEmpty ? 'Unassigned' : a.assignedTo}',
                style: const TextStyle(fontSize: 12.5, color: kMuted)),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                      onPressed: () => _view(a), child: const Text('View')),
                  TextButton(
                      onPressed: () => _assign(a),
                      child: Text(a.assignedTo.isEmpty ? 'Assign' : 'Move')),
                  TextButton(
                      onPressed: () => _condition_(a),
                      child: const Text('Condition')),
                ],
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) =>
      HrmsListView<HrAsset>(delegate: this, state: this);
}

/// Sentinel returned by the assign sheet's "Unassigned" row — an empty name
/// tells `_assign` to clear the holder.
final Employee _unassigned = Employee(
  id: '',
  name: '',
  email: '',
  jobTitle: '',
  department: '',
  manager: '',
  location: '',
  status: EmployeeStatus.active,
  hiredOn: DateTime.fromMillisecondsSinceEpoch(0),
  annualSalary: 0,
);
