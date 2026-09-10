import 'package:flutter/material.dart';

import 'permissions.dart';

/// THE registry of OneCloud platform modules.
///
/// This file is the single source of truth for the module tree: what modules
/// exist, what pages each one has, where each page lives, and which permission
/// it needs. The router, the sidebar and the access guards all read from here,
/// so a new page is *one entry* — it cannot appear in the sidebar without a
/// route, or be routable without a permission check.
///
/// ponytail: a flat const list rather than a registration API or a code
/// generator. The table is data; iterating it is enough for every consumer.

/// A single navigable page inside a module.
@immutable
class ModulePage {
  const ModulePage({
    required this.slug,
    required this.title,
    required this.permission,
    this.icon,
  });

  /// Final URL segment, e.g. `employees` in `/hrms/employees`.
  final String slug;

  /// Label shown in the sidebar and as the page heading.
  final String title;

  /// The permission required to see and open this page. Every page has one —
  /// there is no "public once signed in" page, so nothing is reachable by
  /// omission.
  final String permission;

  /// Optional icon; sub-pages usually inherit the module's.
  final IconData? icon;
}

/// A top-level platform module, corresponding to one domain microservice.
@immutable
class PlatformModule {
  const PlatformModule({
    required this.id,
    required this.title,
    required this.icon,
    required this.pages,
    this.group = ModuleGroup.business,
    this.legacyPath,
  });

  /// URL segment and stable identity, e.g. `hrms` in `/hrms/employees`.
  final String id;

  final String title;
  final IconData icon;

  /// The module's pages, in sidebar order. The first is its landing page.
  final List<ModulePage> pages;

  /// Which sidebar heading this module sits under.
  final ModuleGroup group;

  /// A pre-existing top-level route that already serves this module's landing
  /// page, e.g. `/reports` for Reporting & BI.
  ///
  /// Set where a module's id would otherwise shadow a route that already
  /// exists and works. The legacy path stays canonical — it is what the
  /// sidebar links to and what the URL shows — so centralizing the module tree
  /// never produces two routes for one screen.
  final String? legacyPath;

  /// Base path, e.g. `/hrms`.
  String get path => '/$id';

  /// Where the module opens when selected: the legacy route when one owns
  /// this module's landing screen, else its first page.
  String get landingPath => legacyPath ?? '$path/${pages.first.slug}';

  /// Full path for one page, e.g. `/hrms/employees`.
  ///
  /// The first page resolves to [legacyPath] when set, so the existing screen
  /// keeps its URL and no second route points at the same content.
  String pathFor(ModulePage page) =>
      (legacyPath != null && page.slug == pages.first.slug)
          ? legacyPath!
          : '$path/${page.slug}';

  /// The union of the module's page permissions. A user who holds none of
  /// these cannot reach any page, so the module is hidden entirely.
  Set<String> get permissions => {for (final p in pages) p.permission};

  /// Looks up a page by slug, or null when the slug is unknown (→ 404).
  ModulePage? page(String slug) {
    for (final p in pages) {
      if (p.slug == slug) return p;
    }
    return null;
  }
}

/// Sidebar headings, in display order.
enum ModuleGroup {
  /// The dashboard itself — sits above every heading.
  overview('OVERVIEW'),
  business('BUSINESS'),
  operations('OPERATIONS'),
  intelligence('INTELLIGENCE'),
  platform('PLATFORM');

  const ModuleGroup(this.label);
  final String label;
}

/// Every module in the platform. Order here is sidebar order.
const List<PlatformModule> kModules = [
  // --- Platform administration ---------------------------------------------
  PlatformModule(
    id: 'admin',
    title: 'Platform Administration',
    icon: Icons.admin_panel_settings_outlined,
    group: ModuleGroup.platform,
    pages: [
      ModulePage(
          slug: 'overview', title: 'Admin Dashboard', permission: Perm.adminView),
      ModulePage(slug: 'users', title: 'Users', permission: Perm.adminUsers),
      ModulePage(slug: 'roles', title: 'Roles', permission: Perm.adminRoles),
      ModulePage(
          slug: 'permissions', title: 'Permissions', permission: Perm.adminRoles),
      ModulePage(
          slug: 'organizations',
          title: 'Organizations',
          permission: Perm.adminTenants),
      ModulePage(
          slug: 'tenants', title: 'Tenant Management', permission: Perm.adminTenants),
      ModulePage(
          slug: 'settings', title: 'Platform Settings', permission: Perm.adminSettings),
    ],
  ),

  // --- HRMS ------------------------------------------------------------------
  PlatformModule(
    id: 'hrms',
    title: 'HRMS',
    icon: Icons.badge_outlined,
    group: ModuleGroup.business,
    pages: [
      ModulePage(
          slug: 'overview', title: 'HR Dashboard', permission: Perm.hrmsView),
      ModulePage(
          slug: 'employees', title: 'Employees', permission: Perm.hrmsEmployees),
      ModulePage(
          slug: 'attendance', title: 'Attendance', permission: Perm.hrmsAttendance),
      ModulePage(slug: 'leave', title: 'Leave', permission: Perm.hrmsLeave),
      ModulePage(slug: 'payroll', title: 'Payroll', permission: Perm.hrmsPayroll),
      ModulePage(
          slug: 'recruitment',
          title: 'Recruitment',
          permission: Perm.hrmsRecruitment),
      ModulePage(
          slug: 'performance', title: 'Performance', permission: Perm.hrmsView),
      ModulePage(slug: 'learning', title: 'Learning', permission: Perm.hrmsView),
      ModulePage(slug: 'assets', title: 'Assets', permission: Perm.hrmsView),
    ],
  ),

  // --- CRM -------------------------------------------------------------------
  PlatformModule(
    id: 'crm',
    title: 'CRM',
    icon: Icons.handshake_outlined,
    group: ModuleGroup.business,
    pages: [
      ModulePage(
          slug: 'overview', title: 'CRM Dashboard', permission: Perm.crmView),
      ModulePage(slug: 'leads', title: 'Leads', permission: Perm.crmLeads),
      ModulePage(
          slug: 'opportunities',
          title: 'Opportunities',
          permission: Perm.crmOpportunities),
      ModulePage(slug: 'accounts', title: 'Accounts', permission: Perm.crmAccounts),
      ModulePage(slug: 'contacts', title: 'Contacts', permission: Perm.crmAccounts),
      ModulePage(slug: 'activities', title: 'Activities', permission: Perm.crmView),
      ModulePage(slug: 'tickets', title: 'Tickets', permission: Perm.crmTickets),
      ModulePage(slug: 'campaigns', title: 'Campaigns', permission: Perm.crmView),
    ],
  ),

  // --- ERP -------------------------------------------------------------------
  PlatformModule(
    id: 'erp',
    title: 'ERP',
    icon: Icons.inventory_2_outlined,
    group: ModuleGroup.operations,
    pages: [
      ModulePage(
          slug: 'overview', title: 'ERP Dashboard', permission: Perm.erpView),
      ModulePage(
          slug: 'inventory', title: 'Inventory', permission: Perm.erpInventory),
      ModulePage(slug: 'products', title: 'Products', permission: Perm.erpInventory),
      ModulePage(
          slug: 'procurement',
          title: 'Procurement',
          permission: Perm.erpProcurement),
      ModulePage(slug: 'vendors', title: 'Vendors', permission: Perm.erpProcurement),
      ModulePage(slug: 'production', title: 'Production', permission: Perm.erpView),
      ModulePage(slug: 'orders', title: 'Orders', permission: Perm.erpOrders),
      ModulePage(slug: 'dispatch', title: 'Dispatch', permission: Perm.erpOrders),
      ModulePage(slug: 'maintenance', title: 'Maintenance', permission: Perm.erpView),
    ],
  ),

  // --- Finance ---------------------------------------------------------------
  PlatformModule(
    id: 'finance',
    title: 'Finance & Accounting',
    icon: Icons.account_balance_outlined,
    group: ModuleGroup.business,
    pages: [
      ModulePage(
          slug: 'overview',
          title: 'Finance Dashboard',
          permission: Perm.financeView),
      ModulePage(
          slug: 'ledger', title: 'General Ledger', permission: Perm.financeLedger),
      ModulePage(
          slug: 'accounts', title: 'Chart of Accounts', permission: Perm.financeLedger),
      ModulePage(
          slug: 'payable',
          title: 'Accounts Payable',
          permission: Perm.financeInvoices),
      ModulePage(
          slug: 'receivable',
          title: 'Accounts Receivable',
          permission: Perm.financeInvoices),
      ModulePage(
          slug: 'invoices', title: 'Invoices', permission: Perm.financeInvoices),
      ModulePage(
          slug: 'payments', title: 'Payments', permission: Perm.financePayments),
      ModulePage(slug: 'tax', title: 'Tax', permission: Perm.financeView),
      ModulePage(slug: 'budgets', title: 'Budgets', permission: Perm.financeView),
    ],
  ),

  // --- Workflow --------------------------------------------------------------
  PlatformModule(
    id: 'workflow',
    title: 'Workflow & Automation',
    icon: Icons.account_tree_outlined,
    group: ModuleGroup.operations,
    pages: [
      ModulePage(
          slug: 'overview',
          title: 'Workflow Dashboard',
          permission: Perm.workflowView),
      ModulePage(
          slug: 'builder', title: 'Workflow Builder', permission: Perm.workflowBuild),
      ModulePage(
          slug: 'approvals', title: 'Approvals', permission: Perm.workflowApprove),
      ModulePage(slug: 'tasks', title: 'My Tasks', permission: Perm.workflowView),
      ModulePage(
          slug: 'automation',
          title: 'Automation Rules',
          permission: Perm.workflowBuild),
      ModulePage(slug: 'runs', title: 'Workflow Runs', permission: Perm.workflowView),
    ],
  ),

  // --- Documents -------------------------------------------------------------
  PlatformModule(
    id: 'documents',
    title: 'Document Management',
    icon: Icons.folder_copy_outlined,
    group: ModuleGroup.operations,
    pages: [
      ModulePage(
          slug: 'overview', title: 'Documents', permission: Perm.documentsView),
      ModulePage(slug: 'folders', title: 'Folders', permission: Perm.documentsView),
      ModulePage(
          slug: 'approvals', title: 'Approvals', permission: Perm.documentsApprove),
      ModulePage(slug: 'versions', title: 'Versions', permission: Perm.documentsView),
      ModulePage(
          slug: 'retention', title: 'Retention', permission: Perm.documentsApprove),
    ],
  ),

  // --- Subscriptions ---------------------------------------------------------
  PlatformModule(
    id: 'subscriptions',
    title: 'Subscriptions',
    icon: Icons.card_membership_outlined,
    group: ModuleGroup.business,
    pages: [
      ModulePage(
          slug: 'overview',
          title: 'Subscription Dashboard',
          permission: Perm.subscriptionsView),
      ModulePage(slug: 'plans', title: 'Plans', permission: Perm.subscriptionsView),
      ModulePage(
          slug: 'list', title: 'Subscriptions', permission: Perm.subscriptionsView),
      ModulePage(slug: 'usage', title: 'Usage', permission: Perm.subscriptionsView),
      ModulePage(
          slug: 'renewals', title: 'Renewals', permission: Perm.subscriptionsManage),
      ModulePage(
          slug: 'billing', title: 'Billing', permission: Perm.subscriptionsManage),
    ],
  ),

  // --- Revenue ---------------------------------------------------------------
  PlatformModule(
    id: 'revenue',
    title: 'Revenue',
    icon: Icons.trending_up_outlined,
    group: ModuleGroup.intelligence,
    pages: [
      ModulePage(
          slug: 'overview', title: 'Revenue Dashboard', permission: Perm.revenueView),
      ModulePage(slug: 'analytics', title: 'Analytics', permission: Perm.revenueView),
      ModulePage(slug: 'forecast', title: 'Forecast', permission: Perm.revenueView),
      ModulePage(
          slug: 'recognition', title: 'Recognition', permission: Perm.revenueView),
    ],
  ),

  // --- Reporting -------------------------------------------------------------
  PlatformModule(
    id: 'reports',
    title: 'Reporting & BI',
    icon: Icons.insights_outlined,
    group: ModuleGroup.intelligence,
    // /reports already renders the built Reports screen.
    legacyPath: '/reports',
    pages: [
      ModulePage(slug: 'overview', title: 'Reports', permission: Perm.reportsView),
      ModulePage(
          slug: 'standard', title: 'Standard Reports', permission: Perm.reportsView),
      ModulePage(slug: 'builder', title: 'Report Builder', permission: Perm.reportsBuild),
      ModulePage(
          slug: 'dashboards', title: 'Dashboards', permission: Perm.reportsView),
      ModulePage(
          slug: 'scheduled', title: 'Scheduled Reports', permission: Perm.reportsBuild),
    ],
  ),

  // --- Enterprise AI ---------------------------------------------------------
  PlatformModule(
    id: 'ai',
    title: 'Enterprise AI',
    icon: Icons.auto_awesome_outlined,
    group: ModuleGroup.intelligence,
    pages: [
      ModulePage(slug: 'overview', title: 'AI Dashboard', permission: Perm.aiView),
      ModulePage(slug: 'assistant', title: 'AI Assistant', permission: Perm.aiView),
      ModulePage(slug: 'insights', title: 'AI Insights', permission: Perm.aiView),
      ModulePage(slug: 'predictions', title: 'Predictions', permission: Perm.aiView),
      ModulePage(slug: 'models', title: 'AI Models', permission: Perm.aiModels),
      ModulePage(slug: 'usage', title: 'AI Usage', permission: Perm.aiModels),
    ],
  ),

  // --- Notifications ---------------------------------------------------------
  PlatformModule(
    id: 'notifications',
    title: 'Notifications',
    icon: Icons.notifications_none,
    group: ModuleGroup.platform,
    // /notifications already renders the built Notification Center.
    legacyPath: '/notifications',
    pages: [
      ModulePage(
          slug: 'center',
          title: 'Notification Center',
          permission: Perm.notificationsView),
      ModulePage(
          slug: 'templates', title: 'Templates', permission: Perm.notificationsView),
      ModulePage(
          slug: 'preferences',
          title: 'Preferences',
          permission: Perm.notificationsView),
      ModulePage(
          slug: 'history', title: 'History', permission: Perm.notificationsView),
    ],
  ),

  // --- Calendar --------------------------------------------------------------
  PlatformModule(
    id: 'calendar',
    title: 'Calendar',
    icon: Icons.calendar_month_outlined,
    group: ModuleGroup.platform,
    pages: [
      ModulePage(slug: 'overview', title: 'Calendar', permission: Perm.calendarView),
      ModulePage(slug: 'events', title: 'Events', permission: Perm.calendarView),
      ModulePage(slug: 'meetings', title: 'Meetings', permission: Perm.calendarView),
      ModulePage(
          slug: 'resources', title: 'Resource Booking', permission: Perm.calendarView),
    ],
  ),

  // --- Integrations ----------------------------------------------------------
  PlatformModule(
    id: 'integrations',
    title: 'Integration',
    icon: Icons.hub_outlined,
    group: ModuleGroup.platform,
    pages: [
      ModulePage(
          slug: 'overview', title: 'Integrations', permission: Perm.integrationsView),
      ModulePage(
          slug: 'webhooks', title: 'Webhooks', permission: Perm.integrationsManage),
      ModulePage(
          slug: 'sync', title: 'Sync Jobs', permission: Perm.integrationsManage),
      ModulePage(slug: 'logs', title: 'Logs', permission: Perm.integrationsView),
    ],
  ),

  // --- Security --------------------------------------------------------------
  PlatformModule(
    id: 'security',
    title: 'Security & Compliance',
    icon: Icons.shield_outlined,
    group: ModuleGroup.platform,
    pages: [
      ModulePage(
          slug: 'overview',
          title: 'Security Dashboard',
          permission: Perm.securityView),
      ModulePage(
          slug: 'audit', title: 'Audit Logs', permission: Perm.securityAudit),
      ModulePage(
          slug: 'compliance', title: 'Compliance', permission: Perm.securityView),
      ModulePage(slug: 'policies', title: 'Policies', permission: Perm.securityView),
      ModulePage(
          slug: 'retention', title: 'Data Retention', permission: Perm.securityView),
      ModulePage(
          slug: 'alerts', title: 'Security Alerts', permission: Perm.securityView),
    ],
  ),
];

/// Index by id, built once. Route resolution is a map lookup, not a scan.
final Map<String, PlatformModule> kModulesById = {
  for (final m in kModules) m.id: m,
};

/// Modules under one sidebar heading, in registry order.
List<PlatformModule> modulesInGroup(ModuleGroup group) =>
    [for (final m in kModules) if (m.group == group) m];

/// The modules a principal may see at all. Used by the sidebar so a user is
/// never shown a heading they cannot open, and by the guard that picks a
/// landing page after sign-in.
List<PlatformModule> visibleModules(PermissionSet perms) =>
    [for (final m in kModules) if (perms.canAny(m.permissions)) m];

/// The pages of [module] this principal may open.
List<ModulePage> visiblePages(PlatformModule module, PermissionSet perms) =>
    [for (final p in module.pages) if (perms.can(p.permission)) p];
