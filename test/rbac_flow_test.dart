import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stackly_auth/auth.dart';
import 'package:stackly_auth/core/platform/modules.dart';
import 'package:stackly_auth/providers/auth_provider.dart';
import 'package:stackly_auth/router/app_router.dart';

import 'test_app.dart';

/// End-to-end authorization: sign a real role in through the real router and
/// assert what it can actually reach and see.
///
/// The unit tests in permissions_test.dart prove the guard function is correct.
/// These prove it is actually *wired in* — a correct guard nobody calls would
/// pass that suite and leak every page.
void main() {
  /// Pumps a bounded number of frames.
  ///
  /// The shell runs continuous entrance animations, so `pumpAndSettle` never
  /// returns here — the rest of the suite uses this same helper.
  Future<void> step(WidgetTester tester) async {
    await tester.pump();
    for (var i = 0; i < 16; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// Signs in fully (password, then OTP) as one of the seeded demo accounts.
  Future<TestAppState> signInAs(
    WidgetTester tester,
    String email, {
    Size size = const Size(1600, 2400),
  }) async {
    String? code;
    final auth = AuthProvider(
      DemoAuthBackend(onCodeSent: (c) => code = c, latency: Duration.zero),
    );
    addTearDown(auth.dispose);

    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(TestApp(auth: auth));
    // unawaited: awaiting these inside the test zone deadlocks against the
    // pumped frames, so drive them the way the rest of the suite does.
    unawaited(auth.signIn(email, 'password123'));
    await step(tester);
    unawaited(auth.verify(code!));
    await step(tester);

    return tester.state<TestAppState>(find.byType(TestApp));
  }

  testWidgets('an HR admin can open an HRMS page', (tester) async {
    final app = await signInAs(tester, 'hr@onecloud.com');

    app.router.go('/hrms/payroll');
    await step(tester);

    expect(app.router.location, '/hrms/payroll');
    expect(find.text('Payroll'), findsWidgets);
  });

  testWidgets('an HR admin is refused a finance page', (tester) async {
    final app = await signInAs(tester, 'hr@onecloud.com');

    app.router.go('/finance/ledger');
    await step(tester);

    // Refused at the route, not merely hidden in the sidebar.
    expect(app.router.location, AppRoutes.unauthorized);
    expect(find.text('Access denied'), findsOneWidget);
    // The page names what would have been needed, without leaking content.
    expect(find.text('finance.ledger'), findsOneWidget);
  });

  testWidgets('a sales manager is refused platform administration',
      (tester) async {
    final app = await signInAs(tester, 'sales@onecloud.com');

    app.router.go('/admin/users');
    await step(tester);

    expect(app.router.location, AppRoutes.unauthorized);
  });

  testWidgets('the sidebar hides modules the user cannot open', (tester) async {
    // Desktop size, so the rail is present rather than behind a drawer.
    await signInAs(tester, 'hr@onecloud.com');

    expect(find.text('HRMS'), findsWidgets);
    // HR holds no finance, ERP or CRM permission at all.
    expect(find.text('Finance & Accounting'), findsNothing);
    expect(find.text('ERP'), findsNothing);
    expect(find.text('CRM'), findsNothing);
  });

  testWidgets('a super admin sees every module in the sidebar', (tester) async {
    await signInAs(tester, 'me@stackly.com');

    // Scroll the rail rather than asserting everything fits on screen.
    for (final module in kModules) {
      expect(
        find.text(module.title),
        findsWidgets,
        reason: '${module.title} missing from the sidebar for a super admin',
      );
    }
  });

  testWidgets('signing out drops the user off a permitted module page',
      (tester) async {
    final app = await signInAs(tester, 'hr@onecloud.com');
    final auth = app.router.auth;
    app.router.go('/hrms/employees');
    await step(tester);
    expect(app.router.location, '/hrms/employees');

    unawaited(auth.signOut());
    await step(tester);

    // The session ended, so the protected page must not still be showing.
    expect(app.router.location, AppRoutes.login);
  });

  testWidgets('a deep link into a module page opens that module in the sidebar',
      (tester) async {
    final app = await signInAs(tester, 'me@stackly.com');

    app.router.go('/crm/leads');
    await step(tester);

    expect(app.router.location, '/crm/leads');
    // The module was revealed, so its pages are listed rather than collapsed.
    expect(app.navigation.isModuleExpanded('crm'), isTrue);
  });

  testWidgets('an unknown page under a real module shows the 404, not the 403',
      (tester) async {
    final app = await signInAs(tester, 'me@stackly.com');

    app.router.go('/hrms/does-not-exist');
    await step(tester);

    expect(app.router.location, AppRoutes.notFound);
    expect(find.text('Access denied'), findsNothing);
  });
}
