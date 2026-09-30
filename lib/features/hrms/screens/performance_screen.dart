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

/// Performance: create a review cycle for an employee, advance it through the
/// workflow (not started → self → manager → calibration → closed), submit a
/// rating on close. Status filter; audit on every transition.
class PerformanceScreen extends StatefulWidget {
  const PerformanceScreen({super.key, required this.hrms});

  final HrmsController hrms;

  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen>
    with ListViewState<PerformanceScreen, ReviewCycle>
    implements HrmsListDelegate<ReviewCycle> {
  List<ReviewCycle> _reviews = const [];
  List<Employee> _employees = const [];
  bool _loading = true;
  String? _error;
  ReviewStatus? _status;

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
        widget.hrms.repo.reviews(),
        widget.hrms.repo.employees(),
      ).wait;
      if (!mounted) return;
      setState(() {
        _reviews = r.$1;
        _employees = r.$2;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "We couldn't load reviews.";
        _loading = false;
      });
    }
  }

  @override
  String get title => 'Performance';
  @override
  String get description => 'Review cycles, goals and ratings.';
  @override
  List<ReviewCycle> get rows => _reviews;
  @override
  List<ReviewCycle> get source => _reviews;
  @override
  bool get loading => _loading;
  @override
  String? get error => _error;
  @override
  VoidCallback get onRetry => _load;
  @override
  String get searchHint => 'Search employee, reviewer or cycle';
  @override
  IconData get emptyIcon => Icons.rate_review_outlined;
  @override
  String? get emptyActionLabel => 'Create Review';
  @override
  VoidCallback? get onEmptyAction => _create;

  @override
  bool get hasActiveFilters => _status != null;
  @override
  bool matchesQuery(ReviewCycle r, String q) =>
      r.employeeName.toLowerCase().contains(q) ||
      r.reviewer.toLowerCase().contains(q) ||
      r.name.toLowerCase().contains(q);
  @override
  bool matchesFilters(ReviewCycle r) => _status == null || r.status == _status;

  @override
  List<Widget> filters() => [
        FilterDropdown<ReviewStatus>(
          label: 'statuses',
          value: _status,
          options: ReviewStatus.values,
          labelOf: (s) => s.label,
          onChanged: (v) => onFilterChanged(() => _status = v),
        ),
      ];

  @override
  List<Widget> kpis(List<ReviewCycle> rows) {
    final open = rows.where((r) => r.status != ReviewStatus.closed).length;
    final closed = rows.where((r) => r.status == ReviewStatus.closed).toList();
    final avg = closed.isEmpty
        ? 0.0
        : closed.fold(0.0, (s, r) => s + (r.rating ?? 0)) / closed.length;
    final overdue = rows
        .where((r) =>
            r.status != ReviewStatus.closed && r.dueOn.isBefore(DateTime.now()))
        .length;
    return [
      hrmsKpi(
          'Reviews', '${rows.length}', Icons.fact_check_outlined, 'This cycle'),
      hrmsKpi('In Progress', '$open', Icons.pending_outlined, 'Not yet closed'),
      hrmsKpi('Overdue', '$overdue', Icons.event_busy_outlined,
          'Past their due date'),
      hrmsKpi('Avg Rating', avg == 0 ? '—' : avg.toStringAsFixed(1),
          Icons.star_outline, 'Across closed reviews'),
    ];
  }

  @override
  Widget? primaryAction() => hrmsAddButton('Create Review', _create);

  Future<void> _create() async {
    if (_employees.isEmpty) return;
    final employee = await showModalBottomSheet<Employee>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.6,
          child: ListView(
            children: [
              for (final e in _employees)
                ListTile(
                  leading: InitialsAvatar(name: e.name),
                  title: Text(e.name),
                  subtitle: Text(e.jobTitle),
                  onTap: () => Navigator.of(context).pop(e),
                ),
            ],
          ),
        ),
      ),
    );
    if (employee == null || !mounted) return;

    final values = await showFormDialog(
      context,
      title: 'Create Review',
      subtitle: employee.name,
      submitLabel: 'Create',
      fields: [
        const FormFieldSpec(label: 'Cycle name', icon: Icons.label_outline),
        FormFieldSpec(
            label: 'Reviewer',
            icon: Icons.supervisor_account_outlined,
            initial: employee.manager),
        const FormFieldSpec(
            label: 'Due (YYYY-MM-DD)',
            validator: validateIsoDate,
            crossValidator: validateDueDate,
            icon: Icons.event_outlined),
      ],
    );
    if (values == null || !mounted) return;
    // Validated in the dialog, so this always parses.
    final due = parseIsoDate(values['Due (YYYY-MM-DD)']!)!;
    final saved = await widget.hrms.repo.createReview(ReviewCycle(
      id: '',
      name: values['Cycle name']!,
      employeeId: employee.id,
      employeeName: employee.name,
      reviewer:
          values['Reviewer']!.isEmpty ? widget.hrms.actor : values['Reviewer']!,
      status: ReviewStatus.notStarted,
      dueOn: due,
    ));
    widget.hrms.log(
      action: 'CREATE',
      entity: 'ReviewCycle',
      entityId: saved.id,
      summary: 'Opened review "${saved.name}" for ${employee.name}',
    );
    await _load();
    setState(() => page = 0);
    if (mounted) showToast(context, 'Review created.');
  }

  Future<void> _advance(ReviewCycle r) async {
    const order = ReviewStatus.values;
    final i = order.indexOf(r.status);
    if (i >= order.length - 1) {
      showToast(context, 'Review is already closed.');
      return;
    }
    final next = order[i + 1];

    double? rating;
    if (next == ReviewStatus.closed) {
      final values = await showFormDialog(
        context,
        title: 'Submit Review',
        subtitle: '${r.employeeName} · ${r.name}',
        submitLabel: 'Close review',
        fields: const [
          FormFieldSpec(
            label: 'Overall rating (1-5)',
            validator: validateDecimalRating,
            icon: Icons.star_outline,
            keyboardType: TextInputType.number,
          ),
        ],
      );
      if (values == null || !mounted) return;
      rating = double.tryParse(values['Overall rating (1-5)']!.trim());
      if (rating == null || rating < 1 || rating > 5) {
        showToast(context, 'Rating must be 1–5.', isError: true);
        return;
      }
    }

    final saved = await widget.hrms.repo.updateReview(
      r.copyWith(status: next, rating: rating),
    );
    widget.hrms.log(
      action: next == ReviewStatus.closed ? 'PUBLISH' : 'UPDATE',
      entity: 'ReviewCycle',
      entityId: saved.id,
      summary: next == ReviewStatus.closed
          ? 'Closed review for ${r.employeeName} — rating ${rating!.toStringAsFixed(1)}'
          : '${r.employeeName}\'s review → ${next.label}',
    );
    await _load();
    if (mounted) {
      showToast(
        context,
        next == ReviewStatus.closed
            ? 'Review closed.'
            : 'Review moved to ${next.label}.',
      );
    }
  }

  void _view(ReviewCycle r) => showDetailDialog(
        context,
        title: r.employeeName,
        subtitle: r.name,
        fields: {
          'Review ID': r.id.toUpperCase(),
          'Cycle': r.name,
          'Reviewer': r.reviewer,
          'Status': r.status.label,
          'Due': formatDate(r.dueOn),
          'Rating':
              r.rating == null ? 'Not yet rated' : r.rating!.toStringAsFixed(1),
        },
      );

  @override
  List<TableColumn<ReviewCycle>> get columns => [
        TableColumn(
          label: 'Employee',
          width: const FlexColumnWidth(1.8),
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
          label: 'Cycle',
          width: const FlexColumnWidth(1.4),
          sortBy: (r) => r.name,
          cell: (r) => hrmsMuted(r.name),
        ),
        TableColumn(
          label: 'Reviewer',
          width: const FlexColumnWidth(1.4),
          sortBy: (r) => r.reviewer,
          cell: (r) => hrmsMuted(r.reviewer),
        ),
        TableColumn(
          label: 'Due',
          width: const FlexColumnWidth(1),
          sortBy: (r) => r.dueOn.millisecondsSinceEpoch,
          cell: (r) => hrmsMuted(formatDate(r.dueOn)),
        ),
        TableColumn(
          label: 'Status',
          width: const FlexColumnWidth(1.2),
          sortBy: (r) => r.status.index,
          cell: (r) => Align(
            alignment: Alignment.centerLeft,
            child: StatusPill(label: r.status.label, color: r.status.color),
          ),
        ),
        TableColumn(
          label: 'Rating',
          width: const FlexColumnWidth(0.8),
          numeric: true,
          sortBy: (r) => r.rating ?? 0,
          cell: (r) => Align(
            alignment: Alignment.centerRight,
            child: hrmsMuted(
                r.rating == null ? '—' : r.rating!.toStringAsFixed(1)),
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
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              if (r.status != ReviewStatus.closed)
                IconButton(
                  onPressed: () => _advance(r),
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  tooltip: 'Advance stage',
                  color: kIndigo,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ),
      ];

  @override
  Widget cardBuilder(ReviewCycle r) => Container(
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
                '${r.name} · reviewer ${r.reviewer} · due ${formatDate(r.dueOn)}',
                style: const TextStyle(fontSize: 12.5, color: kMuted)),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                      onPressed: () => _view(r), child: const Text('View')),
                  if (r.status != ReviewStatus.closed)
                    TextButton(
                        onPressed: () => _advance(r),
                        child: const Text('Advance')),
                ],
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) =>
      HrmsListView<ReviewCycle>(delegate: this, state: this);
}
