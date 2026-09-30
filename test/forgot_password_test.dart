import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stackly_auth/auth.dart';
import 'package:stackly_auth/providers/auth_provider.dart';
import 'package:stackly_auth/router/app_router.dart';

import 'test_app.dart';

void main() {
  Future<TestAppState> openLogin(
    WidgetTester tester, {
    Size size = const Size(390, 1000),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      TestApp(auth: AuthProvider(DemoAuthBackend(latency: Duration.zero))),
    );
    await tester.pumpAndSettle();
    return tester.state<TestAppState>(find.byType(TestApp));
  }

  /// Steps the login form to the password step, where the link lives.
  Future<void> toPasswordStep(WidgetTester tester) async {
    // Narrow windows open on the brand splash; the form is behind "SIGN IN".
    if (find.text('SIGN IN').evaluate().isNotEmpty) {
      await tester.tap(find.text('SIGN IN'));
      await tester.pumpAndSettle();
    }
    await tester.enterText(
      find.widgetWithText(TextFormField, 'you@acmecorp.com'),
      'me@stackly.com',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
  }

  testWidgets('the route renders the page instead of falling back to login',
      (tester) async {
    final app = await openLogin(tester);
    app.router.go(AppRoutes.forgotPassword);
    await tester.pumpAndSettle();

    expect(app.router.location, AppRoutes.forgotPassword);
    expect(find.text('Forgot your password?'), findsOneWidget);
    expect(find.text('PASSWORD RECOVERY'), findsOneWidget);
    expect(find.text('Back to sign in'), findsOneWidget);
    expect(find.text('Send reset link'), findsOneWidget);
    expect(find.text('Remembered it? '), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('"Forgot password?" on the login form opens the page',
      (tester) async {
    final app = await openLogin(tester);
    await toPasswordStep(tester);

    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();

    expect(app.router.location, AppRoutes.forgotPassword);
    expect(find.text('Forgot your password?'), findsOneWidget);
  });

  testWidgets('Back to sign in returns to the login screen', (tester) async {
    final app = await openLogin(tester);
    app.router.go(AppRoutes.forgotPassword);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Back to sign in'));
    await tester.pumpAndSettle();

    expect(app.router.location, AppRoutes.login);
    // Narrow windows land on the brand splash ahead of the form.
    expect(find.text('SIGN IN'), findsOneWidget);
  });

  testWidgets('an invalid email is rejected before anything is sent',
      (tester) async {
    await openLogin(tester);
    tester
        .state<TestAppState>(find.byType(TestApp))
        .router
        .go(AppRoutes.forgotPassword);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'you@acmecorp.com'),
      'not-an-email',
    );
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid email address'), findsOneWidget);
    // No reset dialog opened.
    expect(find.text('Choose a new password'), findsNothing);
  });

  testWidgets('sending shows the check-your-email panel', (tester) async {
    await openLogin(tester);
    tester
        .state<TestAppState>(find.byType(TestApp))
        .router
        .go(AppRoutes.forgotPassword);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'you@acmecorp.com'),
      'me@stackly.com',
    );
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();

    expect(find.text('Check your email'), findsOneWidget);
    expect(find.textContaining('me@stackly.com'), findsWidgets);
    expect(find.textContaining('expires in 30 minutes'), findsOneWidget);
    expect(find.text('Resend email'), findsOneWidget);
    expect(find.text('Back to sign in'), findsOneWidget);
    expect(find.textContaining("Didn't get it?"), findsOneWidget);
    // The form it replaced is gone.
    expect(find.text('Send reset link'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a valid email opens the reset dialog', (tester) async {
    await openLogin(tester);
    tester
        .state<TestAppState>(find.byType(TestApp))
        .router
        .go(AppRoutes.forgotPassword);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'you@acmecorp.com'),
      'me@stackly.com',
    );
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enter reset code'));
    await tester.pumpAndSettle();

    expect(find.text('Choose a new password'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an unregistered address gets the same reply', (tester) async {
    await openLogin(tester);
    tester
        .state<TestAppState>(find.byType(TestApp))
        .router
        .go(AppRoutes.forgotPassword);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'you@acmecorp.com'),
      'nobody@nowhere.com',
    );
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();

    // Same panel as a real account: the page never reveals who is registered.
    expect(find.text('Check your email'), findsOneWidget);
    expect(find.textContaining('nobody@nowhere.com'), findsWidgets);
  });
}
