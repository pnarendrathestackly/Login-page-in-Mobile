import 'dart:async';
import 'dart:math';

import '../models/hrms_models.dart';

/// The seam a real HRMS backend plugs into, mirroring `DashboardRepository`.
///
/// Every method is what a server would expose over HTTP. Reads return the whole
/// collection (the demo sets are small; searching, filtering and paging happen
/// client-side). Writes take the changed record and return the persisted copy.
///
/// Swap [DemoHrmsRepository] for an HTTP implementation and no screen changes.
abstract class HrmsRepository {
  // --- Employees ---------------------------------------------------------
  Future<List<Employee>> employees();
  Future<Employee> createEmployee(Employee draft);
  Future<Employee> updateEmployee(Employee employee);
  Future<void> deleteEmployee(String id);

  // --- Attendance ------------------------------------------------------------
  Future<List<AttendanceRecord>> attendance();
  Future<AttendanceRecord> saveAttendance(AttendanceRecord record);

  // --- Leave ---------------------------------------------------------------
  Future<List<LeaveRequest>> leaveRequests();
  Future<List<LeaveBalance>> leaveBalances();
  Future<LeaveRequest> createLeaveRequest(LeaveRequest draft);
  Future<LeaveRequest> updateLeaveRequest(LeaveRequest request);

  // --- Payroll -----------------------------------------------------------
  Future<List<PayrollRun>> payrollRuns();
  Future<PayrollRun> createPayrollRun(PayrollRun draft);
  Future<PayrollRun> updatePayrollRun(PayrollRun run);

  // --- Recruitment -------------------------------------------------------
  Future<List<JobOpening>> jobOpenings();
  Future<List<Candidate>> candidates();
  Future<JobOpening> createJob(JobOpening draft);
  Future<JobOpening> updateJob(JobOpening job);
  Future<Candidate> createCandidate(Candidate draft);
  Future<Candidate> updateCandidate(Candidate candidate);

  // --- Performance -----------------------------------------------------------
  Future<List<ReviewCycle>> reviews();
  Future<ReviewCycle> createReview(ReviewCycle draft);
  Future<ReviewCycle> updateReview(ReviewCycle review);

  // --- Learning --------------------------------------------------------------
  Future<List<Course>> courses();
  Future<List<Enrollment>> enrollments();
  Future<Course> createCourse(Course draft);
  Future<Course> updateCourse(Course course);
  Future<Enrollment> createEnrollment(Enrollment draft);
  Future<Enrollment> updateEnrollment(Enrollment enrollment);

  // --- Assets --------------------------------------------------------------
  Future<List<HrAsset>> assets();
  Future<HrAsset> createAsset(HrAsset draft);
  Future<HrAsset> updateAsset(HrAsset asset);
  Future<void> deleteAsset(String id);
}

/// DEMO DATA — not a real backend.
///
/// Holds every collection in memory and mutates it on write, so filters,
/// search, paging and KPI counts all operate on live data. Seeded once from a
/// fixed date; `latency` is injectable so widget tests can pass `Duration.zero`.
///
/// State resets on app restart — there is no persistence layer in a
/// frontend-only build.
class DemoHrmsRepository implements HrmsRepository {
  DemoHrmsRepository({this.latency = const Duration(milliseconds: 500)}) {
    _seed();
  }

  final Duration latency;
  final _rng = Random(7);
  final DateTime _now = DateTime.now();
  int _seq = 0;

  late List<Employee> _employees;
  late List<AttendanceRecord> _attendance;
  late List<LeaveRequest> _leave;
  late List<LeaveBalance> _balances;
  late List<PayrollRun> _payroll;
  late List<JobOpening> _jobs;
  late List<Candidate> _candidates;
  late List<ReviewCycle> _reviews;
  late List<Course> _courses;
  late List<Enrollment> _enrollments;
  late List<HrAsset> _assets;

  String _id(String prefix) => '$prefix-${(++_seq).toString().padLeft(4, '0')}';
  Future<T> _io<T>(T value) => Future<void>.delayed(latency).then((_) => value);
  DateTime _daysAgo(int d) => DateTime(_now.year, _now.month, _now.day - d);

  // -----------------------------------------------------------------------
  // Seed
  // -----------------------------------------------------------------------

  void _seed() {
    const departments = ['Engineering', 'Sales', 'HR', 'Finance', 'Operations'];
    const locations = ['London', 'Berlin', 'Remote', 'Singapore', 'Austin'];
    const firstNames = [
      'Arun',
      'Priya',
      'Mei',
      'Daniel',
      'Sam',
      'Kavya',
      'Rahul',
      'Meera',
      'Chen',
      'Nadia',
      'Omar',
      'Lena',
      'Tariq',
      'Sofia',
      'Ivan',
      'Hana',
      'Diego',
      'Fatima',
      'Noah',
      'Aisha',
    ];
    const lastNames = [
      'Kumar',
      'Raman',
      'Tanaka',
      'Okoro',
      'Whitfield',
      'Nair',
      'Menon',
      'Shah',
      'Wei',
      'Haddad',
      'Farah',
      'Berg',
      'Aziz',
      'Ferreira',
      'Petrov',
      'Kim',
      'Torres',
      'Ali',
      'Cohen',
      'Bello',
    ];

    _employees = [
      for (var i = 0; i < 20; i++)
        Employee(
          id: _id('emp'),
          name: '${firstNames[i]} ${lastNames[i]}',
          email:
              '${firstNames[i].toLowerCase()}.${lastNames[i].toLowerCase()}@onecloud.com',
          jobTitle: const [
            'Software Engineer',
            'Account Executive',
            'HR Partner',
            'Financial Analyst',
            'Operations Lead',
          ][i % 5],
          department: departments[i % 5],
          manager: i < 5 ? '' : '${firstNames[i % 5]} ${lastNames[i % 5]}',
          location: locations[i % 5],
          status: i % 9 == 0
              ? EmployeeStatus.probation
              : (i % 7 == 0 ? EmployeeStatus.onLeave : EmployeeStatus.active),
          hiredOn: _daysAgo(40 + i * 55),
          annualSalary: 62000 + (i % 5) * 14000 + _rng.nextInt(8) * 1000,
          documents: i.isEven ? const ['contract.pdf'] : const [],
        ),
    ];

    // `taken` is filled in after _leave is seeded, so it is always the exact
    // sum of that employee's approved paid leave — the same rule
    // [_recomputeBalance] applies on every approval.
    _balances = [
      for (final e in _employees)
        LeaveBalance(
          employeeId: e.id,
          employeeName: e.name,
          entitlement: 25,
          taken: 0,
        ),
    ];

    _attendance = [
      for (final e in _employees.take(12))
        for (var d = 0; d < 5; d++)
          AttendanceRecord(
            id: _id('att'),
            employeeId: e.id,
            employeeName: e.name,
            date: _daysAgo(d),
            checkIn: DateTime(
                _now.year, _now.month, _now.day - d, 9, _rng.nextInt(40)),
            checkOut: DateTime(_now.year, _now.month, _now.day - d,
                17 + _rng.nextInt(2), _rng.nextInt(50)),
            status: d == 2 && e.id.endsWith('2')
                ? AttendanceStatus.late
                : (e.location == 'Remote'
                    ? AttendanceStatus.remote
                    : AttendanceStatus.present),
          ),
    ];

    _leave = [
      for (var i = 0; i < 9; i++)
        LeaveRequest(
          id: _id('lv'),
          employeeId: _employees[i].id,
          employeeName: _employees[i].name,
          type: LeaveType.values[i % LeaveType.values.length],
          from: _daysAgo(-3 - i),
          to: _daysAgo(-3 - i - (i % 3)),
          reason: const [
            'Family holiday',
            'Medical appointment',
            'Personal matter',
            'Conference',
            'Moving house',
          ][i % 5],
          status: i < 4
              ? RequestStatus.pending
              : (i < 7 ? RequestStatus.approved : RequestStatus.rejected),
          requestedOn: _daysAgo(i + 1),
          approver: i < 4 ? null : 'Priya Raman',
          decidedOn: i < 4 ? null : _daysAgo(i),
        ),
    ];

    // Now that leave exists, make each balance's `taken` the real approved sum.
    for (final b in _balances.toList()) {
      _recomputeBalance(b.employeeId);
    }

    _payroll = [
      for (var m = 1; m <= 4; m++)
        PayrollRun(
          id: _id('pay'),
          period: const [
            'December 2025',
            'January 2026',
            'February 2026',
            'March 2026',
          ][m - 1],
          status: m < 4 ? PayrollStatus.paid : PayrollStatus.draft,
          employeeCount: _employees.length,
          grossTotal: _employees.fold(0, (s, e) => s + e.annualSalary ~/ 12),
          deductionsTotal:
              _employees.fold(0, (s, e) => s + (e.annualSalary ~/ 12 ~/ 4)),
          processedOn: m < 4 ? _daysAgo((4 - m) * 30) : null,
        ),
    ];

    _jobs = [
      JobOpening(
        id: _id('job'),
        title: 'Senior Frontend Engineer',
        department: 'Engineering',
        location: 'Remote',
        openings: 2,
        isOpen: true,
        postedOn: _daysAgo(18),
      ),
      JobOpening(
        id: _id('job'),
        title: 'Enterprise Account Executive',
        department: 'Sales',
        location: 'London',
        openings: 1,
        isOpen: true,
        postedOn: _daysAgo(9),
      ),
      JobOpening(
        id: _id('job'),
        title: 'People Operations Coordinator',
        department: 'HR',
        location: 'Berlin',
        openings: 1,
        isOpen: false,
        postedOn: _daysAgo(60),
      ),
    ];

    _candidates = [
      for (var i = 0; i < 10; i++)
        Candidate(
          id: _id('cand'),
          name: '${firstNames[(i + 3) % 20]} ${lastNames[(i + 11) % 20]}',
          email: 'candidate$i@example.com',
          jobId: _jobs[i % _jobs.length].id,
          jobTitle: _jobs[i % _jobs.length].title,
          stage: CandidateStage.values[i % 5],
          appliedOn: _daysAgo(i * 2 + 1),
          rating: i % 3 == 0 ? 0 : 3 + i % 3,
        ),
    ];

    _reviews = [
      for (var i = 0; i < 12; i++)
        ReviewCycle(
          id: _id('rev'),
          name: 'H1 2026 Review',
          employeeId: _employees[i].id,
          employeeName: _employees[i].name,
          reviewer: _employees[i].manager.isEmpty
              ? 'Priya Raman'
              : _employees[i].manager,
          status: ReviewStatus.values[i % ReviewStatus.values.length],
          dueOn: _daysAgo(-14 + i),
          rating:
              i % ReviewStatus.values.length == 4 ? 3.5 + (i % 3) * 0.5 : null,
        ),
    ];

    _courses = [
      Course(
          id: _id('crs'),
          title: 'Security Awareness',
          category: 'Compliance',
          durationHours: 2,
          enrolledCount: 18),
      Course(
          id: _id('crs'),
          title: 'Leadership Fundamentals',
          category: 'Management',
          durationHours: 8,
          enrolledCount: 6),
      Course(
          id: _id('crs'),
          title: 'Advanced Dart & Flutter',
          category: 'Technical',
          durationHours: 12,
          enrolledCount: 9),
    ];

    _enrollments = [
      for (var i = 0; i < 14; i++)
        Enrollment(
          id: _id('enr'),
          courseId: _courses[i % _courses.length].id,
          courseTitle: _courses[i % _courses.length].title,
          employeeId: _employees[i].id,
          employeeName: _employees[i].name,
          status: CourseStatus.values[i % 3],
          progress: (i % 3) == 0 ? 0.0 : ((i % 3) == 1 ? 0.45 : 1.0),
          enrolledOn: _daysAgo(i * 3 + 2),
          certified: (i % 3) == 2,
        ),
    ];

    _assets = [
      for (var i = 0; i < 12; i++)
        HrAsset(
          id: _id('ast'),
          tag: 'AST-${(140 + i).toString().padLeft(4, '0')}',
          name: const [
            'MacBook Pro 14"',
            'Dell UltraSharp 27"',
            'iPhone 15',
            'Herman Miller Chair',
            'Logitech MX Keys',
          ][i % 5],
          category: const [
            'Laptop',
            'Monitor',
            'Phone',
            'Furniture',
            'Peripheral',
          ][i % 5],
          assignedTo: i < 9 ? _employees[i].name : '',
          condition: AssetCondition.values[i % 4],
          purchasedOn: _daysAgo(120 + i * 20),
        ),
    ];
  }

  // -----------------------------------------------------------------------
  // Employees
  // -----------------------------------------------------------------------

  @override
  Future<List<Employee>> employees() => _io(List.of(_employees));

  @override
  Future<Employee> createEmployee(Employee draft) {
    final saved = draft.id.isEmpty ? _withId(draft, _id('emp')) : draft;
    _employees = [saved, ..._employees];
    _balances = [
      LeaveBalance(
        employeeId: saved.id,
        employeeName: saved.name,
        entitlement: 25,
        taken: 0,
      ),
      ..._balances,
    ];
    return _io(saved);
  }

  Employee _withId(Employee e, String id) => Employee(
        id: id,
        name: e.name,
        email: e.email,
        jobTitle: e.jobTitle,
        department: e.department,
        manager: e.manager,
        location: e.location,
        status: e.status,
        hiredOn: e.hiredOn,
        annualSalary: e.annualSalary,
        documents: e.documents,
      );

  @override
  Future<Employee> updateEmployee(Employee employee) {
    _employees = [
      for (final e in _employees)
        if (e.id == employee.id) employee else e,
    ];
    return _io(employee);
  }

  @override
  Future<void> deleteEmployee(String id) {
    _employees = [
      for (final e in _employees)
        if (e.id != id) e
    ];
    _balances = [
      for (final b in _balances)
        if (b.employeeId != id) b
    ];
    return _io(null);
  }

  // -----------------------------------------------------------------------
  // Attendance
  // -----------------------------------------------------------------------

  @override
  Future<List<AttendanceRecord>> attendance() => _io(List.of(_attendance));

  @override
  Future<AttendanceRecord> saveAttendance(AttendanceRecord record) {
    final saved = record.id.isEmpty
        ? AttendanceRecord(
            id: _id('att'),
            employeeId: record.employeeId,
            employeeName: record.employeeName,
            date: record.date,
            checkIn: record.checkIn,
            checkOut: record.checkOut,
            status: record.status,
          )
        : record;
    final exists = _attendance.any((a) => a.id == saved.id);
    _attendance = exists
        ? [
            for (final a in _attendance)
              if (a.id == saved.id) saved else a
          ]
        : [saved, ..._attendance];
    return _io(saved);
  }

  // -----------------------------------------------------------------------
  // Leave
  // -----------------------------------------------------------------------

  @override
  Future<List<LeaveRequest>> leaveRequests() => _io(List.of(_leave));

  @override
  Future<List<LeaveBalance>> leaveBalances() => _io(List.of(_balances));

  @override
  Future<LeaveRequest> createLeaveRequest(LeaveRequest draft) {
    final saved = LeaveRequest(
      id: _id('lv'),
      employeeId: draft.employeeId,
      employeeName: draft.employeeName,
      type: draft.type,
      from: draft.from,
      to: draft.to,
      reason: draft.reason,
      status: RequestStatus.pending,
      requestedOn: DateTime.now(),
    );
    _leave = [saved, ..._leave];
    return _io(saved);
  }

  @override
  Future<LeaveRequest> updateLeaveRequest(LeaveRequest request) {
    _leave = [
      for (final l in _leave)
        if (l.id == request.id) request else l,
    ];
    // Approving a leave draws down the balance; cancelling/rejecting an
    // already-approved one returns it.
    _recomputeBalance(request.employeeId);
    return _io(request);
  }

  void _recomputeBalance(String employeeId) {
    final approvedDays = _leave
        .where((l) =>
            l.employeeId == employeeId &&
            l.status == RequestStatus.approved &&
            l.type != LeaveType.unpaid)
        .fold(0, (s, l) => s + l.days);
    _balances = [
      for (final b in _balances)
        if (b.employeeId == employeeId)
          LeaveBalance(
            employeeId: b.employeeId,
            employeeName: b.employeeName,
            entitlement: b.entitlement,
            taken: approvedDays,
          )
        else
          b,
    ];
  }

  // -----------------------------------------------------------------------
  // Payroll
  // -----------------------------------------------------------------------

  @override
  Future<List<PayrollRun>> payrollRuns() => _io(List.of(_payroll));

  @override
  Future<PayrollRun> createPayrollRun(PayrollRun draft) {
    final gross = _employees
        .where((e) => e.status != EmployeeStatus.terminated)
        .fold(0, (s, e) => s + e.annualSalary ~/ 12);
    final saved = PayrollRun(
      id: _id('pay'),
      period: draft.period,
      status: PayrollStatus.draft,
      employeeCount:
          _employees.where((e) => e.status != EmployeeStatus.terminated).length,
      grossTotal: gross,
      deductionsTotal: (gross * 0.24).round(),
      processedOn: null,
    );
    _payroll = [saved, ..._payroll];
    return _io(saved);
  }

  @override
  Future<PayrollRun> updatePayrollRun(PayrollRun run) {
    _payroll = [
      for (final p in _payroll)
        if (p.id == run.id) run else p,
    ];
    return _io(run);
  }

  // -----------------------------------------------------------------------
  // Recruitment
  // -----------------------------------------------------------------------

  @override
  Future<List<JobOpening>> jobOpenings() => _io(List.of(_jobs));

  @override
  Future<List<Candidate>> candidates() => _io(List.of(_candidates));

  @override
  Future<JobOpening> createJob(JobOpening draft) {
    final saved = JobOpening(
      id: _id('job'),
      title: draft.title,
      department: draft.department,
      location: draft.location,
      openings: draft.openings,
      isOpen: true,
      postedOn: DateTime.now(),
    );
    _jobs = [saved, ..._jobs];
    return _io(saved);
  }

  @override
  Future<JobOpening> updateJob(JobOpening job) {
    _jobs = [
      for (final j in _jobs)
        if (j.id == job.id) job else j
    ];
    return _io(job);
  }

  @override
  Future<Candidate> createCandidate(Candidate draft) {
    final job =
        _jobs.firstWhere((j) => j.id == draft.jobId, orElse: () => _jobs.first);
    final saved = Candidate(
      id: _id('cand'),
      name: draft.name,
      email: draft.email,
      jobId: job.id,
      jobTitle: job.title,
      stage: CandidateStage.applied,
      appliedOn: DateTime.now(),
    );
    _candidates = [saved, ..._candidates];
    return _io(saved);
  }

  @override
  Future<Candidate> updateCandidate(Candidate candidate) {
    _candidates = [
      for (final c in _candidates)
        if (c.id == candidate.id) candidate else c,
    ];
    // Hiring a candidate adds them as an employee — the pipeline's whole point.
    if (candidate.stage == CandidateStage.hired &&
        !_employees.any((e) => e.email == candidate.email)) {
      final job = _jobs.firstWhere((j) => j.id == candidate.jobId,
          orElse: () => _jobs.first);
      createEmployee(Employee(
        id: '',
        name: candidate.name,
        email: candidate.email,
        jobTitle: job.title,
        department: job.department,
        manager: '',
        location: job.location,
        status: EmployeeStatus.probation,
        hiredOn: DateTime.now(),
        annualSalary: 65000,
      ));
    }
    return _io(candidate);
  }

  // -----------------------------------------------------------------------
  // Performance
  // -----------------------------------------------------------------------

  @override
  Future<List<ReviewCycle>> reviews() => _io(List.of(_reviews));

  @override
  Future<ReviewCycle> createReview(ReviewCycle draft) {
    final saved = ReviewCycle(
      id: _id('rev'),
      name: draft.name,
      employeeId: draft.employeeId,
      employeeName: draft.employeeName,
      reviewer: draft.reviewer,
      status: ReviewStatus.notStarted,
      dueOn: draft.dueOn,
    );
    _reviews = [saved, ..._reviews];
    return _io(saved);
  }

  @override
  Future<ReviewCycle> updateReview(ReviewCycle review) {
    _reviews = [
      for (final r in _reviews)
        if (r.id == review.id) review else r,
    ];
    return _io(review);
  }

  // -----------------------------------------------------------------------
  // Learning
  // -----------------------------------------------------------------------

  @override
  Future<List<Course>> courses() => _io(List.of(_courses));

  @override
  Future<List<Enrollment>> enrollments() => _io(List.of(_enrollments));

  @override
  Future<Course> createCourse(Course draft) {
    final saved = Course(
      id: _id('crs'),
      title: draft.title,
      category: draft.category,
      durationHours: draft.durationHours,
      enrolledCount: 0,
    );
    _courses = [saved, ..._courses];
    return _io(saved);
  }

  @override
  Future<Course> updateCourse(Course course) {
    _courses = [
      for (final c in _courses)
        if (c.id == course.id) course else c
    ];
    return _io(course);
  }

  @override
  Future<Enrollment> createEnrollment(Enrollment draft) {
    final course = _courses.firstWhere((c) => c.id == draft.courseId,
        orElse: () => _courses.first);
    final saved = Enrollment(
      id: _id('enr'),
      courseId: course.id,
      courseTitle: course.title,
      employeeId: draft.employeeId,
      employeeName: draft.employeeName,
      status: CourseStatus.notStarted,
      progress: 0,
      enrolledOn: DateTime.now(),
    );
    _enrollments = [saved, ..._enrollments];
    _courses = [
      for (final c in _courses)
        if (c.id == course.id)
          c.copyWith(enrolledCount: c.enrolledCount + 1)
        else
          c,
    ];
    return _io(saved);
  }

  @override
  Future<Enrollment> updateEnrollment(Enrollment enrollment) {
    _enrollments = [
      for (final e in _enrollments)
        if (e.id == enrollment.id) enrollment else e,
    ];
    return _io(enrollment);
  }

  // -----------------------------------------------------------------------
  // Assets
  // -----------------------------------------------------------------------

  @override
  Future<List<HrAsset>> assets() => _io(List.of(_assets));

  @override
  Future<HrAsset> createAsset(HrAsset draft) {
    final saved = HrAsset(
      id: _id('ast'),
      tag: draft.tag,
      name: draft.name,
      category: draft.category,
      assignedTo: draft.assignedTo,
      condition: draft.condition,
      purchasedOn: draft.purchasedOn,
    );
    _assets = [saved, ..._assets];
    return _io(saved);
  }

  @override
  Future<HrAsset> updateAsset(HrAsset asset) {
    _assets = [
      for (final a in _assets)
        if (a.id == asset.id) asset else a
    ];
    return _io(asset);
  }

  @override
  Future<void> deleteAsset(String id) {
    _assets = [
      for (final a in _assets)
        if (a.id != id) a
    ];
    return _io(null);
  }
}
