import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stackly_auth/auth.dart';
import 'package:stackly_auth/providers/auth_provider.dart';

import 'test_app.dart';

void main() {
  Future<void> pumpLogin(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
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
  }

  testWidgets('phone opens on the splash and SIGN IN reveals the form',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      TestApp(auth: AuthProvider(DemoAuthBackend(latency: Duration.zero))),
    );
    await tester.pumpAndSettle();

    expect(find.text('SIGN IN'), findsOneWidget);
    expect(find.textContaining('One identity.'), findsOneWidget);
    expect(
        find.widgetWithText(TextFormField, 'you@acmecorp.com'), findsNothing);

    // The cover art: the four module cards and the hub, all on screen.
    for (final card in const [
      'People',
      'Applications',
      'Security',
      'Analytics'
    ]) {
      expect(find.text(card), findsOneWidget);
      expect(tester.getRect(find.text(card)).bottom, lessThanOrEqualTo(844));
    }
    expect(find.text('1E'), findsOneWidget);
    expect(find.textContaining('CLOUD PLATFORM'), findsOneWidget);

    // A phone taller than the mock leaves no empty band under the button:
    // SIGN IN and the footer sit at the bottom of the screen.
    final button = tester.getRect(find.widgetWithText(FilledButton, 'SIGN IN'));
    expect(844 - button.bottom, lessThan(100));
    expect(tester.getRect(find.text('Secure')).bottom, greaterThan(800));

    await tester.tap(find.text('SIGN IN'));
    await tester.pumpAndSettle();

    // The cover is gone: the form is on screen instead.
    expect(find.text('Secure'), findsNothing);
    expect(find.text('1E'), findsNothing);
    expect(
      find.widgetWithText(TextFormField, 'you@acmecorp.com'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the splash survives the tiny first web frame', (tester) async {
    // Flutter web lays the first frame out in a ~1.6px box before the real
    // window size arrives. The fixed-height top bar and button cannot shrink
    // to fit that, so the splash must clip rather than overflow.
    tester.view.physicalSize = const Size(2, 2);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      TestApp(auth: AuthProvider(DemoAuthBackend(latency: Duration.zero))),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // And it lays out normally once the real size arrives.
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(find.text('SIGN IN'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone shows the brand header above the form', (tester) async {
    await pumpLogin(tester, const Size(390, 844));

    // Header and form are both on screen, header first.
    expect(find.textContaining('One identity.'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(
      tester.getTopLeft(find.textContaining('One identity.')).dy,
      lessThan(tester.getTopLeft(find.text('Sign in')).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone form scrolls to the sign-up link', (tester) async {
    await pumpLogin(tester, const Size(390, 844));

    // Phones link to self-serve sign-up; desktop shows "Create New Account".
    await tester.scrollUntilVisible(
      find.text('Create an account'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Create an account'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone reaches the password step cleanly', (tester) async {
    await pumpLogin(tester, const Size(390, 844));

    await tester.enterText(
      find.widgetWithText(TextFormField, 'you@acmecorp.com'),
      'me@stackly.com',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // The brand header stays above the form across steps.
    expect(find.textContaining('One identity.'), findsOneWidget);
    expect(find.text('Enter your password'), findsNWidgets(2));
    expect(find.text('STEP 2 OF 3 · PASSWORD'), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
    expect(find.text('Switch'), findsOneWidget);
    expect(find.text('Remember me'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.textContaining('Protected by enterprise'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone reaches the verify step cleanly', (tester) async {
    await pumpLogin(tester, const Size(390, 844));

    await tester.enterText(
      find.widgetWithText(TextFormField, 'you@acmecorp.com'),
      'me@stackly.com',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Enter your password'),
      'password123',
    );
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('STEP 3 OF 3 · VERIFY'), findsOneWidget);
    expect(find.text('Two-factor verification'), findsOneWidget);
    expect(
      find.text('Enter the 6-digit code from your authenticator app.'),
      findsOneWidget,
    );
    expect(find.text('Back'), findsOneWidget);
    expect(find.text('Resend'), findsOneWidget);
    expect(find.textContaining('Code expires in 0'), findsOneWidget);
    expect(find.text('Verify and sign in'), findsOneWidget);
    expect(find.text('Contact support'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a verified sign-in confirms before the dashboard',
      (tester) async {
    await pumpLogin(tester, const Size(390, 844));

    await tester.enterText(
      find.widgetWithText(TextFormField, 'you@acmecorp.com'),
      'me@stackly.com',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Enter your password'),
      'password123',
    );
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    // Completing the boxes submits the form.
    await tester.enterText(find.byType(TextField).last, '123456');
    await tester.pump();
    await tester.pump();

    // The confirmation shows during the handoff to the dashboard.
    expect(find.text("You're in"), findsOneWidget);
    expect(find.text('Redirecting to your dashboard...'), findsOneWidget);

    // Let the redirect complete so no countdown timer outlives the test.
    await tester.pumpAndSettle();
    expect(find.textContaining('Welcome back,'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop keeps the split panel', (tester) async {
    await pumpLogin(tester, const Size(1440, 900));

    expect(find.textContaining('Every operation.'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
