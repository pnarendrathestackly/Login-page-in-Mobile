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

  /// Material fallback icon. Used wherever [logoAsset] is null, and as the
  /// error/placeholder while the asset loads.
  final IconData icon;

  /// Bundled logo for this module, resolved from [_moduleLogos] by [id]. Null
  /// when the module has no artwork yet, in which case [icon] is shown.
  String? get logoAsset => _moduleLogos[id];

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

/// Bundled sidebar logo per module id. Files live in `assets/` and are
/// registered in `pubspec.yaml`. A module id absent here falls back to its
/// Material [PlatformModule.icon].
const Map<String, String> _moduleLogos = {
  'admin': 'assets/platform_Administration_Service.png',
  'hrms': 'assets/HRMS Service.png',
  'crm': 'assets/CRM Service.png',
  'erp': 'assets/ERP Service.png',
  'finance': 'assets/Finance & Accounting Service.png',
  'workflow': 'assets/Workflow & Automation service.png',
  'documents': 'assets/Document Management service.png',
  'subscriptions': 'assets/subscription service .png',
  'revenue': 'assets/Revenue Service .png',
  'reports': 'assets/Reporting & BI service .png',
  'ai': 'assets/Enterprise AI service.png',
  'notifications': 'assets/Notification service .png',
  'calendar': 'assets/calendar service.png',
  'integrations': 'assets/integration service.png',
  'search': 'assets/search service.png',
  'security': 'assets/security & compliances service.png',
};

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
        slug: 'overview',
        title: 'Admin Dashboard',
        permission: Perm.adminView,
        icon: Icons.space_dashboard_outlined,
      ),
      ModulePage(
        slug: 'global',
        title: 'Global Dashboard',
        permission: Perm.adminView,
        icon: Icons.public,
      ),
      ModulePage(
        slug: 'branding',
        title: 'Platform Branding',
        permission: Perm.adminSettings,
        icon: Icons.brush_outlined,
      ),
      ModulePage(
        slug: 'users',
        title: 'Users',
        permission: Perm.adminUsers,
        icon: Icons.people_outline,
      ),
      ModulePage(
        slug: 'roles',
        title: 'Roles',
        permission: Perm.adminRoles,
        icon: Icons.badge_outlined,
      ),
      ModulePage(
        slug: 'permissions',
        title: 'Permissions',
        permission: Perm.adminRoles,
        icon: Icons.lock_outline,
      ),
      ModulePage(
        slug: 'organizations',
        title: 'Organizations',
        permission: Perm.adminTenants,
        icon: Icons.corporate_fare_outlined,
      ),
      ModulePage(
        slug: 'tenants',
        title: 'Tenant Management',
        permission: Perm.adminTenants,
        icon: Icons.apartment_outlined,
      ),
      ModulePage(
        slug: 'settings',
        title: 'Platform Settings',
        permission: Perm.adminSettings,
        icon: Icons.settings_outlined,
      ),
      ModulePage(
        slug: 'licenses',
        title: 'License Management',
        permission: Perm.adminSettings,
        icon: Icons.vpn_key_outlined,
      ),
      ModulePage(
        slug: 'features',
        title: 'Feature Management',
        permission: Perm.adminSettings,
        icon: Icons.toggle_on_outlined,
      ),
      ModulePage(
        slug: 'resources',
        title: 'Resource Management',
        permission: Perm.adminSettings,
        icon: Icons.memory_outlined,
      ),
      ModulePage(
        slug: 'health',
        title: 'System Health',
        permission: Perm.adminView,
        icon: Icons.monitor_heart_outlined,
      ),
      ModulePage(
        slug: 'tenant-templates',
        title: 'Tenant Templates',
        permission: Perm.adminTenants,
        icon: Icons.copy_all_outlined,
      ),
      ModulePage(
        slug: 'global-settings',
        title: 'Global Settings',
        permission: Perm.adminSettings,
        icon: Icons.tune,
      ),
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
        slug: 'overview',
        title: 'HR Dashboard',
        permission: Perm.hrmsView,
        icon: Icons.space_dashboard_outlined,
      ),
      ModulePage(
        slug: 'employees',
        title: 'Employees',
        permission: Perm.hrmsEmployees,
        icon: Icons.people_outline,
      ),
      ModulePage(
        slug: 'attendance',
        title: 'Attendance',
        permission: Perm.hrmsAttendance,
        icon: Icons.how_to_reg_outlined,
      ),
      ModulePage(
        slug: 'leave',
        title: 'Leave',
        permission: Perm.hrmsLeave,
        icon: Icons.event_busy_outlined,
      ),
      ModulePage(
        slug: 'payroll',
        title: 'Payroll',
        permission: Perm.hrmsPayroll,
        icon: Icons.payments_outlined,
      ),
      ModulePage(
        slug: 'recruitment',
        title: 'Recruitment',
        permission: Perm.hrmsRecruitment,
        icon: Icons.person_search_outlined,
      ),
      ModulePage(
        slug: 'performance',
        title: 'Performance',
        permission: Perm.hrmsView,
        icon: Icons.trending_up,
      ),
      ModulePage(
        slug: 'learning',
        title: 'Learning',
        permission: Perm.hrmsView,
        icon: Icons.school_outlined,
      ),
      ModulePage(
        slug: 'assets',
        title: 'Assets',
        permission: Perm.hrmsView,
        icon: Icons.devices_outlined,
      ),
      ModulePage(
        slug: 'ess',
        title: 'ESS / MSS',
        permission: Perm.hrmsView,
        icon: Icons.manage_accounts_outlined,
      ),
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
        slug: 'overview',
        title: 'CRM Dashboard',
        permission: Perm.crmView,
        icon: Icons.space_dashboard_outlined,
      ),
      ModulePage(
        slug: 'leads',
        title: 'Leads',
        permission: Perm.crmLeads,
        icon: Icons.person_add_alt_outlined,
      ),
      ModulePage(
        slug: 'opportunities',
        title: 'Opportunities',
        permission: Perm.crmOpportunities,
        icon: Icons.handshake_outlined,
      ),
      ModulePage(
        slug: 'accounts',
        title: 'Accounts',
        permission: Perm.crmAccounts,
        icon: Icons.business_outlined,
      ),
      ModulePage(
        slug: 'contacts',
        title: 'Contacts',
        permission: Perm.crmAccounts,
        icon: Icons.contacts_outlined,
      ),
      ModulePage(
        slug: 'activities',
        title: 'Activities',
        permission: Perm.crmView,
        icon: Icons.event_note_outlined,
      ),
      ModulePage(
        slug: 'tickets',
        title: 'Tickets',
        permission: Perm.crmTickets,
        icon: Icons.confirmation_number_outlined,
      ),
      ModulePage(
        slug: 'campaigns',
        title: 'Campaigns',
        permission: Perm.crmView,
        icon: Icons.campaign_outlined,
      ),
      ModulePage(
        slug: 'pipeline',
        title: 'Pipeline',
        permission: Perm.crmOpportunities,
        icon: Icons.filter_alt_outlined,
      ),
      ModulePage(
        slug: 'quotations',
        title: 'Quotations',
        permission: Perm.crmOpportunities,
        icon: Icons.request_quote_outlined,
      ),
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
        slug: 'overview',
        title: 'ERP Dashboard',
        permission: Perm.erpView,
        icon: Icons.space_dashboard_outlined,
      ),
      ModulePage(
        slug: 'inventory',
        title: 'Inventory',
        permission: Perm.erpInventory,
        icon: Icons.inventory_2_outlined,
      ),
      ModulePage(
        slug: 'products',
        title: 'Products',
        permission: Perm.erpInventory,
        icon: Icons.category_outlined,
      ),
      ModulePage(
        slug: 'procurement',
        title: 'Procurement',
        permission: Perm.erpProcurement,
        icon: Icons.shopping_cart_outlined,
      ),
      ModulePage(
        slug: 'vendors',
        title: 'Vendors',
        permission: Perm.erpProcurement,
        icon: Icons.storefront_outlined,
      ),
      ModulePage(
        slug: 'production',
        title: 'Production',
        permission: Perm.erpView,
        icon: Icons.precision_manufacturing_outlined,
      ),
      ModulePage(
        slug: 'orders',
        title: 'Orders',
        permission: Perm.erpOrders,
        icon: Icons.receipt_long_outlined,
      ),
      ModulePage(
        slug: 'dispatch',
        title: 'Dispatch',
        permission: Perm.erpOrders,
        icon: Icons.local_shipping_outlined,
      ),
      ModulePage(
        slug: 'maintenance',
        title: 'Maintenance',
        permission: Perm.erpView,
        icon: Icons.build_outlined,
      ),
      ModulePage(
        slug: 'assets',
        title: 'Asset Management',
        permission: Perm.erpView,
        icon: Icons.inventory_outlined,
      ),
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
        permission: Perm.financeView,
        icon: Icons.space_dashboard_outlined,
      ),
      ModulePage(
        slug: 'ledger',
        title: 'General Ledger',
        permission: Perm.financeLedger,
        icon: Icons.menu_book_outlined,
      ),
      ModulePage(
        slug: 'accounts',
        title: 'Chart of Accounts',
        permission: Perm.financeLedger,
        icon: Icons.account_tree_outlined,
      ),
      ModulePage(
        slug: 'payable',
        title: 'Accounts Payable',
        permission: Perm.financeInvoices,
        icon: Icons.call_made_outlined,
      ),
      ModulePage(
        slug: 'receivable',
        title: 'Accounts Receivable',
        permission: Perm.financeInvoices,
        icon: Icons.call_received_outlined,
      ),
      ModulePage(
        slug: 'invoices',
        title: 'Invoices',
        permission: Perm.financeInvoices,
        icon: Icons.receipt_outlined,
      ),
      ModulePage(
        slug: 'payments',
        title: 'Payments',
        permission: Perm.financePayments,
        icon: Icons.payments_outlined,
      ),
      ModulePage(
        slug: 'tax',
        title: 'Tax',
        permission: Perm.financeView,
        icon: Icons.percent_outlined,
      ),
      ModulePage(
        slug: 'budgets',
        title: 'Budgets',
        permission: Perm.financeView,
        icon: Icons.savings_outlined,
      ),
      ModulePage(
        slug: 'costing',
        title: 'Costing',
        permission: Perm.financeView,
        icon: Icons.calculate_outlined,
      ),
      ModulePage(
        slug: 'reconciliation',
        title: 'Reconciliation',
        permission: Perm.financeLedger,
        icon: Icons.fact_check_outlined,
      ),
      ModulePage(
        slug: 'currency',
        title: 'Multi-Currency Management',
        permission: Perm.financeView,
        icon: Icons.currency_exchange_outlined,
      ),
      ModulePage(
        slug: 'reports',
        title: 'Financial Reports',
        permission: Perm.financeView,
        icon: Icons.summarize_outlined,
      ),
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
        permission: Perm.workflowView,
        icon: Icons.space_dashboard_outlined,
      ),
      ModulePage(
        slug: 'builder',
        title: 'Workflow Builder',
        permission: Perm.workflowBuild,
        icon: Icons.account_tree_outlined,
      ),
      ModulePage(
        slug: 'approvals',
        title: 'Approvals',
        permission: Perm.workflowApprove,
        icon: Icons.approval_outlined,
      ),
      ModulePage(
        slug: 'tasks',
        title: 'My Tasks',
        permission: Perm.workflowView,
        icon: Icons.checklist_outlined,
      ),
      ModulePage(
        slug: 'automation',
        title: 'Automation Rules',
        permission: Perm.workflowBuild,
        icon: Icons.smart_toy_outlined,
      ),
      ModulePage(
        slug: 'runs',
        title: 'Workflow Runs',
        permission: Perm.workflowView,
        icon: Icons.play_circle_outline,
      ),
      ModulePage(
        slug: 'rules',
        title: 'Business Rules',
        permission: Perm.workflowBuild,
        icon: Icons.rule_outlined,
      ),
      ModulePage(
        slug: 'triggers',
        title: 'Triggers',
        permission: Perm.workflowBuild,
        icon: Icons.bolt_outlined,
      ),
      ModulePage(
        slug: 'sla',
        title: 'SLAs & Escalations',
        permission: Perm.workflowView,
        icon: Icons.timer_outlined,
      ),
      ModulePage(
        slug: 'monitoring',
        title: 'Process Monitoring',
        permission: Perm.workflowView,
        icon: Icons.monitor_outlined,
      ),
      ModulePage(
        slug: 'templates',
        title: 'Workflow Templates',
        permission: Perm.workflowBuild,
        icon: Icons.dashboard_customize_outlined,
      ),
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
        slug: 'overview',
        title: 'Documents',
        permission: Perm.documentsView,
        icon: Icons.description_outlined,
      ),
      ModulePage(
        slug: 'folders',
        title: 'Folders',
        permission: Perm.documentsView,
        icon: Icons.folder_outlined,
      ),
      ModulePage(
        slug: 'approvals',
        title: 'Approvals',
        permission: Perm.documentsApprove,
        icon: Icons.approval_outlined,
      ),
      ModulePage(
        slug: 'versions',
        title: 'Versions',
        permission: Perm.documentsView,
        icon: Icons.history_outlined,
      ),
      ModulePage(
        slug: 'retention',
        title: 'Retention',
        permission: Perm.documentsApprove,
        icon: Icons.schedule_outlined,
      ),
      ModulePage(
        slug: 'upload',
        title: 'File Upload / Download',
        permission: Perm.documentsUpload,
        icon: Icons.cloud_upload_outlined,
      ),
      ModulePage(
        slug: 'tagging',
        title: 'Tagging & Search',
        permission: Perm.documentsView,
        icon: Icons.sell_outlined,
      ),
      ModulePage(
        slug: 'audit-trails',
        title: 'Audit Trails',
        permission: Perm.documentsView,
        icon: Icons.plagiarism_outlined,
      ),
      ModulePage(
        slug: 'ocr',
        title: 'OCR Integration',
        permission: Perm.documentsUpload,
        icon: Icons.document_scanner_outlined,
      ),
      ModulePage(
        slug: 'access',
        title: 'Access Control',
        permission: Perm.documentsApprove,
        icon: Icons.lock_outline,
      ),
      ModulePage(
        slug: 'templates',
        title: 'Document Templates',
        permission: Perm.documentsView,
        icon: Icons.file_copy_outlined,
      ),
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
        permission: Perm.subscriptionsView,
        icon: Icons.space_dashboard_outlined,
      ),
      ModulePage(
        slug: 'plans',
        title: 'Plans',
        permission: Perm.subscriptionsView,
        icon: Icons.layers_outlined,
      ),
      ModulePage(
        slug: 'list',
        title: 'Subscriptions',
        permission: Perm.subscriptionsView,
        icon: Icons.subscriptions_outlined,
      ),
      ModulePage(
        slug: 'usage',
        title: 'Usage',
        permission: Perm.subscriptionsView,
        icon: Icons.data_usage_outlined,
      ),
      ModulePage(
        slug: 'renewals',
        title: 'Renewals',
        permission: Perm.subscriptionsManage,
        icon: Icons.autorenew_outlined,
      ),
      ModulePage(
        slug: 'billing',
        title: 'Billing',
        permission: Perm.subscriptionsManage,
        icon: Icons.credit_card_outlined,
      ),
      ModulePage(
        slug: 'license-allocation',
        title: 'License Allocation',
        permission: Perm.subscriptionsManage,
        icon: Icons.assignment_ind_outlined,
      ),
      ModulePage(
        slug: 'license-keys',
        title: 'License Keys',
        permission: Perm.subscriptionsManage,
        icon: Icons.vpn_key_outlined,
      ),
      ModulePage(
        slug: 'trials',
        title: 'Trial Management',
        permission: Perm.subscriptionsManage,
        icon: Icons.hourglass_empty_outlined,
      ),
      ModulePage(
        slug: 'billing-integration',
        title: 'Billing Integration',
        permission: Perm.subscriptionsManage,
        icon: Icons.sync_alt_outlined,
      ),
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
        slug: 'overview',
        title: 'Revenue Dashboard',
        permission: Perm.revenueView,
        icon: Icons.space_dashboard_outlined,
      ),
      ModulePage(
        slug: 'analytics',
        title: 'Analytics',
        permission: Perm.revenueView,
        icon: Icons.analytics_outlined,
      ),
      ModulePage(
        slug: 'forecast',
        title: 'Forecast',
        permission: Perm.revenueView,
        icon: Icons.ssid_chart_outlined,
      ),
      ModulePage(
        slug: 'recognition',
        title: 'Recognition',
        permission: Perm.revenueView,
        icon: Icons.verified_outlined,
      ),
      ModulePage(
        slug: 'reports',
        title: 'Revenue Reports',
        permission: Perm.revenueView,
        icon: Icons.summarize_outlined,
      ),
      ModulePage(
        slug: 'commissions',
        title: 'Commission Management',
        permission: Perm.revenueView,
        icon: Icons.percent_outlined,
      ),
      ModulePage(
        slug: 'financial-analytics',
        title: 'Financial Analytics',
        permission: Perm.revenueView,
        icon: Icons.insights_outlined,
      ),
      ModulePage(
        slug: 'invoicing',
        title: 'Invoicing',
        permission: Perm.revenueView,
        icon: Icons.receipt_outlined,
      ),
      ModulePage(
        slug: 'integrations',
        title: 'Revenue Integrations',
        permission: Perm.revenueView,
        icon: Icons.extension_outlined,
      ),
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
      ModulePage(
        slug: 'overview',
        title: 'Reports',
        permission: Perm.reportsView,
        icon: Icons.assessment_outlined,
      ),
      ModulePage(
        slug: 'standard',
        title: 'Standard Reports',
        permission: Perm.reportsView,
        icon: Icons.description_outlined,
      ),
      ModulePage(
        slug: 'builder',
        title: 'Report Builder',
        permission: Perm.reportsBuild,
        icon: Icons.build_circle_outlined,
      ),
      ModulePage(
        slug: 'dashboards',
        title: 'Dashboards',
        permission: Perm.reportsView,
        icon: Icons.dashboard_outlined,
      ),
      ModulePage(
        slug: 'scheduled',
        title: 'Scheduled Reports',
        permission: Perm.reportsBuild,
        icon: Icons.schedule_send_outlined,
      ),
      ModulePage(
        slug: 'exploration',
        title: 'Data Exploration',
        permission: Perm.reportsView,
        icon: Icons.travel_explore_outlined,
      ),
      ModulePage(
        slug: 'exports',
        title: 'Data Exports',
        permission: Perm.reportsView,
        icon: Icons.file_download_outlined,
      ),
      ModulePage(
        slug: 'visualization',
        title: 'Data Visualization',
        permission: Perm.reportsView,
        icon: Icons.bar_chart_outlined,
      ),
      ModulePage(
        slug: 'self-service',
        title: 'Self-Service Analytics',
        permission: Perm.reportsView,
        icon: Icons.self_improvement_outlined,
      ),
    ],
  ),

  // --- Enterprise AI ---------------------------------------------------------
  PlatformModule(
    id: 'ai',
    title: 'Enterprise AI',
    icon: Icons.auto_awesome_outlined,
    group: ModuleGroup.intelligence,
    pages: [
      ModulePage(
        slug: 'overview',
        title: 'AI Dashboard',
        permission: Perm.aiView,
        icon: Icons.space_dashboard_outlined,
      ),
      ModulePage(
        slug: 'assistant',
        title: 'AI Assistant',
        permission: Perm.aiView,
        icon: Icons.assistant_outlined,
      ),
      ModulePage(
        slug: 'insights',
        title: 'AI Insights',
        permission: Perm.aiView,
        icon: Icons.lightbulb_outline,
      ),
      ModulePage(
        slug: 'predictions',
        title: 'Predictions',
        permission: Perm.aiView,
        icon: Icons.auto_graph_outlined,
      ),
      ModulePage(
        slug: 'models',
        title: 'AI Models',
        permission: Perm.aiModels,
        icon: Icons.model_training_outlined,
      ),
      ModulePage(
        slug: 'usage',
        title: 'AI Usage',
        permission: Perm.aiModels,
        icon: Icons.data_usage_outlined,
      ),
      ModulePage(
        slug: 'document-ai',
        title: 'Document AI / OCR',
        permission: Perm.aiView,
        icon: Icons.document_scanner_outlined,
      ),
      ModulePage(
        slug: 'recommendations',
        title: 'Recommendations',
        permission: Perm.aiView,
        icon: Icons.recommend_outlined,
      ),
      ModulePage(
        slug: 'ai-workflow',
        title: 'AI Workflow',
        permission: Perm.aiView,
        icon: Icons.account_tree_outlined,
      ),
      ModulePage(
        slug: 'prompts',
        title: 'Prompt Engineering',
        permission: Perm.aiModels,
        icon: Icons.edit_note_outlined,
      ),
      ModulePage(
        slug: 'usage-logs',
        title: 'AI Usage Logs',
        permission: Perm.aiModels,
        icon: Icons.receipt_long_outlined,
      ),
      ModulePage(
        slug: 'model-management',
        title: 'Model Management',
        permission: Perm.aiModels,
        icon: Icons.tune_outlined,
      ),
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
        permission: Perm.notificationsView,
        icon: Icons.notifications_outlined,
      ),
      ModulePage(
        slug: 'templates',
        title: 'Templates',
        permission: Perm.notificationsView,
        icon: Icons.article_outlined,
      ),
      ModulePage(
        slug: 'preferences',
        title: 'Preferences',
        permission: Perm.notificationsView,
        icon: Icons.tune_outlined,
      ),
      ModulePage(
        slug: 'history',
        title: 'History',
        permission: Perm.notificationsView,
        icon: Icons.history_outlined,
      ),
      ModulePage(
        slug: 'sms',
        title: 'SMS Notifications',
        permission: Perm.notificationsView,
        icon: Icons.sms_outlined,
      ),
      ModulePage(
        slug: 'push',
        title: 'Push Notifications',
        permission: Perm.notificationsView,
        icon: Icons.notifications_active_outlined,
      ),
      ModulePage(
        slug: 'schedules',
        title: 'Notification Schedules',
        permission: Perm.notificationsView,
        icon: Icons.schedule_outlined,
      ),
      ModulePage(
        slug: 'delivery',
        title: 'Delivery Tracking',
        permission: Perm.notificationsView,
        icon: Icons.mark_email_read_outlined,
      ),
      ModulePage(
        slug: 'channels',
        title: 'Multi-Channel Notifications',
        permission: Perm.notificationsView,
        icon: Icons.hub_outlined,
      ),
      ModulePage(
        slug: 'email',
        title: 'Email Notifications',
        permission: Perm.notificationsView,
        icon: Icons.email_outlined,
      ),
    ],
  ),

  // --- Calendar --------------------------------------------------------------
  PlatformModule(
    id: 'calendar',
    title: 'Calendar',
    icon: Icons.calendar_month_outlined,
    group: ModuleGroup.platform,
    pages: [
      ModulePage(
        slug: 'overview',
        title: 'Calendar',
        permission: Perm.calendarView,
        icon: Icons.calendar_month_outlined,
      ),
      ModulePage(
        slug: 'events',
        title: 'Events',
        permission: Perm.calendarView,
        icon: Icons.event_outlined,
      ),
      ModulePage(
        slug: 'meetings',
        title: 'Meetings',
        permission: Perm.calendarView,
        icon: Icons.groups_outlined,
      ),
      ModulePage(
        slug: 'resources',
        title: 'Resource Booking',
        permission: Perm.calendarView,
        icon: Icons.meeting_room_outlined,
      ),
      ModulePage(
        slug: 'user-calendars',
        title: 'User Calendars',
        permission: Perm.calendarView,
        icon: Icons.person_outline,
      ),
      ModulePage(
        slug: 'team-calendars',
        title: 'Team Calendars',
        permission: Perm.calendarView,
        icon: Icons.diversity_3_outlined,
      ),
      ModulePage(
        slug: 'google-sync',
        title: 'Google Calendar Integration',
        permission: Perm.calendarView,
        icon: Icons.sync_outlined,
      ),
      ModulePage(
        slug: 'outlook-sync',
        title: 'Microsoft Outlook Integration',
        permission: Perm.calendarView,
        icon: Icons.mail_outline,
      ),
      ModulePage(
        slug: 'availability',
        title: 'Availability Management',
        permission: Perm.calendarView,
        icon: Icons.event_available_outlined,
      ),
      ModulePage(
        slug: 'shared',
        title: 'Shared Calendars',
        permission: Perm.calendarView,
        icon: Icons.share_outlined,
      ),
      ModulePage(
        slug: 'reminders',
        title: 'Reminders',
        permission: Perm.calendarView,
        icon: Icons.alarm_outlined,
      ),
      ModulePage(
        slug: 'integrations',
        title: 'Calendar Integrations',
        permission: Perm.calendarView,
        icon: Icons.link_outlined,
      ),
      ModulePage(
        slug: 'event-notifications',
        title: 'Event Notifications',
        permission: Perm.calendarView,
        icon: Icons.notifications_active_outlined,
      ),
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
        slug: 'overview',
        title: 'Integrations',
        permission: Perm.integrationsView,
        icon: Icons.extension_outlined,
      ),
      ModulePage(
        slug: 'webhooks',
        title: 'Webhooks',
        permission: Perm.integrationsManage,
        icon: Icons.webhook_outlined,
      ),
      ModulePage(
        slug: 'sync',
        title: 'Sync Jobs',
        permission: Perm.integrationsManage,
        icon: Icons.sync_outlined,
      ),
      ModulePage(
        slug: 'logs',
        title: 'Logs',
        permission: Perm.integrationsView,
        icon: Icons.receipt_long_outlined,
      ),
      ModulePage(
        slug: 'api',
        title: 'API Management',
        permission: Perm.integrationsManage,
        icon: Icons.api_outlined,
      ),
      ModulePage(
        slug: 'third-party',
        title: 'Third-Party Integrations',
        permission: Perm.integrationsManage,
        icon: Icons.apps_outlined,
      ),
      ModulePage(
        slug: 'events',
        title: 'Event Streaming',
        permission: Perm.integrationsManage,
        icon: Icons.stream_outlined,
      ),
      ModulePage(
        slug: 'transform',
        title: 'Data Transformation',
        permission: Perm.integrationsManage,
        icon: Icons.transform_outlined,
      ),
      ModulePage(
        slug: 'etl',
        title: 'ETL / Data Synchronization',
        permission: Perm.integrationsManage,
        icon: Icons.swap_horiz_outlined,
      ),
      ModulePage(
        slug: 'connectors',
        title: 'Connectors',
        permission: Perm.integrationsView,
        icon: Icons.cable_outlined,
      ),
    ],
  ),

  // --- Search ------------------------------------------------------------------
  PlatformModule(
    id: 'search',
    title: 'Search',
    icon: Icons.search_outlined,
    group: ModuleGroup.platform,
    pages: [
      ModulePage(
        slug: 'overview',
        title: 'Global Search',
        permission: Perm.searchView,
        icon: Icons.search_outlined,
      ),
      ModulePage(
        slug: 'saved',
        title: 'Saved Searches',
        permission: Perm.searchView,
        icon: Icons.bookmark_outline,
      ),
      ModulePage(
        slug: 'analytics',
        title: 'Search Analytics',
        permission: Perm.searchView,
        icon: Icons.query_stats_outlined,
      ),
      ModulePage(
        slug: 'index',
        title: 'Index Management',
        permission: Perm.searchView,
        icon: Icons.list_alt_outlined,
      ),
      ModulePage(
        slug: 'autocomplete',
        title: 'Autocomplete',
        permission: Perm.searchView,
        icon: Icons.keyboard_outlined,
      ),
      ModulePage(
        slug: 'ranking',
        title: 'Relevance Ranking',
        permission: Perm.searchView,
        icon: Icons.sort_outlined,
      ),
      ModulePage(
        slug: 'synonyms',
        title: 'Synonyms',
        permission: Perm.searchView,
        icon: Icons.compare_arrows_outlined,
      ),
      ModulePage(
        slug: 'suggestions',
        title: 'Suggestions Engine',
        permission: Perm.searchView,
        icon: Icons.tips_and_updates_outlined,
      ),
      ModulePage(
        slug: 'tenant-index',
        title: 'Multi-Tenant Index',
        permission: Perm.searchView,
        icon: Icons.domain_outlined,
      ),
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
        permission: Perm.securityView,
        icon: Icons.security_outlined,
      ),
      ModulePage(
        slug: 'audit',
        title: 'Audit Logs',
        permission: Perm.securityAudit,
        icon: Icons.plagiarism_outlined,
      ),
      ModulePage(
        slug: 'compliance',
        title: 'Compliance',
        permission: Perm.securityView,
        icon: Icons.verified_user_outlined,
      ),
      ModulePage(
        slug: 'policies',
        title: 'Policies',
        permission: Perm.securityView,
        icon: Icons.policy_outlined,
      ),
      ModulePage(
        slug: 'retention',
        title: 'Data Retention',
        permission: Perm.securityView,
        icon: Icons.schedule_outlined,
      ),
      ModulePage(
        slug: 'alerts',
        title: 'Security Alerts',
        permission: Perm.securityView,
        icon: Icons.notification_important_outlined,
      ),
      ModulePage(
        slug: 'threats',
        title: 'Threat Detection',
        permission: Perm.securityAudit,
        icon: Icons.gpp_maybe_outlined,
      ),
      ModulePage(
        slug: 'vulnerabilities',
        title: 'Vulnerability Management',
        permission: Perm.securityAudit,
        icon: Icons.bug_report_outlined,
      ),
      ModulePage(
        slug: 'encryption',
        title: 'Encryption & Key Management',
        permission: Perm.securityView,
        icon: Icons.enhanced_encryption_outlined,
      ),
      ModulePage(
        slug: 'activity',
        title: 'Activity Tracking',
        permission: Perm.securityAudit,
        icon: Icons.timeline_outlined,
      ),
    ],
  ),
];

/// Index by id, built once. Route resolution is a map lookup, not a scan.
final Map<String, PlatformModule> kModulesById = {
  for (final m in kModules) m.id: m,
};

/// Modules under one sidebar heading, in registry order.
List<PlatformModule> modulesInGroup(ModuleGroup group) => [
      for (final m in kModules)
        if (m.group == group) m
    ];

/// The modules a principal may see at all. Used by the sidebar so a user is
/// never shown a heading they cannot open, and by the guard that picks a
/// landing page after sign-in.
List<PlatformModule> visibleModules(PermissionSet perms) => [
      for (final m in kModules)
        if (perms.canAny(m.permissions)) m
    ];

/// The pages of [module] this principal may open.
List<ModulePage> visiblePages(PlatformModule module, PermissionSet perms) => [
      for (final p in module.pages)
        if (perms.can(p.permission)) p
    ];
