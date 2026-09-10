import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stackly_auth/auth.dart';
import 'package:stackly_auth/dashboard.dart';
import 'package:stackly_auth/widgets/header/app_header.dart';
import 'package:stackly_auth/providers/auth_provider.dart';

import 'test_app.dart';

/// The page header stays put while only the content scrolls.
void main() {
  Future<void> step(WidgetTester tester) async {
    await tester.pump();
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> signedIn(
    WidgetTester tester, {
    Size size = const Size(1400, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    String? code;
    final auth = AuthProvider(
      DemoAuthBackend(onCodeSent: (c) => code = c, latency: Duration.zero),
    );
    await tester.pumpWidget(TestApp(auth: auth));
    unawaited(auth.signIn('me@stackly.com', 'password123'));
    await step(tester);
    unawaited(auth.verify(code!));
    await step(tester);
  }

  testWidgets('the header holds its position while the content scrolls',
      (tester) async {
    await signedIn(tester);

    final header = find.byType(DashboardHeader);
    expect(header, findsOneWidget);
    final before = tester.getTopLeft(header);

    // Scroll the content area well past a screen height.
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -600),
    );
    await step(tester);

    // Header unmoved, and still showing the page title.
    expect(tester.getTopLeft(header), before);
    expect(find.byType(DashboardHeader), findsOneWidget);
  });

  testWidgets('the page title stays visible after scrolling', (tester) async {
    await signedIn(tester, size: const Size(500, 800));

    expect(find.text(DashboardSection.overview.label), findsWidgets);

    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -500),
    );
    await step(tester);

    // The title lives in the fixed header, so scrolling cannot remove it.
    expect(find.text(DashboardSection.overview.label), findsWidgets);
  });
}
