import 'package:flutter_test/flutter_test.dart';
import 'package:stackly_auth/features/hrms/hrms_controller.dart';
import 'package:stackly_auth/features/hrms/models/hrms_models.dart';
import 'package:stackly_auth/features/hrms/services/hrms_audit.dart';
import 'package:stackly_auth/features/hrms/services/hrms_repository.dart';

/// Exercises the HRMS data layer directly — the CRUD, the derived state
/// (leave-balance drawdown, hire-on-employee, enrolment count) and the audit
/// log. The screens are thin wrappers over this; verifying it here keeps the
/// tests fast (no widget tree, no timers).
DemoHrmsRepository _repo() => DemoHrmsRepository(latency: Duration.zero);

void main() {
  group('employees', () {
    test('create persists and appears in the list', () async {
      final repo = _repo();
      final before = (await repo.employees()).length;
      final saved = await repo.createEmployee(Employee(
        id: '',
        name: 'Test Person',
        email: 'test.person@onecloud.com',
        jobTitle: 'QA',
        department: 'Engineering',
        manager: '',
        location: 'Remote',
        status: EmployeeStatus.probation,
        hiredOn: DateTime(2025, 1, 1),
        annualSalary: 70000,
      ));
      expect(saved.id, isNotEmpty);
      final after = await repo.employees();
      expect(after.length, before + 1);
      expect(after.any((e) => e.id == saved.id && e.name == 'Test Person'),
          isTrue);
    });

    test('update replaces the record; delete removes it', () async {
      final repo = _repo();
      final first = (await repo.employees()).first;
      final updated =
          await repo.updateEmployee(first.copyWith(jobTitle: 'Changed Title'));
      expect(updated.jobTitle, 'Changed Title');
      expect(
          (await repo.employees()).firstWhere((e) => e.id == first.id).jobTitle,
          'Changed Title');

      await repo.deleteEmployee(first.id);
      expect((await repo.employees()).any((e) => e.id == first.id), isFalse);
    });

    test('a new employee gets a fresh 25-day leave balance', () async {
      final repo = _repo();
      final saved = await repo.createEmployee(Employee(
        id: '',
        name: 'Balance Check',
        email: 'balance@onecloud.com',
        jobTitle: 'Analyst',
        department: 'Finance',
        manager: '',
        location: 'London',
        status: EmployeeStatus.active,
        hiredOn: DateTime(2025, 1, 1),
        annualSalary: 60000,
      ));
      final bal = (await repo.leaveBalances())
          .firstWhere((b) => b.employeeId == saved.id);
      expect(bal.entitlement, 25);
      expect(bal.taken, 0);
      expect(bal.remaining, 25);
    });
  });

  group('leave', () {
    test('approving a request records approver + timestamp', () async {
      final repo = _repo();
      final pending = (await repo.leaveRequests())
          .firstWhere((l) => l.status == RequestStatus.pending);
      final decidedAt = DateTime(2026, 3, 1);
      final approved = await repo.updateLeaveRequest(pending.copyWith(
        status: RequestStatus.approved,
        approver: 'Priya Raman',
        decidedOn: decidedAt,
      ));
      expect(approved.status, RequestStatus.approved);
      expect(approved.approver, 'Priya Raman');
      expect(approved.decidedOn, decidedAt);
    });

    test('approving paid leave draws the balance down by the day count',
        () async {
      final repo = _repo();
      final req = (await repo.leaveRequests()).firstWhere((l) =>
          l.status == RequestStatus.pending && l.type != LeaveType.unpaid);
      final before = (await repo.leaveBalances())
          .firstWhere((b) => b.employeeId == req.employeeId)
          .taken;
      await repo.updateLeaveRequest(req.copyWith(
        status: RequestStatus.approved,
        approver: 'M',
        decidedOn: DateTime(2026),
      ));
      final after = (await repo.leaveBalances())
          .firstWhere((b) => b.employeeId == req.employeeId)
          .taken;
      expect(after, before + req.days);
    });

    test('new request starts pending regardless of the draft', () async {
      final repo = _repo();
      final emp = (await repo.employees()).first;
      final saved = await repo.createLeaveRequest(LeaveRequest(
        id: '',
        employeeId: emp.id,
        employeeName: emp.name,
        type: LeaveType.annual,
        from: DateTime(2026, 6, 1),
        to: DateTime(2026, 6, 3),
        reason: 'x',
        status: RequestStatus.approved, // should be ignored
        requestedOn: DateTime(2020),
      ));
      expect(saved.status, RequestStatus.pending);
      expect(saved.days, 3);
    });
  });

  group('payroll', () {
    test('processing a draft run marks it paid with a timestamp', () async {
      final repo = _repo();
      final draft = await repo.createPayrollRun(const PayrollRun(
        id: '',
        period: 'May 2026',
        status: PayrollStatus.draft,
        employeeCount: 0,
        grossTotal: 0,
        deductionsTotal: 0,
        processedOn: null,
      ));
      expect(draft.status, PayrollStatus.draft);
      expect(draft.grossTotal, greaterThan(0));

      final paid = await repo.updatePayrollRun(draft.copyWith(
        status: PayrollStatus.paid,
        processedOn: DateTime(2026, 6, 1),
      ));
      expect(paid.status, PayrollStatus.paid);
      expect(paid.processedOn, isNotNull);
      expect(paid.netTotal, paid.grossTotal - paid.deductionsTotal);
    });
  });

  group('recruitment', () {
    test('hiring a candidate creates a matching employee', () async {
      final repo = _repo();
      final cand = (await repo.candidates())
          .firstWhere((c) => c.stage != CandidateStage.hired);
      final empBefore = (await repo.employees()).length;
      await repo.updateCandidate(cand.copyWith(stage: CandidateStage.hired));
      final employees = await repo.employees();
      expect(employees.length, empBefore + 1);
      expect(employees.any((e) => e.email == cand.email), isTrue);
    });

    test('candidate stage advances through the pipeline', () {
      expect(CandidateStage.applied.next, CandidateStage.screening);
      expect(CandidateStage.offer.next, CandidateStage.hired);
      expect(CandidateStage.hired.next, isNull);
    });
  });

  group('learning', () {
    test('enrolling bumps the course enrolled count', () async {
      final repo = _repo();
      final course = (await repo.courses()).first;
      final emp = (await repo.employees()).last;
      final countBefore = course.enrolledCount;
      await repo.createEnrollment(Enrollment(
        id: '',
        courseId: course.id,
        courseTitle: course.title,
        employeeId: emp.id,
        employeeName: emp.name,
        status: CourseStatus.notStarted,
        progress: 0,
        enrolledOn: DateTime(2026),
      ));
      final after = (await repo.courses()).firstWhere((c) => c.id == course.id);
      expect(after.enrolledCount, countBefore + 1);
    });
  });

  group('assets', () {
    test('assign then return updates the holder', () async {
      final repo = _repo();
      final asset =
          (await repo.assets()).firstWhere((a) => a.assignedTo.isEmpty);
      final assigned =
          await repo.updateAsset(asset.copyWith(assignedTo: 'Arun Kumar'));
      expect(assigned.assignedTo, 'Arun Kumar');
      final returned =
          await repo.updateAsset(assigned.copyWith(assignedTo: ''));
      expect(returned.assignedTo, isEmpty);
    });

    test('delete removes the asset', () async {
      final repo = _repo();
      final a = (await repo.assets()).first;
      await repo.deleteAsset(a.id);
      expect((await repo.assets()).any((x) => x.id == a.id), isFalse);
    });
  });

  group('audit log', () {
    test('records entries newest-first and filters by entity', () {
      final log = HrmsAuditLog();
      log.record(
          actor: 'A',
          action: 'CREATE',
          entity: 'Employee',
          entityId: 'emp-1',
          summary: 'created');
      log.record(
          actor: 'A',
          action: 'UPDATE',
          entity: 'Employee',
          entityId: 'emp-1',
          summary: 'updated');
      log.record(
          actor: 'A',
          action: 'DELETE',
          entity: 'HrAsset',
          entityId: 'ast-9',
          summary: 'deleted');

      expect(log.entries.length, 3);
      expect(log.entries.first.action, 'DELETE'); // newest first
      expect(log.forEntity('Employee', 'emp-1').length, 2);
      expect(log.forEntity('HrAsset', 'ast-9').single.summary, 'deleted');
    });

    test('controller.log stamps the actor and notifies', () {
      final hrms = HrmsController(repository: _repo(), actor: 'Vishnu Vardhan');
      var notified = false;
      hrms.audit.addListener(() => notified = true);
      hrms.log(
          action: 'APPROVE',
          entity: 'LeaveRequest',
          entityId: 'lv-1',
          summary: 'approved');
      expect(notified, isTrue);
      expect(hrms.audit.entries.single.actor, 'Vishnu Vardhan');
    });
  });

  group('helpers', () {
    test('toCsv quotes cells and doubles internal quotes', () {
      final csv = toCsv(
        const ['Name', 'Note'],
        [
          ['Ann', 'plain'],
          ['Bob "B"', 'a,b'],
        ],
      );
      final lines = csv.trim().split('\n');
      expect(lines[0], '"Name","Note"');
      expect(lines[1], '"Ann","plain"');
      expect(lines[2], '"Bob ""B""","a,b"');
    });

    test('money formats with thousands separators', () {
      expect(money(0), r'$0');
      expect(money(1500), r'$1,500');
      expect(money(1420000), r'$1,420,000');
      expect(money(-2500), r'-$2,500');
    });

    test('clock formats 12-hour time', () {
      expect(clock(null), '—');
      expect(clock(DateTime(2026, 1, 1, 9, 4)), '9:04 AM');
      expect(clock(DateTime(2026, 1, 1, 13, 0)), '1:00 PM');
      expect(clock(DateTime(2026, 1, 1, 0, 30)), '12:30 AM');
    });
  });
}
