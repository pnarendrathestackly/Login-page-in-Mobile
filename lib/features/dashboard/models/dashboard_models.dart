import 'package:flutter/material.dart';

import '../../../main.dart';

/// Data the dashboard renders. These are the shapes a real API must return —
/// swap [DemoDashboardRepository] for an HTTP one and nothing in the UI moves.

enum Trend { up, down, flat }

class Kpi {
  const Kpi({
    required this.label,
    required this.value,
    required this.icon,
    required this.changePercent,
    required this.caption,
  });

  final String label;
  final String value;
  final IconData icon;

  /// Percentage change against the previous period. Null means "not a metric
  /// that trends" (system health), and the card hides the indicator.
  final double? changePercent;
  final String caption;

  Trend get trend => switch (changePercent) {
        null => Trend.flat,
        final c when c > 0 => Trend.up,
        final c when c < 0 => Trend.down,
        _ => Trend.flat,
      };
}

enum ChartRange {
  week('7 Days', 7),
  month('30 Days', 30),
  quarter('3 Months', 12),
  year('12 Months', 12);

  const ChartRange(this.label, this.points);
  final String label;
  final int points;
}

class ProjectStatus {
  const ProjectStatus._(this.label, this.color);

  static const active = ProjectStatus._('Active', kInfo);
  static const inProgress = ProjectStatus._('In Progress', kPurple);
  static const completed = ProjectStatus._('Completed', kSuccess);
  static const onHold = ProjectStatus._('On Hold', kNeutral);
  static const atRisk = ProjectStatus._('At Risk', kDanger);
  static const pending = ProjectStatus._('Pending', kWarning);
  static const blocked = ProjectStatus._('Blocked', kDanger);

  final String label;
  final Color color;
}

class Project {
  const Project({
    required this.name,
    required this.client,
    required this.owner,
    required this.status,
    required this.progress,
    required this.due,
  });

  final String name;
  final String client;
  final String owner;
  final ProjectStatus status;

  /// 0..1.
  final double progress;
  final DateTime due;
}

enum Priority {
  low('Low', kNeutral),
  medium('Medium', kInfo),
  high('High', kWarning),
  critical('Critical', kDanger);

  const Priority(this.label, this.color);
  final String label;
  final Color color;
}

enum TaskState {
  pending('Pending', kWarning),
  inProgress('In Progress', kPurple),
  completed('Completed', kSuccess),
  overdue('Overdue', kDanger);

  const TaskState(this.label, this.color);
  final String label;
  final Color color;
}

class Task {
  const Task({
    required this.name,
    required this.project,
    required this.priority,
    required this.assignee,
    required this.due,
    required this.state,
  });

  final String name;
  final String project;
  final Priority priority;
  final String assignee;
  final DateTime due;
  final TaskState state;
}

class Activity {
  const Activity({
    required this.description,
    required this.actor,
    required this.at,
    required this.icon,
  });

  final String description;
  final String actor;
  final DateTime at;
  final IconData icon;
}

enum ServiceState {
  operational('Operational', kSuccess),
  degraded('Degraded', kWarning),
  down('Down', kDanger),
  unknown('Unknown', kMuted);

  const ServiceState(this.label, this.color);
  final String label;
  final Color color;
}

class ServiceHealth {
  const ServiceHealth(this.name, this.state, {this.detail});
  final String name;
  final ServiceState state;
  final String? detail;
}

/// Notification categories, used by the notification centre's filter tabs.
enum NotificationKind {
  mention('Mentions'),
  task('Tasks'),
  project('Projects'),
  system('System');

  const NotificationKind(this.label);
  final String label;
}

class AppNotification {
  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.at,
    required this.icon,
    this.kind = NotificationKind.system,
    this.read = false,
  });

  final String id;
  final String title;
  final String body;
  final DateTime at;
  final IconData icon;
  final NotificationKind kind;
  bool read;
}

/// Everything the overview screen needs, fetched as one unit so the dashboard
/// makes a single round trip rather than one per section.
class DashboardData {
  const DashboardData({
    required this.kpis,
    required this.userActivity,
    required this.projectBreakdown,
    required this.activity,
    required this.projects,
    required this.tasks,
    required this.health,
  });

  final List<Kpi> kpis;

  /// (active, inactive) user counts per bucket, most recent last.
  final List<({String label, int active, int inactive})> userActivity;

  /// Project counts by status for the donut.
  final List<({ProjectStatus status, int count})> projectBreakdown;

  final List<Activity> activity;
  final List<Project> projects;
  final List<Task> tasks;
  final List<ServiceHealth> health;

  TaskTotals get taskTotals => tasks.totals;
}

typedef TaskTotals = ({
  int total,
  int completed,
  int inProgress,
  int pending,
  int overdue,
});

extension TaskListTotals on List<Task> {
  /// One pass over the list rather than five `where` scans.
  TaskTotals get totals {
    var completed = 0, inProgress = 0, pending = 0, overdue = 0;
    for (final t in this) {
      switch (t.state) {
        case TaskState.completed:
          completed++;
        case TaskState.inProgress:
          inProgress++;
        case TaskState.pending:
          pending++;
        case TaskState.overdue:
          overdue++;
      }
    }
    return (
      total: length,
      completed: completed,
      inProgress: inProgress,
      pending: pending,
      overdue: overdue,
    );
  }
}

/// Series for the business performance chart, keyed by the selected range so
/// switching ranges does not refetch the whole dashboard.
class PerformanceSeries {
  const PerformanceSeries({required this.labels, required this.values});
  final List<String> labels;
  final List<double> values;
}

// ---------------------------------------------------------------------------
// Directory models — the entities the Users / Customers / Projects / Tasks
// pages list. Same contract style as the overview models above: these are the
// shapes a real API must return.
// ---------------------------------------------------------------------------

enum AccountStatus {
  active('Active', kSuccess),
  inactive('Inactive', kNeutral),
  pending('Pending', kWarning),
  suspended('Suspended', kDanger);

  const AccountStatus(this.label, this.color);
  final String label;
  final Color color;
}

class Member {
  const Member({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.department,
    required this.status,
    required this.lastActive,
    required this.joined,
  });

  final String id;
  final String name;
  final String email;
  final String role;
  final String department;
  final AccountStatus status;
  final DateTime lastActive;
  final DateTime joined;
}

enum CustomerHealth {
  healthy('Healthy', kSuccess),
  watch('Watch', kWarning),
  atRisk('At Risk', kDanger);

  const CustomerHealth(this.label, this.color);
  final String label;
  final Color color;
}

class Customer {
  const Customer({
    required this.id,
    required this.company,
    required this.contact,
    required this.email,
    required this.industry,
    required this.manager,
    required this.status,
    required this.health,
    required this.projects,
    required this.lastActivity,
    required this.value,
  });

  final String id;
  final String company;
  final String contact;
  final String email;
  final String industry;

  /// Account manager responsible for this customer.
  final String manager;
  final AccountStatus status;
  final CustomerHealth health;
  final int projects;
  final DateTime lastActivity;

  /// Annual contract value, already formatted for display.
  final String value;
}

/// A richer project than the overview's [Project]: the Projects page shows
/// dates, team and priority that the dashboard summary has no room for.
class ProjectRecord {
  const ProjectRecord({
    required this.id,
    required this.name,
    required this.customer,
    required this.manager,
    required this.team,
    required this.start,
    required this.end,
    required this.progress,
    required this.priority,
    required this.status,
  });

  final String id;
  final String name;
  final String customer;
  final String manager;

  /// Team member names; the table shows a count plus initials.
  final List<String> team;
  final DateTime start;
  final DateTime end;

  /// 0..1.
  final double progress;
  final Priority priority;
  final ProjectStatus status;

  /// Past its end date without being complete.
  bool isDelayed(DateTime now) =>
      progress < 1 && end.isBefore(now) && status != ProjectStatus.completed;
}

/// Board state for the Tasks page. Wider than the overview's [TaskState],
/// which only needs the four summary buckets.
enum TaskStage {
  todo('To Do', kNeutral),
  inProgress('In Progress', kPurple),
  review('Review', kInfo),
  completed('Completed', kSuccess),
  blocked('Blocked', kDanger);

  const TaskStage(this.label, this.color);
  final String label;
  final Color color;
}

class TaskRecord {
  const TaskRecord({
    required this.id,
    required this.name,
    required this.project,
    required this.assignee,
    required this.priority,
    required this.stage,
    required this.due,
    required this.progress,
    required this.created,
  });

  final String id;
  final String name;
  final String project;
  final String assignee;
  final Priority priority;
  final TaskStage stage;
  final DateTime due;

  /// 0..1.
  final double progress;
  final DateTime created;

  /// Past due and not finished.
  bool isOverdue(DateTime now) =>
      stage != TaskStage.completed && due.isBefore(now);
}

/// A dated item on the overview's "Upcoming" list: a deadline, milestone or
/// scheduled activity.
enum UpcomingKind {
  deadline('Deadline', Icons.flag_outlined),
  milestone('Milestone', Icons.outlined_flag),
  task('Task', Icons.checklist_outlined),
  meeting('Meeting', Icons.event_outlined);

  const UpcomingKind(this.label, this.icon);
  final String label;
  final IconData icon;
}

class UpcomingItem {
  const UpcomingItem({
    required this.title,
    required this.context,
    required this.due,
    required this.kind,
    required this.priority,
  });

  final String title;

  /// What it belongs to — a project or customer name.
  final String context;
  final DateTime due;
  final UpcomingKind kind;
  final Priority priority;
}

/// Everything the Reports page charts.
class ReportsData {
  const ReportsData({
    required this.kpis,
    required this.revenue,
    required this.customerGrowth,
    required this.taskCompletion,
    required this.teamProductivity,
    required this.industryMix,
    required this.projectMix,
  });

  final List<Kpi> kpis;
  final PerformanceSeries revenue;
  final PerformanceSeries customerGrowth;

  /// Completed vs outstanding tasks per period.
  final List<({String label, int active, int inactive})> taskCompletion;

  /// Delivery throughput per team member.
  final List<({String name, int delivered, double utilisation})>
      teamProductivity;

  /// Customers per industry, for the distribution donut.
  final List<({ProjectStatus status, int count})> industryMix;

  /// Projects per status.
  final List<({ProjectStatus status, int count})> projectMix;
}
