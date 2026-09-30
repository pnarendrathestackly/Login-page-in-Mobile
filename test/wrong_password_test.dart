import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stackly_auth/auth.dart';
import 'package:stackly_auth/providers/auth_provider.dart';

import 'test_app.dart';

void main() {
  Future<AuthProvider> openPasswordStep(
    WidgetTester tester, {
    Size size = const Size(390, 900),
  }) async {
    final auth = AuthProvider(DemoAuthBackend(latency: Duration.zero));
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(TestApp(auth: auth));
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
    return auth;
  }

  testWidgets('a wrong password shows the error and the attempts left',
      (tester) async {
    await openPasswordStep(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Enter your password'),
      'wrongpassword',
    );
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Incorrect email or password.'), findsOneWidget);
    expect(find.text('4 attempts remaining before lockout.'), findsOneWidget);
    // Still on the password step, ready for another try.
    expect(find.text('Enter your password'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the attempts remaining count counts down', (tester) async {
    await openPasswordStep(tester);

    for (final expected in [4, 3, 2]) {
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Enter your password'),
        'wrongpassword',
      );
      await tester.ensureVisible(find.text('Sign in'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(
        find.text('$expected attempts remaining before lockout.'),
        findsOneWidget,
        reason: 'after ${5 - expected} failed attempts',
      );
    }
  });

  testWidgets('a correct password still reaches the verify step',
      (tester) async {
    await openPasswordStep(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Enter your password'),
      'wrongpassword',
    );
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Incorrect email or password.'), findsOneWidget);

    // Recovering clears the banner rather than leaving a stale attempts line.
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Enter your password'),
      'password123',
    );
    await tester.ensureVisible(find.text('Sign in'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Two-factor verification'), findsOneWidget);
    expect(find.textContaining('attempts remaining'), findsNothing);
  });

  test('the singular is used on the last attempt', () async {
    final backend = DemoAuthBackend(latency: Duration.zero);
    for (var i = 0; i < 3; i++) {
      await expectLater(
        () => backend.signIn('me@stackly.com', 'nope'),
        throwsA(isA<AuthException>()),
      );
    }
    try {
      await backend.signIn('me@stackly.com', 'nope');
      fail('expected a rejection');
    } on AuthException catch (e) {
      expect(e.detail, '1 attempt remaining before lockout.');
    }
  });

  test('the account locks after the budget is spent', () async {
    final backend = DemoAuthBackend(latency: Duration.zero);
    for (var i = 0; i < DemoAuthBackend.maxAttempts; i++) {
      await expectLater(
        () => backend.signIn('me@stackly.com', 'nope'),
        throwsA(isA<AuthException>()),
      );
    }

    // Even the RIGHT password is refused while the account is locked.
    try {
      await backend.signIn('me@stackly.com', 'password123');
      fail('expected a lockout');
    } on AuthException catch (e) {
      expect(e.message, 'Too many failed attempts.');
      expect(e.lockedUntil, isNotNull);
    }
  });

  test('a successful sign-in clears the attempt count', () async {
    final backend = DemoAuthBackend(latency: Duration.zero);
    await expectLater(
      () => backend.signIn('me@stackly.com', 'nope'),
      throwsA(isA<AuthException>()),
    );
    await backend.signIn('me@stackly.com', 'password123');

    // The budget is full again, so the next slip reports the first attempt.
    try {
      await backend.signIn('me@stackly.com', 'nope');
      fail('expected a rejection');
    } on AuthException catch (e) {
      expect(e.detail, '4 attempts remaining before lockout.');
    }
  });
}
