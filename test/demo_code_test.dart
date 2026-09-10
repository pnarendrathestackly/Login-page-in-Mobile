import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stackly_auth/auth.dart';
import 'package:stackly_auth/providers/auth_provider.dart';

import 'test_app.dart';

/// The demo code is the ONLY way to sign in — there is no mail or SMS service
/// here. If it stops rendering, the app becomes impossible to use, so it is
/// worth a test rather than a manual check.
void main() {
  Future<void> step(WidgetTester tester) async {
    await tester.pump();
    for (var i = 0; i < 16; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('the demo code is shown on screen after the password step',
      (tester) async {
    String? code;
    final auth = AuthProvider(
      DemoAuthBackend(onCodeSent: (c) => code = c, latency: Duration.zero),
    );
    addTearDown(auth.dispose);
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(TestApp(auth: auth));
    await step(tester);

    // No code exists until the password is submitted, so nothing is shown.
    expect(find.text('Demo code:'), findsNothing);

    unawaited(auth.signIn('me@stackly.com', 'password123'));
    await step(tester);

    // Now it is on screen, and it is the code that would actually verify.
    expect(find.text('Demo code:'), findsOneWidget);
    expect(find.text(code!), findsOneWidget);
  });

  testWidgets('the prompt does not claim the code was sent anywhere',
      (tester) async {
    final auth = AuthProvider(DemoAuthBackend(latency: Duration.zero));
    addTearDown(auth.dispose);
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(TestApp(auth: auth));
    unawaited(auth.signInWithCode(
      email: 'me@stackly.com',
      password: 'password123',
      code: '',
    ));
    await step(tester);

    // Telling the user to check an inbox nothing will ever arrive in is how
    // this flow becomes impossible to finish.
    expect(find.textContaining('sent'), findsNothing);
    expect(find.textContaining('email'), findsNothing);
  });
}
