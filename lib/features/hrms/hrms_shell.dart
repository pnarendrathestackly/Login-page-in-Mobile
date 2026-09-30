import 'package:flutter/material.dart';

import '../../core/platform/modules.dart';
import 'hrms_controller.dart';
import 'screens/assets_screen.dart';
import 'screens/attendance_screen.dart';
import 'screens/employees_screen.dart';
import 'screens/ess_screen.dart';
import 'screens/hrms_overview_screen.dart';
import 'screens/leave_screen.dart';
import 'screens/learning_screen.dart';
import 'screens/payroll_screen.dart';
import 'screens/performance_screen.dart';
import 'screens/recruitment_screen.dart';

/// Maps an HRMS [ModulePage] to its implemented screen. Returns null for slugs
/// that don't have one yet, so the caller can fall back to the generic
/// placeholder — nothing here fakes a screen that isn't built.
///
/// The `hrms` controller (repository + audit log) is created once per session
/// by the dashboard shell and threaded through here.
Widget? hrmsScreenFor(HrmsController hrms, ModulePage page) {
  return switch (page.slug) {
    'overview' => HrmsOverviewScreen(hrms: hrms),
    'employees' => EmployeesScreen(hrms: hrms),
    'attendance' => AttendanceScreen(hrms: hrms),
    'leave' => LeaveScreen(hrms: hrms),
    'payroll' => PayrollScreen(hrms: hrms),
    'recruitment' => RecruitmentScreen(hrms: hrms),
    'performance' => PerformanceScreen(hrms: hrms),
    'learning' => LearningScreen(hrms: hrms),
    'ess' => EssScreen(hrms: hrms),
    'assets' => AssetsScreen(hrms: hrms),
    _ => null,
  };
}
