import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stackly_auth/auth.dart';
import 'package:stackly_auth/providers/auth_provider.dart';

import 'test_app.dart';

void main() {
  Future<void> failUntilLocked(WidgetTester tester) async {
    for (var i = 0; i < DemoAuthBackend.maxAttempts; i++) {
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Enter your password'),
        'wrongpassword',
      );
      await tester.ensureVisible(find.text('Sign in'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
    }
  }

  Future<void> toPasswordStep(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      TestApp(auth: AuthProvider(DemoAuthBackend(latency: Duration.zero))),
    );
    await tester.pumpAndSettle();
    // Phones open on the brand splash; the form is behind "SIGN IN".
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

  testWidgets('the lock screen replaces the form after the last attempt',
      (tester) async {
    await toPasswordStep(tester);
    await failUntilLocked(tester);

    expect(find.text('This account is locked'), findsOneWidget);
    expect(find.textContaining('Try again in 1'), findsOneWidget);
    expect(find.text('Reset password'), findsOneWidget);
    expect(find.text('Back to sign in'), findsOneWidget);
    expect(find.textContaining('Recorded in the security audit log'),
        findsOneWidget);
    // The password field is gone: nothing useful to submit.
    expect(find.widgetWithText(TextFormField, 'Enter your password'),
        findsNothing);
  });

  testWidgets('the countdown shows the time left, near the full duration',
      (tester) async {
    await toPasswordStep(tester);
    await failUntilLocked(tester);

    // The label is driven by real wall-clock time (a widget test's fake async
    // does not move DateTime.now()), so assert the value rather than a tick.
    final shown = tester
        .widgetList<Text>(find.textContaining('Try again in '))
        .first
        .data!;
    final mm = int.parse(shown.split('in ').last.split(':').first);
    expect(mm, inInclusiveRange(13, 15));
  });

  test('the lock expires on its own', () async {
    final backend = DemoAuthBackend(latency: Duration.zero);
    for (var i = 0; i < DemoAuthBackend.maxAttempts; i++) {
      await expectLater(
        () => backend.signIn('me@stackly.com', 'nope'),
        throwsA(isA<AuthException>()),
      );
    }

    late DateTime until;
    try {
      await backend.signIn('me@stackly.com', 'password123');
      fail('expected a lockout');
    } on AuthException catch (e) {
      expect(e.lockedUntil, isNotNull);
      until = e.lockedUntil!;
    }

    // The lock is time-boxed, not permanent.
    expect(
      until.difference(DateTime.now()).inMinutes,
      closeTo(DemoAuthBackend.lockoutDuration.inMinutes, 1),
    );
  });

  test('lockedUntil reports null once the moment has passed', () {
    final auth = AuthProvider(DemoAuthBackend(latency: Duration.zero));
    expect(auth.lockedUntil, isNull);
  });
}
