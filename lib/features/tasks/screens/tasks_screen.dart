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

/// Task management: KPI tallies, filters, and a table that flags overdue and
/// critical work.
class TasksPage extends StatefulWidget {
  const TasksPage({
    super.key,
    required this.tasks,
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  final List<TaskRecord> tasks;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage>
    with ListViewState<TasksPage, TaskRecord> {
  late List<TaskRecord> _tasks = List.of(widget.tasks);

  TaskStage? _stage;
  Priority? _priority;
  String? _assignee;

  /// Extra filter beyond the dropdowns: "overdue only".
  bool _overdueOnly = false;

  @override
  void didUpdateWidget(TasksPage old) {
    super.didUpdateWidget(old);
    if (widget.tasks != old.tasks) _tasks = List.of(widget.tasks);
  }

  @override
  List<TaskRecord> get source => _tasks;

  @override
  bool get hasActiveFilters =>
      _stage != null || _priority != null || _assignee != null || _overdueOnly;

  @override
  bool matchesQuery(TaskRecord t, String q) =>
      t.name.toLowerCase().contains(q) ||
      t.project.toLowerCase().contains(q) ||
      t.assignee.toLowerCase().contains(q);

  @override
  bool matchesFilters(TaskRecord t) =>
      (_stage == null || t.stage == _stage) &&
      (_priority == null || t.priority == _priority) &&
      (_assignee == null || t.assignee == _assignee) &&
      (!_overdueOnly || t.isOverdue(DateTime.now()));

  List<String> get _assignees =>
      {for (final t in _tasks) t.assignee}.toList()..sort();

  Future<void> _add() async {
    final values = await showFormDialog(
      context,
      title: 'Create Task',
      subtitle: 'Add a new item to the backlog.',
      submitLabel: 'Create',
      fields: const [
        FormFieldSpec(label: 'Task name', icon: Icons.checklist_outlined),
        FormFieldSpec(label: 'Project', icon: Icons.folder_outlined),
        FormFieldSpec(label: 'Assignee', icon: Icons.person_outline),
      ],
    );
    if (values == null || !mounted) return;

    final now = DateTime.now();
    setState(() {
      _tasks = [
        TaskRecord(
          id: 't-${4000 + _tasks.length + 1}',
          name: values['Task name']!,
          project: values['Project']!,
          assignee: values['Assignee']!,
          priority: Priority.medium,
          stage: TaskStage.todo,
          due: now.add(const Duration(days: 7)),
          progress: 0,
          created: now,
        ),
        ..._tasks,
      ];
      page = 0;
    });
    if (mounted) showToast(context, '${values['Task name']} created.');
  }

  Future<void> _edit(TaskRecord t) async {
    final values = await showFormDialog(
      context,
      title: 'Edit Task',
      subtitle: t.project,
      fields: [
        FormFieldSpec(
          label: 'Task name',
          icon: Icons.checklist_outlined,
          initial: t.name,
        ),
        FormFieldSpec(
          label: 'Project',
          icon: Icons.folder_outlined,
          initial: t.project,
        ),
        FormFieldSpec(
          label: 'Assignee',
          icon: Icons.person_outline,
          initial: t.assignee,
        ),
      ],
    );
    if (values == null || !mounted) return;

    setState(() {
      _tasks = [
        for (final row in _tasks)
          if (row.id == t.id)
            TaskRecord(
              id: row.id,
              name: values['Task name']!,
              project: values['Project']!,
              assignee: values['Assignee']!,
              priority: row.priority,
              stage: row.stage,
              due: row.due,
              progress: row.progress,
              created: row.created,
            )
          else
            row,
      ];
    });
    if (mounted) showToast(context, '${values['Task name']} updated.');
  }

  Future<void> _delete(TaskRecord t) async {
    final ok = await confirm(
      context,
      title: 'Delete this task?',
      message: '"${t.name}" will be removed permanently.',
    );
    if (!ok || !mounted) return;
    setState(() => _tasks = [
          for (final row in _tasks)
            if (row.id != t.id) row,
        ]);
    if (mounted) showToast(context, 'Task deleted.', isError: true);
  }

  /// Marks a task complete from the row menu — the one state change that is
  /// useful without a full editor.
  void _complete(TaskRecord t) {
    setState(() {
      _tasks = [
        for (final row in _tasks)
          if (row.id == t.id)
            TaskRecord(
              id: row.id,
              name: row.name,
              project: row.project,
              assignee: row.assignee,
              priority: row.priority,
              stage: TaskStage.completed,
              due: row.due,
              progress: 1,
              created: row.created,
            )
          else
            row,
      ];
    });
    showToast(context, '"${t.name}" marked complete.');
  }

  void _view(TaskRecord t) => showDetailDialog(
        context,
        title: t.name,
        subtitle: t.project,
        fields: {
          'Task ID': t.id.toUpperCase(),
          'Project': t.project,
          'Assignee': t.assignee,
          'Priority': t.priority.label,
          'Status': t.stage.label,
          'Progress': '${(t.progress * 100).round()}%',
          'Due date': formatDate(t.due),
          'Created': formatDate(t.created),
        },
      );

  @override
  List<TableColumn<TaskRecord>> get columns => [
        TableColumn(
          label: 'Task',
          width: const FlexColumnWidth(2.3),
          sortBy: (t) => t.name,
          cell: (t) => Row(
            children: [
              // Overdue work is flagged in the row itself, not only in a pill.
              if (t.isOverdue(DateTime.now()))
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Icon(
                    Icons.error_outline,
                    size: 15,
                    color: kDanger,
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      t.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: kInk,
                      ),
                    ),
                    Text(
                      t.project,
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
          label: 'Assignee',
          width: const FlexColumnWidth(1.5),
          sortBy: (t) => t.assignee,
          cell: (t) => Row(
            children: [
              InitialsAvatar(name: t.assignee, radius: 12),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t.assignee,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: kMuted),
                ),
              ),
            ],
          ),
        ),
        TableColumn(
          label: 'Priority',
          width: const FlexColumnWidth(1.1),
          sortBy: (t) => t.priority.index,
          cell: (t) => Align(
            alignment: Alignment.centerLeft,
            child: StatusPill(label: t.priority.label, color: t.priority.color),
          ),
        ),
        TableColumn(
          label: 'Status',
          width: const FlexColumnWidth(1.2),
          sortBy: (t) => t.stage.index,
          cell: (t) => Align(
            alignment: Alignment.centerLeft,
            child: StatusPill(label: t.stage.label, color: t.stage.color),
          ),
        ),
        TableColumn(
          label: 'Progress',
          width: const FlexColumnWidth(1.4),
          sortBy: (t) => t.progress,
          cell: (t) => ProgressBar(value: t.progress),
        ),
        TableColumn(
          label: 'Due',
          width: const FlexColumnWidth(1.1),
          sortBy: (t) => t.due.millisecondsSinceEpoch,
          cell: (t) {
            final overdue = t.isOverdue(DateTime.now());
            return Text(
              formatDate(t.due),
              style: TextStyle(
                fontSize: 13,
                color: overdue ? kDanger : kMuted,
                fontWeight: overdue ? FontWeight.w600 : FontWeight.w400,
              ),
            );
          },
        ),
        TableColumn(
          label: 'Actions',
          width: const FixedColumnWidth(120),
          cell: (t) => RowActions(
            onView: () => _view(t),
            onEdit: () => _edit(t),
            onDelete: () => _delete(t),
            extra: [
              if (t.stage != TaskStage.completed)
                (
                  label: 'Mark complete',
                  icon: Icons.task_alt_outlined,
                  onTap: () => _complete(t),
                ),
            ],
          ),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    if (widget.error != null) {
      return DirectoryScaffold(
        title: 'Tasks',
        description: 'Work in flight across every project.',
        kpis: const [],
        child: ErrorState(message: widget.error!, onRetry: widget.onRetry),
      );
    }
    if (widget.loading) return const DirectorySkeleton(title: 'Tasks');

    final now = DateTime.now();
    final total = _tasks.length;
    final todo = _tasks.where((t) => t.stage == TaskStage.todo).length;
    final inProgress =
        _tasks.where((t) => t.stage == TaskStage.inProgress).length;
    final completed =
        _tasks.where((t) => t.stage == TaskStage.completed).length;
    final overdue = _tasks.where((t) => t.isOverdue(now)).length;

    return DirectoryScaffold(
      title: 'Tasks',
      description: 'Work in flight across every project.',
      action: FilledButton.icon(
        onPressed: _add,
        icon: const Icon(Icons.add_task, size: 18),
        label: const Text('Create Task'),
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
            label: 'Total Tasks',
            value: '$total',
            icon: Icons.checklist_outlined,
            changePercent: null,
            caption: 'Across all projects',
          ),
        ),
        KpiCard(
          kpi: Kpi(
            label: 'To Do',
            value: '$todo',
            icon: Icons.inbox_outlined,
            changePercent: null,
            caption: 'Not yet started',
          ),
        ),
        KpiCard(
          kpi: Kpi(
            label: 'In Progress',
            value: '$inProgress',
            icon: Icons.play_circle_outline,
            changePercent: null,
            caption: 'Being worked on now',
          ),
        ),
        KpiCard(
          kpi: Kpi(
            label: 'Completed',
            value: '$completed',
            icon: Icons.task_alt_outlined,
            changePercent: null,
            caption: 'Closed this period',
          ),
        ),
        KpiCard(
          kpi: Kpi(
            label: 'Overdue',
            value: '$overdue',
            icon: Icons.error_outline,
            changePercent: null,
            caption: 'Past their due date',
          ),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TableToolbar(
            search: SearchBox(
              hint: 'Search task, project or assignee',
              onChanged: setQuery,
            ),
            filters: [
              FilterDropdown<TaskStage>(
                label: 'statuses',
                value: _stage,
                options: TaskStage.values,
                labelOf: (s) => s.label,
                onChanged: (v) => onFilterChanged(() => _stage = v),
              ),
              FilterDropdown<Priority>(
                label: 'priorities',
                value: _priority,
                options: Priority.values,
                labelOf: (p) => p.label,
                onChanged: (v) => onFilterChanged(() => _priority = v),
              ),
              FilterDropdown<String>(
                label: 'assignees',
                value: _assignee,
                options: _assignees,
                labelOf: (a) => a,
                onChanged: (v) => onFilterChanged(() => _assignee = v),
              ),
              FilterChip(
                label: const Text('Overdue only'),
                selected: _overdueOnly,
                showCheckmark: false,
                avatar: Icon(
                  Icons.error_outline,
                  size: 16,
                  color: _overdueOnly ? kIndigo : kMuted,
                ),
                labelStyle: TextStyle(
                  fontSize: 13.5,
                  color: _overdueOnly ? kIndigo : kInk,
                  fontWeight: _overdueOnly ? FontWeight.w600 : FontWeight.w400,
                ),
                backgroundColor: kFieldFill,
                selectedColor: kIndigo.withValues(alpha: .10),
                side: BorderSide(color: _overdueOnly ? kIndigo : kBorder),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
                onSelected: (v) => onFilterChanged(() => _overdueOnly = v),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (visible.isEmpty)
            EmptyState(
              icon: isFiltering ? Icons.search_off : Icons.checklist_outlined,
              title: isFiltering ? 'No matching tasks' : 'No tasks yet',
              message: isFiltering
                  ? 'Try a different search term or clear the filters.'
                  : 'Create a task to start tracking work.',
              actionLabel: isFiltering ? null : 'Create Task',
              onAction: isFiltering ? null : _add,
            )
          else ...[
            RecordTable<TaskRecord>(
              rows: visible,
              columns: columns,
              sortColumn: sortColumn,
              ascending: ascending,
              onSort: toggleSort,
              minTableWidth: 1020,
              cardBuilder: (t) => _TaskCard(
                task: t,
                onView: () => _view(t),
                onEdit: () => _edit(t),
                onDelete: () => _delete(t),
                onComplete:
                    t.stage == TaskStage.completed ? null : () => _complete(t),
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

/// Mobile presentation of a task row.
class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.onComplete,
  });

  final TaskRecord task;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context) {
    final overdue = task.isOverdue(DateTime.now());
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kInset,
        borderRadius: BorderRadius.circular(12),
        // Overdue rows carry a red edge so they stand out while scanning.
        border: Border.all(
          color: overdue ? kDanger.withValues(alpha: .4) : kBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (overdue)
                const Padding(
                  padding: EdgeInsets.only(right: 6, top: 2),
                  child: Icon(
                    Icons.error_outline,
                    size: 16,
                    color: kDanger,
                  ),
                ),
              Expanded(
                child: Text(
                  task.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: kInk,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              StatusPill(label: task.stage.label, color: task.stage.color),
            ],
          ),
          const SizedBox(height: 8),
          ProgressBar(value: task.progress),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusPill(
                label: task.priority.label,
                color: task.priority.color,
              ),
              Text(
                task.project,
                style: const TextStyle(fontSize: 12.5, color: kMuted),
              ),
              Text(
                '· ${task.assignee}',
                style: const TextStyle(fontSize: 12.5, color: kMuted),
              ),
              Text(
                '· due ${formatDate(task.due)}',
                style: TextStyle(
                  fontSize: 12.5,
                  color: overdue ? kDanger : kMuted,
                  fontWeight: overdue ? FontWeight.w600 : FontWeight.w400,
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
              extra: [
                if (onComplete != null)
                  (
                    label: 'Mark complete',
                    icon: Icons.task_alt_outlined,
                    onTap: onComplete!,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
