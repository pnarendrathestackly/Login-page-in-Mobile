import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stackly_auth/auth.dart';
import 'package:stackly_auth/features/auth/screens/login/widgets/login_form.dart';
import 'package:stackly_auth/providers/auth_provider.dart';

import 'test_app.dart';

/// The login form must fit on screen without scrolling.
///
/// Measured in the WORST case — the demo-code banner and an error banner both
/// visible — because that is a normal state (wrong code entered), not an edge
/// case. Measuring the empty form would pass while real use still scrolls.
void main() {
  Future<void> step(WidgetTester tester) async {
    await tester.pump();
    for (var i = 0; i < 16; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  const sizes = <Size>[
    Size(1024, 768), // tablet landscape
    Size(1280, 720), // smallest common laptop
    Size(1366, 768), // 15.6"
    Size(1440, 900), // 14"
    Size(1512, 982), // 14.5"
    Size(1536, 864), // scaled 1080p
    Size(1600, 900),
    Size(1920, 1080),
  ];

  for (final size in sizes) {
    final label = '${size.width.toInt()}x${size.height.toInt()}';

    testWidgets('the login form fits without scrolling at $label',
        (tester) async {
      final auth = AuthProvider(DemoAuthBackend(latency: Duration.zero));
      addTearDown(auth.dispose);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(TestApp(auth: auth));
      await step(tester);

      // Worst case: password accepted (demo banner shows), then a wrong code
      // (error banner shows). Both are on screen at once.
      unawaited(auth.signIn('me@stackly.com', 'password123'));
      await step(tester);
      unawaited(auth.verify('000000'));
      await step(tester);

      // The form card's own scroll view, not the hero panel's: the hero
      // carries a product screenshot and is allowed to scroll, the sign-in
      // controls are not.
      final scrollView = find.ancestor(
        of: find.byType(LoginForm),
        matching: find.byType(SingleChildScrollView),
      );
      final viewport = tester.renderObject<RenderBox>(scrollView).size.height;
      final content = tester
          .renderObject<RenderBox>(
            find
                .descendant(of: scrollView, matching: find.byType(Column))
                .first,
          )
          .size
          .height;

      expect(
        content,
        lessThanOrEqualTo(viewport),
        reason:
            'the login form needs ${(content - viewport).toStringAsFixed(0)}px '
            'more than the $label viewport, so the user has to scroll to reach '
            'the Login button',
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the Verify button is reachable without scrolling at 1366x768',
      (tester) async {
    final auth = AuthProvider(DemoAuthBackend(latency: Duration.zero));
    addTearDown(auth.dispose);
    tester.view.physicalSize = const Size(1366, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(TestApp(auth: auth));
    await step(tester);
    unawaited(auth.signIn('me@stackly.com', 'password123'));
    await step(tester);

    // The measurement above proves the column fits; this proves the control
    // the user actually needs is inside the visible viewport.
    final button = find.widgetWithText(InkWell, 'Verify and sign in');
    expect(button, findsWidgets);
    final rect = tester.getRect(button.first);
    expect(rect.bottom, lessThanOrEqualTo(768),
        reason: 'the Verify button sits below the fold');
  });
}
