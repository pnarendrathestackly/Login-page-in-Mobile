import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stackly_auth/auth.dart';
import 'package:stackly_auth/providers/auth_provider.dart';

import 'test_app.dart';

/// Guards against horizontal overflow at phone, tablet and desktop widths.
/// A RenderFlex overflow throws in tests, so reaching the assertion is the check.
void main() {
  /// Resolves a zero-latency backend call, then runs the screen transition and
  /// entrance animations out.
  Future<void> step(WidgetTester tester) async {
    await tester.pump();
    for (var i = 0; i < 14; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  const sizes = {
    'phone': Size(390, 844),
    'tablet': Size(834, 1112),
    'desktop': Size(1440, 900),
  };

  for (final entry in sizes.entries) {
    testWidgets('dashboard lays out cleanly on ${entry.key}', (tester) async {
      String? code;
      final auth = AuthProvider(
        DemoAuthBackend(onCodeSent: (c) => code = c, latency: Duration.zero),
      );
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(TestApp(auth: auth));
      unawaited(auth.signIn('me@stackly.com', 'password123'));
      await step(tester);
      unawaited(auth.verify(code!));
      await step(tester);

      expect(find.textContaining('Welcome back,'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('login lays out cleanly on ${entry.key}', (tester) async {
      final auth = AuthProvider(DemoAuthBackend(latency: Duration.zero));
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(TestApp(auth: auth));
      await step(tester);

      // Narrow windows open on the brand splash, wide ones on the form.
      if (entry.value.width < 900) {
        expect(find.text('SIGN IN'), findsOneWidget);
        await tester.tap(find.text('SIGN IN'));
        await step(tester);
      }
      expect(find.text('Sign in'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final entry in sizes.entries) {
    testWidgets('profile panel lays out cleanly on ${entry.key}',
        (tester) async {
      String? code;
      final auth = AuthProvider(
        DemoAuthBackend(onCodeSent: (c) => code = c, latency: Duration.zero),
      );
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(TestApp(auth: auth));
      unawaited(auth.signIn('me@stackly.com', 'password123'));
      await step(tester);
      unawaited(auth.verify(code!));
      await step(tester);

      // Profile lives in the header's account menu.
      await tester.tap(find.bySemanticsLabel(RegExp('Account menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('My Profile'));
      await tester.pumpAndSettle();

      expect(find.text('Your account and workspace details.'), findsOneWidget);
      expect(find.text('me@stackly.com'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('mobile exposes a drawer menu button', (tester) async {
    String? code;
    final auth = AuthProvider(
      DemoAuthBackend(onCodeSent: (c) => code = c, latency: Duration.zero),
    );
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(TestApp(auth: auth));
    unawaited(auth.signIn('me@stackly.com', 'password123'));
    await step(tester);
    unawaited(auth.verify(code!));
    await step(tester);

    final menu = find.byTooltip('Open navigation menu');
    expect(menu, findsOneWidget);

    await tester.tap(menu);
    await step(tester);
    await step(tester);
    // Sidebar nav is now reachable from the drawer.
    expect(find.text('Log out'), findsOneWidget);
    expect(find.text('PLATFORM ADMINISTRATION'), findsOneWidget);

    // The drawer closes on its own X, not just the scrim.
    await tester.tap(find.byTooltip('Close menu'));
    await step(tester);
    await step(tester);
    expect(find.text('Platform Configuration'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
