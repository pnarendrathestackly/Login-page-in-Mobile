import 'package:flutter/material.dart';

import '../../../main.dart';
import '../../../widgets.dart';
import '../../../widgets/common/charts.dart';
import '../../../widgets/common/data_table.dart';
import '../../dashboard/services/demo_data.dart';
import '../../dashboard/models/dashboard_models.dart';
import '../../../widgets/common/parts.dart';
import '../../../widgets/common/sections.dart';
import '../../../widgets/common/directory_skeleton.dart';
import '../../../widgets/common/file_export.dart';

/// Business intelligence: KPI strip, report controls, and seven analytics
/// panels built from the existing chart widgets.
class ReportsPage extends StatefulWidget {
  const ReportsPage({
    super.key,
    required this.data,
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  final ReportsData? data;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  ChartRange _range = ChartRange.year;
  String? _department;
  String? _customer;

  static const _departments = [
    'Delivery',
    'Engineering',
    'Customer Success',
    'Product',
    'Finance',
  ];

  static const _customers = [
    'Northwind Ltd',
    'Verdant Health',
    'Kestrel Finance',
    'Orion Logistics',
    'Halcyon Energy',
  ];

  /// Exports the figures this page is showing.
  void _export() {
    final d = widget.data;
    if (d == null) {
      showToast(context, 'The report is still loading.', isError: true);
      return;
    }
    exportCsv(
      context,
      fileName: 'report.csv',
      csv: csvOf([
        'section',
        'label',
        'value'
      ], [
        for (final k in d.kpis) ['KPI', k.label, k.value],
        for (var i = 0; i < d.revenue.labels.length; i++)
          ['Revenue', d.revenue.labels[i], d.revenue.values[i]],
        for (var i = 0; i < d.customerGrowth.labels.length; i++)
          [
            'Customer growth',
            d.customerGrowth.labels[i],
            d.customerGrowth.values[i]
          ],
        for (final t in d.taskCompletion)
          ['Tasks', t.label, '${t.active} done / ${t.inactive} open'],
        for (final p in d.teamProductivity)
          [
            'Team',
            p.name,
            '${p.delivered} delivered, '
                '${(p.utilisation * 100).round()}% utilized'
          ],
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.error != null) {
      return DirectoryScaffold(
        title: 'Reports & Analytics',
        description: 'Performance across revenue, delivery and people.',
        kpis: const [],
        child: ErrorState(message: widget.error!, onRetry: widget.onRetry),
      );
    }
    final data = widget.data;
    if (widget.loading || data == null) {
      return const DirectorySkeleton(title: 'Reports & Analytics');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 12,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  header: true,
                  child: const Text(
                    'Reports & Analytics',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: kInk,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Performance across revenue, delivery and people.',
                  style: TextStyle(fontSize: 14.5, color: kMuted),
                ),
              ],
            ),
            OutlinedButton.icon(
              onPressed: _export,
              icon: const Icon(Icons.download_outlined, size: 18),
              label: const Text('Export Report'),
              style: OutlinedButton.styleFrom(
                foregroundColor: kIndigo,
                side: const BorderSide(color: kBorder),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        KpiRow(cards: [for (final k in data.kpis) KpiCard(kpi: k)]),
        const SizedBox(height: 16),

        // --- Report controls -------------------------------------------------
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(
                title: 'Report Controls',
                subtitle: 'Narrow the reporting period and scope.',
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilterDropdown<ChartRange>(
                    label: 'periods',
                    value: _range,
                    options: ChartRange.values,
                    labelOf: (r) => r.label,
                    // Period always has a value; null falls back to 12 months.
                    onChanged: (v) =>
                        setState(() => _range = v ?? ChartRange.year),
                  ),
                  FilterDropdown<String>(
                    label: 'departments',
                    value: _department,
                    options: _departments,
                    labelOf: (d) => d,
                    onChanged: (v) => setState(() => _department = v),
                  ),
                  FilterDropdown<String>(
                    label: 'customers',
                    value: _customer,
                    options: _customers,
                    labelOf: (c) => c,
                    onChanged: (v) => setState(() => _customer = v),
                  ),
                ],
              ),
              if (_department != null || _customer != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.filter_alt_outlined,
                        size: 15, color: kMuted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Filtered by '
                        '${[
                          if (_department != null) _department,
                          if (_customer != null) _customer,
                        ].join(' · ')}',
                        style: const TextStyle(fontSize: 12.5, color: kMuted),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        _department = null;
                        _customer = null;
                      }),
                      style: TextButton.styleFrom(foregroundColor: kIndigo),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // --- Analytics panels ------------------------------------------------
        LayoutBuilder(
          builder: (context, c) {
            final twoUp = c.maxWidth >= 1000;

            final revenue = _ChartPanel(
              title: 'Revenue Performance',
              subtitle: 'Monthly recognized revenue, in thousands.',
              child: AreaChart(series: data.revenue, height: 240),
            );
            final growth = _ChartPanel(
              title: 'Customer Growth',
              subtitle: 'Total active customers over the period.',
              child: AreaChart(series: data.customerGrowth, height: 240),
            );
            final tasks = _ChartPanel(
              title: 'Task Completion Analysis',
              subtitle: 'Completed against outstanding, per week.',
              child: Column(
                children: [
                  UserActivityChart(buckets: data.taskCompletion, height: 200),
                  const SizedBox(height: 14),
                  const ChartLegend(
                    entries: [
                      (
                        label: 'Completed',
                        color: UserActivityChart.activeColor,
                        value: null
                      ),
                      (
                        label: 'Outstanding',
                        color: UserActivityChart.inactiveColor,
                        value: null
                      ),
                    ],
                  ),
                ],
              ),
            );
            final projects = _ChartPanel(
              title: 'Project Performance',
              subtitle: 'Distribution across delivery states.',
              child: Column(
                children: [
                  Center(child: DonutChart(slices: data.projectMix)),
                  const SizedBox(height: 16),
                  ChartLegend(
                    entries: [
                      for (final s in data.projectMix)
                        (
                          label: s.status.label,
                          color: s.status.color,
                          value: '${s.count}'
                        ),
                    ],
                  ),
                ],
              ),
            );
            final industries = _ChartPanel(
              title: 'Customer Distribution by Industry',
              subtitle: 'Where your accounts are concentrated.',
              child: Column(
                children: [
                  Center(child: DonutChart(slices: data.industryMix)),
                  const SizedBox(height: 16),
                  ChartLegend(
                    entries: [
                      for (final (i, s) in data.industryMix.indexed)
                        (
                          label: i < DemoData.industryLabels.length
                              ? DemoData.industryLabels[i]
                              : s.status.label,
                          color: s.status.color,
                          value: '${s.count}'
                        ),
                    ],
                  ),
                ],
              ),
            );
            final team = _ChartPanel(
              title: 'Team Productivity',
              subtitle: 'Items delivered and capacity used, this quarter.',
              child: Column(
                children: [
                  for (final member in data.teamProductivity)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(
                        children: [
                          InitialsAvatar(name: member.name, radius: 13),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 108,
                            child: Text(
                              member.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                color: kInk,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                              child: ProgressBar(value: member.utilisation)),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 62,
                            child: Text(
                              '${member.delivered} items',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 12,
                                color: kMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );

            if (!twoUp) {
              return StaggeredColumn(
                children: [revenue, growth, tasks, projects, industries, team],
              );
            }
            return Column(
              children: [
                _Row(left: revenue, right: growth),
                const SizedBox(height: 16),
                _Row(left: tasks, right: team),
                const SizedBox(height: 16),
                _Row(left: projects, right: industries),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Two panels side by side, top-aligned so a shorter one leaves no dead space.
class _Row extends StatelessWidget {
  const _Row({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 16),
        Expanded(child: right),
      ],
    );
  }
}

/// A titled analytics panel — the repeated shape on this page.
class _ChartPanel extends StatelessWidget {
  const _ChartPanel({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: title, subtitle: subtitle),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
