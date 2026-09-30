import 'package:flutter/material.dart';

import '../../../main.dart';
import '../../../widgets/common/data_table.dart';
import '../../../widgets/common/parts.dart';
import '../hrms_controller.dart';
import '../models/hrms_models.dart';
import 'hrms_list_scaffold.dart';

/// HR Dashboard: KPIs and a recent-activity feed, all computed from the live
/// repository data (not hardcoded). Refreshes whenever the audit log changes.
class HrmsOverviewScreen extends StatefulWidget {
  const HrmsOverviewScreen({super.key, required this.hrms});

  final HrmsController hrms;

  @override
  State<HrmsOverviewScreen> createState() => _HrmsOverviewScreenState();
}

class _HrmsOverviewScreenState extends State<HrmsOverviewScreen> {
  bool _loading = true;
  String? _error;

  List<Employee> _employees = const [];
  List<LeaveRequest> _leave = const [];
  List<Candidate> _candidates = const [];
  List<HrAsset> _assets = const [];
  List<ReviewCycle> _reviews = const [];

  @override
  void initState() {
    super.initState();
    widget.hrms.audit.addListener(_onAudit);
    _load();
  }

  @override
  void dispose() {
    widget.hrms.audit.removeListener(_onAudit);
    super.dispose();
  }

  void _onAudit() {
    // A mutation elsewhere in HRMS — reload the counts.
    if (mounted) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await (
        widget.hrms.repo.employees(),
        widget.hrms.repo.leaveRequests(),
        widget.hrms.repo.candidates(),
        widget.hrms.repo.assets(),
        widget.hrms.repo.reviews(),
      ).wait;
      if (!mounted) return;
      setState(() {
        _employees = r.$1;
        _leave = r.$2;
        _candidates = r.$3;
        _assets = r.$4;
        _reviews = r.$5;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "We couldn't load the HR dashboard.";
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return DirectoryScaffold(
        title: 'HR Dashboard',
        description: 'Headline HR metrics for the organization.',
        kpis: const [],
        child: ErrorState(message: _error!, onRetry: _load),
      );
    }
    if (_loading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          Text('HR Dashboard',
              style: TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w800, color: kInk)),
          SizedBox(height: 20),
          SkeletonPanel(lines: 2, height: 120),
          SizedBox(height: 16),
          SkeletonPanel(lines: 6, height: 260),
        ],
      );
    }

    final active =
        _employees.where((e) => e.status == EmployeeStatus.active).length;
    final onLeave =
        _employees.where((e) => e.status == EmployeeStatus.onLeave).length;
    final pendingLeave =
        _leave.where((l) => l.status == RequestStatus.pending).length;
    final openReqs = _candidates
        .where((c) =>
            c.stage != CandidateStage.hired &&
            c.stage != CandidateStage.rejected)
        .length;
    final unassignedAssets = _assets
        .where((a) =>
            a.assignedTo.isEmpty && a.condition != AssetCondition.retired)
        .length;
    final openReviews =
        _reviews.where((r) => r.status != ReviewStatus.closed).length;

    return DirectoryScaffold(
      title: 'HR Dashboard',
      description: 'Headline HR metrics, calculated from live data.',
      kpis: [
        hrmsKpi('Headcount', '${_employees.length}', Icons.groups_outlined,
            '$active active · $onLeave on leave'),
        hrmsKpi('Pending Leave', '$pendingLeave',
            Icons.pending_actions_outlined, 'Awaiting approval'),
        hrmsKpi('Open Requisitions', '$openReqs', Icons.work_outline,
            'Candidates in pipeline'),
        hrmsKpi('Reviews In Flight', '$openReviews', Icons.rate_review_outlined,
            'Not yet closed'),
        hrmsKpi('Unassigned Assets', '$unassignedAssets',
            Icons.inventory_outlined, 'Available to allocate'),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(title: 'Recent HR activity'),
          const SizedBox(height: 8),
          AnimatedBuilder(
            animation: widget.hrms.audit,
            builder: (context, _) {
              final entries = widget.hrms.audit.entries;
              if (entries.isEmpty) {
                return const EmptyState(
                  icon: Icons.history_outlined,
                  title: 'No activity yet this session',
                  message: 'Actions across HRMS — creates, approvals, status '
                      'changes — are logged here.',
                );
              }
              return Column(
                children: [
                  for (final e in entries.take(15))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            margin: const EdgeInsets.only(right: 10, top: 1),
                            decoration: BoxDecoration(
                              color: kIndigo.withValues(alpha: .10),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(e.action,
                                style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: kIndigo)),
                          ),
                          Expanded(
                            child: Text(e.summary,
                                style:
                                    const TextStyle(fontSize: 13, color: kInk)),
                          ),
                          const SizedBox(width: 10),
                          Text(relativeTime(e.at),
                              style: const TextStyle(
                                  fontSize: 11.5, color: kMuted)),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
