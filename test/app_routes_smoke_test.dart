import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stackly_auth/auth.dart';
import 'package:stackly_auth/providers/auth_provider.dart';
import 'package:stackly_auth/router/app_router.dart';

import 'test_app.dart';

/// Smoke test: sign in once, then walk a representative page from each major
/// module and assert nothing throws on the way.
///
/// One sign-in for the whole walk, not one per route — signing in per route
/// made this file slower than the rest of the suite combined.
///
/// Bounded pumps, never pumpAndSettle: the loading Skeleton runs a repeating
/// pulse, so settling never completes while a page is loading.
void main() {
  Future<void> step(WidgetTester tester, [int n = 8]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  const paths = <String>[
    AppRoutes.dashboard,
    AppRoutes.users,
    AppRoutes.customers,
    AppRoutes.projects,
    AppRoutes.tasks,
    AppRoutes.settings,
    '/hrms/employees',
    '/crm/leads',
    '/finance/ledger',
    '/erp/inventory',
    '/security/audit',
  ];

  testWidgets('every major route renders without throwing', (tester) async {
    final auth = AuthProvider(DemoAuthBackend(latency: Duration.zero));
    addTearDown(auth.dispose);
    tester.view.physicalSize = const Size(1366, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(TestApp(auth: auth));
    await step(tester);
    // unawaited + pump, not await: the controller's timers only advance while
    // the test pumps, so awaiting the future here deadlocks the test.
    unawaited(auth.signIn('me@stackly.com', 'password123'));
    await step(tester);
    unawaited(auth.verify(DemoAuthBackend.demoCode));
    await step(tester);
    expect(auth.status, AuthStatus.authenticated);

    final router = tester.state<TestAppState>(find.byType(TestApp)).router;
    for (final path in paths) {
      router.go(path);
      await step(tester);
      expect(tester.takeException(), isNull, reason: '$path threw on render');
    }
  });
}
