import 'package:flutter/material.dart';

import '../auth.dart';
import '../core/platform/modules.dart';
import '../core/platform/permissions.dart';
import '../dashboard.dart';
import '../features/dashboard/services/dashboard_repository.dart';
import '../features/auth/screens/login/login_screen.dart';
import '../motion.dart';
import '../not_found_page.dart';
import '../providers/navigation_provider.dart';
import '../signup_page.dart';
import '../unauthorized_page.dart';

/// THE single source of truth for application routing.
///
/// Every route name, every guard and the whole route table live in this file.
/// Screens never build routes of their own — they call [AppRouter.go] (or the
/// helpers on [BuildContext] at the bottom of this file) with a name from
/// [AppRoutes].
///
/// ponytail: built on Flutter's own Router API rather than go_router. The
/// entire route table is the `switch` in [_resolve]; a package would add a
/// dependency and its own DSL to express the same dozen lines. Swap in
/// go_router if nested navigators or shell routes ever become a real
/// requirement — [AppRoutes] and the guard rules would carry over unchanged.

// ---------------------------------------------------------------------------
// 1. Route names
// ---------------------------------------------------------------------------

/// Canonical route names. Nothing in the app hardcodes a path string.
class AppRoutes {
  const AppRoutes._();

  // --- Public / authentication routes -------------------------------------
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';

  // --- Protected routes ----------------------------------------------------
  static const dashboard = '/dashboard';
  static const users = '/users';
  static const customers = '/customers';
  static const projects = '/projects';
  static const tasks = '/tasks';
  static const reports = '/reports';
  static const notifications = '/notifications';
  static const messages = '/messages';
  static const profile = '/profile';
  static const help = '/help';

  // --- Settings ------------------------------------------------------------
  static const settings = '/settings';
  static const settingsProfile = '/settings/profile';
  static const settingsSecurity = '/settings/security';

  // --- Error ---------------------------------------------------------------
  static const notFound = '/404';
  static const unauthorized = '/403';

  /// Where an authenticated user lands.
  static const home = dashboard;

  /// Routes reachable without a session. Everything else is protected, so a
  /// new route is guarded by default rather than by remembering to list it.
  static const _public = {login, register, forgotPassword};

  static bool isPublic(String path) => _public.contains(_stripQuery(path));
}

// ---------------------------------------------------------------------------
// 2. Parsed route
// ---------------------------------------------------------------------------

/// A resolved location: which screen, plus any id captured from a dynamic
/// segment such as `/projects/123`.
@immutable
class AppRoute {
  const AppRoute(this.path, {this.id, this.child, this.module, this.page});

  /// The platform module this route belongs to, when it is a `/module/page`
  /// route. Null for legacy and auth routes.
  final PlatformModule? module;

  /// The specific page within [module]. Carries the permission the guard
  /// checks, so authorization is resolved from the route table rather than
  /// re-derived per screen.
  final ModulePage? page;

  /// The permission required to open this route, or null when it needs none
  /// beyond being signed in.
  String? get requiredPermission => page?.permission;

  /// The canonical path, e.g. `/projects` or `/projects/123`.
  final String path;

  /// Captured `:id` for dynamic routes, else null.
  final String? id;

  /// Sub-section of a nested route, e.g. `tasks` in `/projects/1/tasks`.
  final String? child;

  /// The [DashboardSection] this route displays, or null if it is not a
  /// dashboard route. Keeps the sidebar and the URL in agreement.
  DashboardSection? get section => switch (_base) {
        AppRoutes.dashboard => DashboardSection.overview,
        AppRoutes.users => DashboardSection.users,
        AppRoutes.customers => DashboardSection.customers,
        AppRoutes.projects => DashboardSection.projects,
        AppRoutes.tasks => DashboardSection.tasks,
        AppRoutes.reports => DashboardSection.reports,
        AppRoutes.notifications => DashboardSection.notifications,
        AppRoutes.messages => DashboardSection.messages,
        AppRoutes.profile => DashboardSection.profile,
        AppRoutes.help => DashboardSection.help,
        // Every /settings/* leaf shows the settings screen.
        final p when p == AppRoutes.settings => DashboardSection.settings,
        _ => null,
      };

  String get _base {
    final p = _stripQuery(path);
    if (p.startsWith('${AppRoutes.settings}/')) return AppRoutes.settings;
    final segments = p.split('/').where((s) => s.isNotEmpty).toList();
    return segments.isEmpty ? AppRoutes.dashboard : '/${segments.first}';
  }

  @override
  bool operator ==(Object other) =>
      other is AppRoute &&
      other.path == path &&
      other.id == id &&
      other.page?.slug == page?.slug;

  @override
  int get hashCode => Object.hash(path, id);
}

String _stripQuery(String path) => path.split('?').first;

// ---------------------------------------------------------------------------
// 3. Route table
// ---------------------------------------------------------------------------

/// Turns a raw path into an [AppRoute]. This `switch` IS the route table —
/// adding a screen means adding a case here and a name in [AppRoutes].
AppRoute _resolve(String rawPath) {
  final path = _stripQuery(rawPath);
  final segments = path.split('/').where((s) => s.isNotEmpty).toList();

  if (segments.isEmpty) return const AppRoute(AppRoutes.dashboard);

  // Module routes (/<module>/<page>) resolve from the registry in
  // core/platform/modules.dart, so adding a page there routes it here with no
  // change to this function.
  final module = kModulesById[segments.first];
  if (module != null) {
    // Bare /<module>: when a legacy route already owns this module's landing
    // screen (/reports, /notifications), fall through to the switch below so
    // that existing screen keeps serving it. Two routes for one screen is
    // exactly the duplication the registry exists to prevent.
    if (segments.length == 1 && module.legacyPath == null) {
      final landing = module.pages.first;
      return AppRoute(
        module.pathFor(landing),
        module: module,
        page: landing,
      );
    }
    final page = segments.length > 1 ? module.page(segments[1]) : null;
    if (page != null) {
      // The landing slug under a legacy module (/reports/overview) is not a
      // route of its own — the legacy path is canonical.
      if (module.legacyPath != null && page.slug == module.pages.first.slug) {
        return AppRoute(AppRoutes.notFound, id: path);
      }
      return AppRoute(
        module.pathFor(page),
        module: module,
        page: page,
        // A third segment is a record id: /crm/leads/42.
        id: segments.length > 2 ? segments[2] : null,
      );
    }
    // Known module, unknown page — a genuine 404, not a permission problem.
    // Bare legacy paths fall through instead, to the switch that owns them.
    if (!(segments.length == 1 && module.legacyPath != null)) {
      return AppRoute(AppRoutes.notFound, id: path);
    }
  }

  return switch (segments) {
    // --- Static routes ----------------------------------------------------
    ['403'] => const AppRoute(AppRoutes.unauthorized),
    ['login'] => const AppRoute(AppRoutes.login),
    ['register'] => const AppRoute(AppRoutes.register),
    ['forgot-password'] => const AppRoute(AppRoutes.forgotPassword),
    ['dashboard'] => const AppRoute(AppRoutes.dashboard),
    ['notifications'] => const AppRoute(AppRoutes.notifications),
    ['messages'] => const AppRoute(AppRoutes.messages),
    ['profile'] => const AppRoute(AppRoutes.profile),
    ['help'] => const AppRoute(AppRoutes.help),
    ['reports'] => const AppRoute(AppRoutes.reports),

    // --- Settings (nested) -------------------------------------------------
    ['settings'] => const AppRoute(AppRoutes.settings),
    ['settings', 'profile'] => const AppRoute(AppRoutes.settingsProfile),
    ['settings', 'security'] => const AppRoute(AppRoutes.settingsSecurity),

    // --- Collection + dynamic detail routes --------------------------------
    // The detail screens are not built yet; the id is parsed and carried so
    // the URL keeps working and the screen can use it once it exists.
    ['users'] => const AppRoute(AppRoutes.users),
    ['users', final id] => AppRoute('${AppRoutes.users}/$id', id: id),
    ['customers'] => const AppRoute(AppRoutes.customers),
    ['customers', final id] => AppRoute('${AppRoutes.customers}/$id', id: id),
    ['projects'] => const AppRoute(AppRoutes.projects),
    ['projects', final id] => AppRoute('${AppRoutes.projects}/$id', id: id),
    ['projects', final id, 'tasks'] =>
      AppRoute('${AppRoutes.projects}/$id/tasks', id: id, child: 'tasks'),
    ['tasks'] => const AppRoute(AppRoutes.tasks),
    ['tasks', final id] => AppRoute('${AppRoutes.tasks}/$id', id: id),

    // --- Unknown -----------------------------------------------------------
    _ => AppRoute(AppRoutes.notFound, id: path),
  };
}

// ---------------------------------------------------------------------------
// 4. Guards
// ---------------------------------------------------------------------------

/// The one place that decides whether a location is allowed for the current
/// auth state. Returns the path to show — the request itself when permitted,
/// or a redirect target.
///
/// A half-authenticated user (password accepted, OTP outstanding) is NOT
/// authenticated. Because the OTP lives on the login form there is no second
/// screen to send them to — they stay on login until the code is accepted.
String applyGuards(
  String requested,
  AuthStatus status, {
  PermissionSet permissions = const PermissionSet.empty(),
}) {
  final path = _stripQuery(requested);
  final route = _resolve(path);

  switch (status) {
    case AuthStatus.authenticated:
      // Signed in: the auth screens have nothing to offer. Bounce to the
      // dashboard rather than letting a stale /login URL show a login form.
      if (AppRoutes.isPublic(path)) return AppRoutes.home;

      // Authorization. A route that declares a permission is refused unless
      // the principal holds it — this is the ONE place route-level access is
      // decided, so no screen can be reached by a URL that skipped a check.
      //
      // SECURITY: a UX guard only. The API must re-check every one of these;
      // hiding a route does not protect the data behind it.
      final needed = route.requiredPermission;
      if (needed != null && !permissions.can(needed)) {
        return AppRoutes.unauthorized;
      }
      return route.path;

    case AuthStatus.unauthenticated:
    case AuthStatus.authenticating:
    case AuthStatus.awaitingVerification:
      // The OTP is part of the login form, so a half-finished sign-in is
      // still the login screen — there is no second route to land on.
      //
      // 404 stays visible while signed out; it leaks nothing and redirecting
      // it to /login would hide genuine typos behind a login form.
      if (route.path == AppRoutes.notFound) return route.path;
      // A signed-out user hitting /403 is sent to login: there is nothing to
      // deny yet, and the login screen is the actionable next step.
      if (AppRoutes.isPublic(path)) return route.path;
      return AppRoutes.login;
  }
}

// ---------------------------------------------------------------------------
// 5. Router
// ---------------------------------------------------------------------------

/// Drives [MaterialApp.router]. Owns the current location, applies the guards
/// on every change, and builds the page stack.
class AppRouter extends RouterDelegate<AppRoute>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<AppRoute> {
  AppRouter({
    required this.auth,
    this.dashboardRepository,
    NavigationProvider? navigation,
  }) : navigation = navigation ?? NavigationProvider() {
    // Signing in or out re-runs the guards, so an expired session leaves a
    // protected screen on its own rather than waiting for the next tap.
    auth.addListener(_onAuthChanged);
  }

  final AuthController auth;

  /// Sidebar/navigation UI state. The router pushes the active section into it
  /// on every route change, so the highlight follows the URL rather than the
  /// tap — deep links and browser back stay in sync for free.
  final NavigationProvider navigation;

  /// Passed through to the dashboard; injectable for tests and a real API.
  final DashboardRepository? dashboardRepository;

  @override
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  String _location = AppRoutes.login;

  /// The location currently displayed, after guards.
  String get location => _location;

  @override
  AppRoute get currentConfiguration => _resolve(_location);

  /// The path the user actually asked for, kept so the 404 page can echo it
  /// back — `_location` holds the post-guard destination, not the request.
  String? _attempted;

  /// Mirrors the active section into [navigation]. Called after every change
  /// to `_location`, so there is exactly one place the highlight is updated.
  void _syncNavigation() {
    final route = _resolve(_location);
    final section = route.section;
    if (section != null) navigation.syncWithRoute(section);
    // Deep link into a module page: open that module so the user can see where
    // they are rather than landing in a collapsed sidebar.
    final module = route.module;
    if (module != null) navigation.revealModule(module.id);
  }

  void _onAuthChanged() {
    final next = applyGuards(_location, auth.status,
        permissions: auth.permissions);
    if (next != _location) {
      _location = next;
      _syncNavigation();
    }
    // Always notify, even when the path is unchanged: screens read state such
    // as `auth.error` and `auth.busy` straight off the controller, and the
    // previous AuthGate rebuilt them on every notification.
    notifyListeners();
  }

  /// Navigate to a named route. The single entry point for app navigation.
  void go(String path) {
    final next =
        applyGuards(path, auth.status, permissions: auth.permissions);
    _attempted = next == AppRoutes.notFound || next == AppRoutes.unauthorized
        ? _stripQuery(path)
        : null;
    if (next == _location) return;
    _location = next;
    _syncNavigation();
    notifyListeners();
  }

  /// Sign out through the existing auth controller, then land on login.
  /// The redirect falls out of [_onAuthChanged] — there is no second path.
  Future<void> signOut() => auth.signOut();

  @override
  Future<void> setNewRoutePath(AppRoute configuration) async {
    // Entry point for deep links and browser back/forward.
    final next = applyGuards(configuration.path, auth.status,
        permissions: auth.permissions);
    _attempted = next == AppRoutes.notFound || next == AppRoutes.unauthorized
        ? (configuration.path)
        : null;
    _location = next;
    _syncNavigation();
    notifyListeners();
  }

  @override
  Future<bool> popRoute() async {
    // Sign-up sits on top of login; popping it returns to login.
    if (currentConfiguration.path == AppRoutes.register) {
      go(AppRoutes.login);
      return true;
    }
    return super.popRoute();
  }

  @override
  void dispose() {
    auth.removeListener(_onAuthChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final route = currentConfiguration;

    // Screens read `auth.error`, `auth.busy` and `auth.user` directly off the
    // controller rather than subscribing themselves, so the page stack is
    // rebuilt on every auth notification — the same single rebuild point the
    // previous AuthGate provided.
    return AnimatedBuilder(
      // Listen to both: `this` for route changes, `auth` because screens read
      // controller state (error, busy, user) directly rather than subscribing.
      animation: Listenable.merge([this, auth]),
      builder: (context, _) => Navigator(
        key: navigatorKey,
        onDidRemovePage: (page) {
          // Only the sign-up page is ever stacked; removing it means "go back
          // to login".
          if (page.name == AppRoutes.register) go(AppRoutes.login);
        },
        pages: [
          for (final page in _pagesFor(route)) page,
        ],
      ),
    );
  }

  /// The page stack for a location. Sign-up is the only route that stacks;
  /// everything else replaces, so there is no history to "back" into after
  /// signing out.
  List<Page<void>> _pagesFor(AppRoute route) {
    final section = route.section;

    // Module routes and section routes share ONE shell page: same key, so the
    // shell element (and its fetched data) survives moving between them.
    if (section != null || route.module != null) {
      return [
        // One stable key across every dashboard destination: switching
        // sections must reuse the same page element, so the shell keeps its
        // fetched data instead of remounting and reloading on each tap.
        //
        // Because the page (and its route) are reused, the builder below runs
        // only once — so the content subscribes to the router itself and reads
        // the section at build time, rather than capturing it here.
        _FadePage(
          name: route.path,
          key: const ValueKey('dashboard'),
          builder: (_) => AnimatedBuilder(
            animation: this,
            builder: (context, _) => DashboardPage(
              controller: auth,
              repository: dashboardRepository,
              // Sidebar selection is driven by the URL, not by local state.
              section:
                  currentConfiguration.section ?? DashboardSection.overview,
              module: currentConfiguration.module,
              modulePage: currentConfiguration.page,
              onNavigate: (s) => go(pathForSection(s)),
            ),
          ),
        ),
      ];
    }

    return switch (route.path) {
      AppRoutes.register => [
          _FadePage(
            name: AppRoutes.login,
            key: const ValueKey('login'),
            builder: (_) => const LoginScreen(),
          ),
          // Pushed on top, preserving the existing slide-up sign-up flow.
          MaterialPage(
            name: AppRoutes.register,
            key: const ValueKey('register'),
            child: SignUpPage(controller: auth),
          ),
        ],
      AppRoutes.unauthorized => [
          _FadePage(
            name: AppRoutes.unauthorized,
            key: const ValueKey('unauthorized'),
            builder: (_) => UnauthorizedPage(
              path: _attempted ?? '',
              requiredPermission:
                  _attempted == null ? null : _resolve(_attempted!).requiredPermission,
              onHome: () => go(homePathFor(auth.permissions)),
            ),
          ),
        ],
      AppRoutes.notFound => [
          _FadePage(
            name: AppRoutes.notFound,
            key: const ValueKey('not-found'),
            builder: (_) => NotFoundPage(
              path: _attempted ?? route.id ?? '',
              onHome: () => go(
                auth.status == AuthStatus.authenticated
                    ? AppRoutes.home
                    : AppRoutes.login,
              ),
            ),
          ),
        ],
      _ => [
          _FadePage(
            name: AppRoutes.login,
            key: const ValueKey('login'),
            builder: (_) => const LoginScreen(),
          ),
        ],
    };
  }
}

/// Where a principal lands after signing in.
///
/// The shared dashboard when they can open it, otherwise the first module
/// their permissions allow — so a narrowly-scoped user (a Partner, say) never
/// lands on a page that immediately bounces them to /403. Falls back to the
/// dashboard when nothing matches; the guard then decides.
String homePathFor(PermissionSet permissions) {
  if (permissions.can(Perm.selfService)) return AppRoutes.dashboard;
  final allowed = visibleModules(permissions);
  if (allowed.isEmpty) return AppRoutes.dashboard;
  final module = allowed.first;
  final pages = visiblePages(module, permissions);
  return pages.isEmpty ? AppRoutes.dashboard : module.pathFor(pages.first);
}

/// Maps a sidebar destination to its route. The sidebar holds no paths of its
/// own — it reports which section was tapped and the router decides the URL.
String pathForSection(DashboardSection section) => switch (section) {
      DashboardSection.overview => AppRoutes.dashboard,
      DashboardSection.users => AppRoutes.users,
      DashboardSection.customers => AppRoutes.customers,
      DashboardSection.projects => AppRoutes.projects,
      DashboardSection.tasks => AppRoutes.tasks,
      DashboardSection.reports => AppRoutes.reports,
      DashboardSection.notifications => AppRoutes.notifications,
      DashboardSection.messages => AppRoutes.messages,
      DashboardSection.profile => AppRoutes.profile,
      DashboardSection.settings => AppRoutes.settings,
      DashboardSection.help => AppRoutes.help,
    };

/// Screen swap matching the transition the app used before routing existed,
/// so centralizing routes did not change how the app looks or moves.
///
/// Takes a builder rather than a widget: a [Page] is immutable and its route
/// is created once, so a captured child would freeze the screen at the state
/// it had when the route was first pushed. The builder runs on every rebuild,
/// which is how `auth.error` and `auth.busy` reach the login screen.
class _FadePage<T> extends Page<T> {
  const _FadePage({required this.builder, required super.key, super.name});

  final WidgetBuilder builder;

  @override
  Route<T> createRoute(BuildContext context) {
    return PageRouteBuilder<T>(
      settings: this,
      transitionDuration: Motion.page,
      reverseTransitionDuration: Motion.page,
      pageBuilder: (context, animation, secondary) => builder(context),
      transitionsBuilder: (context, animation, secondary, child) {
        if (Motion.reduced(context)) return child;
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Motion.enter),
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, .02),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Motion.enter),
            ),
            child: child,
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 6. URL parsing
// ---------------------------------------------------------------------------

/// Translates between browser URLs and [AppRoute], so deep links and the
/// address bar work on web.
class AppRouteParser extends RouteInformationParser<AppRoute> {
  const AppRouteParser();

  @override
  Future<AppRoute> parseRouteInformation(
    RouteInformation routeInformation,
  ) async =>
      _resolve(routeInformation.uri.path);

  @override
  RouteInformation? restoreRouteInformation(AppRoute configuration) =>
      RouteInformation(uri: Uri.parse(configuration.path));
}

// ---------------------------------------------------------------------------
// 7. Navigation helpers
// ---------------------------------------------------------------------------

/// Lets any widget navigate without reaching for a Navigator:
/// `context.go(AppRoutes.settings)`.
extension AppNavigation on BuildContext {
  AppRouter get router =>
      (Router.of(this).routerDelegate as AppRouter);

  void go(String path) => router.go(path);
}
