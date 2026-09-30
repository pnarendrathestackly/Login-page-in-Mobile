import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stackly_auth/auth.dart';
import 'package:stackly_auth/providers/auth_provider.dart';

import 'test_app.dart';

/// Controls that used to do nothing, or only claimed to, now run a real
/// operation — these drive them through the widgets.
void main() {
  Future<void> step(WidgetTester tester) async {
    await tester.pump();
    for (var i = 0; i < 16; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<(AuthProvider, TestAppState)> boot(WidgetTester tester) async {
    final auth = AuthProvider(DemoAuthBackend(latency: Duration.zero));
    addTearDown(auth.dispose);
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(TestApp(auth: auth));
    await step(tester);
    return (auth, tester.state<TestAppState>(find.byType(TestApp)));
  }

  Future<(AuthProvider, TestAppState)> signedIn(WidgetTester tester) async {
    final (auth, app) = await boot(tester);
    unawaited(auth.signIn('me@stackly.com', 'password123'));
    await step(tester);
    unawaited(auth.verify(DemoAuthBackend.demoCode));
    await step(tester);
    return (auth, app);
  }

  Finder field(String hint) => find.widgetWithText(TextFormField, hint);

  group('login', () {
    testWidgets('an unknown workspace is refused on step 1', (tester) async {
      await boot(tester);
      await tester.enterText(field('acmecorp'), 'nope');
      await tester.pump(); // the email hint follows the workspace
      await tester.enterText(field('you@nope.com'), 'me@stackly.com');
      await tester.tap(find.text('Continue'));
      await step(tester);
      expect(find.text("We couldn't find a workspace called \"nope\"."),
          findsOneWidget);
      expect(find.text('STEP 1 OF 3 · IDENTIFY'), findsOneWidget);
    });

    testWidgets('Find it here fills in the workspace', (tester) async {
      await boot(tester);
      await tester.enterText(field('acmecorp'), 'wrong');
      await tester.tap(find.text('Find it here'));
      await step(tester);
      await tester.enterText(field('Work email').last, 'me@stackly.com');
      await tester.tap(find.text('Find'));
      await step(tester);
      expect(field('acmecorp'), findsOneWidget);
      expect(find.text('Found your workspace: acmecorp.'), findsOneWidget);
    });

    testWidgets('an unknown email keeps the Find dialog open with a reason',
        (tester) async {
      await boot(tester);
      await tester.tap(find.text('Find it here'));
      await step(tester);
      await tester.enterText(field('Work email').last, 'nobody@x.com');
      await tester.tap(find.text('Find'));
      await step(tester);
      expect(find.text('No workspace is linked to that email address.'),
          findsOneWidget);
      expect(find.text('Find your workspace'), findsOneWidget);
    });

    testWidgets('forgot password resets it, and the new one signs in',
        (tester) async {
      final (auth, _) = await boot(tester);
      await tester.enterText(field('you@acmecorp.com'), 'me@stackly.com');
      await tester.tap(find.text('Continue'));
      await step(tester);
      // "Forgot password?" now opens a page, not a dialog.
      await tester.tap(find.text('Forgot password?'));
      await step(tester);
      await tester.enterText(field('you@acmecorp.com'), 'me@stackly.com');
      await tester.tap(find.text('Send reset link'));
      await step(tester);
      await tester.tap(find.text('Enter reset code'));
      await step(tester);

      await tester.enterText(field('Reset code'), DemoAuthBackend.demoCode);
      await tester.enterText(field('New password').last, 'brandnew123');
      await tester.enterText(field('Confirm new password'), 'brandnew123');
      await tester.tap(find.text('Reset password'));
      await step(tester);
      expect(
          find.textContaining('Password changed successfully'), findsOneWidget);

      unawaited(auth.signIn('me@stackly.com', 'brandnew123'));
      await step(tester);
      expect(auth.status, AuthStatus.awaitingVerification);
    });

    testWidgets('social sign-in says it is not set up', (tester) async {
      await boot(tester);
      await tester.tap(find.text('Google'));
      await step(tester);
      expect(
          find.textContaining("Google sign-in isn't set up"), findsOneWidget);
    });
  });

  group('signed in', () {
    testWidgets('change password keeps the dialog open on a wrong password',
        (tester) async {
      final (_, app) = await signedIn(tester);
      app.router.go('/settings');
      await step(tester);
      await tester.tap(find.text('Account').last);
      await step(tester);
      await tester.tap(find.text('Change password'));
      await step(tester);

      await tester.enterText(field('Current password'), 'wrong-one');
      await tester.enterText(field('New password'), 'another123');
      await tester.enterText(field('Confirm new password'), 'another123');
      await tester.tap(find.text('Update password'));
      await step(tester);
      expect(find.text('Your current password is incorrect.'), findsOneWidget);
      expect(find.text('Change Password'), findsOneWidget,
          reason: 'stays open');

      await tester.enterText(field('Current password'), 'password123');
      await tester.tap(find.text('Update password'));
      await step(tester);
      expect(find.text('Password changed successfully.'), findsOneWidget);
    });

    testWidgets('header search opens the matching page', (tester) async {
      final (_, app) = await signedIn(tester);
      await tester.enterText(
        find.widgetWithText(
            TextField,
            'Search tenants, users, settings, '
            'audit logs...'),
        'payroll',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await step(tester);
      expect(app.router.location, '/hrms/payroll');
    });

    testWidgets('header search reports no results', (tester) async {
      await signedIn(tester);
      await tester.enterText(
        find.widgetWithText(
            TextField,
            'Search tenants, users, settings, '
            'audit logs...'),
        'zzzz-nothing',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await step(tester);
      expect(find.text('No matching results found.'), findsOneWidget);
    });

    testWidgets('an out-of-range rollout is caught inside the dialog',
        (tester) async {
      final (_, app) = await signedIn(tester);
      app.router.go('/admin/features');
      await step(tester);
      await tester.tap(find.text('Configure').first);
      await step(tester);
      await tester.enterText(field('100'), '150');
      await tester.tap(find.text('Apply'));
      await step(tester);
      expect(find.text('Rollout must be a whole number from 0 to 100.'),
          findsOneWidget);
      // The error sits on the field alone; no generic form-wide banner.
      expect(find.text('Please correct the highlighted fields.'), findsNothing);
    });
  });
}
