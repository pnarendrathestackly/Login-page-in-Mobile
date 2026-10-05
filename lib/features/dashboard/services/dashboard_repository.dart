import 'dart:math';

import 'package:flutter/material.dart';

import './demo_data.dart';
import '../models/dashboard_models.dart';

/// The seam a real backend plugs into, mirroring `AuthBackend` in auth.dart.
///
/// Every method is what a server would expose over HTTP. Implement this
/// against your API and no widget below changes.
abstract class DashboardRepository {
  /// One round trip for the whole overview.
  Future<DashboardData> load();

  /// Separate from [load] so changing the range does not refetch everything.
  Future<PerformanceSeries> performance(ChartRange range);

  Future<List<AppNotification>> notifications();

  /// Persists the read flag. [id] null means "all".
  Future<void> markRead({String? id});

  /// Removes one notification permanently.
  Future<void> deleteNotification(String id);

  // --- Directory pages ------------------------------------------------------
  // One call per page. Each returns the full collection; searching, filtering
  // and paging happen client-side because these sets are small. Swap these for
  // query-parameterised endpoints when the data outgrows that.

  Future<List<Member>> members();
  Future<List<Customer>> customers();
  Future<List<ProjectRecord>> projects();
  Future<List<TaskRecord>> tasks();

  /// Dated items for the overview's "Upcoming" panel.
  Future<List<UpcomingItem>> upcoming();

  /// Everything the Reports page charts.
  Future<ReportsData> reports();
}

/// DEMO DATA — not a real backend.
///
/// Everything below is generated on the client from a fixed seed so the UI has
/// something realistic to render. It is deliberately kept in this one class:
/// nothing else in the app fabricates numbers, so replacing this with an HTTP
/// repository removes all mock data at once.
///
/// The health checks in particular do NOT probe anything — they report a
/// static shape so the section's layout exists, and must be wired to real
/// health endpoints before they mean anything.
class DemoDashboardRepository implements DashboardRepository {
  DemoDashboardRepository({this.latency = const Duration(milliseconds: 700)});

  /// Fake network delay so skeleton loaders are visible. Tests pass zero.
  final Duration latency;

  final _rng = Random(42); // fixed seed: the demo looks the same every run
  final DateTime _now = DateTime.now();

  List<AppNotification>? _notifications;

  @override
  Future<DashboardData> load() async {
    await Future<void>.delayed(latency);
    return DashboardData(
      kpis: const [
        Kpi(
          label: 'Total Users',
          value: '12,847',
          icon: Icons.groups_outlined,
          changePercent: 8.2,
          caption: '11,873 last period',
        ),
        Kpi(
          label: 'Active Customers',
          value: '3,214',
          icon: Icons.business_center_outlined,
          changePercent: 4.6,
          caption: '3,073 last period',
        ),
        Kpi(
          label: 'Active Projects',
          value: '186',
          icon: Icons.folder_open_outlined,
          changePercent: 2.1,
          caption: '182 last period',
        ),
        Kpi(
          label: 'Pending Tasks',
          value: '429',
          icon: Icons.checklist_outlined,
          changePercent: -6.4,
          caption: '458 last period',
        ),
        Kpi(
          label: 'Revenue',
          value: r'$1.42M',
          icon: Icons.trending_up_outlined,
          changePercent: 12.9,
          caption: r'$1.26M last period',
        ),
        Kpi(
          label: 'Platform Health',
          value: 'Healthy',
          icon: Icons.monitor_heart_outlined,
          changePercent: null,
          caption: '99.98% availability',
        ),
      ],
      userActivity: [
        for (final (i, label)
            in const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].indexed)
          (
            label: label,
            active: 2400 + _rng.nextInt(900) - i * 40,
            inactive: 700 + _rng.nextInt(400),
          ),
      ],
      projectBreakdown: const [
        (status: ProjectStatus.completed, count: 74),
        (status: ProjectStatus.inProgress, count: 58),
        (status: ProjectStatus.pending, count: 31),
        (status: ProjectStatus.blocked, count: 9),
      ],
      activity: [
        Activity(
          description: 'created a new project — Atlas Migration',
          actor: 'Arun Kumar',
          at: _now.subtract(const Duration(minutes: 15)),
          icon: Icons.create_new_folder_outlined,
        ),
        Activity(
          description: 'completed Project Alpha onboarding task',
          actor: 'Priya Raman',
          at: _now.subtract(const Duration(hours: 1)),
          icon: Icons.task_alt_outlined,
        ),
        Activity(
          description: 'registered a new user account',
          actor: 'System',
          at: _now.subtract(const Duration(hours: 3)),
          icon: Icons.person_add_alt_outlined,
        ),
        Activity(
          description: 'created customer account — Northwind Ltd',
          actor: 'Meera Shah',
          at: _now.subtract(const Duration(hours: 5)),
          icon: Icons.business_outlined,
        ),
        Activity(
          description: "updated Dinesh's role to Administrator",
          actor: 'Vishnu Vardhan',
          at: _now.subtract(const Duration(hours: 9)),
          icon: Icons.admin_panel_settings_outlined,
        ),
        Activity(
          description: 'generated the Q3 revenue report',
          actor: 'Kavya Nair',
          at: _now.subtract(const Duration(days: 1)),
          icon: Icons.description_outlined,
        ),
        Activity(
          description: 'changed the SSO configuration',
          actor: 'Rahul Menon',
          at: _now.subtract(const Duration(days: 2)),
          icon: Icons.settings_suggest_outlined,
        ),
      ],
      projects: [
        Project(
          name: 'Atlas Migration',
          client: 'Northwind Ltd',
          owner: 'Arun Kumar',
          status: ProjectStatus.inProgress,
          progress: .68,
          due: _now.add(const Duration(days: 12)),
        ),
        Project(
          name: 'Customer Portal 2.0',
          client: 'Verdant Health',
          owner: 'Priya Raman',
          status: ProjectStatus.active,
          progress: .41,
          due: _now.add(const Duration(days: 26)),
        ),
        Project(
          name: 'Billing Consolidation',
          client: 'Kestrel Finance',
          owner: 'Meera Shah',
          status: ProjectStatus.atRisk,
          progress: .23,
          due: _now.add(const Duration(days: 5)),
        ),
        Project(
          name: 'Data Warehouse Refresh',
          client: 'Orion Logistics',
          owner: 'Rahul Menon',
          status: ProjectStatus.completed,
          progress: 1,
          due: _now.subtract(const Duration(days: 3)),
        ),
        Project(
          name: 'Mobile SDK Rollout',
          client: 'Solent Retail',
          owner: 'Kavya Nair',
          status: ProjectStatus.onHold,
          progress: .55,
          due: _now.add(const Duration(days: 40)),
        ),
      ],
      tasks: [
        Task(
          name: 'Finalize data migration plan',
          project: 'Atlas Migration',
          priority: Priority.critical,
          assignee: 'Arun Kumar',
          due: _now.add(const Duration(days: 2)),
          state: TaskState.inProgress,
        ),
        Task(
          name: 'Review Q3 access audit',
          project: 'Compliance',
          priority: Priority.high,
          assignee: 'Meera Shah',
          due: _now.subtract(const Duration(days: 1)),
          state: TaskState.overdue,
        ),
        Task(
          name: 'Ship portal design tokens',
          project: 'Customer Portal 2.0',
          priority: Priority.medium,
          assignee: 'Priya Raman',
          due: _now.add(const Duration(days: 6)),
          state: TaskState.pending,
        ),
        Task(
          name: 'Retire legacy billing jobs',
          project: 'Billing Consolidation',
          priority: Priority.high,
          assignee: 'Rahul Menon',
          due: _now.add(const Duration(days: 9)),
          state: TaskState.inProgress,
        ),
        Task(
          name: 'Publish SDK release notes',
          project: 'Mobile SDK Rollout',
          priority: Priority.low,
          assignee: 'Kavya Nair',
          due: _now.subtract(const Duration(days: 4)),
          state: TaskState.completed,
        ),
      ],
      // ponytail: static shape, not a real probe. Point each entry at the
      // matching health endpoint when one exists.
      health: const [
        ServiceHealth('API', ServiceState.operational, detail: '142ms p95'),
        ServiceHealth('Database', ServiceState.operational, detail: '11ms p95'),
        ServiceHealth('Authentication', ServiceState.operational,
            detail: 'No incidents'),
        ServiceHealth('Storage', ServiceState.operational, detail: '62% used'),
        ServiceHealth('Application', ServiceState.operational,
            detail: 'v1.0.0 stable'),
      ],
    );
  }

  @override
  Future<PerformanceSeries> performance(ChartRange range) async {
    await Future<void>.delayed(latency ~/ 2);
    // Deterministic per range so switching back and forth is stable.
    final rng = Random(range.index * 7 + 3);
    final labels = switch (range) {
      ChartRange.week => const [
          'Mon',
          'Tue',
          'Wed',
          'Thu',
          'Fri',
          'Sat',
          'Sun'
        ],
      ChartRange.month => [for (var i = 1; i <= 30; i += 1) '$i'],
      ChartRange.quarter => [for (var i = 1; i <= 12; i += 1) 'W$i'],
      ChartRange.year => const [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec'
        ],
    };
    var value = 60.0 + rng.nextInt(20);
    return PerformanceSeries(
      labels: labels,
      values: [
        for (var i = 0; i < labels.length; i++)
          value = (value + rng.nextDouble() * 18 - 7).clamp(20, 100),
      ],
    );
  }

  @override
  Future<List<AppNotification>> notifications() async {
    await Future<void>.delayed(latency ~/ 2);
    return _notifications ??= [
      AppNotification(
        id: 'n1',
        title: 'Billing Consolidation is at risk',
        body: 'Due in 5 days with 23% progress.',
        at: _now.subtract(const Duration(minutes: 8)),
        icon: Icons.warning_amber_outlined,
        kind: NotificationKind.project,
      ),
      AppNotification(
        id: 'n2',
        title: 'Access audit is overdue',
        body: 'Assigned to Meera Shah, due yesterday.',
        at: _now.subtract(const Duration(hours: 2)),
        icon: Icons.pending_actions_outlined,
        kind: NotificationKind.task,
      ),
      AppNotification(
        id: 'n3',
        title: 'New sign-in from a new device',
        body: 'Chrome on Windows — approved via two-step verification.',
        at: _now.subtract(const Duration(hours: 6)),
        icon: Icons.security_outlined,
        kind: NotificationKind.system,
      ),
      AppNotification(
        id: 'n4',
        title: 'Q3 revenue report is ready',
        body: 'Generated by Kavya Nair.',
        at: _now.subtract(const Duration(days: 1)),
        icon: Icons.description_outlined,
        kind: NotificationKind.system,
        read: true,
      ),
      AppNotification(
        id: 'n5',
        title: 'Priya Raman mentioned you',
        body: 'On "Atlas Migration": can you confirm the cutover window?',
        at: _now.subtract(const Duration(minutes: 40)),
        icon: Icons.alternate_email_outlined,
        kind: NotificationKind.mention,
      ),
      AppNotification(
        id: 'n6',
        title: 'Project Phoenix has reached 80% completion',
        body: 'Delivery is tracking ahead of the agreed schedule.',
        at: _now.subtract(const Duration(hours: 11)),
        icon: Icons.trending_up_outlined,
        kind: NotificationKind.project,
      ),
      AppNotification(
        id: 'n7',
        title: 'You have been assigned a high-priority task',
        body: '"Renegotiate Kestrel support SLA" is due tomorrow.',
        at: _now.subtract(const Duration(hours: 20)),
        icon: Icons.assignment_ind_outlined,
        kind: NotificationKind.task,
        read: true,
      ),
    ];
  }

  @override
  Future<void> markRead({String? id}) async {
    final list = _notifications;
    if (list == null) return;
    for (final n in list) {
      if (id == null || n.id == id) n.read = true;
    }
  }

  @override
  Future<void> deleteNotification(String id) async {
    _notifications?.removeWhere((n) => n.id == id);
  }

  // --- Directory pages ------------------------------------------------------
  // Cached after the first call: the demo dataset is dated relative to `_now`,
  // so regenerating it per call would make timestamps drift between screens.

  List<Member>? _members;
  List<Customer>? _customers;
  List<ProjectRecord>? _projects;
  List<TaskRecord>? _tasks;

  @override
  Future<List<Member>> members() async {
    await Future<void>.delayed(latency);
    return _members ??= DemoData.members(_now);
  }

  @override
  Future<List<Customer>> customers() async {
    await Future<void>.delayed(latency);
    return _customers ??= DemoData.customers(_now);
  }

  @override
  Future<List<ProjectRecord>> projects() async {
    await Future<void>.delayed(latency);
    return _projects ??= DemoData.projects(_now);
  }

  @override
  Future<List<TaskRecord>> tasks() async {
    await Future<void>.delayed(latency);
    return _tasks ??= DemoData.tasks(_now);
  }

  @override
  Future<List<UpcomingItem>> upcoming() async {
    await Future<void>.delayed(latency);
    return DemoData.upcoming(_now);
  }

  @override
  Future<ReportsData> reports() async {
    await Future<void>.delayed(latency);
    return DemoData.reports(_now);
  }
}
