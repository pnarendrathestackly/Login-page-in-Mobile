import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stackly_auth/auth.dart';
import 'package:stackly_auth/providers/auth_provider.dart';

import 'test_app.dart';

/// Drives the real widget tree through the two steps.
///
/// The verify screen runs a 1s repeating countdown, so `pumpAndSettle` would
/// never settle. Every wait here is an explicit, bounded `pump` instead.
void main() {
  Future<void> pumpApp(WidgetTester tester, AuthProvider auth) async {
    // The split layout needs a wide surface; the default test view is 800px.
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(TestApp(auth: auth));
  }

  /// Lets a zero-latency backend call resolve, then runs the screen
  /// transition out. Bounded pumps rather than pumpAndSettle, so a repeating
  /// animation cannot stall the test.
  Future<void> step(WidgetTester tester) async {
    await tester.pump();
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  AuthProvider controller([void Function(String)? onCode]) => AuthProvider(
        DemoAuthBackend(onCodeSent: onCode, latency: Duration.zero),
      );

  testWidgets('password step alone does not reach the dashboard',
      (tester) async {
    String? code;
    final auth = controller((c) => code = c);
    await pumpApp(tester, auth);
    expect(find.text('Welcome Back'), findsOneWidget);

    unawaited(auth.signIn('me@stackly.com', 'password123'));
    await step(tester);

    // Second factor outstanding. The OTP is part of the login form, so the
    // user stays on it — there is no separate verify screen — and the
    // dashboard is not reachable.
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('One-time password'), findsOneWidget);
    expect(find.textContaining('Welcome back,'), findsNothing);
    expect(code, isNotNull);
  });

  testWidgets('the login form carries email, password and OTP together',
      (tester) async {
    await pumpApp(tester, controller());
    await step(tester);

    // All three inputs on one screen, OTP below the password.
    expect(find.widgetWithText(TextFormField, 'Email address'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
    expect(find.text('One-time password'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);

    // The OTP boxes sit below the password field, not on another screen.
    final password = tester.getTopLeft(
      find.widgetWithText(TextFormField, 'Password'),
    );
    final otp = tester.getTopLeft(find.text('One-time password'));
    expect(otp.dy, greaterThan(password.dy));
  });

  testWidgets('a wrong code keeps the user on login with an error',
      (tester) async {
    String? code;
    final auth = controller((c) => code = c);
    await pumpApp(tester, auth);

    unawaited(auth.signInWithCode(
      email: 'me@stackly.com',
      password: 'password123',
      code: '000000',
    ));
    await step(tester);

    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.textContaining('Welcome back,'), findsNothing);
    expect(auth.error, isNotNull);
    expect(code, isNotNull);
  });

  testWidgets('email, password and OTP in one submit reaches the dashboard',
      (tester) async {
    String? code;
    final auth = controller((c) => code = c);
    await pumpApp(tester, auth);

    // Issue a code first, so the form has a valid one to submit.
    unawaited(auth.signIn('me@stackly.com', 'password123'));
    await step(tester);

    unawaited(auth.signInWithCode(
      email: 'me@stackly.com',
      password: 'password123',
      code: code!,
    ));
    await step(tester);
    await step(tester);

    expect(find.textContaining('Welcome back,'), findsOneWidget);
  });

  testWidgets('verifying reaches the dashboard with both sign-out controls',
      (tester) async {
    String? code;
    final auth = controller((c) => code = c);
    await pumpApp(tester, auth);

    unawaited(auth.signIn('me@stackly.com', 'password123'));
    await step(tester);
    unawaited(auth.verify(code!));
    await step(tester);

    expect(find.textContaining('Welcome back,'), findsOneWidget);
    // Labelled in the sidebar...
    expect(find.text('Sign Out'), findsOneWidget);
    // ...and always in the header, icon-only at this width.
    expect(find.byTooltip('Sign Out'), findsOneWidget);

    // ...and reachable from the header's profile dropdown as well.
    await tester.tap(find.bySemanticsLabel(RegExp('Account menu')));
    await step(tester);
    expect(find.text('Sign Out'), findsNWidgets(2));
    expect(find.text('My Profile'), findsOneWidget);
    expect(find.text('Account Settings'), findsOneWidget);
  });

  testWidgets('signing out returns to login', (tester) async {
    String? code;
    final auth = controller((c) => code = c);
    await pumpApp(tester, auth);

    unawaited(auth.signIn('me@stackly.com', 'password123'));
    await step(tester);
    unawaited(auth.verify(code!));
    await step(tester);
    expect(find.textContaining('Welcome back,'), findsOneWidget);

    unawaited(auth.signOut());
    await step(tester);
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.textContaining('Welcome back,'), findsNothing);
  });

  testWidgets('invalid credentials show an error and stay on login',
      (tester) async {
    final auth = controller();
    await pumpApp(tester, auth);

    unawaited(auth.signIn('me@stackly.com', 'nope-wrong'));
    await step(tester);

    expect(find.text('Incorrect email or password.'), findsOneWidget);
    expect(find.text('Welcome Back'), findsOneWidget);
  });

  testWidgets('pasting the code spreads across all six boxes', (tester) async {
    String? code;
    final auth = controller((c) => code = c);
    await pumpApp(tester, auth);
    unawaited(auth.signIn('me@stackly.com', 'password123'));
    await step(tester);

    // Paste a partial code: it spreads without tripping the auto-verify that
    // a complete code would, so the boxes are still on screen to inspect.
    final partial = code!.substring(0, 4);
    await tester.enterText(find.byType(TextField).first, partial);
    await step(tester);

    final digits = tester
        .widgetList<TextField>(find.byType(TextField))
        .map((f) => f.controller!.text)
        .join();
    expect(digits, partial);
  });

  testWidgets('a complete pasted code submits the login form', (tester) async {
    String? code;
    final auth = controller((c) => code = c);
    await pumpApp(tester, auth);
    unawaited(auth.signIn('me@stackly.com', 'password123'));
    await step(tester);

    // Fill the form the way a user would, then paste the code into the OTP
    // boxes: completing them submits without touching the button.
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email address'),
      'me@stackly.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'password123',
    );
    await step(tester);

    await tester.enterText(find.byType(TextField).last, code!);
    await step(tester);
    await step(tester);

    expect(find.textContaining('Welcome back,'), findsOneWidget);
  });
}
