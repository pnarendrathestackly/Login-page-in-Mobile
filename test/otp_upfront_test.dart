import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stackly_auth/auth.dart';
import 'package:stackly_auth/providers/auth_provider.dart';

import 'test_app.dart';

/// The demo code must be visible on the verify step, before the user has to
/// type it: it is the only way into the app.
void main() {
  testWidgets('demo code is on screen as soon as the verify step opens',
      (tester) async {
    final auth = AuthProvider(DemoAuthBackend(latency: Duration.zero));
    addTearDown(auth.dispose);
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(TestApp(auth: auth));
    await tester.pumpAndSettle();
    // Not awaited: the demo backend's timer only fires as the test clock is
    // pumped.
    unawaited(auth.signIn('me@stackly.com', 'password123'));
    await tester.pumpAndSettle();

    // Nothing typed yet: the code is already shown.
    expect(find.text(DemoAuthBackend.demoCode), findsOneWidget);
  });

  test('demoCode is non-null on a fresh controller', () {
    final auth = AuthProvider(DemoAuthBackend(latency: Duration.zero));
    addTearDown(auth.dispose);
    expect(auth.demoCode, DemoAuthBackend.demoCode);
  });
}
