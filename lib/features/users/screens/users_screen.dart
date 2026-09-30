import 'package:flutter/material.dart';

import '../../../main.dart';
import '../../../widgets/common/directory_skeleton.dart';
import '../../../widgets.dart';
import '../../../widgets/common/data_table.dart';
import '../../../widgets/common/dialogs.dart';
import '../../../widgets/common/list_view_state.dart';
import '../../dashboard/models/dashboard_models.dart';
import '../../../widgets/common/parts.dart';
import '../../../widgets/common/sections.dart';

/// User management: KPIs, search, role/status filters, sortable table with
/// paging, and the row actions (view, edit, activate/deactivate, delete).
class UsersPage extends StatefulWidget {
  const UsersPage({
    super.key,
    required this.members,
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  final List<Member> members;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage>
    with ListViewState<UsersPage, Member> {
  // Local working copy: edits and deletions apply here. A real backend would
  // persist them and the list would come back from the repository instead.
  late List<Member> _members = List.of(widget.members);

  String? _role;
  AccountStatus? _status;

  @override
  void didUpdateWidget(UsersPage old) {
    super.didUpdateWidget(old);
    if (widget.members != old.members) {
      _members = List.of(widget.members);
    }
  }

  @override
  List<Member> get source => _members;

  @override
  bool get hasActiveFilters => _role != null || _status != null;

  @override
  bool matchesQuery(Member m, String q) =>
      m.name.toLowerCase().contains(q) ||
      m.email.toLowerCase().contains(q) ||
      m.department.toLowerCase().contains(q);

  @override
  bool matchesFilters(Member m) =>
      (_role == null || m.role == _role) &&
      (_status == null || m.status == _status);

  List<String> get _roles =>
      {for (final m in _members) m.role}.toList()..sort();

  Future<void> _add() async {
    final values = await showFormDialog(
      context,
      title: 'Add User',
      subtitle: 'Invite a person to the workspace.',
      submitLabel: 'Send invite',
      fields: const [
        FormFieldSpec(label: 'Full name', icon: Icons.person_outline),
        FormFieldSpec(
          label: 'Email address',
          icon: Icons.mail_outline,
          email: true,
          keyboardType: TextInputType.emailAddress,
        ),
        FormFieldSpec(label: 'Role', icon: Icons.badge_outlined),
        FormFieldSpec(label: 'Department', icon: Icons.apartment_outlined),
      ],
    );
    if (values == null || !mounted) return;

    setState(() {
      _members = [
        Member(
          id: 'u-${1000 + _members.length + 1}',
          name: values['Full name']!,
          email: values['Email address']!,
          role: values['Role']!,
          department: values['Department']!,
          // Invited, not yet accepted.
          status: AccountStatus.pending,
          lastActive: DateTime.now(),
          joined: DateTime.now(),
        ),
        ..._members,
      ];
      page = 0;
    });
    if (mounted) {
      // No email service exists, so nothing is sent; say what did happen.
      showToast(
        context,
        '${values['Full name']} added as a pending user. Invitation emails '
        "aren't connected yet.",
      );
    }
  }

  Future<void> _edit(Member m) async {
    final values = await showFormDialog(
      context,
      title: 'Edit User',
      subtitle: m.email,
      fields: [
        FormFieldSpec(
          label: 'Full name',
          icon: Icons.person_outline,
          initial: m.name,
        ),
        FormFieldSpec(
          label: 'Email address',
          icon: Icons.mail_outline,
          initial: m.email,
          email: true,
          keyboardType: TextInputType.emailAddress,
        ),
        FormFieldSpec(
          label: 'Role',
          icon: Icons.badge_outlined,
          initial: m.role,
        ),
        FormFieldSpec(
          label: 'Department',
          icon: Icons.apartment_outlined,
          initial: m.department,
        ),
      ],
    );
    if (values == null || !mounted) return;

    setState(() {
      _members = [
        for (final row in _members)
          if (row.id == m.id)
            Member(
              id: row.id,
              name: values['Full name']!,
              email: values['Email address']!,
              role: values['Role']!,
              department: values['Department']!,
              status: row.status,
              lastActive: row.lastActive,
              joined: row.joined,
            )
          else
            row,
      ];
    });
    if (mounted) showToast(context, '${values['Full name']} updated.');
  }

  Future<void> _toggleActive(Member m) async {
    final deactivating = m.status == AccountStatus.active;
    if (deactivating) {
      final ok = await confirm(
        context,
        title: 'Deactivate ${m.name}?',
        message: 'They will lose access immediately. You can reactivate the '
            'account at any time.',
        confirmLabel: 'Deactivate',
      );
      if (!ok || !mounted) return;
    }
    setState(() {
      _members = [
        for (final row in _members)
          if (row.id == m.id)
            Member(
              id: row.id,
              name: row.name,
              email: row.email,
              role: row.role,
              department: row.department,
              status:
                  deactivating ? AccountStatus.inactive : AccountStatus.active,
              lastActive: row.lastActive,
              joined: row.joined,
            )
          else
            row,
      ];
    });
    if (mounted) {
      showToast(
        context,
        '${m.name} ${deactivating ? 'deactivated' : 'activated'}.',
      );
    }
  }

  Future<void> _delete(Member m) async {
    final ok = await confirm(
      context,
      title: 'Delete ${m.name}?',
      message: 'This permanently removes the account and cannot be undone.',
    );
    if (!ok || !mounted) return;
    setState(() => _members = [
          for (final row in _members)
            if (row.id != m.id) row,
        ]);
    if (mounted) showToast(context, '${m.name} deleted.', isError: true);
  }

  void _view(Member m) => showDetailDialog(
        context,
        title: m.name,
        subtitle: m.role,
        leading: InitialsAvatar(name: m.name, radius: 22),
        fields: {
          'Employee ID': m.id.toUpperCase(),
          'Email': m.email,
          'Role': m.role,
          'Department': m.department,
          'Status': m.status.label,
          'Last active': relativeTime(m.lastActive),
          'Joined': formatDate(m.joined),
        },
      );

  @override
  List<TableColumn<Member>> get columns => [
        TableColumn(
          label: 'User',
          width: const FlexColumnWidth(2.2),
          sortBy: (m) => m.name,
          cell: (m) => Row(
            children: [
              InitialsAvatar(name: m.name),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      m.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: kInk,
                      ),
                    ),
                    Text(
                      m.email,
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
          label: 'Role',
          width: const FlexColumnWidth(1.4),
          sortBy: (m) => m.role,
          cell: (m) => _muted(m.role),
        ),
        TableColumn(
          label: 'Department',
          width: const FlexColumnWidth(1.4),
          sortBy: (m) => m.department,
          cell: (m) => _muted(m.department),
        ),
        TableColumn(
          label: 'Status',
          width: const FlexColumnWidth(1.2),
          sortBy: (m) => m.status.index,
          cell: (m) => Align(
            alignment: Alignment.centerLeft,
            child: StatusPill(label: m.status.label, color: m.status.color),
          ),
        ),
        TableColumn(
          label: 'Last active',
          width: const FlexColumnWidth(1.4),
          sortBy: (m) => m.lastActive.millisecondsSinceEpoch,
          cell: (m) => _muted(relativeTime(m.lastActive)),
        ),
        TableColumn(
          label: 'Joined',
          width: const FlexColumnWidth(1.2),
          sortBy: (m) => m.joined.millisecondsSinceEpoch,
          cell: (m) => _muted(formatDate(m.joined)),
        ),
        TableColumn(
          label: 'Actions',
          width: const FixedColumnWidth(120),
          cell: (m) => RowActions(
            onView: () => _view(m),
            onEdit: () => _edit(m),
            onDelete: () => _delete(m),
            extra: [
              (
                label: m.status == AccountStatus.active
                    ? 'Deactivate'
                    : 'Activate',
                icon: m.status == AccountStatus.active
                    ? Icons.block_outlined
                    : Icons.check_circle_outline,
                onTap: () => _toggleActive(m),
              ),
            ],
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
        title: 'Users',
        description: 'Manage everyone with access to your workspace.',
        kpis: const [],
        child: ErrorState(message: widget.error!, onRetry: widget.onRetry),
      );
    }
    if (widget.loading) return const DirectorySkeleton(title: 'Users');

    final total = _members.length;
    final active =
        _members.where((m) => m.status == AccountStatus.active).length;
    final inactive = _members
        .where((m) =>
            m.status == AccountStatus.inactive ||
            m.status == AccountStatus.suspended)
        .length;
    final pending =
        _members.where((m) => m.status == AccountStatus.pending).length;

    return DirectoryScaffold(
      title: 'Users',
      description: 'Manage everyone with access to your workspace.',
      action: FilledButton.icon(
        onPressed: _add,
        icon: const Icon(Icons.person_add_alt, size: 18),
        label: const Text('Add User'),
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
            label: 'Total Users',
            value: '$total',
            icon: Icons.groups_outlined,
            changePercent: 6.4,
            caption: 'Across all departments',
          ),
        ),
        KpiCard(
          kpi: Kpi(
            label: 'Active Users',
            value: '$active',
            icon: Icons.check_circle_outline,
            changePercent: 3.2,
            caption: 'Signed in within 30 days',
          ),
        ),
        KpiCard(
          kpi: Kpi(
            label: 'Inactive Users',
            value: '$inactive',
            icon: Icons.pause_circle_outline,
            changePercent: -2.1,
            caption: 'Deactivated or suspended',
          ),
        ),
        KpiCard(
          kpi: Kpi(
            label: 'Pending Invitations',
            value: '$pending',
            icon: Icons.mark_email_unread_outlined,
            changePercent: null,
            caption: 'Awaiting acceptance',
          ),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TableToolbar(
            search: SearchBox(
              hint: 'Search name, email or department',
              onChanged: setQuery,
            ),
            filters: [
              FilterDropdown<String>(
                label: 'roles',
                value: _role,
                options: _roles,
                labelOf: (r) => r,
                onChanged: (v) => onFilterChanged(() => _role = v),
              ),
              FilterDropdown<AccountStatus>(
                label: 'statuses',
                value: _status,
                options: AccountStatus.values,
                labelOf: (s) => s.label,
                onChanged: (v) => onFilterChanged(() => _status = v),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (visible.isEmpty)
            EmptyState(
              icon: isFiltering ? Icons.search_off : Icons.group_add_outlined,
              title: isFiltering ? 'No matching users' : 'No users yet',
              message: isFiltering
                  ? 'Try a different search term or clear the filters.'
                  : 'Invite your first teammate to get started.',
              actionLabel: isFiltering ? null : 'Add User',
              onAction: isFiltering ? null : _add,
            )
          else ...[
            RecordTable<Member>(
              rows: visible,
              columns: columns,
              sortColumn: sortColumn,
              ascending: ascending,
              onSort: toggleSort,
              cardBuilder: (m) => _UserCard(
                member: m,
                onView: () => _view(m),
                onEdit: () => _edit(m),
                onDelete: () => _delete(m),
                onToggle: () => _toggleActive(m),
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

/// Mobile presentation of a user row.
class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.member,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  final Member member;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
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
              InitialsAvatar(name: member.name, radius: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: kInk,
                      ),
                    ),
                    Text(
                      member.email,
                      style: const TextStyle(fontSize: 12.5, color: kMuted),
                    ),
                  ],
                ),
              ),
              StatusPill(
                label: member.status.label,
                color: member.status.color,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${member.role} · ${member.department}',
            style: const TextStyle(fontSize: 12.5, color: kMuted),
          ),
          const SizedBox(height: 2),
          Text(
            'Active ${relativeTime(member.lastActive)} · joined '
            '${formatDate(member.joined)}',
            style: const TextStyle(fontSize: 12, color: kMuted),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: RowActions(
              onView: onView,
              onEdit: onEdit,
              onDelete: onDelete,
              extra: [
                (
                  label: member.status == AccountStatus.active
                      ? 'Deactivate'
                      : 'Activate',
                  icon: member.status == AccountStatus.active
                      ? Icons.block_outlined
                      : Icons.check_circle_outline,
                  onTap: onToggle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Loading state shaped like a directory page, so nothing jumps when the data
/// lands. Shared by all four list pages.
