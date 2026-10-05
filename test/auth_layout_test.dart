import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stackly_auth/auth.dart';
import 'package:stackly_auth/providers/auth_provider.dart';
import 'package:stackly_auth/router/app_router.dart';

import 'test_app.dart';

/// Layout guard for the two auth pages.
///
/// Both pages are built from the same shell, so a change to one silently
/// reshapes the other. This sweeps real window sizes and asserts the things
/// that actually broke during the redesign: content past the fold, artwork
/// running off the panel edges, and overflow exceptions.
void main() {
  /// Desktop and laptop sizes only. A phone-sized window legitimately scrolls
  /// — the signup form has six fields and cannot fit 740px — so the fold
  /// assertions below do not apply there.
  const desktop = <Size>[
    Size(1920, 1080),
    Size(1600, 900),
    Size(1536, 864),
    Size(1440, 900),
    Size(1366, 768),
    Size(1280, 800),
    Size(1280, 720),
    Size(1024, 768),
  ];

  Future<void> open(WidgetTester tester, Size window,
      {required bool signup}) async {
    final auth = AuthProvider(DemoAuthBackend(latency: Duration.zero));
    addTearDown(auth.dispose);
    tester.view.physicalSize = window;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(TestApp(auth: auth));
    await tester.pumpAndSettle();
    if (signup) {
      tester
          .state<TestAppState>(find.byType(TestApp))
          .router
          .go(AppRoutes.register);
      await tester.pumpAndSettle();
    }
  }

  /// Labels that must be on screen without scrolling.
  ///
  /// Sign-up's step 1 collects nine required fields, so its button and footer
  /// are legitimately below the fold on a laptop — only the heading is
  /// asserted there. The sign-in form is short and must fit whole.
  List<String> anchorsFor({required bool signup}) => signup
      ? const ['Tell us about your organization']
      : const ['Sign in', 'Continue', 'Create New Account'];

  for (final window in desktop) {
    final label = '${window.width.toInt()}x${window.height.toInt()}';

    for (final signup in [false, true]) {
      final page = signup ? 'register' : 'login';

      testWidgets('$page fits the $label viewport', (tester) async {
        await open(tester, window, signup: signup);

        for (final text in anchorsFor(signup: signup)) {
          final finder = find.text(text);
          expect(finder, findsWidgets, reason: '"$text" is missing on $page');
          final rect = tester.getRect(finder.first);
          expect(rect.bottom, lessThanOrEqualTo(window.height),
              reason: '"$text" sits below the fold on $page at $label');
          expect(rect.right, lessThanOrEqualTo(window.width),
              reason: '"$text" runs off the right edge on $page at $label');
          expect(rect.left, greaterThanOrEqualTo(0),
              reason: '"$text" runs off the left edge on $page at $label');
        }
        expect(tester.takeException(), isNull);
      });

    }
  }

  testWidgets('a phone-sized register form scrolls to its footer',
      (tester) async {
    await open(tester, const Size(360, 740), signup: true);
    await tester.scrollUntilVisible(
      find.text('Already have an organization? '),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('Already have an organization? ')).bottom,
        lessThanOrEqualTo(740));
    expect(tester.takeException(), isNull);
  });
}
