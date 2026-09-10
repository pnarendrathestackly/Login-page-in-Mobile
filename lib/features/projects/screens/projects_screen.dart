import 'package:flutter/material.dart';

import '../../../main.dart';
import '../../../widgets.dart';
import '../../../widgets/common/data_table.dart';
import '../../../widgets/common/dialogs.dart';
import '../../../widgets/common/list_view_state.dart';
import '../../dashboard/models/dashboard_models.dart';
import '../../../widgets/common/parts.dart';
import '../../../widgets/common/sections.dart';
import '../../../widgets/common/directory_skeleton.dart';

/// Project delivery: KPIs, filters by status/priority/customer, and a table
/// showing schedule, team and progress.
class ProjectsPage extends StatefulWidget {
  const ProjectsPage({
    super.key,
    required this.projects,
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  final List<ProjectRecord> projects;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  @override
  State<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage>
    with ListViewState<ProjectsPage, ProjectRecord> {
  late List<ProjectRecord> _projects = List.of(widget.projects);

  ProjectStatus? _status;
  Priority? _priority;
  String? _customer;

  @override
  void didUpdateWidget(ProjectsPage old) {
    super.didUpdateWidget(old);
    if (widget.projects != old.projects) {
      _projects = List.of(widget.projects);
    }
  }

  @override
  List<ProjectRecord> get source => _projects;

  @override
  bool get hasActiveFilters =>
      _status != null || _priority != null || _customer != null;

  @override
  bool matchesQuery(ProjectRecord p, String q) =>
      p.name.toLowerCase().contains(q) ||
      p.customer.toLowerCase().contains(q) ||
      p.manager.toLowerCase().contains(q);

  @override
  bool matchesFilters(ProjectRecord p) =>
      (_status == null || p.status.label == _status!.label) &&
      (_priority == null || p.priority == _priority) &&
      (_customer == null || p.customer == _customer);

  List<String> get _customers =>
      {for (final p in _projects) p.customer}.toList()..sort();

  /// The statuses this dataset actually uses, so the filter never offers an
  /// option that matches nothing.
  List<ProjectStatus> get _statuses {
    final seen = <String, ProjectStatus>{};
    for (final p in _projects) {
      seen[p.status.label] = p.status;
    }
    return seen.values.toList()
      ..sort((a, b) => a.label.compareTo(b.label));
  }

  Future<void> _add() async {
    final values = await showFormDialog(
      context,
      title: 'Create Project',
      subtitle: 'Set up a new delivery engagement.',
      submitLabel: 'Create',
      fields: const [
        FormFieldSpec(label: 'Project name', icon: Icons.folder_outlined),
        FormFieldSpec(label: 'Customer', icon: Icons.business_outlined),
        FormFieldSpec(
          label: 'Project manager',
          icon: Icons.person_outline,
        ),
      ],
    );
    if (values == null || !mounted) return;

    final now = DateTime.now();
    setState(() {
      _projects = [
        ProjectRecord(
          id: 'p-${3000 + _projects.length + 1}',
          name: values['Project name']!,
          customer: values['Customer']!,
          manager: values['Project manager']!,
          team: const [],
          start: now,
          end: now.add(const Duration(days: 90)),
          progress: 0,
          priority: Priority.medium,
          status: ProjectStatus.pending,
        ),
        ..._projects,
      ];
      page = 0;
    });
    if (mounted) showToast(context, '${values['Project name']} created.');
  }

  Future<void> _edit(ProjectRecord p) async {
    final values = await showFormDialog(
      context,
      title: 'Edit Project',
      subtitle: p.customer,
      fields: [
        FormFieldSpec(
          label: 'Project name',
          icon: Icons.folder_outlined,
          initial: p.name,
        ),
        FormFieldSpec(
          label: 'Customer',
          icon: Icons.business_outlined,
          initial: p.customer,
        ),
        FormFieldSpec(
          label: 'Project manager',
          icon: Icons.person_outline,
          initial: p.manager,
        ),
      ],
    );
    if (values == null || !mounted) return;

    setState(() {
      _projects = [
        for (final row in _projects)
          if (row.id == p.id)
            ProjectRecord(
              id: row.id,
              name: values['Project name']!,
              customer: values['Customer']!,
              manager: values['Project manager']!,
              team: row.team,
              start: row.start,
              end: row.end,
              progress: row.progress,
              priority: row.priority,
              status: row.status,
            )
          else
            row,
      ];
    });
    if (mounted) showToast(context, '${values['Project name']} updated.');
  }

  Future<void> _delete(ProjectRecord p) async {
    final ok = await confirm(
      context,
      title: 'Delete ${p.name}?',
      message: 'This removes the project and its task history permanently.',
    );
    if (!ok || !mounted) return;
    setState(() => _projects = [
          for (final row in _projects)
            if (row.id != p.id) row,
        ]);
    if (mounted) showToast(context, '${p.name} deleted.', isError: true);
  }

  void _view(ProjectRecord p) => showDetailDialog(
        context,
        title: p.name,
        subtitle: p.customer,
        fields: {
          'Project ID': p.id.toUpperCase(),
          'Customer': p.customer,
          'Project manager': p.manager,
          'Team': p.team.isEmpty ? 'Not yet assigned' : p.team.join(', '),
          'Start date': formatDate(p.start),
          'End date': formatDate(p.end),
          'Progress': '${(p.progress * 100).round()}%',
          'Priority': p.priority.label,
          'Status': p.status.label,
        },
      );

  @override
  List<TableColumn<ProjectRecord>> get columns => [
        TableColumn(
          label: 'Project',
          width: const FlexColumnWidth(2),
          sortBy: (p) => p.name,
          cell: (p) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                p.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: kInk,
                ),
              ),
              Text(
                p.customer,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: kMuted),
              ),
            ],
          ),
        ),
        TableColumn(
          label: 'Manager',
          width: const FlexColumnWidth(1.3),
          sortBy: (p) => p.manager,
          cell: (p) => _muted(p.manager),
        ),
        TableColumn(
          label: 'Team',
          width: const FlexColumnWidth(.9),
          sortBy: (p) => p.team.length,
          cell: (p) => _TeamCell(team: p.team),
        ),
        TableColumn(
          label: 'Timeline',
          width: const FlexColumnWidth(1.7),
          sortBy: (p) => p.end.millisecondsSinceEpoch,
          cell: (p) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _muted('${formatDate(p.start)} →'),
              Text(
                formatDate(p.end),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: TextStyle(
                  fontSize: 13,
                  // Overrunning end dates read as a warning, not neutral text.
                  color: p.isDelayed(DateTime.now())
                      ? const Color(0xFFDC2626)
                      : kMuted,
                  fontWeight: p.isDelayed(DateTime.now())
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        TableColumn(
          label: 'Progress',
          width: const FlexColumnWidth(1.5),
          sortBy: (p) => p.progress,
          cell: (p) => ProgressBar(value: p.progress),
        ),
        TableColumn(
          label: 'Priority',
          width: const FlexColumnWidth(1.1),
          sortBy: (p) => p.priority.index,
          cell: (p) => Align(
            alignment: Alignment.centerLeft,
            child: StatusPill(
              label: p.priority.label,
              color: p.priority.color,
            ),
          ),
        ),
        TableColumn(
          label: 'Status',
          width: const FlexColumnWidth(1.2),
          sortBy: (p) => p.status.label,
          cell: (p) => Align(
            alignment: Alignment.centerLeft,
            child: StatusPill(label: p.status.label, color: p.status.color),
          ),
        ),
        TableColumn(
          label: 'Actions',
          width: const FixedColumnWidth(120),
          cell: (p) => RowActions(
            onView: () => _view(p),
            onEdit: () => _edit(p),
            onDelete: () => _delete(p),
          ),
        ),
      ];

  static Widget _muted(String s) => Text(
        s,
        // One line: dates and names read as columns, not paragraphs.
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
        style: const TextStyle(fontSize: 13, color: kMuted),
      );

  @override
  Widget build(BuildContext context) {
    if (widget.error != null) {
      return DirectoryScaffold(
        title: 'Projects',
        description: 'Delivery status across every engagement.',
        kpis: const [],
        child: ErrorState(message: widget.error!, onRetry: widget.onRetry),
      );
    }
    if (widget.loading) return const DirectorySkeleton(title: 'Projects');

    final now = DateTime.now();
    final total = _projects.length;
    final active = _projects
        .where((p) =>
            p.status.label == ProjectStatus.active.label ||
            p.status.label == ProjectStatus.inProgress.label)
        .length;
    final completed = _projects
        .where((p) => p.status.label == ProjectStatus.completed.label)
        .length;
    final delayed = _projects.where((p) => p.isDelayed(now)).length;

    return DirectoryScaffold(
      title: 'Projects',
      description: 'Delivery status across every engagement.',
      action: FilledButton.icon(
        onPressed: _add,
        icon: const Icon(Icons.create_new_folder_outlined, size: 18),
        label: const Text('Create Project'),
        style: FilledButton.styleFrom(
          backgroundColor: kIndigo,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      kpis: [
        KpiCard(
          kpi: Kpi(
            label: 'Total Projects',
            value: '$total',
            icon: Icons.folder_open_outlined,
            changePercent: 2.1,
            caption: 'All engagements',
          ),
        ),
        KpiCard(
          kpi: Kpi(
            label: 'Active Projects',
            value: '$active',
            icon: Icons.play_circle_outline,
            changePercent: 5.3,
            caption: 'Currently in delivery',
          ),
        ),
        KpiCard(
          kpi: Kpi(
            label: 'Completed',
            value: '$completed',
            icon: Icons.check_circle_outline,
            changePercent: 8.7,
            caption: 'Delivered to date',
          ),
        ),
        KpiCard(
          kpi: Kpi(
            label: 'Delayed',
            value: '$delayed',
            icon: Icons.schedule_outlined,
            changePercent: -3.2,
            caption: 'Past their end date',
          ),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TableToolbar(
            search: SearchBox(
              hint: 'Search project, customer or manager',
              onChanged: setQuery,
            ),
            filters: [
              FilterDropdown<ProjectStatus>(
                label: 'statuses',
                value: _status,
                options: _statuses,
                labelOf: (s) => s.label,
                onChanged: (v) => onFilterChanged(() => _status = v),
              ),
              FilterDropdown<Priority>(
                label: 'priorities',
                value: _priority,
                options: Priority.values,
                labelOf: (p) => p.label,
                onChanged: (v) => onFilterChanged(() => _priority = v),
              ),
              FilterDropdown<String>(
                label: 'customers',
                value: _customer,
                options: _customers,
                labelOf: (c) => c,
                onChanged: (v) => onFilterChanged(() => _customer = v),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (visible.isEmpty)
            EmptyState(
              icon: isFiltering ? Icons.search_off : Icons.folder_open_outlined,
              title:
                  isFiltering ? 'No matching projects' : 'No projects yet',
              message: isFiltering
                  ? 'Try a different search term or clear the filters.'
                  : 'Create your first project to start tracking progress.',
              actionLabel: isFiltering ? null : 'Create Project',
              onAction: isFiltering ? null : _add,
            )
          else ...[
            RecordTable<ProjectRecord>(
              rows: visible,
              columns: columns,
              sortColumn: sortColumn,
              ascending: ascending,
              onSort: toggleSort,
              minTableWidth: 1080,
              cardBuilder: (p) => _ProjectCard(
                project: p,
                onView: () => _view(p),
                onEdit: () => _edit(p),
                onDelete: () => _delete(p),
              ),
            ),
            Pagination(
              page: page,
              pageCount: pageCount,
              total: filtered.length,
              onPage: setPage,
            ),
          ],
        ],
      ),
    );
  }
}

/// Overlapping initials, capped at three plus a "+n" chip.
class _TeamCell extends StatelessWidget {
  const _TeamCell({required this.team});

  final List<String> team;

  @override
  Widget build(BuildContext context) {
    if (team.isEmpty) {
      return const Text(
        'Unassigned',
        style: TextStyle(fontSize: 12.5, color: kMuted),
      );
    }
    final shown = team.take(3).toList();
    final extra = team.length - shown.length;
    const avatar = 26.0; // diameter incl. the white ring
    const step = 18.0; // visible slice of each overlapped avatar

    // Stack, not a Row of negative-offset Transforms: a Transform does not
    // reduce the width its parent measures, which overflows a narrow column.
    return Semantics(
      label: '${team.length} team members: ${team.join(', ')}',
      excludeSemantics: true,
      child: SizedBox(
        height: avatar,
        width: (shown.length - 1) * step + avatar + (extra > 0 ? 22 : 0),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (final (i, name) in shown.indexed)
              Positioned(
                left: i * step,
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  padding: const EdgeInsets.all(1.5),
                  child: InitialsAvatar(name: name, radius: 11.5),
                ),
              ),
            if (extra > 0)
              Positioned(
                left: (shown.length - 1) * step + avatar + 2,
                top: 5,
                child: Text(
                  '+$extra',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: kMuted,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Mobile presentation of a project row.
class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.project,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  final ProjectRecord project;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final delayed = project.isDelayed(DateTime.now());
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.name,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: kInk,
                      ),
                    ),
                    Text(
                      '${project.customer} · ${project.manager}',
                      style: const TextStyle(fontSize: 12.5, color: kMuted),
                    ),
                  ],
                ),
              ),
              StatusPill(
                label: project.status.label,
                color: project.status.color,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ProgressBar(value: project.progress),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusPill(
                label: project.priority.label,
                color: project.priority.color,
              ),
              Text(
                'Due ${formatDate(project.end)}',
                style: TextStyle(
                  fontSize: 12.5,
                  color: delayed ? const Color(0xFFDC2626) : kMuted,
                  fontWeight: delayed ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: RowActions(
              onView: onView,
              onEdit: onEdit,
              onDelete: onDelete,
            ),
          ),
        ],
      ),
    );
  }
}
