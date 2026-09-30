import 'package:flutter/material.dart';

import '../../auth.dart';
import '../../main.dart';
import '../../motion.dart';
import './charts.dart';
import '../../features/dashboard/models/dashboard_models.dart';
import './parts.dart';

const _positive = kSuccess;
const _negative = kDanger;

/// "Welcome back, Vishnu" plus who and when. Everything here comes from the
/// authenticated session — nothing is hardcoded.
class WelcomeBanner extends StatelessWidget {
  const WelcomeBanner({super.key, required this.user, required this.now});

  final AuthUser user;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final firstName = user.name.trim().split(RegExp(r'\s+')).first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            'Welcome back, $firstName',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: kInk,
              height: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          "Here's what's happening across your organization today.",
          style: TextStyle(fontSize: 15, color: kMuted),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Meta(icon: Icons.event_outlined, text: formatLongDate(now)),
            _Meta(icon: Icons.badge_outlined, text: user.role),
            const _Meta(icon: Icons.apartment_outlined, text: 'TheStackly'),
          ],
        ),
      ],
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: kSurfaceElevated,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: kMuted),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 12.5, color: kInk)),
        ],
      ),
    );
  }
}

/// One KPI: icon, label, value, and the change against the previous period.
class KpiCard extends StatelessWidget {
  const KpiCard({super.key, required this.kpi});

  final Kpi kpi;

  @override
  Widget build(BuildContext context) {
    final change = kpi.changePercent;
    final color = switch (kpi.trend) {
      Trend.up => _positive,
      Trend.down => _negative,
      Trend.flat => kMuted,
    };
    return Semantics(
      label: change == null
          ? '${kpi.label}: ${kpi.value}. ${kpi.caption}'
          : '${kpi.label}: ${kpi.value}, '
              '${change >= 0 ? 'up' : 'down'} '
              '${change.abs().toStringAsFixed(1)} percent. ${kpi.caption}',
      excludeSemantics: true,
      child: HoverLift(
        borderRadius: BorderRadius.circular(16),
        child: Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: kIndigo.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(kpi.icon, size: 18, color: kIndigo),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      kpi.label.toUpperCase(),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .8,
                        color: kMuted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                kpi.value,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: kInk,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (change != null) ...[
                    Icon(
                      kpi.trend == Trend.up
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                      size: 14,
                      color: color,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${change.abs().toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      kpi.caption,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, color: kMuted),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Business performance, with the range filter that drives its own fetch.
class PerformancePanel extends StatelessWidget {
  const PerformancePanel({
    super.key,
    required this.range,
    required this.onRange,
    required this.series,
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  final ChartRange range;
  final ValueChanged<ChartRange> onRange;
  final PerformanceSeries? series;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final data = series;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Business Performance',
            subtitle: 'Indexed performance over the selected period.',
          ),
          const SizedBox(height: 14),
          // Scrolls horizontally on narrow screens rather than overflowing.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final r in ChartRange.values) ...[
                  _RangeChip(
                    label: r.label,
                    selected: r == range,
                    onTap: () => onRange(r),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (error != null)
            ErrorState(message: error!, onRetry: onRetry)
          else if (loading || data == null)
            const SizedBox(
              height: 240,
              child: Center(child: Skeleton(height: 200, radius: 12)),
            )
          else
            AreaChart(series: data, height: 240),
        ],
      ),
    );
  }
}

class _RangeChip extends StatelessWidget {
  const _RangeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? kIndigo.withValues(alpha: .10) : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: selected ? kIndigo : kBorder),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? kIndigo : kInk,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class UserActivityPanel extends StatelessWidget {
  const UserActivityPanel({super.key, required this.buckets});

  final List<({String label, int active, int inactive})> buckets;

  @override
  Widget build(BuildContext context) {
    final active = buckets.fold(0, (s, b) => s + b.active);
    final inactive = buckets.fold(0, (s, b) => s + b.inactive);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'User Activity',
            subtitle: 'Active against inactive users.',
          ),
          const SizedBox(height: 16),
          if (buckets.isEmpty)
            const EmptyState(
              icon: Icons.insights_outlined,
              title: 'No activity yet',
              message:
                  'User activity appears here once people start signing in.',
            )
          else ...[
            UserActivityChart(buckets: buckets),
            const SizedBox(height: 14),
            ChartLegend(
              entries: [
                (
                  label: 'Active',
                  color: UserActivityChart.activeColor,
                  value: '$active'
                ),
                (
                  label: 'Inactive',
                  color: UserActivityChart.inactiveColor,
                  value: '$inactive'
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class ProjectStatusPanel extends StatelessWidget {
  const ProjectStatusPanel({super.key, required this.slices});

  final List<({ProjectStatus status, int count})> slices;

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Project Status',
            subtitle: 'Breakdown across all projects.',
          ),
          const SizedBox(height: 16),
          if (slices.every((s) => s.count == 0))
            const EmptyState(
              icon: Icons.donut_large_outlined,
              title: 'Nothing to break down',
              message: 'Status appears here once projects exist.',
            )
          else ...[
            Center(child: DonutChart(slices: slices)),
            const SizedBox(height: 16),
            ChartLegend(
              entries: [
                for (final s in slices)
                  (
                    label: s.status.label,
                    color: s.status.color,
                    value: '${s.count}'
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class RecentActivityPanel extends StatelessWidget {
  const RecentActivityPanel(
      {super.key, required this.items, required this.now});

  final List<Activity> items;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Recent Activity',
            subtitle: 'The latest changes across your organization.',
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            const EmptyState(
              icon: Icons.history_outlined,
              title: 'No activity yet',
              message: 'Actions taken across the platform show up here.',
            )
          else
            for (final a in items.take(7))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: kIndigo.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(a.icon, size: 16, color: kIndigo),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: a.actor,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: kInk,
                                  ),
                                ),
                                TextSpan(text: ' ${a.description}'),
                              ],
                            ),
                            style: const TextStyle(
                              fontSize: 13.5,
                              color: kInk,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            relativeTime(a.at, now),
                            style: const TextStyle(fontSize: 12, color: kMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

/// Recent projects. A table on wide screens, stacked cards on narrow ones —
/// a squeezed 7-column table is unreadable on a phone.
class ProjectTable extends StatelessWidget {
  const ProjectTable({super.key, required this.projects, required this.onView});

  final List<Project> projects;
  final ValueChanged<Project> onView;

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Recent Projects',
            subtitle: 'Delivery status across active engagements.',
          ),
          const SizedBox(height: 16),
          if (projects.isEmpty)
            const EmptyState(
              icon: Icons.folder_open_outlined,
              title: 'No projects yet',
              message: 'Create your first project to start tracking progress.',
            )
          else
            LayoutBuilder(
              builder: (context, c) => c.maxWidth >= 720
                  ? _wideTable(context)
                  : Column(
                      children: [
                        for (final p in projects)
                          _ProjectCard(p, onView: onView),
                      ],
                    ),
            ),
        ],
      ),
    );
  }

  Widget _wideTable(BuildContext context) {
    const head = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: .6,
      color: kMuted,
    );
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2.2),
        1: FlexColumnWidth(1.6),
        2: FlexColumnWidth(1.4),
        3: FlexColumnWidth(1.3),
        4: FlexColumnWidth(1.6),
        5: FlexColumnWidth(1.3),
        6: FixedColumnWidth(96),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        const TableRow(
          children: [
            _Cell(child: Text('PROJECT', style: head)),
            _Cell(child: Text('CLIENT', style: head)),
            _Cell(child: Text('OWNER', style: head)),
            _Cell(child: Text('STATUS', style: head)),
            _Cell(child: Text('PROGRESS', style: head)),
            _Cell(child: Text('DUE', style: head)),
            _Cell(child: Text('ACTIONS', style: head)),
          ],
        ),
        for (final p in projects)
          TableRow(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: kBorder)),
            ),
            children: [
              _Cell(
                child: Text(
                  p.name,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: kInk,
                  ),
                ),
              ),
              _Cell(child: _muted(p.client)),
              _Cell(child: _muted(p.owner)),
              _Cell(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: StatusPill(
                    label: p.status.label,
                    color: p.status.color,
                  ),
                ),
              ),
              _Cell(child: ProgressBar(value: p.progress)),
              _Cell(child: _muted(formatDate(p.due))),
              _Cell(child: _ProjectActions(project: p, onView: onView)),
            ],
          ),
      ],
    );
  }

  static Widget _muted(String s) => Text(
        s,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13, color: kMuted),
      );
}

class _Cell extends StatelessWidget {
  const _Cell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        child: child,
      );
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard(this.project, {required this.onView});

  final Project project;
  final ValueChanged<Project> onView;

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
              Expanded(
                child: Text(
                  project.name,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: kInk,
                  ),
                ),
              ),
              StatusPill(
                label: project.status.label,
                color: project.status.color,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${project.client} · ${project.owner}',
            style: const TextStyle(fontSize: 12.5, color: kMuted),
          ),
          const SizedBox(height: 12),
          ProgressBar(value: project.progress),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Due ${formatDate(project.due)}',
                  style: const TextStyle(fontSize: 12.5, color: kMuted),
                ),
              ),
              _ProjectActions(project: project, onView: onView),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProjectActions extends StatelessWidget {
  const _ProjectActions({required this.project, required this.onView});

  final Project project;
  final ValueChanged<Project> onView;

  @override
  Widget build(BuildContext context) {
    // ponytail: View only. Edit/delete need endpoints this app does not have —
    // add them here once the projects API exists.
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: () => onView(project),
        style: TextButton.styleFrom(
          foregroundColor: kIndigo,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Semantics(
          label: 'View ${project.name}',
          child: const Text(
            'View',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key, required this.value});

  /// 0..1.
  final double value;

  @override
  Widget build(BuildContext context) {
    final pct = (value.clamp(0, 1) * 100).round();
    return Semantics(
      label: '$pct percent complete',
      excludeSemantics: true,
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              // Fills from empty on first show, then eases between values.
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: value.clamp(0, 1).toDouble()),
                duration: Motion.duration(context, Motion.complex),
                curve: Motion.standardCurve,
                builder: (_, v, __) => LinearProgressIndicator(
                  value: v,
                  minHeight: 6,
                  backgroundColor: kTrack,
                  valueColor: const AlwaysStoppedAnimation(kIndigo),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$pct%',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: kInk,
            ),
          ),
        ],
      ),
    );
  }
}

class TaskOverviewPanel extends StatelessWidget {
  const TaskOverviewPanel({super.key, required this.tasks});

  final List<Task> tasks;

  @override
  Widget build(BuildContext context) {
    final t = tasks.totals;

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Task Overview',
            subtitle: 'Workload across every active project.',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Tally('Total', t.total, kInk),
              _Tally('Completed', t.completed, TaskState.completed.color),
              _Tally('In Progress', t.inProgress, TaskState.inProgress.color),
              _Tally('Pending', t.pending, TaskState.pending.color),
              _Tally('Overdue', t.overdue, TaskState.overdue.color),
            ],
          ),
          const SizedBox(height: 18),
          if (tasks.isEmpty)
            const EmptyState(
              icon: Icons.checklist_outlined,
              title: 'No tasks yet',
              message: 'Create a task to start tracking work.',
            )
          else
            for (final task in tasks)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _TaskRow(task),
              ),
        ],
      ),
    );
  }
}

class _Tally extends StatelessWidget {
  const _Tally(this.label, this.count, this.color);
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: kInset,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(label, style: const TextStyle(fontSize: 12, color: kMuted)),
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow(this.task);
  final Task task;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
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
              Expanded(
                child: Text(
                  task.name,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: kInk,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              StatusPill(label: task.state.label, color: task.state.color),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusPill(
                  label: task.priority.label, color: task.priority.color),
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
                style: const TextStyle(fontSize: 12.5, color: kMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SystemHealthPanel extends StatelessWidget {
  const SystemHealthPanel({super.key, required this.services});

  final List<ServiceHealth> services;

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'System Health',
            // Says plainly that nothing is probed yet, rather than implying
            // these are live checks.
            subtitle: 'Reported status. Not wired to live health checks yet.',
          ),
          const SizedBox(height: 8),
          for (final s in services)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: s.state.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      s.name,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: kInk,
                      ),
                    ),
                  ),
                  if (s.detail != null) ...[
                    Flexible(
                      child: Text(
                        s.detail!,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: kMuted),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Text(
                    s.state.label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: s.state.color,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Quick actions. Each one navigates to a section that exists in this app —
/// nothing here promises a screen that is not there.
class QuickActions extends StatelessWidget {
  const QuickActions({super.key, required this.actions});

  final List<({String label, IconData icon, VoidCallback onTap})> actions;

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Quick Actions'),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final a in actions)
                OutlinedButton.icon(
                  onPressed: a.onTap,
                  icon: Icon(a.icon, size: 18),
                  label: Text(a.label),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kIndigo,
                    side: const BorderSide(color: kBorder),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Staggered entrance for a list of panels, using the app's Motion vocabulary.
class StaggeredColumn extends StatelessWidget {
  const StaggeredColumn({super.key, required this.children, this.gap = 16});

  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, child) in children.indexed) ...[
          if (i > 0) SizedBox(height: gap),
          FadeIn(delay: Motion.stagger * i, child: child),
        ],
      ],
    );
  }
}

/// Upcoming deadlines, milestones and scheduled activities, soonest first.
class UpcomingPanel extends StatelessWidget {
  const UpcomingPanel({
    super.key,
    required this.items,
    required this.now,
    required this.loading,
  });

  final List<UpcomingItem> items;
  final DateTime now;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final sorted = [...items]..sort((a, b) => a.due.compareTo(b.due));

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Upcoming',
            subtitle: 'Deadlines, milestones and scheduled activities.',
          ),
          const SizedBox(height: 8),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Column(
                children: [
                  Skeleton(height: 34, radius: 10),
                  SizedBox(height: 10),
                  Skeleton(height: 34, radius: 10),
                  SizedBox(height: 10),
                  Skeleton(height: 34, radius: 10),
                ],
              ),
            )
          else if (sorted.isEmpty)
            const EmptyState(
              icon: Icons.event_available_outlined,
              title: 'Nothing scheduled',
              message: 'Deadlines and milestones appear here as they are set.',
            )
          else
            for (final item in sorted.take(6))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: item.priority.color.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        item.kind.icon,
                        size: 16,
                        color: item.priority.color,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: kInk,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${item.kind.label} · ${item.context}',
                            style: const TextStyle(fontSize: 12, color: kMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _due(item.due, now),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            // Anything inside a week reads as urgent.
                            color: item.due.difference(now).inDays <= 7
                                ? item.priority.color
                                : kMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          formatDate(item.due),
                          style: const TextStyle(fontSize: 11.5, color: kMuted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  /// "in 3 days" / "today" / "overdue".
  static String _due(DateTime due, DateTime now) {
    final days = due.difference(now).inDays;
    if (days < 0) return 'overdue';
    if (days == 0) return 'today';
    if (days == 1) return 'tomorrow';
    return 'in $days days';
  }
}
