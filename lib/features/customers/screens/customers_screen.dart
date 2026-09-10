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

/// Customer management: KPIs, an overview strip (top accounts and health),
/// then the searchable, filterable customer table.
class CustomersPage extends StatefulWidget {
  const CustomersPage({
    super.key,
    required this.customers,
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  final List<Customer> customers;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage>
    with ListViewState<CustomersPage, Customer> {
  late List<Customer> _customers = List.of(widget.customers);

  String? _industry;
  AccountStatus? _status;
  CustomerHealth? _health;

  @override
  void didUpdateWidget(CustomersPage old) {
    super.didUpdateWidget(old);
    if (widget.customers != old.customers) {
      _customers = List.of(widget.customers);
    }
  }

  @override
  List<Customer> get source => _customers;

  @override
  bool get hasActiveFilters =>
      _industry != null || _status != null || _health != null;

  @override
  bool matchesQuery(Customer c, String q) =>
      c.company.toLowerCase().contains(q) ||
      c.contact.toLowerCase().contains(q) ||
      c.email.toLowerCase().contains(q) ||
      c.manager.toLowerCase().contains(q);

  @override
  bool matchesFilters(Customer c) =>
      (_industry == null || c.industry == _industry) &&
      (_status == null || c.status == _status) &&
      (_health == null || c.health == _health);

  List<String> get _industries =>
      {for (final c in _customers) c.industry}.toList()..sort();

  Future<void> _add() async {
    final values = await showFormDialog(
      context,
      title: 'Add Customer',
      subtitle: 'Create a new customer account.',
      submitLabel: 'Create',
      fields: const [
        FormFieldSpec(label: 'Company', icon: Icons.business_outlined),
        FormFieldSpec(label: 'Primary contact', icon: Icons.person_outline),
        FormFieldSpec(
          label: 'Email address',
          icon: Icons.mail_outline,
          email: true,
          keyboardType: TextInputType.emailAddress,
        ),
        FormFieldSpec(label: 'Industry', icon: Icons.category_outlined),
        FormFieldSpec(
          label: 'Account manager',
          icon: Icons.support_agent_outlined,
        ),
      ],
    );
    if (values == null || !mounted) return;

    setState(() {
      _customers = [
        Customer(
          id: 'c-${2000 + _customers.length + 1}',
          company: values['Company']!,
          contact: values['Primary contact']!,
          email: values['Email address']!,
          industry: values['Industry']!,
          manager: values['Account manager']!,
          status: AccountStatus.pending,
          health: CustomerHealth.healthy,
          projects: 0,
          lastActivity: DateTime.now(),
          value: r'$0',
        ),
        ..._customers,
      ];
      page = 0;
    });
    if (mounted) showToast(context, '${values['Company']} created.');
  }

  Future<void> _edit(Customer c) async {
    final values = await showFormDialog(
      context,
      title: 'Edit Customer',
      subtitle: c.company,
      fields: [
        FormFieldSpec(
          label: 'Company',
          icon: Icons.business_outlined,
          initial: c.company,
        ),
        FormFieldSpec(
          label: 'Primary contact',
          icon: Icons.person_outline,
          initial: c.contact,
        ),
        FormFieldSpec(
          label: 'Email address',
          icon: Icons.mail_outline,
          initial: c.email,
          email: true,
          keyboardType: TextInputType.emailAddress,
        ),
        FormFieldSpec(
          label: 'Industry',
          icon: Icons.category_outlined,
          initial: c.industry,
        ),
        FormFieldSpec(
          label: 'Account manager',
          icon: Icons.support_agent_outlined,
          initial: c.manager,
        ),
      ],
    );
    if (values == null || !mounted) return;

    setState(() {
      _customers = [
        for (final row in _customers)
          if (row.id == c.id)
            Customer(
              id: row.id,
              company: values['Company']!,
              contact: values['Primary contact']!,
              email: values['Email address']!,
              industry: values['Industry']!,
              manager: values['Account manager']!,
              status: row.status,
              health: row.health,
              projects: row.projects,
              lastActivity: row.lastActivity,
              value: row.value,
            )
          else
            row,
      ];
    });
    if (mounted) showToast(context, '${values['Company']} updated.');
  }

  Future<void> _delete(Customer c) async {
    final ok = await confirm(
      context,
      title: 'Delete ${c.company}?',
      message: c.projects > 0
          ? '${c.company} has ${c.projects} active '
              '${c.projects == 1 ? 'project' : 'projects'}. Deleting the '
              'account also removes its project history.'
          : 'This permanently removes the customer account.',
    );
    if (!ok || !mounted) return;
    setState(() => _customers = [
          for (final row in _customers)
            if (row.id != c.id) row,
        ]);
    if (mounted) showToast(context, '${c.company} deleted.', isError: true);
  }

  void _view(Customer c) => showDetailDialog(
        context,
        title: c.company,
        subtitle: c.industry,
        leading: InitialsAvatar(name: c.company, radius: 22),
        fields: {
          'Account ID': c.id.toUpperCase(),
          'Primary contact': c.contact,
          'Email': c.email,
          'Industry': c.industry,
          'Account manager': c.manager,
          'Status': c.status.label,
          'Health': c.health.label,
          'Active projects': '${c.projects}',
          'Contract value': c.value,
          'Last activity': relativeTime(c.lastActivity),
        },
      );

  @override
  List<TableColumn<Customer>> get columns => [
        TableColumn(
          label: 'Customer',
          width: const FlexColumnWidth(2.2),
          sortBy: (c) => c.company,
          cell: (c) => Row(
            children: [
              InitialsAvatar(name: c.company),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      c.company,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: kInk,
                      ),
                    ),
                    Text(
                      c.email,
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
          label: 'Contact',
          width: const FlexColumnWidth(1.4),
          sortBy: (c) => c.contact,
          cell: (c) => _muted(c.contact),
        ),
        TableColumn(
          label: 'Industry',
          width: const FlexColumnWidth(1.4),
          sortBy: (c) => c.industry,
          cell: (c) => _muted(c.industry),
        ),
        TableColumn(
          label: 'Manager',
          width: const FlexColumnWidth(1.4),
          sortBy: (c) => c.manager,
          cell: (c) => _muted(c.manager),
        ),
        TableColumn(
          label: 'Health',
          width: const FlexColumnWidth(1.3),
          sortBy: (c) => c.health.index,
          cell: (c) => Align(
            alignment: Alignment.centerLeft,
            child: StatusPill(label: c.health.label, color: c.health.color),
          ),
        ),
        TableColumn(
          label: 'Projects',
          width: const FlexColumnWidth(.9),
          numeric: true,
          sortBy: (c) => c.projects,
          cell: (c) => Text(
            '${c.projects}',
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: kInk,
            ),
          ),
        ),
        TableColumn(
          label: 'Last activity',
          width: const FlexColumnWidth(1.3),
          sortBy: (c) => c.lastActivity.millisecondsSinceEpoch,
          cell: (c) => _muted(relativeTime(c.lastActivity)),
        ),
        TableColumn(
          label: 'Actions',
          width: const FixedColumnWidth(120),
          cell: (c) => RowActions(
            onView: () => _view(c),
            onEdit: () => _edit(c),
            onDelete: () => _delete(c),
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
        title: 'Customers',
        description: 'Accounts, contacts and engagement health.',
        kpis: const [],
        child: ErrorState(message: widget.error!, onRetry: widget.onRetry),
      );
    }
    if (widget.loading) return const DirectorySkeleton(title: 'Customers');

    final total = _customers.length;
    final active =
        _customers.where((c) => c.status == AccountStatus.active).length;
    final now = DateTime.now();
    // "New" = first seen in the last 30 days, approximated by recent activity
    // on an account with no delivery history yet.
    final fresh = _customers
        .where((c) =>
            c.projects <= 1 && now.difference(c.lastActivity).inDays <= 30)
        .length;
    final atRisk =
        _customers.where((c) => c.health == CustomerHealth.atRisk).length;

    // Top accounts by project count, for the overview strip.
    final top = [..._customers]
      ..sort((a, b) => b.projects.compareTo(a.projects));

    return DirectoryScaffold(
      title: 'Customers',
      description: 'Accounts, contacts and engagement health.',
      action: FilledButton.icon(
        onPressed: _add,
        icon: const Icon(Icons.add_business_outlined, size: 18),
        label: const Text('Add Customer'),
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
            label: 'Total Customers',
            value: '$total',
            icon: Icons.business_center_outlined,
            changePercent: 4.6,
            caption: 'All accounts on record',
          ),
        ),
        KpiCard(
          kpi: Kpi(
            label: 'Active Customers',
            value: '$active',
            icon: Icons.verified_outlined,
            changePercent: 2.8,
            caption: 'With a live contract',
          ),
        ),
        KpiCard(
          kpi: Kpi(
            label: 'New Customers',
            value: '$fresh',
            icon: Icons.auto_awesome_outlined,
            changePercent: 11.5,
            caption: 'Onboarded in 30 days',
          ),
        ),
        KpiCard(
          kpi: Kpi(
            label: 'At-Risk Customers',
            value: '$atRisk',
            icon: Icons.warning_amber_outlined,
            changePercent: -1.4,
            caption: 'Need account attention',
          ),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (top.isNotEmpty && top.first.projects > 0) ...[
            _TopAccounts(customers: top.take(4).toList()),
            const Divider(color: kBorder, height: 32),
          ],
          TableToolbar(
            search: SearchBox(
              hint: 'Search company, contact or manager',
              onChanged: setQuery,
            ),
            filters: [
              FilterDropdown<String>(
                label: 'industries',
                value: _industry,
                options: _industries,
                labelOf: (i) => i,
                onChanged: (v) => onFilterChanged(() => _industry = v),
              ),
              FilterDropdown<AccountStatus>(
                label: 'statuses',
                value: _status,
                options: AccountStatus.values,
                labelOf: (s) => s.label,
                onChanged: (v) => onFilterChanged(() => _status = v),
              ),
              FilterDropdown<CustomerHealth>(
                label: 'health',
                value: _health,
                options: CustomerHealth.values,
                labelOf: (h) => h.label,
                onChanged: (v) => onFilterChanged(() => _health = v),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (visible.isEmpty)
            EmptyState(
              icon: isFiltering ? Icons.search_off : Icons.business_outlined,
              title: isFiltering
                  ? 'No matching customers'
                  : 'No customers yet',
              message: isFiltering
                  ? 'Try a different search term or clear the filters.'
                  : 'Add your first customer account to start tracking work.',
              actionLabel: isFiltering ? null : 'Add Customer',
              onAction: isFiltering ? null : _add,
            )
          else ...[
            RecordTable<Customer>(
              rows: visible,
              columns: columns,
              sortColumn: sortColumn,
              ascending: ascending,
              onSort: toggleSort,
              minTableWidth: 1020,
              cardBuilder: (c) => _CustomerCard(
                customer: c,
                onView: () => _view(c),
                onEdit: () => _edit(c),
                onDelete: () => _delete(c),
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

/// Top accounts by active project count.
class _TopAccounts extends StatelessWidget {
  const _TopAccounts({required this.customers});

  final List<Customer> customers;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Top Accounts',
          subtitle: 'Your largest engagements by active project count.',
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, c) {
            const gap = 12.0;
            final columns = c.maxWidth >= 900
                ? 4
                : c.maxWidth >= 560
                    ? 2
                    : 1;
            final width = (c.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final customer in customers)
                  SizedBox(
                    width: width,
                    child: Container(
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
                            children: [
                              InitialsAvatar(name: customer.company, radius: 14),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  customer.company,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: kInk,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            customer.value,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: kInk,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${customer.projects} active '
                            '${customer.projects == 1 ? 'project' : 'projects'}',
                            style:
                                const TextStyle(fontSize: 12, color: kMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Mobile presentation of a customer row.
class _CustomerCard extends StatelessWidget {
  const _CustomerCard({
    required this.customer,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  final Customer customer;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
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
              InitialsAvatar(name: customer.company, radius: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.company,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: kInk,
                      ),
                    ),
                    Text(
                      '${customer.contact} · ${customer.industry}',
                      style: const TextStyle(fontSize: 12.5, color: kMuted),
                    ),
                  ],
                ),
              ),
              StatusPill(
                label: customer.health.label,
                color: customer.health.color,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${customer.projects} projects · ${customer.value} · '
            '${customer.manager}',
            style: const TextStyle(fontSize: 12.5, color: kMuted),
          ),
          const SizedBox(height: 2),
          Text(
            'Last activity ${relativeTime(customer.lastActivity)}',
            style: const TextStyle(fontSize: 12, color: kMuted),
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
