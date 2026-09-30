import 'package:flutter/material.dart';

import '../../../main.dart';

/// Entity shapes for the HRMS service. Same contract style as the dashboard
/// models: these are what a real HR API would return, and
/// [DemoHrmsRepository] is the stand-in until one exists.
///
/// Every entity carries an `id`; every mutable field is `final` and updates go
/// through `copyWith`, so a screen never edits a record in place — it asks the
/// repository to replace it, matching how a backend round trip would behave.

// ---------------------------------------------------------------------------
// Shared enums
// ---------------------------------------------------------------------------

enum EmployeeStatus {
  active('Active', kSuccess),
  onLeave('On Leave', kInfo),
  probation('Probation', kWarning),
  terminated('Terminated', kNeutral);

  const EmployeeStatus(this.label, this.color);
  final String label;
  final Color color;
}

enum LeaveType {
  annual('Annual'),
  sick('Sick'),
  casual('Casual'),
  unpaid('Unpaid'),
  parental('Parental');

  const LeaveType(this.label);
  final String label;
}

enum RequestStatus {
  pending('Pending', kWarning),
  approved('Approved', kSuccess),
  rejected('Rejected', kDanger),
  cancelled('Cancelled', kNeutral);

  const RequestStatus(this.label, this.color);
  final String label;
  final Color color;
}

enum AttendanceStatus {
  present('Present', kSuccess),
  late('Late', kWarning),
  absent('Absent', kDanger),
  remote('Remote', kInfo),
  holiday('Holiday', kNeutral);

  const AttendanceStatus(this.label, this.color);
  final String label;
  final Color color;
}

enum PayrollStatus {
  draft('Draft', kNeutral),
  processing('Processing', kInfo),
  paid('Paid', kSuccess),
  failed('Failed', kDanger);

  const PayrollStatus(this.label, this.color);
  final String label;
  final Color color;
}

enum CandidateStage {
  applied('Applied', kNeutral),
  screening('Screening', kInfo),
  interview('Interview', kPurple),
  offer('Offer', kWarning),
  hired('Hired', kSuccess),
  rejected('Rejected', kDanger);

  const CandidateStage(this.label, this.color);
  final String label;
  final Color color;

  /// The next stage in the pipeline, or null at the ends.
  CandidateStage? get next => switch (this) {
        applied => screening,
        screening => interview,
        interview => offer,
        offer => hired,
        hired || rejected => null,
      };
}

enum ReviewStatus {
  notStarted('Not Started', kNeutral),
  selfReview('Self Review', kInfo),
  managerReview('Manager Review', kPurple),
  calibration('Calibration', kWarning),
  closed('Closed', kSuccess);

  const ReviewStatus(this.label, this.color);
  final String label;
  final Color color;
}

enum CourseStatus {
  notStarted('Not Started', kNeutral),
  inProgress('In Progress', kInfo),
  completed('Completed', kSuccess);

  const CourseStatus(this.label, this.color);
  final String label;
  final Color color;
}

enum AssetCondition {
  good('Good', kSuccess),
  fair('Fair', kWarning),
  poor('Poor', kDanger),
  retired('Retired', kNeutral);

  const AssetCondition(this.label, this.color);
  final String label;
  final Color color;
}

// ---------------------------------------------------------------------------
// Employee
// ---------------------------------------------------------------------------

class Employee {
  const Employee({
    required this.id,
    required this.name,
    required this.email,
    required this.jobTitle,
    required this.department,
    required this.manager,
    required this.location,
    required this.status,
    required this.hiredOn,
    required this.annualSalary,
    this.documents = const [],
  });

  final String id;
  final String name;
  final String email;
  final String jobTitle;
  final String department;

  /// Manager's name, or empty for the top of the tree.
  final String manager;
  final String location;
  final EmployeeStatus status;
  final DateTime hiredOn;

  /// Whole-currency amount; formatted at the call site.
  final int annualSalary;

  /// Uploaded document file names. No bytes are stored — this is a
  /// frontend-only demo — but add/remove is real against this list.
  final List<String> documents;

  Employee copyWith({
    String? name,
    String? email,
    String? jobTitle,
    String? department,
    String? manager,
    String? location,
    EmployeeStatus? status,
    DateTime? hiredOn,
    int? annualSalary,
    List<String>? documents,
  }) {
    return Employee(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      jobTitle: jobTitle ?? this.jobTitle,
      department: department ?? this.department,
      manager: manager ?? this.manager,
      location: location ?? this.location,
      status: status ?? this.status,
      hiredOn: hiredOn ?? this.hiredOn,
      annualSalary: annualSalary ?? this.annualSalary,
      documents: documents ?? this.documents,
    );
  }
}

// ---------------------------------------------------------------------------
// Attendance
// ---------------------------------------------------------------------------

class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.date,
    required this.checkIn,
    required this.checkOut,
    required this.status,
  });

  final String id;
  final String employeeId;
  final String employeeName;

  /// The day this record is for (time component ignored).
  final DateTime date;

  /// Null until the person checks in / out.
  final DateTime? checkIn;
  final DateTime? checkOut;
  final AttendanceStatus status;

  /// Worked duration, or null when incomplete.
  Duration? get worked => (checkIn != null && checkOut != null)
      ? checkOut!.difference(checkIn!)
      : null;

  AttendanceRecord copyWith({
    DateTime? checkIn,
    DateTime? checkOut,
    AttendanceStatus? status,
  }) {
    return AttendanceRecord(
      id: id,
      employeeId: employeeId,
      employeeName: employeeName,
      date: date,
      checkIn: checkIn ?? this.checkIn,
      checkOut: checkOut ?? this.checkOut,
      status: status ?? this.status,
    );
  }
}

// ---------------------------------------------------------------------------
// Leave
// ---------------------------------------------------------------------------

class LeaveRequest {
  const LeaveRequest({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.type,
    required this.from,
    required this.to,
    required this.reason,
    required this.status,
    required this.requestedOn,
    this.approver,
    this.decidedOn,
  });

  final String id;
  final String employeeId;
  final String employeeName;
  final LeaveType type;
  final DateTime from;
  final DateTime to;
  final String reason;
  final RequestStatus status;
  final DateTime requestedOn;

  /// Set when approved or rejected — who decided, and when.
  final String? approver;
  final DateTime? decidedOn;

  /// Inclusive day count.
  int get days => to.difference(from).inDays + 1;

  LeaveRequest copyWith({
    LeaveType? type,
    DateTime? from,
    DateTime? to,
    String? reason,
    RequestStatus? status,
    String? approver,
    DateTime? decidedOn,
  }) {
    return LeaveRequest(
      id: id,
      employeeId: employeeId,
      employeeName: employeeName,
      type: type ?? this.type,
      from: from ?? this.from,
      to: to ?? this.to,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      requestedOn: requestedOn,
      approver: approver ?? this.approver,
      decidedOn: decidedOn ?? this.decidedOn,
    );
  }
}

/// Per-employee leave balance, in days.
class LeaveBalance {
  const LeaveBalance({
    required this.employeeId,
    required this.employeeName,
    required this.entitlement,
    required this.taken,
  });

  final String employeeId;
  final String employeeName;
  final int entitlement;
  final int taken;

  int get remaining => entitlement - taken;
}

// ---------------------------------------------------------------------------
// Payroll
// ---------------------------------------------------------------------------

class PayrollRun {
  const PayrollRun({
    required this.id,
    required this.period,
    required this.status,
    required this.employeeCount,
    required this.grossTotal,
    required this.deductionsTotal,
    required this.processedOn,
  });

  final String id;

  /// Human label such as "March 2026".
  final String period;
  final PayrollStatus status;
  final int employeeCount;
  final int grossTotal;
  final int deductionsTotal;
  final DateTime? processedOn;

  int get netTotal => grossTotal - deductionsTotal;

  PayrollRun copyWith({
    PayrollStatus? status,
    int? employeeCount,
    int? grossTotal,
    int? deductionsTotal,
    DateTime? processedOn,
  }) {
    return PayrollRun(
      id: id,
      period: period,
      status: status ?? this.status,
      employeeCount: employeeCount ?? this.employeeCount,
      grossTotal: grossTotal ?? this.grossTotal,
      deductionsTotal: deductionsTotal ?? this.deductionsTotal,
      processedOn: processedOn ?? this.processedOn,
    );
  }
}

// ---------------------------------------------------------------------------
// Recruitment
// ---------------------------------------------------------------------------

class JobOpening {
  const JobOpening({
    required this.id,
    required this.title,
    required this.department,
    required this.location,
    required this.openings,
    required this.isOpen,
    required this.postedOn,
  });

  final String id;
  final String title;
  final String department;
  final String location;
  final int openings;
  final bool isOpen;
  final DateTime postedOn;

  JobOpening copyWith({
    String? title,
    String? department,
    String? location,
    int? openings,
    bool? isOpen,
  }) {
    return JobOpening(
      id: id,
      title: title ?? this.title,
      department: department ?? this.department,
      location: location ?? this.location,
      openings: openings ?? this.openings,
      isOpen: isOpen ?? this.isOpen,
      postedOn: postedOn,
    );
  }
}

class Candidate {
  const Candidate({
    required this.id,
    required this.name,
    required this.email,
    required this.jobId,
    required this.jobTitle,
    required this.stage,
    required this.appliedOn,
    this.rating = 0,
  });

  final String id;
  final String name;
  final String email;
  final String jobId;
  final String jobTitle;
  final CandidateStage stage;
  final DateTime appliedOn;

  /// 0..5; 0 means "not yet rated".
  final int rating;

  Candidate copyWith({
    String? name,
    String? email,
    String? jobId,
    String? jobTitle,
    CandidateStage? stage,
    int? rating,
  }) {
    return Candidate(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      jobId: jobId ?? this.jobId,
      jobTitle: jobTitle ?? this.jobTitle,
      stage: stage ?? this.stage,
      appliedOn: appliedOn,
      rating: rating ?? this.rating,
    );
  }
}

// ---------------------------------------------------------------------------
// Performance
// ---------------------------------------------------------------------------

class ReviewCycle {
  const ReviewCycle({
    required this.id,
    required this.name,
    required this.employeeId,
    required this.employeeName,
    required this.reviewer,
    required this.status,
    required this.dueOn,
    this.rating,
  });

  final String id;
  final String name;
  final String employeeId;
  final String employeeName;
  final String reviewer;
  final ReviewStatus status;
  final DateTime dueOn;

  /// 1..5, set once a review is submitted.
  final double? rating;

  ReviewCycle copyWith({
    String? name,
    String? reviewer,
    ReviewStatus? status,
    DateTime? dueOn,
    double? rating,
  }) {
    return ReviewCycle(
      id: id,
      name: name ?? this.name,
      employeeId: employeeId,
      employeeName: employeeName,
      reviewer: reviewer ?? this.reviewer,
      status: status ?? this.status,
      dueOn: dueOn ?? this.dueOn,
      rating: rating ?? this.rating,
    );
  }
}

// ---------------------------------------------------------------------------
// Learning
// ---------------------------------------------------------------------------

class Course {
  const Course({
    required this.id,
    required this.title,
    required this.category,
    required this.durationHours,
    required this.enrolledCount,
  });

  final String id;
  final String title;
  final String category;
  final int durationHours;
  final int enrolledCount;

  Course copyWith({
    String? title,
    String? category,
    int? durationHours,
    int? enrolledCount,
  }) {
    return Course(
      id: id,
      title: title ?? this.title,
      category: category ?? this.category,
      durationHours: durationHours ?? this.durationHours,
      enrolledCount: enrolledCount ?? this.enrolledCount,
    );
  }
}

class Enrollment {
  const Enrollment({
    required this.id,
    required this.courseId,
    required this.courseTitle,
    required this.employeeId,
    required this.employeeName,
    required this.status,
    required this.progress,
    required this.enrolledOn,
    this.certified = false,
  });

  final String id;
  final String courseId;
  final String courseTitle;
  final String employeeId;
  final String employeeName;
  final CourseStatus status;

  /// 0..1.
  final double progress;
  final DateTime enrolledOn;
  final bool certified;

  Enrollment copyWith({
    CourseStatus? status,
    double? progress,
    bool? certified,
  }) {
    return Enrollment(
      id: id,
      courseId: courseId,
      courseTitle: courseTitle,
      employeeId: employeeId,
      employeeName: employeeName,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      enrolledOn: enrolledOn,
      certified: certified ?? this.certified,
    );
  }
}

// ---------------------------------------------------------------------------
// Assets
// ---------------------------------------------------------------------------

class HrAsset {
  const HrAsset({
    required this.id,
    required this.tag,
    required this.name,
    required this.category,
    required this.assignedTo,
    required this.condition,
    required this.purchasedOn,
  });

  final String id;

  /// Asset tag such as "LToP-0142".
  final String tag;
  final String name;
  final String category;

  /// Employee name, or empty when unassigned / returned.
  final String assignedTo;
  final AssetCondition condition;
  final DateTime purchasedOn;

  HrAsset copyWith({
    String? tag,
    String? name,
    String? category,
    String? assignedTo,
    AssetCondition? condition,
  }) {
    return HrAsset(
      id: id,
      tag: tag ?? this.tag,
      name: name ?? this.name,
      category: category ?? this.category,
      assignedTo: assignedTo ?? this.assignedTo,
      condition: condition ?? this.condition,
      purchasedOn: purchasedOn,
    );
  }
}
