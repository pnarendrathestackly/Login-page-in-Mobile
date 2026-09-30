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

/// Recruitment: two tabs — Jobs and Candidates. Create a job, open/close it,
/// add a candidate against a job, advance a candidate through the pipeline
/// (applied → screening → interview → offer → hired), rate, reject. Hiring a
/// candidate creates an employee via the repository.
class RecruitmentScreen extends StatefulWidget {
  const RecruitmentScreen({super.key, required this.hrms});

  final HrmsController hrms;

  @override
  State<RecruitmentScreen> createState() => _RecruitmentScreenState();
}

class _RecruitmentScreenState extends State<RecruitmentScreen> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TabBar(
            labelColor: kIndigo,
            unselectedLabelColor: kMuted,
            indicatorColor: kIndigo,
            tabs: [Tab(text: 'Jobs'), Tab(text: 'Candidates')],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 1400,
            child: TabBarView(
              children: [
                _JobsTab(hrms: widget.hrms),
                _CandidatesTab(hrms: widget.hrms),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Jobs
// ---------------------------------------------------------------------------

class _JobsTab extends StatefulWidget {
  const _JobsTab({required this.hrms});
  final HrmsController hrms;
  @override
  State<_JobsTab> createState() => _JobsTabState();
}

class _JobsTabState extends State<_JobsTab>
    with ListViewState<_JobsTab, JobOpening>
    implements HrmsListDelegate<JobOpening> {
  List<JobOpening> _jobs = const [];
  bool _loading = true;
  String? _error;

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
      final list = await widget.hrms.repo.jobOpenings();
      if (!mounted) return;
      setState(() {
        _jobs = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "We couldn't load job openings.";
        _loading = false;
      });
    }
  }

  @override
  String get title => 'Job Openings';
  @override
  String get description => 'Roles the organization is hiring for.';
  @override
  List<JobOpening> get rows => _jobs;
  @override
  List<JobOpening> get source => _jobs;
  @override
  bool get loading => _loading;
  @override
  String? get error => _error;
  @override
  VoidCallback get onRetry => _load;
  @override
  String get searchHint => 'Search title, department or location';
  @override
  IconData get emptyIcon => Icons.work_outline;
  @override
  String? get emptyActionLabel => 'Create Job';
  @override
  VoidCallback? get onEmptyAction => _create;

  @override
  bool matchesQuery(JobOpening j, String q) =>
      j.title.toLowerCase().contains(q) ||
      j.department.toLowerCase().contains(q) ||
      j.location.toLowerCase().contains(q);

  @override
  List<Widget> filters() => const [];
  @override
  bool get hasActiveFilters => false;
  @override
  bool matchesFilters(JobOpening j) => true;

  @override
  List<Widget> kpis(List<JobOpening> rows) {
    final open = rows.where((j) => j.isOpen).length;
    final seats = rows.where((j) => j.isOpen).fold(0, (s, j) => s + j.openings);
    return [
      hrmsKpi('Jobs', '${rows.length}', Icons.work_outline, 'All postings'),
      hrmsKpi(
          'Open', '$open', Icons.lock_open_outlined, 'Accepting applicants'),
      hrmsKpi(
          'Seats', '$seats', Icons.event_seat_outlined, 'Positions to fill'),
      hrmsKpi('Closed', '${rows.length - open}', Icons.lock_outline,
          'No longer hiring'),
    ];
  }

  @override
  Widget? primaryAction() => hrmsAddButton('Create Job', _create);

  Future<void> _create() async {
    final values = await showFormDialog(
      context,
      title: 'Create Job',
      subtitle: 'Post a new opening.',
      submitLabel: 'Create',
      fields: const [
        FormFieldSpec(label: 'Title', icon: Icons.work_outline),
        FormFieldSpec(label: 'Department', icon: Icons.apartment_outlined),
        FormFieldSpec(label: 'Location', icon: Icons.place_outlined),
        FormFieldSpec(
          label: 'Openings',
          validator: validateOpenings,
          icon: Icons.numbers_outlined,
          keyboardType: TextInputType.number,
        ),
      ],
    );
    if (values == null || !mounted) return;
    final n = int.tryParse(values['Openings']!.trim());
    if (n == null || n < 1) {
      showToast(context, 'Openings must be a positive number.', isError: true);
      return;
    }
    final saved = await widget.hrms.repo.createJob(JobOpening(
      id: '',
      title: values['Title']!,
      department: values['Department']!,
      location: values['Location']!,
      openings: n,
      isOpen: true,
      postedOn: DateTime.now(),
    ));
    widget.hrms.log(
      action: 'CREATE',
      entity: 'JobOpening',
      entityId: saved.id,
      summary: 'Posted "${saved.title}" (${saved.department})',
    );
    await _load();
    setState(() => page = 0);
    if (mounted) showToast(context, 'Job posted.');
  }

  Future<void> _edit(JobOpening j) async {
    final values = await showFormDialog(
      context,
      title: 'Edit Job',
      subtitle: j.title,
      fields: [
        FormFieldSpec(
            label: 'Title', icon: Icons.work_outline, initial: j.title),
        FormFieldSpec(
            label: 'Department',
            icon: Icons.apartment_outlined,
            initial: j.department),
        FormFieldSpec(
            label: 'Location', icon: Icons.place_outlined, initial: j.location),
        FormFieldSpec(
          label: 'Openings',
          validator: validateOpenings,
          icon: Icons.numbers_outlined,
          initial: '${j.openings}',
          keyboardType: TextInputType.number,
        ),
      ],
    );
    if (values == null || !mounted) return;
    final n = int.tryParse(values['Openings']!.trim());
    if (n == null || n < 1) {
      showToast(context, 'Openings must be a positive number.', isError: true);
      return;
    }
    final saved = await widget.hrms.repo.updateJob(j.copyWith(
      title: values['Title'],
      department: values['Department'],
      location: values['Location'],
      openings: n,
    ));
    widget.hrms.log(
      action: 'UPDATE',
      entity: 'JobOpening',
      entityId: saved.id,
      summary: 'Updated "${saved.title}"',
    );
    await _load();
    if (mounted) showToast(context, 'Job updated.');
  }

  Future<void> _toggle(JobOpening j) async {
    final saved =
        await widget.hrms.repo.updateJob(j.copyWith(isOpen: !j.isOpen));
    widget.hrms.log(
      action: saved.isOpen ? 'ENABLE' : 'DISABLE',
      entity: 'JobOpening',
      entityId: saved.id,
      summary: '${saved.isOpen ? 'Reopened' : 'Closed'} "${saved.title}"',
    );
    await _load();
    if (mounted) {
      showToast(context, saved.isOpen ? 'Job reopened.' : 'Job closed.');
    }
  }

  void _view(JobOpening j) => showDetailDialog(
        context,
        title: j.title,
        subtitle: j.department,
        fields: {
          'Job ID': j.id.toUpperCase(),
          'Department': j.department,
          'Location': j.location,
          'Openings': '${j.openings}',
          'Status': j.isOpen ? 'Open' : 'Closed',
          'Posted': formatDate(j.postedOn),
        },
      );

  @override
  List<TableColumn<JobOpening>> get columns => [
        TableColumn(
          label: 'Title',
          width: const FlexColumnWidth(2),
          sortBy: (j) => j.title,
          cell: (j) => Text(j.title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w600, color: kInk)),
        ),
        TableColumn(
          label: 'Department',
          width: const FlexColumnWidth(1.2),
          sortBy: (j) => j.department,
          cell: (j) => hrmsMuted(j.department),
        ),
        TableColumn(
          label: 'Location',
          width: const FlexColumnWidth(1),
          sortBy: (j) => j.location,
          cell: (j) => hrmsMuted(j.location),
        ),
        TableColumn(
          label: 'Openings',
          width: const FlexColumnWidth(0.8),
          numeric: true,
          sortBy: (j) => j.openings,
          cell: (j) => Align(
              alignment: Alignment.centerRight,
              child: hrmsMuted('${j.openings}')),
        ),
        TableColumn(
          label: 'Status',
          width: const FlexColumnWidth(1),
          sortBy: (j) => j.isOpen ? 0 : 1,
          cell: (j) => Align(
            alignment: Alignment.centerLeft,
            child: StatusPill(
              label: j.isOpen ? 'Open' : 'Closed',
              color: j.isOpen ? kSuccess : kNeutral,
            ),
          ),
        ),
        TableColumn(
          label: 'Actions',
          width: const FixedColumnWidth(120),
          cell: (j) => RowActions(
            onView: () => _view(j),
            onEdit: () => _edit(j),
            onDelete: () => _toggle(j),
            extra: [
              (
                label: j.isOpen ? 'Close job' : 'Reopen job',
                icon: j.isOpen ? Icons.lock_outline : Icons.lock_open_outlined,
                onTap: () => _toggle(j),
              ),
            ],
          ),
        ),
      ];

  @override
  Widget cardBuilder(JobOpening j) => Container(
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
                Expanded(
                  child: Text(j.title,
                      style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: kInk)),
                ),
                StatusPill(
                  label: j.isOpen ? 'Open' : 'Closed',
                  color: j.isOpen ? kSuccess : kNeutral,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('${j.department} · ${j.location} · ${j.openings} seat(s)',
                style: const TextStyle(fontSize: 12.5, color: kMuted)),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                      onPressed: () => _view(j), child: const Text('View')),
                  TextButton(
                      onPressed: () => _edit(j), child: const Text('Edit')),
                  TextButton(
                      onPressed: () => _toggle(j),
                      child: Text(j.isOpen ? 'Close' : 'Reopen')),
                ],
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) =>
      HrmsListView<JobOpening>(delegate: this, state: this);
}

// ---------------------------------------------------------------------------
// Candidates
// ---------------------------------------------------------------------------

class _CandidatesTab extends StatefulWidget {
  const _CandidatesTab({required this.hrms});
  final HrmsController hrms;
  @override
  State<_CandidatesTab> createState() => _CandidatesTabState();
}

class _CandidatesTabState extends State<_CandidatesTab>
    with ListViewState<_CandidatesTab, Candidate>
    implements HrmsListDelegate<Candidate> {
  List<Candidate> _candidates = const [];
  List<JobOpening> _jobs = const [];
  bool _loading = true;
  String? _error;
  CandidateStage? _stage;

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
        widget.hrms.repo.candidates(),
        widget.hrms.repo.jobOpenings(),
      ).wait;
      if (!mounted) return;
      setState(() {
        _candidates = r.$1;
        _jobs = r.$2;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "We couldn't load candidates.";
        _loading = false;
      });
    }
  }

  @override
  String get title => 'Candidates';
  @override
  String get description => 'Applicants moving through the hiring pipeline.';
  @override
  List<Candidate> get rows => _candidates;
  @override
  List<Candidate> get source => _candidates;
  @override
  bool get loading => _loading;
  @override
  String? get error => _error;
  @override
  VoidCallback get onRetry => _load;
  @override
  String get searchHint => 'Search name, email or role';
  @override
  IconData get emptyIcon => Icons.people_alt_outlined;
  @override
  String? get emptyActionLabel => 'Add Candidate';
  @override
  VoidCallback? get onEmptyAction => _add;

  @override
  bool get hasActiveFilters => _stage != null;
  @override
  bool matchesQuery(Candidate c, String q) =>
      c.name.toLowerCase().contains(q) ||
      c.email.toLowerCase().contains(q) ||
      c.jobTitle.toLowerCase().contains(q);
  @override
  bool matchesFilters(Candidate c) => _stage == null || c.stage == _stage;

  @override
  List<Widget> filters() => [
        FilterDropdown<CandidateStage>(
          label: 'stages',
          value: _stage,
          options: CandidateStage.values,
          labelOf: (s) => s.label,
          onChanged: (v) => onFilterChanged(() => _stage = v),
        ),
      ];

  @override
  List<Widget> kpis(List<Candidate> rows) {
    final active = rows
        .where((c) =>
            c.stage != CandidateStage.hired &&
            c.stage != CandidateStage.rejected)
        .length;
    final offers = rows.where((c) => c.stage == CandidateStage.offer).length;
    final hired = rows.where((c) => c.stage == CandidateStage.hired).length;
    return [
      hrmsKpi('Candidates', '${rows.length}', Icons.people_alt_outlined,
          'All applicants'),
      hrmsKpi(
          'In Pipeline', '$active', Icons.timeline_outlined, 'Not yet decided'),
      hrmsKpi('Offers Out', '$offers', Icons.mark_email_read_outlined,
          'Awaiting acceptance'),
      hrmsKpi('Hired', '$hired', Icons.how_to_reg_outlined,
          'Converted to employees'),
    ];
  }

  @override
  Widget? primaryAction() => hrmsAddButton('Add Candidate', _add);

  Future<void> _add() async {
    final openJobs = _jobs.where((j) => j.isOpen).toList();
    if (openJobs.isEmpty) {
      showToast(context, 'Create an open job first.', isError: true);
      return;
    }
    final job = await showModalBottomSheet<JobOpening>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final j in openJobs)
              ListTile(
                title: Text(j.title),
                subtitle: Text('${j.department} · ${j.location}'),
                onTap: () => Navigator.of(context).pop(j),
              ),
          ],
        ),
      ),
    );
    if (job == null || !mounted) return;

    final values = await showFormDialog(
      context,
      title: 'Add Candidate',
      subtitle: 'Applying for ${job.title}',
      submitLabel: 'Add',
      fields: const [
        FormFieldSpec(label: 'Full name', icon: Icons.person_outline),
        FormFieldSpec(
          label: 'Email address',
          icon: Icons.mail_outline,
          email: true,
          keyboardType: TextInputType.emailAddress,
        ),
      ],
    );
    if (values == null || !mounted) return;

    final saved = await widget.hrms.repo.createCandidate(Candidate(
      id: '',
      name: values['Full name']!,
      email: values['Email address']!,
      jobId: job.id,
      jobTitle: job.title,
      stage: CandidateStage.applied,
      appliedOn: DateTime.now(),
    ));
    widget.hrms.log(
      action: 'CREATE',
      entity: 'Candidate',
      entityId: saved.id,
      summary: '${saved.name} applied for ${job.title}',
    );
    await _load();
    setState(() => page = 0);
    if (mounted) showToast(context, 'Candidate added.');
  }

  Future<void> _advance(Candidate c) async {
    final next = c.stage.next;
    if (next == null) {
      showToast(context, '${c.name} is already ${c.stage.label}.');
      return;
    }
    final saved =
        await widget.hrms.repo.updateCandidate(c.copyWith(stage: next));
    widget.hrms.log(
      action: next == CandidateStage.hired ? 'ASSIGN' : 'UPDATE',
      entity: 'Candidate',
      entityId: saved.id,
      summary: next == CandidateStage.hired
          ? 'Hired ${c.name} — created employee record'
          : '${c.name} advanced to ${next.label}',
    );
    await _load();
    if (mounted) {
      showToast(
        context,
        next == CandidateStage.hired
            ? '${c.name} hired — added as an employee.'
            : '${c.name} moved to ${next.label}.',
      );
    }
  }

  Future<void> _reject(Candidate c) async {
    if (c.stage == CandidateStage.rejected || c.stage == CandidateStage.hired) {
      return;
    }
    final ok = await confirm(
      context,
      title: 'Reject ${c.name}?',
      message: 'They will be moved to the Rejected stage.',
      confirmLabel: 'Reject',
    );
    if (!ok || !mounted) return;
    final saved = await widget.hrms.repo
        .updateCandidate(c.copyWith(stage: CandidateStage.rejected));
    widget.hrms.log(
      action: 'REJECT',
      entity: 'Candidate',
      entityId: saved.id,
      summary: 'Rejected ${c.name} for ${c.jobTitle}',
    );
    await _load();
    if (mounted) showToast(context, '${c.name} rejected.', isError: true);
  }

  Future<void> _rate(Candidate c) async {
    final values = await showFormDialog(
      context,
      title: 'Record Feedback',
      subtitle: c.name,
      submitLabel: 'Save rating',
      fields: [
        FormFieldSpec(
          label: 'Rating (1-5)',
          validator: validateRating,
          icon: Icons.star_outline,
          initial: c.rating == 0 ? '' : '${c.rating}',
          keyboardType: TextInputType.number,
        ),
      ],
    );
    if (values == null || !mounted) return;
    final r = int.tryParse(values['Rating (1-5)']!.trim());
    if (r == null || r < 1 || r > 5) {
      showToast(context, 'Rating must be 1–5.', isError: true);
      return;
    }
    final saved = await widget.hrms.repo.updateCandidate(c.copyWith(rating: r));
    widget.hrms.log(
      action: 'UPDATE',
      entity: 'Candidate',
      entityId: saved.id,
      summary: 'Rated ${c.name} $r/5',
    );
    await _load();
    if (mounted) showToast(context, 'Feedback saved.');
  }

  void _view(Candidate c) => showDetailDialog(
        context,
        title: c.name,
        subtitle: c.jobTitle,
        leading: InitialsAvatar(name: c.name, radius: 22),
        fields: {
          'Candidate ID': c.id.toUpperCase(),
          'Email': c.email,
          'Applying for': c.jobTitle,
          'Stage': c.stage.label,
          'Rating': c.rating == 0 ? 'Not rated' : '${c.rating}/5',
          'Applied': formatDate(c.appliedOn),
        },
      );

  @override
  List<TableColumn<Candidate>> get columns => [
        TableColumn(
          label: 'Candidate',
          width: const FlexColumnWidth(2),
          sortBy: (c) => c.name,
          cell: (c) => Row(
            children: [
              InitialsAvatar(name: c.name),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(c.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: kInk)),
                    Text(c.email,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: kMuted)),
                  ],
                ),
              ),
            ],
          ),
        ),
        TableColumn(
          label: 'Role',
          width: const FlexColumnWidth(1.5),
          sortBy: (c) => c.jobTitle,
          cell: (c) => hrmsMuted(c.jobTitle),
        ),
        TableColumn(
          label: 'Stage',
          width: const FlexColumnWidth(1.1),
          sortBy: (c) => c.stage.index,
          cell: (c) => Align(
            alignment: Alignment.centerLeft,
            child: StatusPill(label: c.stage.label, color: c.stage.color),
          ),
        ),
        TableColumn(
          label: 'Rating',
          width: const FlexColumnWidth(0.8),
          numeric: true,
          sortBy: (c) => c.rating,
          cell: (c) => Align(
            alignment: Alignment.centerRight,
            child: hrmsMuted(c.rating == 0 ? '—' : '${c.rating}/5'),
          ),
        ),
        TableColumn(
          label: 'Actions',
          width: const FixedColumnWidth(160),
          cell: (c) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (c.stage.next != null) ...[
                IconButton(
                  onPressed: () => _advance(c),
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  tooltip: 'Advance stage',
                  color: kIndigo,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 6),
              ],
              RowActions(
                onView: () => _view(c),
                onEdit: () => _rate(c),
                onDelete: () => _reject(c),
                extra: const [],
              ),
            ],
          ),
        ),
      ];

  @override
  Widget cardBuilder(Candidate c) => Container(
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
                InitialsAvatar(name: c.name, radius: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(c.name,
                      style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: kInk)),
                ),
                StatusPill(label: c.stage.label, color: c.stage.color),
              ],
            ),
            const SizedBox(height: 8),
            Text(
                '${c.jobTitle} · ${c.rating == 0 ? 'unrated' : '${c.rating}/5'}',
                style: const TextStyle(fontSize: 12.5, color: kMuted)),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (c.stage.next != null)
                    TextButton(
                        onPressed: () => _advance(c),
                        child: const Text('Advance')),
                  TextButton(
                      onPressed: () => _view(c), child: const Text('View')),
                  TextButton(
                      onPressed: () => _rate(c), child: const Text('Rate')),
                ],
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) =>
      HrmsListView<Candidate>(delegate: this, state: this);
}
