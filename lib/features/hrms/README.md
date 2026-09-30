# HRMS — functionality matrix

Frontend-only implementation. All state lives in `DemoHrmsRepository`
(in-memory, mutating, resets on restart). Every mutation records an
`AuditEntry` via `HrmsController.audit`. Routes are guarded by the existing
RBAC layer (`hrms.*` permissions in `core/platform/permissions.dart`); the
dashboard shell dispatches `/hrms/<slug>` to `hrmsScreenFor()`.

| Page | Route | CRUD | Search | Filters | Sort | Paging | Domain actions | Audit |
|---|---|---|---|---|---|---|---|---|
| HR Dashboard | `/hrms/overview` | — (read) | — | — | — | — | live KPIs from repo; activity feed from audit log | reads |
| Employees | `/hrms/employees` | C R U D | name/email/title/dept | department, status | all cols | 8/pg | change status, upload document, view audit history | ✅ |
| Attendance | `/hrms/attendance` | R U (+create via check-in) | employee | status | all cols | 8/pg | check-in / check-out, correct times, export CSV | ✅ |
| Leave | `/hrms/leave` | C R U (cancel) | employee/reason | type, status | all cols | 8/pg | approve / reject (records approver + timestamp, draws balance), cancel | ✅ |
| Payroll | `/hrms/payroll` | C R U | period | status | all cols | 8/pg | process draft → paid, export CSV, payslip summary | ✅ |
| Recruitment · Jobs | `/hrms/recruitment` | C R U (close/reopen) | title/dept/location | — | all cols | 8/pg | open / close job | ✅ |
| Recruitment · Candidates | `/hrms/recruitment` | C R U | name/email/role | stage | all cols | 8/pg | advance stage, reject, rate; **hire creates an Employee** | ✅ |
| Performance | `/hrms/performance` | C R U | employee/reviewer/cycle | status | all cols | 8/pg | advance workflow, submit rating on close | ✅ |
| Learning · Courses | `/hrms/learning` | C R U | title/category | — | all cols | 8/pg | — | ✅ |
| Learning · Enrollments | `/hrms/learning` | C R U | employee/course | status | all cols | 8/pg | set progress; 100% completes + issues certificate | ✅ |
| ESS / MSS | `/hrms/ess` | R (+request leave) | — | — | — | — | request leave; managers approve/reject reports' leave | ✅ |
| Assets | `/hrms/assets` | C R U D | tag/name/holder | category, condition | all cols | 8/pg | assign / transfer / return, change condition, retire | ✅ |

## Cross-entity relationships wired

- Hire a candidate → new `Employee` (probation) + fresh 25-day leave balance.
- Approve paid leave → employee's `LeaveBalance.taken` recomputed.
- Enrol an employee → course `enrolledCount` incremented.
- Complete an enrollment (100%) → `certified = true`.
- Retire an asset → holder cleared.
- Any HRMS mutation → audit entry → HR Dashboard activity feed refreshes.

## Known limitations

- **No persistence.** Restarting the app resets all data.
- **Export produces CSV text, not a file.** `toCsv()` builds RFC-4180 text and
  the UI confirms row count; wiring an actual download needs a platform target
  (`dart:html` anchor on web, a share/save plugin on mobile). Marked
  `ponytail:` in `hrms_controller.dart`.
- **Document upload stores the file name only**, no bytes — frontend-only.
- Widget tests cover the data layer (`test/hrms_test.dart`, 17 tests). Screen
  widgets are exercised by the existing `rbac_flow_test` mount and manually.
