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

/// Learning: two tabs — Courses and Enrollments. Create a course, enrol an
/// employee, mark progress, complete (which issues a certificate). Status
/// filter on enrollments; audit on every change.
class LearningScreen extends StatefulWidget {
  const LearningScreen({super.key, required this.hrms});

  final HrmsController hrms;

  @override
  State<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends State<LearningScreen> {
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
            tabs: [Tab(text: 'Courses'), Tab(text: 'Enrollments')],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 1400,
            child: TabBarView(
              children: [
                _CoursesTab(hrms: widget.hrms),
                _EnrollmentsTab(hrms: widget.hrms),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CoursesTab extends StatefulWidget {
  const _CoursesTab({required this.hrms});
  final HrmsController hrms;
  @override
  State<_CoursesTab> createState() => _CoursesTabState();
}

class _CoursesTabState extends State<_CoursesTab>
    with ListViewState<_CoursesTab, Course>
    implements HrmsListDelegate<Course> {
  List<Course> _courses = const [];
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
      final list = await widget.hrms.repo.courses();
      if (!mounted) return;
      setState(() {
        _courses = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "We couldn't load courses.";
        _loading = false;
      });
    }
  }

  @override
  String get title => 'Courses';
  @override
  String get description => 'The learning catalog.';
  @override
  List<Course> get rows => _courses;
  @override
  List<Course> get source => _courses;
  @override
  bool get loading => _loading;
  @override
  String? get error => _error;
  @override
  VoidCallback get onRetry => _load;
  @override
  String get searchHint => 'Search title or category';
  @override
  IconData get emptyIcon => Icons.menu_book_outlined;
  @override
  String? get emptyActionLabel => 'Create Course';
  @override
  VoidCallback? get onEmptyAction => _create;
  @override
  List<Widget> filters() => const [];
  @override
  bool get hasActiveFilters => false;
  @override
  bool matchesFilters(Course c) => true;
  @override
  bool matchesQuery(Course c, String q) =>
      c.title.toLowerCase().contains(q) || c.category.toLowerCase().contains(q);

  @override
  List<Widget> kpis(List<Course> rows) {
    final hours = rows.fold(0, (s, c) => s + c.durationHours);
    final enrolled = rows.fold(0, (s, c) => s + c.enrolledCount);
    return [
      hrmsKpi('Courses', '${rows.length}', Icons.menu_book_outlined,
          'In the catalog'),
      hrmsKpi('Total Hours', '$hours', Icons.timelapse_outlined,
          'Combined content'),
      hrmsKpi('Enrollments', '$enrolled', Icons.groups_outlined,
          'Across all courses'),
      hrmsKpi(
          'Avg / Course',
          rows.isEmpty ? '0' : (enrolled / rows.length).toStringAsFixed(1),
          Icons.equalizer_outlined,
          'Learners per course'),
    ];
  }

  @override
  Widget? primaryAction() => hrmsAddButton('Create Course', _create);

  Future<void> _create() async {
    final values = await showFormDialog(
      context,
      title: 'Create Course',
      subtitle: 'Add to the learning catalog.',
      submitLabel: 'Create',
      fields: const [
        FormFieldSpec(label: 'Title', icon: Icons.title_outlined),
        FormFieldSpec(label: 'Category', icon: Icons.category_outlined),
        FormFieldSpec(
          label: 'Duration (hours)',
          validator: validateDurationHours,
          icon: Icons.schedule_outlined,
          keyboardType: TextInputType.number,
        ),
      ],
    );
    if (values == null || !mounted) return;
    final h = int.tryParse(values['Duration (hours)']!.trim());
    if (h == null || h < 1) {
      showToast(context, 'Duration must be a positive number.', isError: true);
      return;
    }
    final saved = await widget.hrms.repo.createCourse(Course(
      id: '',
      title: values['Title']!,
      category: values['Category']!,
      durationHours: h,
      enrolledCount: 0,
    ));
    widget.hrms.log(
      action: 'CREATE',
      entity: 'Course',
      entityId: saved.id,
      summary: 'Added course "${saved.title}" (${saved.category})',
    );
    await _load();
    setState(() => page = 0);
    if (mounted) showToast(context, 'Course created.');
  }

  Future<void> _edit(Course c) async {
    final values = await showFormDialog(
      context,
      title: 'Edit Course',
      subtitle: c.title,
      fields: [
        FormFieldSpec(
            label: 'Title', icon: Icons.title_outlined, initial: c.title),
        FormFieldSpec(
            label: 'Category',
            icon: Icons.category_outlined,
            initial: c.category),
        FormFieldSpec(
          label: 'Duration (hours)',
          validator: validateDurationHours,
          icon: Icons.schedule_outlined,
          initial: '${c.durationHours}',
          keyboardType: TextInputType.number,
        ),
      ],
    );
    if (values == null || !mounted) return;
    final h = int.tryParse(values['Duration (hours)']!.trim());
    if (h == null || h < 1) {
      showToast(context, 'Duration must be a positive number.', isError: true);
      return;
    }
    final saved = await widget.hrms.repo.updateCourse(c.copyWith(
      title: values['Title'],
      category: values['Category'],
      durationHours: h,
    ));
    widget.hrms.log(
      action: 'UPDATE',
      entity: 'Course',
      entityId: saved.id,
      summary: 'Updated course "${saved.title}"',
    );
    await _load();
    if (mounted) showToast(context, 'Course updated.');
  }

  void _view(Course c) => showDetailDialog(
        context,
        title: c.title,
        subtitle: c.category,
        fields: {
          'Course ID': c.id.toUpperCase(),
          'Category': c.category,
          'Duration': '${c.durationHours} hours',
          'Enrolled': '${c.enrolledCount}',
        },
      );

  @override
  List<TableColumn<Course>> get columns => [
        TableColumn(
          label: 'Title',
          width: const FlexColumnWidth(2.2),
          sortBy: (c) => c.title,
          cell: (c) => Text(c.title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w600, color: kInk)),
        ),
        TableColumn(
          label: 'Category',
          width: const FlexColumnWidth(1.2),
          sortBy: (c) => c.category,
          cell: (c) => hrmsMuted(c.category),
        ),
        TableColumn(
          label: 'Hours',
          width: const FlexColumnWidth(0.8),
          numeric: true,
          sortBy: (c) => c.durationHours,
          cell: (c) => Align(
              alignment: Alignment.centerRight,
              child: hrmsMuted('${c.durationHours}')),
        ),
        TableColumn(
          label: 'Enrolled',
          width: const FlexColumnWidth(0.9),
          numeric: true,
          sortBy: (c) => c.enrolledCount,
          cell: (c) => Align(
              alignment: Alignment.centerRight,
              child: hrmsMuted('${c.enrolledCount}')),
        ),
        TableColumn(
          label: 'Actions',
          width: const FixedColumnWidth(120),
          cell: (c) => RowActions(
            onView: () => _view(c),
            onEdit: () => _edit(c),
            onDelete: () => _edit(c),
            extra: const [],
          ),
        ),
      ];

  @override
  Widget cardBuilder(Course c) => Container(
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
            Text(c.title,
                style: const TextStyle(
                    fontSize: 14.5, fontWeight: FontWeight.w700, color: kInk)),
            const SizedBox(height: 6),
            Text(
                '${c.category} · ${c.durationHours}h · ${c.enrolledCount} enrolled',
                style: const TextStyle(fontSize: 12.5, color: kMuted)),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                      onPressed: () => _view(c), child: const Text('View')),
                  TextButton(
                      onPressed: () => _edit(c), child: const Text('Edit')),
                ],
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) =>
      HrmsListView<Course>(delegate: this, state: this);
}

class _EnrollmentsTab extends StatefulWidget {
  const _EnrollmentsTab({required this.hrms});
  final HrmsController hrms;
  @override
  State<_EnrollmentsTab> createState() => _EnrollmentsTabState();
}

class _EnrollmentsTabState extends State<_EnrollmentsTab>
    with ListViewState<_EnrollmentsTab, Enrollment>
    implements HrmsListDelegate<Enrollment> {
  List<Enrollment> _enrollments = const [];
  List<Course> _courses = const [];
  List<Employee> _employees = const [];
  bool _loading = true;
  String? _error;
  CourseStatus? _status;

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
        widget.hrms.repo.enrollments(),
        widget.hrms.repo.courses(),
        widget.hrms.repo.employees(),
      ).wait;
      if (!mounted) return;
      setState(() {
        _enrollments = r.$1;
        _courses = r.$2;
        _employees = r.$3;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "We couldn't load enrollments.";
        _loading = false;
      });
    }
  }

  @override
  String get title => 'Enrollments';
  @override
  String get description => 'Who is taking what, and how far along.';
  @override
  List<Enrollment> get rows => _enrollments;
  @override
  List<Enrollment> get source => _enrollments;
  @override
  bool get loading => _loading;
  @override
  String? get error => _error;
  @override
  VoidCallback get onRetry => _load;
  @override
  String get searchHint => 'Search employee or course';
  @override
  IconData get emptyIcon => Icons.school_outlined;
  @override
  String? get emptyActionLabel => 'Enroll Employee';
  @override
  VoidCallback? get onEmptyAction => _enrol;

  @override
  bool get hasActiveFilters => _status != null;
  @override
  bool matchesQuery(Enrollment e, String q) =>
      e.employeeName.toLowerCase().contains(q) ||
      e.courseTitle.toLowerCase().contains(q);
  @override
  bool matchesFilters(Enrollment e) => _status == null || e.status == _status;

  @override
  List<Widget> filters() => [
        FilterDropdown<CourseStatus>(
          label: 'statuses',
          value: _status,
          options: CourseStatus.values,
          labelOf: (s) => s.label,
          onChanged: (v) => onFilterChanged(() => _status = v),
        ),
      ];

  @override
  List<Widget> kpis(List<Enrollment> rows) {
    final inProgress =
        rows.where((e) => e.status == CourseStatus.inProgress).length;
    final done = rows.where((e) => e.status == CourseStatus.completed).length;
    final certified = rows.where((e) => e.certified).length;
    return [
      hrmsKpi('Enrollments', '${rows.length}', Icons.school_outlined,
          'All learners'),
      hrmsKpi('In Progress', '$inProgress', Icons.autorenew_outlined,
          'Currently learning'),
      hrmsKpi('Completed', '$done', Icons.verified_outlined, 'Finished'),
      hrmsKpi('Certified', '$certified', Icons.workspace_premium_outlined,
          'Hold a certificate'),
    ];
  }

  @override
  Widget? primaryAction() => hrmsAddButton('Enroll Employee', _enrol);

  Future<void> _enrol() async {
    if (_courses.isEmpty || _employees.isEmpty) return;
    final course = await showModalBottomSheet<Course>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final c in _courses)
              ListTile(
                title: Text(c.title),
                subtitle: Text('${c.category} · ${c.durationHours}h'),
                onTap: () => Navigator.of(context).pop(c),
              ),
          ],
        ),
      ),
    );
    if (course == null || !mounted) return;
    final employee = await showModalBottomSheet<Employee>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.6,
          child: ListView(
            children: [
              for (final e in _employees)
                ListTile(
                  leading: InitialsAvatar(name: e.name),
                  title: Text(e.name),
                  subtitle: Text(e.department),
                  onTap: () => Navigator.of(context).pop(e),
                ),
            ],
          ),
        ),
      ),
    );
    if (employee == null || !mounted) return;

    if (_enrollments.any(
        (en) => en.courseId == course.id && en.employeeId == employee.id)) {
      showToast(context, '${employee.name} is already enrolled.',
          isError: true);
      return;
    }

    final saved = await widget.hrms.repo.createEnrollment(Enrollment(
      id: '',
      courseId: course.id,
      courseTitle: course.title,
      employeeId: employee.id,
      employeeName: employee.name,
      status: CourseStatus.notStarted,
      progress: 0,
      enrolledOn: DateTime.now(),
    ));
    widget.hrms.log(
      action: 'CREATE',
      entity: 'Enrollment',
      entityId: saved.id,
      summary: 'Enrolled ${employee.name} in "${course.title}"',
    );
    await _load();
    setState(() => page = 0);
    if (mounted) showToast(context, 'Enrolled.');
  }

  Future<void> _setProgress(Enrollment e) async {
    final values = await showFormDialog(
      context,
      title: 'Update Progress',
      subtitle: '${e.employeeName} · ${e.courseTitle}',
      submitLabel: 'Save',
      fields: [
        FormFieldSpec(
          label: 'Progress % (0-100)',
          validator: validatePercent,
          icon: Icons.percent_outlined,
          initial: '${(e.progress * 100).round()}',
          keyboardType: TextInputType.number,
        ),
      ],
    );
    if (values == null || !mounted) return;
    final pct = int.tryParse(values['Progress % (0-100)']!.trim());
    if (pct == null || pct < 0 || pct > 100) {
      showToast(context, 'Progress must be 0–100.', isError: true);
      return;
    }
    final progress = pct / 100;
    final status = pct >= 100
        ? CourseStatus.completed
        : (pct > 0 ? CourseStatus.inProgress : CourseStatus.notStarted);
    final saved = await widget.hrms.repo.updateEnrollment(e.copyWith(
      progress: progress,
      status: status,
      certified: status == CourseStatus.completed ? true : e.certified,
    ));
    widget.hrms.log(
      action: status == CourseStatus.completed ? 'PUBLISH' : 'UPDATE',
      entity: 'Enrollment',
      entityId: saved.id,
      summary: status == CourseStatus.completed
          ? '${e.employeeName} completed "${e.courseTitle}" — certificate issued'
          : '${e.employeeName} at $pct% on "${e.courseTitle}"',
    );
    await _load();
    if (mounted) {
      showToast(
        context,
        status == CourseStatus.completed
            ? 'Course completed — certificate issued.'
            : 'Progress updated.',
      );
    }
  }

  void _view(Enrollment e) => showDetailDialog(
        context,
        title: e.employeeName,
        subtitle: e.courseTitle,
        fields: {
          'Enrollment ID': e.id.toUpperCase(),
          'Course': e.courseTitle,
          'Status': e.status.label,
          'Progress': '${(e.progress * 100).round()}%',
          'Certified': e.certified ? 'Yes' : 'No',
          'Enrolled': formatDate(e.enrolledOn),
        },
      );

  @override
  List<TableColumn<Enrollment>> get columns => [
        TableColumn(
          label: 'Employee',
          width: const FlexColumnWidth(1.7),
          sortBy: (e) => e.employeeName,
          cell: (e) => Row(
            children: [
              InitialsAvatar(name: e.employeeName),
              const SizedBox(width: 10),
              Expanded(
                child: Text(e.employeeName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: kInk)),
              ),
            ],
          ),
        ),
        TableColumn(
          label: 'Course',
          width: const FlexColumnWidth(1.8),
          sortBy: (e) => e.courseTitle,
          cell: (e) => hrmsMuted(e.courseTitle),
        ),
        TableColumn(
          label: 'Progress',
          width: const FlexColumnWidth(1),
          numeric: true,
          sortBy: (e) => e.progress,
          cell: (e) => Align(
            alignment: Alignment.centerRight,
            child: hrmsMuted('${(e.progress * 100).round()}%'),
          ),
        ),
        TableColumn(
          label: 'Status',
          width: const FlexColumnWidth(1.1),
          sortBy: (e) => e.status.index,
          cell: (e) => Align(
            alignment: Alignment.centerLeft,
            child: StatusPill(label: e.status.label, color: e.status.color),
          ),
        ),
        TableColumn(
          label: 'Actions',
          width: const FixedColumnWidth(96),
          cell: (e) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () => _view(e),
                icon: const Icon(Icons.visibility_outlined, size: 18),
                tooltip: 'View',
                color: kMuted,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              if (e.status != CourseStatus.completed)
                IconButton(
                  onPressed: () => _setProgress(e),
                  icon: const Icon(Icons.trending_up, size: 18),
                  tooltip: 'Update progress',
                  color: kIndigo,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ),
      ];

  @override
  Widget cardBuilder(Enrollment e) => Container(
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
                InitialsAvatar(name: e.employeeName, radius: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(e.employeeName,
                      style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: kInk)),
                ),
                StatusPill(label: e.status.label, color: e.status.color),
              ],
            ),
            const SizedBox(height: 8),
            Text('${e.courseTitle} · ${(e.progress * 100).round()}%',
                style: const TextStyle(fontSize: 12.5, color: kMuted)),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                      onPressed: () => _view(e), child: const Text('View')),
                  if (e.status != CourseStatus.completed)
                    TextButton(
                        onPressed: () => _setProgress(e),
                        child: const Text('Progress')),
                ],
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) =>
      HrmsListView<Enrollment>(delegate: this, state: this);
}
