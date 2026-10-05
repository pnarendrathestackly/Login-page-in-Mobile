import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth.dart';
import '../../core/platform/modules.dart';
import '../../core/platform/permissions.dart';
import '../../providers/navigation_provider.dart';
import '../../router/app_router.dart';
import 'sidebar_constants.dart';

const _mono = TextStyle(
  fontFamily: 'Consolas',
  fontFamilyFallback: ['Menlo', 'Courier New', 'monospace'],
);

// Rail colours from the mock, on top of the shared navy palette.
const _pillFill = Color(0xFF1B2838);
const _pillText = Color(0xFF7EE0C3);
const _serviceText = Color(0xFF66738F);
const _serviceTextOpen = Color(0xFFAEB6CC);
const _rowText = Color(0xFFD5D9E6);
const _subText = Color(0xFFB4BBCF);
const _footMuted = Color(0xFF8A93AD);
const _logOut = Color(0xFFF38B8B);

/// One collapsible service in the rail: its heading, the registry module it
/// belongs to, and its sub-modules as sidebar label → page slug, in order.
typedef SidebarService = ({
  String title,
  String module,
  Map<String, String> pages,
});

/// The rail's service menu, in display order. Every slug is a page in
/// [kModules], so each row routes and is permission-checked like any other.
const List<SidebarService> kSidebarServices = [
  (
    title: 'Platform Administration',
    module: 'admin',
    pages: {
      'Global Settings': 'global-settings',
      'Platform Configuration': 'settings',
      'License Management': 'licenses',
      'Feature Management': 'features',
      'Resource Management': 'resources',
      'System Health': 'health',
      'Tenant Template': 'tenant-templates',
    },
  ),
  (
    title: 'HRMS',
    module: 'hrms',
    pages: {
      'Employee Management': 'employees',
      'Attendance': 'attendance',
      'Leave': 'leave',
      'Payroll': 'payroll',
      'Recruitment': 'recruitment',
      'Performance': 'performance',
      'Learning': 'learning',
      'ESS / MSS': 'ess',
      'Asset Management': 'assets',
    },
  ),
  (
    title: 'CRM',
    module: 'crm',
    pages: {
      'Leads': 'leads',
      'Opportunities': 'opportunities',
      'Accounts': 'accounts',
      'Contacts': 'contacts',
      'Activities': 'activities',
      'Pipelines': 'pipeline',
      'Quotations': 'quotations',
      'Campaigns': 'campaigns',
      'Customer Support': 'tickets',
    },
  ),
  (
    title: 'ERP',
    module: 'erp',
    pages: {
      'Inventory': 'inventory',
      'Procurement': 'procurement',
      'Production': 'production',
      'Sales Orders': 'orders',
      'Dispatch': 'dispatch',
      'Asset Management': 'assets',
      'Maintenance': 'maintenance',
      'Vendors': 'vendors',
    },
  ),
  (
    title: 'Finance & Accounting',
    module: 'finance',
    pages: {
      'General Ledger': 'ledger',
      'Accounts Payable': 'payable',
      'Accounts Receivable': 'receivable',
      'Tax Management': 'tax',
      'Budgeting': 'budgets',
      'Costing': 'costing',
      'Financial Reports': 'reports',
      'Reconciliation': 'reconciliation',
      'Multi-Currency': 'currency',
    },
  ),
  (
    title: 'Workflow & Automation',
    module: 'workflow',
    pages: {
      'Workflow Builder': 'builder',
      'Approvals': 'approvals',
      'Business Rules': 'rules',
      'Process Automation': 'automation',
      'Task Management': 'tasks',
      'Triggers': 'triggers',
      'SLAs & Escalations': 'sla',
      'Process Monitoring': 'monitoring',
      'Workflow Templates': 'templates',
    },
  ),
  (
    title: 'Document Management',
    module: 'documents',
    pages: {
      'Document Repository': 'overview',
      'Versioning': 'versions',
      'File Upload / Download': 'upload',
      'Access Control': 'access',
      'Document Templates': 'templates',
      'Tagging & Search': 'tagging',
      'Retention Policies': 'retention',
      'Audit Trails': 'audit-trails',
      'OCR Integration': 'ocr',
    },
  ),
  (
    title: 'Subscription',
    module: 'subscriptions',
    pages: {
      'Plans & Features': 'plans',
      'Tenant Subscriptions': 'list',
      'Usage & Quotas': 'usage',
      'Payment Tracking': 'billing',
      'License Allocation': 'license-allocation',
      'License Keys': 'license-keys',
      'Renewals': 'renewals',
      'Trial Management': 'trials',
      'Billing Integration': 'billing-integration',
    },
  ),
  (
    title: 'Revenue',
    module: 'revenue',
    pages: {
      'Revenue Tracking': 'overview',
      'Usage Analytics': 'analytics',
      'Forecasting': 'forecast',
      'Revenue Reports': 'reports',
      'Revenue Recognition': 'recognition',
      'Commission Mgmt.': 'commissions',
      'Financial Analytics': 'financial-analytics',
      'Invoicing': 'invoicing',
      'Integration': 'integrations',
    },
  ),
  (
    title: 'Reporting & BI',
    module: 'reports',
    pages: {
      'Standard Reports': 'standard',
      'Ad-hoc Reports': 'builder',
      'Data Exploration': 'exploration',
      'BI Management': 'dashboards',
      'Data Export': 'exports',
      'Scheduled Reports': 'scheduled',
      'Data Visualization': 'visualization',
      'Self-Service Analytics': 'self-service',
    },
  ),
  (
    title: 'Enterprise AI',
    module: 'ai',
    pages: {
      'AI Models': 'models',
      'AI Chat / Copilot': 'assistant',
      'Document AI / OCR': 'document-ai',
      'Predictive Analytics': 'predictions',
      'Recommendations': 'recommendations',
      'AI Workflows': 'ai-workflow',
      'Model Management': 'model-management',
      'Prompt Engineering': 'prompts',
      'AI Usage Logs': 'usage-logs',
    },
  ),
  (
    title: 'Notification',
    module: 'notifications',
    pages: {
      'In-App Notifications': 'center',
      'Email Notifications': 'email',
      'SMS Notifications': 'sms',
      'Push Notifications': 'push',
      'Templates': 'templates',
      'Preferences': 'preferences',
      'Schedules': 'schedules',
      'Delivery Tracking': 'delivery',
      'Multi-Channel': 'channels',
    },
  ),
  (
    title: 'Calendar',
    module: 'calendar',
    pages: {
      'User Calendars': 'user-calendars',
      'Team Calendars': 'team-calendars',
      'Meeting Scheduler': 'meetings',
      'Resource Booking': 'resources',
      'Reminders': 'reminders',
      'Integrations (Google, Outlook)': 'integrations',
      'Availability': 'availability',
      'Event Notifications': 'event-notifications',
      'Shared Calendars': 'shared',
    },
  ),
  (
    title: 'Integration',
    module: 'integrations',
    pages: {
      'API Management': 'api',
      'Third-Party Integrations': 'third-party',
      'Webhooks': 'webhooks',
      'Event Streaming': 'events',
      'Data Transformation': 'transform',
      'ETL / Data Sync': 'etl',
      'Connectors (ERP, Bank, Payroll, etc.)': 'connectors',
      'Integration Logs': 'logs',
    },
  ),
  (
    title: 'Search',
    module: 'search',
    pages: {
      'Global Search': 'overview',
      'Index Management': 'index',
      'Search Analytics': 'analytics',
      'Autocomplete': 'autocomplete',
      'Relevance Ranking': 'ranking',
      'Saved Searches': 'saved',
      'Multi-Tenant Index': 'tenant-index',
      'Synonyms': 'synonyms',
      'Suggestion Engine': 'suggestions',
    },
  ),
  (
    title: 'Security & Compliance',
    module: 'security',
    pages: {
      'Audit Logs': 'audit',
      'Activity Tracking': 'activity',
      'Compliance Reports': 'compliance',
      'Data Retention': 'retention',
      'Policy Management': 'policies',
      'Threat Detection': 'threats',
      'Vulnerability Mgmt.': 'vulnerabilities',
      'Encryption & Key Mgmt.': 'encryption',
      'Security Alerts': 'alerts',
    },
  ),
];

/// One fixed destination in the rail's ORGANIZATION section.
typedef _Entry = ({String label, IconData icon, String slug, String perm});

const List<_Entry> _organization = [
  (
    label: 'Company Setup',
    icon: Icons.business_outlined,
    slug: 'organizations',
    perm: Perm.adminTenants,
  ),
  (
    label: 'User Management',
    icon: Icons.person_outline,
    slug: 'users',
    perm: Perm.adminUsers,
  ),
];

/// The navy rail: brand, the service menu, organization links, language,
/// log out and the signed-in user.
///
/// Holds no navigation state — the highlight comes from the router's current
/// location, which services are open lives in [NavigationProvider], and every
/// tap goes through [AppRouter].
class AppSidebar extends StatelessWidget {
  const AppSidebar({super.key, required this.controller, this.onClose});

  final AuthController controller;

  /// Set only in the mobile drawer, where the panel needs a way to dismiss
  /// itself; the desktop rail is permanent and passes null.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final delegate = Router.of(context).routerDelegate;
    final location = delegate is AppRouter ? delegate.location : '';
    // Rebuild when the route changes or a service opens.
    final nav = context.watch<NavigationProvider>();
    final perms = controller.permissions;
    final user = controller.user;
    final admin = kModulesById['admin']!;

    final services = <Widget>[];
    for (final s in kSidebarServices) {
      final module = kModulesById[s.module]!;
      final rows = [
        for (final MapEntry(key: label, value: slug) in s.pages.entries)
          if (module.page(slug) case final page?
              when perms.can(page.permission))
            (label: label, path: module.pathFor(page)),
      ];
      // A service the principal can open nothing in would be a dead heading.
      if (rows.isEmpty) continue;
      final open = nav.isModuleExpanded(module.id);
      services.add(_ServiceHeader(
        title: s.title,
        open: open,
        onTap: () => nav.toggleModule(module.id),
      ));
      if (open) {
        for (final r in rows) {
          services.add(_SubItem(
            label: r.label,
            selected: location == r.path,
            onTap: () => _go(context, r.path),
          ));
        }
      }
    }

    final organization = [
      for (final e in _organization)
        if (perms.can(e.perm))
          _Item(
            label: e.label,
            icon: Icon(e.icon, size: 16, color: _rowText),
            selected: location == admin.pathFor(admin.page(e.slug)!),
            onTap: (_) => _go(context, admin.pathFor(admin.page(e.slug)!)),
          ),
    ];

    return Container(
      color: kRail,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(19, 18, 20, 0),
            child: SizedBox(
              height: 28,
              child: Row(
                children: [
                  const Expanded(child: StacklyLogo(height: 28)),
                  if (onClose != null) _CloseButton(onTap: onClose!),
                ],
              ),
            ),
          ),
          Container(
            height: 23,
            // The bottom margin sits outside the scroll view, so scrolled
            // rows clip below the pill rather than running into it.
            margin: const EdgeInsets.fromLTRB(12, 17, 13, 16),
            alignment: Alignment.center,
            decoration: const ShapeDecoration(
              color: _pillFill,
              shape: StadiumBorder(),
            ),
            child: Text(
              'ONE ENTERPRISE CLOUD',
              maxLines: 1,
              style: _mono.copyWith(
                fontSize: 10.5,
                height: 1,
                letterSpacing: 1.3,
                color: _pillText,
              ),
            ),
          ),
          // One scroll view for the whole menu. Nested viewports here break
          // intrinsic sizing for the overlays above the shell.
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 12),
              children: [
                ...services,
                if (organization.isNotEmpty) ...[
                  const _Heading('ORGANIZATION'),
                  ...organization,
                ],
              ],
            ),
          ),
          const _RailDivider(),
          const SizedBox(height: 11),
          _Item(
            label: 'Language',
            icon: const _LanguageGlyph(),
            selected: false,
            trailing: const Text(
              'English',
              style: TextStyle(fontSize: 11.5, color: _rowText),
            ),
            // ponytail: English is the only locale shipped, so the menu lists
            // just it. Add entries here once translations exist.
            onTap: (anchor) => showMenu<String>(
              context: anchor,
              position: _menuPosition(anchor),
              items: const [
                CheckedPopupMenuItem(
                  value: 'en',
                  checked: true,
                  child: Text('English'),
                ),
              ],
            ),
          ),
          _Item(
            label: 'Log out',
            icon: const Icon(Icons.logout, size: 16, color: _logOut),
            color: _logOut,
            selected: false,
            onTap: (_) => controller.signOut(),
          ),
          const SizedBox(height: 11),
          const _RailDivider(),
          if (user != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 21, 20, 20),
              child: Row(
                children: [
                  RailAvatar(size: 26, email: user.email),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.25,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          user.role,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            height: 1.3,
                            color: _footMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Opens a menu just above [anchor]'s bottom-left corner.
  static RelativeRect _menuPosition(BuildContext anchor) {
    final box = anchor.findRenderObject()! as RenderBox;
    final overlay = Overlay.of(anchor).context.findRenderObject()! as RenderBox;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    return RelativeRect.fromRect(
      topLeft & box.size,
      Offset.zero & overlay.size,
    );
  }

  static void _go(BuildContext context, String path) {
    // The drawer is an overlay, not a page: close it before the route changes.
    context.read<NavigationProvider>().closeDrawer();
    if (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
    context.go(path);
  }
}

/// Profile photos uploaded this session, keyed by account email.
// ponytail: in memory — there is no media storage API. Resets on restart.
final profilePhotos = ValueNotifier<Map<String, Uint8List>>({});

/// The user's photo when one was uploaded, otherwise the teal-blue disc from
/// the mock. Shared by the rail footer and the header's profile pill.
class RailAvatar extends StatelessWidget {
  const RailAvatar({super.key, this.size = 30, this.email});

  final double size;
  final String? email;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: profilePhotos,
      builder: (context, photos, _) {
        final photo = email == null ? null : photos[email];
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: photo != null
                ? null
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF8ED9C6), Color(0xFF2E5C8A)],
                  ),
            image: photo == null
                ? null
                : DecorationImage(image: MemoryImage(photo), fit: BoxFit.cover),
          ),
        );
      },
    );
  }
}

/// The bordered square close button in the drawer's top-right corner.
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Close menu',
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: Colors.white.withValues(alpha: .22)),
        ),
        child: InkWell(
          onTap: onTap,
          // The drawer focuses this on open; a subtle ring keeps it from
          // reading as a filled white tile.
          focusColor: Colors.white.withValues(alpha: .08),
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
          child: const SizedBox.square(
            dimension: 26,
            child: Icon(Icons.close, size: 14, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _RailDivider extends StatelessWidget {
  const _RailDivider();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 19),
        child: Divider(height: 1, thickness: 1, color: kRailDivider),
      );
}

/// A service heading: uppercase, muted, with a chevron. Tapping it opens or
/// closes the service's sub-modules; it does not navigate.
class _ServiceHeader extends StatelessWidget {
  const _ServiceHeader({
    required this.title,
    required this.open,
    required this.onTap,
  });

  final String title;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = open ? _serviceTextOpen : _serviceText;
    return Semantics(
      button: true,
      expanded: open,
      excludeSemantics: true,
      label: '$title section, ${open ? "expanded" : "collapsed"}',
      child: InkWell(
        onTap: onTap,
        hoverColor: Colors.white.withValues(alpha: .04),
        child: SizedBox(
          height: 36,
          child: Padding(
            padding: const EdgeInsets.only(left: 24, right: 24),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .25,
                      color: color,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: open ? .5 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: Icon(Icons.keyboard_arrow_down,
                      size: 14, color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A service's sub-module: a plain indented label under its heading.
class _SubItem extends StatelessWidget {
  const _SubItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 0, 12, 1),
      child: Material(
        color: selected ? kRailSelected : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(
            color: selected ? kRailSelectedBorder : Colors.transparent,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          hoverColor: Colors.white.withValues(alpha: .05),
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
          child: Semantics(
            selected: selected,
            button: true,
            child: Container(
              height: 30,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                  color: selected ? Colors.white : _subText,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 30, 20, 4),
      child: Text(
        text,
        style: _mono.copyWith(
          fontSize: 9,
          letterSpacing: .9,
          color: _serviceText,
        ),
      ),
    );
  }
}

/// A full-width rail row with a leading mark: the ORGANIZATION links,
/// Language and Log out.
class _Item extends StatefulWidget {
  const _Item({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.trailing,
    this.color = _rowText,
  });

  final String label;
  final Widget icon;
  final bool selected;
  final Color color;

  /// Receives the row's context, so a row can anchor a menu to itself.
  final void Function(BuildContext anchor) onTap;
  final Widget? trailing;

  @override
  State<_Item> createState() => _ItemState();
}

class _ItemState extends State<_Item> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Material(
          color: selected
              ? kRailSelected
              : _hovered
                  ? Colors.white.withValues(alpha: .05)
                  : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: BorderSide(
              color: selected ? kRailSelectedBorder : Colors.transparent,
            ),
          ),
          child: InkWell(
            onTap: () => widget.onTap(context),
            borderRadius: BorderRadius.circular(6),
            child: Semantics(
              selected: selected,
              button: true,
              child: Container(
                height: 37,
                padding: const EdgeInsets.only(left: 9, right: 13),
                child: Row(
                  children: [
                    SizedBox.square(
                      dimension: 16,
                      child: Center(child: widget.icon),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.label,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight:
                              selected ? FontWeight.w500 : FontWeight.w400,
                          color: selected ? Colors.white : widget.color,
                        ),
                      ),
                    ),
                    if (widget.trailing != null) widget.trailing!,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The mock's language mark: a ring cut by a horizontal line.
class _LanguageGlyph extends StatelessWidget {
  const _LanguageGlyph();

  @override
  Widget build(BuildContext context) =>
      const CustomPaint(size: Size.square(14), painter: _LanguagePainter());
}

class _LanguagePainter extends CustomPainter {
  const _LanguagePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _rowText
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - .65;
    canvas.drawCircle(c, r, paint);
    canvas.drawLine(c.translate(-r, 0), c.translate(r, 0), paint);
  }

  @override
  bool shouldRepaint(_LanguagePainter oldDelegate) => false;
}

/// The brand logo (glyph + STACKLY wordmark), white on transparent.
// ponytail: the supplied PNG is 193×58, so it softens on 2× screens.
// Replace Assets/stackly_logo.png with an SVG or a 4× PNG when available.
class StacklyLogo extends StatelessWidget {
  const StacklyLogo({super.key, this.height = 52});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Image.asset(
        'assets/stackly_logo.png',
        height: height,
        filterQuality: FilterQuality.medium,
        semanticLabel: 'Stackly',
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }
}
