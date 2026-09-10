import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/responsive/responsive.dart';
import 'core/platform/modules.dart';
import 'features/module/screens/module_page_screen.dart';

import 'auth.dart';
import './features/dashboard/models/dashboard_models.dart';
import './features/customers/screens/customers_screen.dart';
import './features/notifications/screens/notifications_screen.dart';
import './features/profile/screens/profile_screen.dart';
import './features/projects/screens/projects_screen.dart';
import './features/reports/screens/reports_screen.dart';
import './features/settings/screens/settings_screen.dart';
import './features/tasks/screens/tasks_screen.dart';
import './features/users/screens/users_screen.dart';
import './widgets/common/parts.dart';
import './features/dashboard/services/dashboard_repository.dart';
import './widgets/common/sections.dart';
import 'main.dart';
import 'motion.dart';
import 'providers/navigation_provider.dart';
import 'widgets.dart';
import 'widgets/header/app_header.dart';
import 'widgets/sidebar/app_sidebar.dart';
import 'widgets/sidebar/sidebar_constants.dart';

/// Every destination in the shell. Adding one here adds it to the sidebar and
/// gives it a title — there is no second list to keep in sync.
enum DashboardSection {
  overview('Dashboard', Icons.dashboard_outlined, SidebarGroup.main),
  users('Users', Icons.groups_outlined, SidebarGroup.main),
  customers('Customers', Icons.business_center_outlined, SidebarGroup.main),
  projects('Projects', Icons.folder_open_outlined, SidebarGroup.main),
  tasks('Tasks', Icons.checklist_outlined, SidebarGroup.main),
  reports('Reports & Analytics', Icons.bar_chart_outlined, SidebarGroup.main),
  notifications(
      'Notifications', Icons.notifications_none, SidebarGroup.communication),
  messages('Messages', Icons.chat_bubble_outline, SidebarGroup.communication),
  profile('Profile', Icons.person_outline, SidebarGroup.management),
  settings('Settings', Icons.settings_outlined, SidebarGroup.management),
  help('Help & Support', Icons.help_outline, SidebarGroup.management);

  const DashboardSection(this.label, this.icon, this.group);
  final String label;
  final IconData icon;
  final SidebarGroup group;
}

/// Sidebar headings. Public because [DashboardSection] exposes it.
enum SidebarGroup {
  main('MAIN'),
  communication('COMMUNICATION'),
  management('MANAGEMENT');

  const SidebarGroup(this.label);
  final String label;
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.controller,
    this.repository,
    this.section = DashboardSection.overview,
    this.onNavigate,
    this.module,
    this.modulePage,
  });

  /// Set when the active route is a `/module/page` route. The shell then
  /// renders that module page instead of a [DashboardSection] screen — the
  /// surrounding chrome (sidebar, header, scroll behaviour) is identical, so
  /// there is one shell rather than a second one per module.
  final PlatformModule? module;
  final ModulePage? modulePage;

  final AuthController controller;

  /// Injectable so tests (and a real API later) can supply their own.
  final DashboardRepository? repository;

  /// Which destination to show. Driven by the URL via the router, so the
  /// sidebar selection and the address bar can never disagree.
  final DashboardSection section;

  /// Reports a sidebar/header tap to the router, which owns the route change.
  /// This widget holds no paths of its own.
  final ValueChanged<DashboardSection>? onNavigate;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late final DashboardRepository _repo =
      widget.repository ?? DemoDashboardRepository();

  /// Mirrors `widget.section`, which the router drives from the URL. Held as
  /// state (and synced in [didUpdateWidget]) so the shell keeps one element
  /// across destinations — remounting per section would refetch every panel.
  late DashboardSection _section = widget.section;

  /// Mirrors the module route, kept in step by [didUpdateWidget] for the same
  /// reason as [_section]: the shell element is reused across destinations.
  late PlatformModule? _module = widget.module;
  late ModulePage? _modulePage = widget.modulePage;

  // Overview data. Fetched once and cached here, so switching sections and
  // coming back does not refetch.
  DashboardData? _data;
  String? _dataError;
  bool _loading = true;

  ChartRange _range = ChartRange.week;
  final Map<ChartRange, PerformanceSeries> _series = {};
  bool _seriesLoading = true;
  String? _seriesError;

  List<AppNotification> _notifications = const [];
  bool _notificationsLoading = true;
  String? _notificationsError;

  // Directory pages. Each is fetched the first time its section is opened and
  // then cached, so navigating between sections costs no extra requests.
  final _directory = <DashboardSection, _Async<Object>>{};

  /// Fetches [load] for [section] once, then serves the cached result.
  _Async<Object> _fetch(
    DashboardSection section,
    Future<Object> Function() load,
  ) {
    final existing = _directory[section];
    if (existing != null) return existing;

    final pending = _Async<Object>(loading: true);
    _directory[section] = pending;
    load().then((value) {
      if (!mounted) return;
      setState(() => _directory[section] = _Async(value: value));
    }).catchError((Object _) {
      if (!mounted) return;
      setState(() => _directory[section] =
          const _Async(error: "We couldn't load this data."));
    });
    return pending;
  }

  /// Drops the cached result so the next build refetches.
  void _retry(DashboardSection section) =>
      setState(() => _directory.remove(section));

  @override
  void didUpdateWidget(DashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The URL is the source of truth; follow it when the router changes route.
    if (widget.section != oldWidget.section) {
      setState(() => _section = widget.section);
    }
    if (widget.module?.id != oldWidget.module?.id ||
        widget.modulePage?.slug != oldWidget.modulePage?.slug) {
      setState(() {
        _module = widget.module;
        _modulePage = widget.modulePage;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
    _loadSeries(_range);
    _loadNotifications();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _dataError = null;
    });
    try {
      final data = await _repo.load();
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      // Message is deliberately generic: server internals never reach the UI.
      setState(() {
        _dataError = "We couldn't load your dashboard data.";
        _loading = false;
      });
    }
  }

  Future<void> _loadSeries(ChartRange range) async {
    // Cached ranges render immediately — no request, no spinner.
    if (_series.containsKey(range)) {
      setState(() {
        _range = range;
        _seriesLoading = false;
        _seriesError = null;
      });
      return;
    }
    setState(() {
      _range = range;
      _seriesLoading = true;
      _seriesError = null;
    });
    try {
      final s = await _repo.performance(range);
      if (!mounted) return;
      setState(() {
        _series[range] = s;
        // A slower earlier request must not clear the spinner for a newer one.
        if (_range == range) _seriesLoading = false;
      });
    } catch (_) {
      if (!mounted || _range != range) return;
      setState(() {
        _seriesError = "We couldn't load performance data.";
        _seriesLoading = false;
      });
    }
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _notificationsLoading = true;
      _notificationsError = null;
    });
    try {
      final n = await _repo.notifications();
      if (!mounted) return;
      setState(() {
        _notifications = n;
        _notificationsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _notificationsError = "We couldn't load notifications.";
        _notificationsLoading = false;
      });
    }
  }

  Future<void> _markRead({String? id}) async {
    await _repo.markRead(id: id);
    if (!mounted) return;
    setState(() {}); // the repository owns the flags; just repaint
  }

  Future<void> _deleteNotification(AppNotification n) async {
    await _repo.deleteNotification(n.id);
    if (!mounted) return;
    setState(() => _notifications = [
          for (final row in _notifications)
            if (row.id != n.id) row,
        ]);
  }

  Future<void> _clearNotifications() async {
    for (final n in [..._notifications]) {
      await _repo.deleteNotification(n.id);
    }
    if (!mounted) return;
    setState(() => _notifications = const []);
  }

  void _select(DashboardSection s) {
    // Dismiss the drawer (a UI overlay, not a page) before the route changes.
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
    // The router performs the navigation; this widget only reports the intent.
    widget.onNavigate?.call(s);
  }

  @override
  Widget build(BuildContext context) {
    // One definition of "wide enough for a permanent sidebar", shared with
    // the header rather than restated here.
    final wide = context.hasPermanentSidebar;
    final user = widget.controller.user;
    // AuthGate only builds this while authenticated; this is belt-and-braces
    // for the frame between sign-out and the swap.
    if (user == null) return const SizedBox.shrink();

    // Sidebar UI state lives in NavigationProvider, not in this widget.
    final nav = context.watch<NavigationProvider>();
    final collapsed = wide && !nav.isSidebarExpanded;

    final sidebar = AppSidebar(
      controller: widget.controller,
      collapsed: collapsed,
    );

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF1F0FB),
      // Swipe/scrim dismissal has to reach the provider too, or the flag
      // would stay true after the drawer is gone.
      onDrawerChanged: (open) => open ? nav.openDrawer() : nav.closeDrawer(),
      drawer: wide
          ? null
          : Drawer(
              width: kSidebarWidth,
              child: AppSidebar(controller: widget.controller),
            ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(wide ? 16 : 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (wide) ...[
                FadeIn(
                  offset: 0,
                  child: AnimatedContainer(
                    duration: Motion.duration(context, Motion.standard),
                    curve: Motion.standardCurve,
                    width: collapsed ? kSidebarCollapsedWidth : kSidebarWidth,
                    child: _Surface(child: sidebar),
                  ),
                ),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Column(
                  children: [
                    FadeIn(
                      delay: Motion.stagger,
                      child: _Surface(
                        child: DashboardHeader(
                          title: _modulePage?.title ?? _section.label,
                          user: user,
                          controller: widget.controller,
                          onMenu: wide
                              ? nav.toggleSidebar
                              : () {
                                  nav.openDrawer();
                                  _scaffoldKey.currentState?.openDrawer();
                                },
                          notifications: _notifications,
                          notificationsLoading: _notificationsLoading,
                          notificationsError: _notificationsError,
                          onRetryNotifications: _loadNotifications,
                          onRead: (n) => _markRead(id: n.id),
                          onReadAll: _markRead,
                          onNavigate: _select,
                        ),
                      ),
                    ),
                    SizedBox(height: wide ? 16 : 12),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.symmetric(
                          horizontal: wide ? 8 : 4,
                          vertical: 8,
                        ),
                        child: FadeIn(
                          key: ValueKey(_modulePage == null
                              ? _section.name
                              : '${_module!.id}/${_modulePage!.slug}'),
                          delay: Motion.stagger * 2,
                          child: _content(user),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(AuthUser user) {
    // Module routes take precedence: when the URL names a module page, that is
    // what the shell shows.
    final module = _module;
    final page = _modulePage;
    if (module != null && page != null) {
      return ModulePageScreen(module: module, page: page);
    }

    switch (_section) {
      case DashboardSection.overview:
        final up = _fetch(DashboardSection.overview, _repo.upcoming);
        return OverviewScreen(
          user: user,
          upcoming: (up.value as List<UpcomingItem>?) ?? const [],
          upcomingLoading: up.loading,
          data: _data,
          loading: _loading,
          error: _dataError,
          onRetry: _load,
          range: _range,
          series: _series[_range],
          seriesLoading: _seriesLoading,
          seriesError: _seriesError,
          onRange: _loadSeries,
          onRetrySeries: () => _loadSeries(_range),
          onNavigate: _select,
        );
      case DashboardSection.profile:
        return ProfilePage(
          user: user,
          activity: _data?.activity ?? const [],
          loading: _loading,
        );
      case DashboardSection.settings:
        return SettingsPage(user: user, controller: widget.controller);
      case DashboardSection.notifications:
        return NotificationsPage(
          items: _notifications,
          loading: _notificationsLoading,
          error: _notificationsError,
          onRetry: _loadNotifications,
          onRead: (n) => _markRead(id: n.id),
          onReadAll: _markRead,
          onDelete: _deleteNotification,
          onClearAll: _clearNotifications,
        );
      case DashboardSection.users:
        final r = _fetch(_section, _repo.members);
        return UsersPage(
          members: (r.value as List<Member>?) ?? const [],
          loading: r.loading,
          error: r.error,
          onRetry: () => _retry(DashboardSection.users),
        );
      case DashboardSection.customers:
        final r = _fetch(_section, _repo.customers);
        return CustomersPage(
          customers: (r.value as List<Customer>?) ?? const [],
          loading: r.loading,
          error: r.error,
          onRetry: () => _retry(DashboardSection.customers),
        );
      case DashboardSection.projects:
        final r = _fetch(_section, _repo.projects);
        return ProjectsPage(
          projects: (r.value as List<ProjectRecord>?) ?? const [],
          loading: r.loading,
          error: r.error,
          onRetry: () => _retry(DashboardSection.projects),
        );
      case DashboardSection.tasks:
        final r = _fetch(_section, _repo.tasks);
        return TasksPage(
          tasks: (r.value as List<TaskRecord>?) ?? const [],
          loading: r.loading,
          error: r.error,
          onRetry: () => _retry(DashboardSection.tasks),
        );
      case DashboardSection.reports:
        final r = _fetch(_section, _repo.reports);
        return ReportsPage(
          data: r.value as ReportsData?,
          loading: r.loading,
          error: r.error,
          onRetry: () => _retry(DashboardSection.reports),
        );
      // Messages and Help have no backend yet; they say so rather than
      // rendering invented content.
      case DashboardSection.messages:
      case DashboardSection.help:
        return _Placeholder(section: _section);
    }
  }
}

/// One directory fetch: loading, then either a value or an error.
///
/// Small enough to keep here rather than pulling in a state-management
/// package for four screens.
class _Async<T> {
  const _Async({this.value, this.error, this.loading = false});

  final T? value;
  final String? error;
  final bool loading;
}

/// Rounded white panel the sidebar and header sit in, so each reads as its own
/// surface floating on the background.
class _Surface extends StatelessWidget {
  const _Surface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 18,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// The overview itself: welcome, KPIs, analytics, and the detail panels.
class OverviewScreen extends StatelessWidget {
  const OverviewScreen({
    super.key,
    required this.user,
    required this.data,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.range,
    required this.series,
    required this.seriesLoading,
    required this.seriesError,
    required this.onRange,
    required this.onRetrySeries,
    required this.onNavigate,
    required this.upcoming,
    required this.upcomingLoading,
  });

  final AuthUser user;
  final DashboardData? data;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final ChartRange range;
  final PerformanceSeries? series;
  final bool seriesLoading;
  final String? seriesError;
  final ValueChanged<ChartRange> onRange;
  final VoidCallback onRetrySeries;
  final ValueChanged<DashboardSection> onNavigate;
  final List<UpcomingItem> upcoming;
  final bool upcomingLoading;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final d = data;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Welcome text and the page's primary action share a row on wide
        // screens and stack on narrow ones.
        LayoutBuilder(
          builder: (context, c) {
            final banner = WelcomeBanner(user: user, now: now);
            final action = FilledButton.icon(
              onPressed: () => onNavigate(DashboardSection.projects),
              icon: const Icon(Icons.create_new_folder_outlined, size: 18),
              label: const Text('Create Project'),
              style: FilledButton.styleFrom(
                backgroundColor: kIndigo,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
            if (c.maxWidth < 640) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [banner, const SizedBox(height: 16), action],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: banner),
                const SizedBox(width: 16),
                action,
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        if (error != null)
          Panel(child: ErrorState(message: error!, onRetry: onRetry))
        else if (loading || d == null)
          const _OverviewSkeleton()
        else
          _OverviewBody(
            data: d,
            now: now,
            upcoming: upcoming,
            upcomingLoading: upcomingLoading,
            range: range,
            series: series,
            seriesLoading: seriesLoading,
            seriesError: seriesError,
            onRange: onRange,
            onRetrySeries: onRetrySeries,
            onNavigate: onNavigate,
          ),
      ],
    );
  }
}

class _OverviewBody extends StatelessWidget {
  const _OverviewBody({
    required this.data,
    required this.now,
    required this.upcoming,
    required this.upcomingLoading,
    required this.range,
    required this.series,
    required this.seriesLoading,
    required this.seriesError,
    required this.onRange,
    required this.onRetrySeries,
    required this.onNavigate,
  });

  final DashboardData data;
  final DateTime now;
  final List<UpcomingItem> upcoming;
  final bool upcomingLoading;
  final ChartRange range;
  final PerformanceSeries? series;
  final bool seriesLoading;
  final String? seriesError;
  final ValueChanged<ChartRange> onRange;
  final VoidCallback onRetrySeries;
  final ValueChanged<DashboardSection> onNavigate;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final kpiColumns = w >= 1500
            ? 6 // all six KPIs on one row once they stay readable
            : w >= 900
                ? 3
                : w >= 600
                    ? 2
                    : 1;
        final twoUp = w >= 1000;

        final performance = PerformancePanel(
          range: range,
          onRange: onRange,
          series: series,
          loading: seriesLoading,
          error: seriesError,
          onRetry: onRetrySeries,
        );
        final activity = RecentActivityPanel(items: data.activity, now: now);
        final upcomingPanel = UpcomingPanel(
          items: upcoming,
          now: now,
          loading: upcomingLoading,
        );
        final userActivity = UserActivityPanel(buckets: data.userActivity);
        final projectStatus = ProjectStatusPanel(slices: data.projectBreakdown);
        final projects = ProjectTable(
          projects: data.projects,
          onView: (p) => showToast(
            context,
            '${p.name} — a project detail screen is not built yet.',
            isError: false,
          ),
        );
        final tasks = TaskOverviewPanel(tasks: data.tasks);
        final health = SystemHealthPanel(services: data.health);
        final quick = QuickActions(
          // Only destinations that exist in this shell.
          actions: [
            (
              label: 'Add User',
              icon: Icons.person_add_alt,
              onTap: () => onNavigate(DashboardSection.users)
            ),
            (
              label: 'Add Customer',
              icon: Icons.business_outlined,
              onTap: () => onNavigate(DashboardSection.customers)
            ),
            (
              label: 'Create Project',
              icon: Icons.create_new_folder_outlined,
              onTap: () => onNavigate(DashboardSection.projects)
            ),
            (
              label: 'Create Task',
              icon: Icons.add_task,
              onTap: () => onNavigate(DashboardSection.tasks)
            ),
            (
              label: 'Generate Report',
              icon: Icons.description_outlined,
              onTap: () => onNavigate(DashboardSection.reports)
            ),
          ],
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Grid(
              columns: kpiColumns,
              children: [for (final k in data.kpis) KpiCard(kpi: k)],
            ),
            const SizedBox(height: 16),
            if (twoUp) ...[
              // Activity is a long feed; stretching the chart panel to match
              // it would leave a large gap under the chart.
              _SideBySide(
                left: performance,
                right: activity,
                leftFlex: 3,
                rightFlex: 2,
                stretch: false,
              ),
              const SizedBox(height: 16),
              _SideBySide(left: userActivity, right: projectStatus),
              const SizedBox(height: 16),
              _SideBySide(
                left: projects,
                right: upcomingPanel,
                leftFlex: 3,
                rightFlex: 2,
                stretch: false,
              ),
              const SizedBox(height: 16),
              _SideBySide(left: tasks, right: health, leftFlex: 3, rightFlex: 2),
              const SizedBox(height: 16),
              quick,
            ] else
              StaggeredColumn(
                children: [
                  performance,
                  userActivity,
                  projectStatus,
                  projects,
                  upcomingPanel,
                  tasks,
                  activity,
                  health,
                  quick,
                ],
              ),
          ],
        );
      },
    );
  }
}

/// Two panels sharing a row, each stretched to the taller one's height.
class _SideBySide extends StatelessWidget {
  const _SideBySide({
    required this.left,
    required this.right,
    this.leftFlex = 1,
    this.rightFlex = 1,
    this.stretch = true,
  });

  final Widget left;
  final Widget right;
  final int leftFlex;
  final int rightFlex;

  /// Match both panels to the taller one. Off when one side is much taller,
  /// which would leave a band of dead space inside the shorter panel.
  final bool stretch;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      crossAxisAlignment:
          stretch ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
      children: [
        Expanded(flex: leftFlex, child: left),
        const SizedBox(width: 16),
        Expanded(flex: rightFlex, child: right),
      ],
    );
    return stretch ? IntrinsicHeight(child: row) : row;
  }
}

/// Equal-width grid that reflows by column count. Wrap rather than GridView so
/// each cell keeps its natural height.
class _Grid extends StatelessWidget {
  const _Grid({required this.columns, required this.children});

  final int columns;
  final List<Widget> children;

  static const gap = 16.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final width = (c.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final (i, child) in children.indexed)
              SizedBox(
                width: width,
                child: FadeIn(delay: Motion.stagger * i, child: child),
              ),
          ],
        );
      },
    );
  }
}

/// Skeleton mirroring the real overview layout, so the page does not jump when
/// the data lands.
class _OverviewSkeleton extends StatelessWidget {
  const _OverviewSkeleton();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final columns = c.maxWidth >= 900
            ? 3
            : c.maxWidth >= 600
                ? 2
                : 1;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Grid(
              columns: columns,
              children: [
                for (var i = 0; i < 6; i++) const SkeletonPanel(lines: 2),
              ],
            ),
            const SizedBox(height: 16),
            const SkeletonPanel(lines: 4, height: 260),
            const SizedBox(height: 16),
            const SkeletonPanel(lines: 4, height: 220),
          ],
        );
      },
    );
  }
}

/// A destination that exists in navigation but has no backend behind it yet.
/// Says so rather than inventing content.
class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.section});

  final DashboardSection section;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          section.label,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: kInk,
          ),
        ),
        const SizedBox(height: 20),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Panel(
            child: EmptyState(
              icon: section.icon,
              title: '${section.label} is not built yet',
              message: 'This screen is wired into navigation and is ready for '
                  'the ${section.label.toLowerCase()} API when it exists.',
            ),
          ),
        ),
      ],
    );
  }
}

