/// Centralized permission vocabulary for the OneCloud platform.
///
/// Permissions are plain strings in `module.action` form so they can travel
/// over the wire from a real identity service without a translation layer.
/// Nothing in the app hardcodes a permission literal — every check names a
/// constant from [Perm], so a typo is a compile error rather than a silently
/// failing authorization check that lets a user through.
///
/// SECURITY: these checks are UX guards. They decide what a signed-in user is
/// shown, not what the server will do. Every one of them must be enforced
/// again server-side; a client the user controls can be made to claim any
/// permission set it likes.
library;

import 'package:flutter/foundation.dart';

/// Every permission the platform recognises.
///
/// Grouped by module, mirroring the service boundaries in the architecture:
/// one module's permissions never gate another module's screens.
class Perm {
  const Perm._();

  // --- Platform administration ---------------------------------------------
  static const adminView = 'admin.view';
  static const adminUsers = 'admin.users';
  static const adminRoles = 'admin.roles';
  static const adminTenants = 'admin.tenants';
  static const adminSettings = 'admin.settings';

  // --- HRMS -----------------------------------------------------------------
  static const hrmsView = 'hrms.view';
  static const hrmsEmployees = 'hrms.employees';
  static const hrmsAttendance = 'hrms.attendance';
  static const hrmsLeave = 'hrms.leave';
  static const hrmsPayroll = 'hrms.payroll';
  static const hrmsRecruitment = 'hrms.recruitment';

  // --- CRM ------------------------------------------------------------------
  static const crmView = 'crm.view';
  static const crmLeads = 'crm.leads';
  static const crmOpportunities = 'crm.opportunities';
  static const crmAccounts = 'crm.accounts';
  static const crmTickets = 'crm.tickets';

  // --- ERP ------------------------------------------------------------------
  static const erpView = 'erp.view';
  static const erpInventory = 'erp.inventory';
  static const erpProcurement = 'erp.procurement';
  static const erpOrders = 'erp.orders';

  // --- Finance --------------------------------------------------------------
  static const financeView = 'finance.view';
  static const financeLedger = 'finance.ledger';
  static const financeInvoices = 'finance.invoices';
  static const financePayments = 'finance.payments';
  /// Approving money movement is deliberately separate from recording it, so
  /// the same person cannot both raise and approve a payment.
  static const financeApprove = 'finance.approve';

  // --- Workflow -------------------------------------------------------------
  static const workflowView = 'workflow.view';
  static const workflowBuild = 'workflow.build';
  static const workflowApprove = 'workflow.approve';

  // --- Documents ------------------------------------------------------------
  static const documentsView = 'documents.view';
  static const documentsUpload = 'documents.upload';
  static const documentsApprove = 'documents.approve';

  // --- Subscriptions & revenue ---------------------------------------------
  static const subscriptionsView = 'subscriptions.view';
  static const subscriptionsManage = 'subscriptions.manage';
  static const revenueView = 'revenue.view';

  // --- Reporting ------------------------------------------------------------
  static const reportsView = 'reports.view';
  static const reportsBuild = 'reports.build';

  // --- AI -------------------------------------------------------------------
  static const aiView = 'ai.view';
  static const aiModels = 'ai.models';

  // --- Platform-wide surfaces ----------------------------------------------
  static const notificationsView = 'notifications.view';
  static const calendarView = 'calendar.view';
  static const integrationsView = 'integrations.view';
  static const integrationsManage = 'integrations.manage';
  static const searchView = 'search.view';
  static const securityView = 'security.view';
  static const securityAudit = 'security.audit';

  // --- Self-service ---------------------------------------------------------
  /// Held by every authenticated principal, including customers and partners.
  static const selfService = 'self.service';

  /// Wildcard held only by Super Admin. [PermissionSet.can] short-circuits on
  /// it, so a new permission does not need adding to that role.
  static const all = '*';
}

/// The roles the platform ships with.
///
/// Roles are a *convenience grouping* over permissions, not a second
/// authorization mechanism: everything downstream checks permissions, never
/// `role == 'x'`. That keeps roles configurable — a deployment can add one
/// without touching a single screen.
enum PlatformRole {
  superAdmin('Super Admin', {Perm.all}),

  platformAdmin('Platform Admin', {
    Perm.adminView, Perm.adminUsers, Perm.adminRoles, Perm.adminTenants,
    Perm.adminSettings, Perm.securityView, Perm.integrationsView,
    Perm.integrationsManage, Perm.notificationsView, Perm.searchView,
    Perm.calendarView, Perm.reportsView, Perm.aiView, Perm.aiModels,
    Perm.selfService,
  }),

  hrAdmin('HR Admin', {
    Perm.hrmsView, Perm.hrmsEmployees, Perm.hrmsAttendance, Perm.hrmsLeave,
    Perm.hrmsPayroll, Perm.hrmsRecruitment, Perm.reportsView,
    Perm.documentsView, Perm.notificationsView, Perm.calendarView,
    Perm.searchView, Perm.selfService,
  }),

  hrManager('HR Manager', {
    Perm.hrmsView, Perm.hrmsEmployees, Perm.hrmsAttendance, Perm.hrmsLeave,
    Perm.hrmsRecruitment, Perm.reportsView, Perm.notificationsView,
    Perm.calendarView, Perm.searchView, Perm.selfService,
  }),

  financeAdmin('Finance Admin', {
    Perm.financeView, Perm.financeLedger, Perm.financeInvoices,
    Perm.financePayments, Perm.financeApprove, Perm.revenueView,
    Perm.subscriptionsView, Perm.subscriptionsManage, Perm.reportsView,
    Perm.documentsView,
    Perm.notificationsView, Perm.calendarView, Perm.searchView,
    Perm.selfService,
  }),

  financeManager('Finance Manager', {
    Perm.financeView, Perm.financeLedger, Perm.financeInvoices,
    Perm.revenueView, Perm.reportsView, Perm.notificationsView,
    Perm.calendarView, Perm.searchView, Perm.selfService,
  }),

  salesManager('Sales Manager', {
    Perm.crmView, Perm.crmLeads, Perm.crmOpportunities, Perm.crmAccounts,
    Perm.crmTickets, Perm.reportsView, Perm.revenueView,
    Perm.notificationsView, Perm.calendarView, Perm.searchView,
    Perm.selfService,
  }),

  operationsManager('Operations Manager', {
    Perm.erpView, Perm.erpInventory, Perm.erpProcurement, Perm.erpOrders,
    Perm.workflowView, Perm.workflowApprove, Perm.workflowBuild,
    Perm.reportsView, Perm.notificationsView, Perm.calendarView,
    Perm.searchView, Perm.selfService,
  }),

  documentManager('Document Manager', {
    Perm.documentsView, Perm.documentsUpload, Perm.documentsApprove,
    Perm.workflowView, Perm.notificationsView, Perm.searchView,
    Perm.calendarView, Perm.selfService,
  }),

  securityAdmin('Security Admin', {
    Perm.securityView, Perm.securityAudit, Perm.adminView,
    Perm.notificationsView, Perm.searchView, Perm.selfService,
  }),

  subscriptionManager('Subscription Manager', {
    Perm.subscriptionsView, Perm.subscriptionsManage, Perm.revenueView,
    Perm.reportsView, Perm.notificationsView, Perm.searchView,
    Perm.calendarView, Perm.selfService,
  }),

  revenueManager('Revenue Manager', {
    Perm.revenueView, Perm.subscriptionsView, Perm.reportsView,
    Perm.financeView, Perm.notificationsView, Perm.searchView,
    Perm.calendarView, Perm.selfService,
  }),

  /// Read-and-build access to reporting, without access to the underlying
  /// domain modules — a analyst who may chart data they cannot administer.
  reportingUser('Reporting User', {
    Perm.reportsView, Perm.reportsBuild, Perm.aiView, Perm.notificationsView,
    Perm.searchView, Perm.calendarView, Perm.selfService,
  }),

  employee('Employee', {
    Perm.hrmsView, Perm.notificationsView, Perm.calendarView,
    Perm.documentsView, Perm.searchView, Perm.aiView, Perm.selfService,
  }),

  customer('Customer', {
    Perm.subscriptionsView, Perm.documentsView, Perm.notificationsView,
    Perm.selfService,
  }),

  partner('Partner', {
    Perm.documentsView, Perm.notificationsView, Perm.selfService,
  });

  const PlatformRole(this.label, this.permissions);

  /// Human-readable name, shown in the header's role indicator.
  final String label;

  /// What this role may do. Resolved into a [PermissionSet] at sign-in.
  final Set<String> permissions;

  /// Parses a role name coming from a backend. Unknown roles fall back to the
  /// least-privileged option rather than to an admin — an unrecognised value
  /// must never widen access.
  static PlatformRole parse(String? name) {
    if (name == null) return PlatformRole.employee;
    final normalized = name.trim().toLowerCase();
    for (final role in PlatformRole.values) {
      if (role.label.toLowerCase() == normalized || role.name == normalized) {
        return role;
      }
    }
    return PlatformRole.employee;
  }
}

/// An immutable, resolved set of permissions for the signed-in principal.
///
/// Built once at sign-in from the roles the backend returns. Every guard in
/// the app asks this object rather than inspecting roles directly.
@immutable
class PermissionSet {
  const PermissionSet(this._granted);

  /// Nobody signed in: grants nothing. The safe default, so any code path that
  /// forgets to populate permissions denies rather than allows.
  const PermissionSet.empty() : _granted = const {};

  /// Resolves the union of several roles — a user may hold more than one.
  factory PermissionSet.forRoles(Iterable<PlatformRole> roles) =>
      PermissionSet({for (final r in roles) ...r.permissions});

  final Set<String> _granted;

  Set<String> get granted => Set.unmodifiable(_granted);

  bool get isEmpty => _granted.isEmpty;

  /// True if the principal holds [permission]. The `*` wildcard grants
  /// everything, which is how Super Admin stays correct as modules are added.
  bool can(String permission) =>
      _granted.contains(Perm.all) || _granted.contains(permission);

  /// True if the principal holds *any* of [permissions]. Used by module-level
  /// guards: a module is reachable when at least one of its pages is.
  bool canAny(Iterable<String> permissions) {
    if (_granted.contains(Perm.all)) return true;
    for (final p in permissions) {
      if (_granted.contains(p)) return true;
    }
    return false;
  }

  /// True only if the principal holds every one of [permissions]. For actions
  /// that legitimately require two grants, such as raising *and* approving.
  bool canAll(Iterable<String> permissions) {
    if (_granted.contains(Perm.all)) return true;
    return permissions.every(_granted.contains);
  }

  @override
  bool operator ==(Object other) =>
      other is PermissionSet &&
      other._granted.length == _granted.length &&
      other._granted.containsAll(_granted);

  @override
  int get hashCode => Object.hashAllUnordered(_granted);
}
