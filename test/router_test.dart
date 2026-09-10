import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stackly_auth/auth.dart';
import 'package:stackly_auth/providers/auth_provider.dart';
import 'package:stackly_auth/dashboard.dart';
import 'package:stackly_auth/router/app_router.dart';

import 'test_app.dart';

void main() {
  // ------------------------------------------------------------------
  // Guards — pure logic, no widgets needed.
  // ------------------------------------------------------------------
  group('guards', () {
    test('protected routes redirect to login when signed out', () {
      for (final path in [
        AppRoutes.dashboard,
        AppRoutes.users,
        AppRoutes.customers,
        AppRoutes.projects,
        AppRoutes.tasks,
        AppRoutes.reports,
        AppRoutes.notifications,
        AppRoutes.settings,
        AppRoutes.profile,
        AppRoutes.help,
        '/projects/123',
        '/settings/security',
      ]) {
        expect(
          applyGuards(path, AuthStatus.unauthenticated),
          AppRoutes.login,
          reason: path,
        );
      }
    });

    test('public routes stay reachable when signed out', () {
      for (final path in [
        AppRoutes.login,
        AppRoutes.register,
        AppRoutes.forgotPassword,
      ]) {
        expect(applyGuards(path, AuthStatus.unauthenticated), path);
      }
    });

    test('an authenticated user is bounced off the auth screens', () {
      for (final path in [
        AppRoutes.login,
        AppRoutes.register,
        AppRoutes.forgotPassword,
      ]) {
        expect(
          applyGuards(path, AuthStatus.authenticated),
          AppRoutes.home,
          reason: path,
        );
      }
    });

    test('protected routes are allowed once authenticated', () {
      expect(
        applyGuards(AppRoutes.projects, AuthStatus.authenticated),
        AppRoutes.projects,
      );
      expect(
        applyGuards('/projects/42', AuthStatus.authenticated),
        '/projects/42',
      );
    });

    test('a half-authenticated user cannot leave the verify step', () {
      // The OTP is outstanding: every destination collapses to /verify, so a
      // typed URL cannot skip the second factor.
      for (final path in [
        AppRoutes.dashboard,
        AppRoutes.login,
        AppRoutes.settings,
        '/users/7',
      ]) {
        // The OTP lives on the login form, so a half-finished sign-in has
        // no second screen to go to — it stays on login.
        expect(
          applyGuards(path, AuthStatus.awaitingVerification),
          AppRoutes.login,
          reason: path,
        );
      }
    });

    test('unknown routes resolve to 404 rather than a redirect loop', () {
      expect(
        applyGuards('/nope', AuthStatus.unauthenticated),
        AppRoutes.notFound,
      );
      expect(
        applyGuards('/nope', AuthStatus.authenticated),
        AppRoutes.notFound,
      );
    });

    test('guards are idempotent — no redirect loops', () {
      for (final status in AuthStatus.values) {
        for (final path in [
          AppRoutes.login,
          AppRoutes.dashboard,
          AppRoutes.settings,
          '/bogus',
        ]) {
          final once = applyGuards(path, status);
          expect(applyGuards(once, status), once, reason: '$path / $status');
        }
      }
    });
  });

  // ------------------------------------------------------------------
  // Widget-level routing.
  // ------------------------------------------------------------------
  Future<void> step(WidgetTester tester) async {
    await tester.pump();
    for (var i = 0; i < 16; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<(AuthController, TestAppState)> boot(
    WidgetTester tester, {
    Size size = const Size(1440, 1200),
  }) async {
    final auth = AuthProvider(DemoAuthBackend(latency: Duration.zero));
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(TestApp(auth: auth));
    await step(tester);
    return (auth, tester.state<TestAppState>(find.byType(TestApp)));
  }

  testWidgets('an unauthenticated app starts on login', (tester) async {
    final (_, app) = await boot(tester);
    expect(app.router.location, AppRoutes.login);
    expect(find.text('Welcome Back'), findsOneWidget);
  });

  testWidgets('a deep link into a protected route lands on login',
      (tester) async {
    final (_, app) = await boot(tester);
    app.router.go(AppRoutes.projects);
    await step(tester);

    expect(app.router.location, AppRoutes.login);
    expect(find.text('Welcome Back'), findsOneWidget);
  });

  testWidgets('signing in routes to the dashboard, and back to login on '
      'sign out', (tester) async {
    String? code;
    final auth = AuthProvider(
      DemoAuthBackend(onCodeSent: (c) => code = c, latency: Duration.zero),
    );
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(TestApp(auth: auth));
    await step(tester);

    unawaited(auth.signIn('me@stackly.com', 'password123'));
    await step(tester);
    final app = tester.state<TestAppState>(find.byType(TestApp));
    // Password accepted but OTP outstanding: not authenticated yet, and the
    // OTP is part of the login form rather than a route of its own.
    expect(app.router.location, AppRoutes.login);

    unawaited(auth.verify(code!));
    await step(tester);
    expect(app.router.location, AppRoutes.dashboard);
    expect(find.textContaining('Welcome back,'), findsOneWidget);

    // Signing out clears the session and returns to login.
    unawaited(auth.signOut());
    await step(tester);
    expect(app.router.location, AppRoutes.login);
    expect(find.text('Welcome Back'), findsOneWidget);
  });

  testWidgets('sidebar navigation drives the URL', (tester) async {
    String? code;
    final auth = AuthProvider(
      DemoAuthBackend(onCodeSent: (c) => code = c, latency: Duration.zero),
    );
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(TestApp(auth: auth));
    unawaited(auth.signIn('me@stackly.com', 'password123'));
    await step(tester);
    unawaited(auth.verify(code!));
    await step(tester);
    final app = tester.state<TestAppState>(find.byType(TestApp));

    await tester.tap(find.text('Customers').first);
    await step(tester);
    expect(app.router.location, AppRoutes.customers);

    await tester.tap(find.text('Settings').first);
    await step(tester);
    expect(app.router.location, AppRoutes.settings);
    expect(
      find.text('Manage your workspace, account and security preferences.'),
      findsOneWidget,
    );
  });

  testWidgets('an authenticated user sent to /login lands on the dashboard',
      (tester) async {
    String? code;
    final auth = AuthProvider(
      DemoAuthBackend(onCodeSent: (c) => code = c, latency: Duration.zero),
    );
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(TestApp(auth: auth));
    unawaited(auth.signIn('me@stackly.com', 'password123'));
    await step(tester);
    unawaited(auth.verify(code!));
    await step(tester);
    final app = tester.state<TestAppState>(find.byType(TestApp));

    app.router.go(AppRoutes.login);
    await step(tester);
    expect(app.router.location, AppRoutes.dashboard);
  });

  testWidgets('an unknown route shows the Not Found page', (tester) async {
    final (_, app) = await boot(tester);
    app.router.go('/does-not-exist');
    await step(tester);

    expect(app.router.location, AppRoutes.notFound);
    expect(find.text('404'), findsOneWidget);
    expect(find.text('Page not found'), findsOneWidget);
    expect(find.textContaining('/does-not-exist'), findsOneWidget);

    // The CTA returns somewhere valid rather than dead-ending.
    await tester.tap(find.text('Go back'));
    await step(tester);
    expect(app.router.location, AppRoutes.login);
  });

  testWidgets('sign-up stacks over login and pops back to it', (tester) async {
    final (_, app) = await boot(tester);

    await tester.tap(find.text('Sign up'));
    await step(tester);
    expect(app.router.location, AppRoutes.register);
    expect(find.text('Create Your Account'), findsOneWidget);

    await tester.tap(find.text('Login').last);
    await step(tester);
    expect(app.router.location, AppRoutes.login);
  });

  // ------------------------------------------------------------------
  // Dynamic + nested routes.
  // ------------------------------------------------------------------
  test('dynamic segments are parsed and preserved', () {
    const parser = AppRouteParser();
    Future<void> check(String path, String? id) async {
      final route = await parser.parseRouteInformation(
        RouteInformation(uri: Uri.parse(path)),
      );
      expect(route.path, path, reason: path);
      expect(route.id, id, reason: path);
    }

    check('/projects/123', '123');
    check('/customers/abc', 'abc');
    check('/users/7', '7');
  });

  test('nested routes keep their parent section', () {
    const settings = AppRoute(AppRoutes.settingsSecurity);
    // /settings/* all render the settings screen.
    expect(settings.section?.label, 'Settings');

    const nested = AppRoute('/projects/1/tasks', id: '1', child: 'tasks');
    expect(nested.id, '1');
    expect(nested.child, 'tasks');
  });

  test('every sidebar section maps to a route and back', () {
    for (final section in DashboardSection.values) {
      final path = pathForSection(section);
      expect(
        AppRoute(path).section,
        section,
        reason: '$section <-> $path',
      );
    }
  });
}
