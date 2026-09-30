import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stackly_auth/auth.dart';
import 'package:stackly_auth/core/platform/permissions.dart';
import 'package:stackly_auth/providers/auth_provider.dart';
import 'package:stackly_auth/router/app_router.dart';

import 'test_app.dart';

void main() {
  Future<void> openSignup(
    WidgetTester tester, {
    Size size = const Size(390, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      TestApp(auth: AuthProvider(DemoAuthBackend(latency: Duration.zero))),
    );
    await tester.pumpAndSettle();
    tester
        .state<TestAppState>(find.byType(TestApp))
        .router
        .go(AppRoutes.register);
    await tester.pumpAndSettle();
  }

  /// Fields are addressed by their hint, which is unique on each step.
  /// Dropdown order on step 1, for [choose].
  const dropdownIndex = {
    'Organization Type': 0,
    'Industry': 1,
    'Company Size': 2,
    'Country': 3,
    'State': 4,
    'Time Zone': 5,
  };

  Future<void> fill(WidgetTester tester, String hint, String value) async {
    await tester.enterText(find.widgetWithText(TextFormField, hint), value);
    await tester.pump();
  }

  /// Picks [value] in the dropdown labelled [label].
  Future<void> choose(WidgetTester tester, String label, String value) async {
    final field =
        find.byType(DropdownButtonFormField<String>).at(dropdownIndex[label]!);
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    await tester.tap(field);
    await tester.pumpAndSettle();
    // The menu renders in an overlay above the page. It is scrollable and
    // lazily built, so a long list (countries, time zones) needs scrolling.
    final item = find.text(value).last;
    if (find.text(value).evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        find.text(value),
        120,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(value).last);
    } else {
      await tester.tap(item);
    }
    await tester.pumpAndSettle();
  }

  Future<void> completeOrgStep(WidgetTester tester) async {
    await fill(tester, 'ABC Technologies Pvt Ltd', 'ABC Technologies Pvt Ltd');
    await choose(tester, 'Organization Type', 'Enterprise');
    await choose(tester, 'Industry', 'Information Technology');
    await choose(tester, 'Company Size', '501-1000');
    await choose(tester, 'Country', 'India');
    await choose(tester, 'State', 'Telangana');
    await fill(tester, 'Hyderabad', 'Hyderabad');
    await choose(tester, 'Time Zone', 'Asia/Kolkata (UTC+05:30)');
    await tester.ensureVisible(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
  }

  Future<void> completeAccountStep(WidgetTester tester) async {
    await fill(tester, 'Ananya', 'Ananya');
    await fill(tester, 'Rao', 'Rao');
    await fill(tester, 'ananya.rao@abctech.com', 'ananya.rao@abctech.com');
    await fill(tester, '+91 98765 43210', '+91 98765 43210');
    await fill(tester, 'Create a password', 'Password1!');
    await fill(tester, 'Re-enter password', 'Password1!');
    await tester.ensureVisible(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
  }

  testWidgets('step 1 has no overflow at 360px', (tester) async {
    await openSignup(tester, size: const Size(360, 740));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('step 1 has no overflow at 360px', (tester) async {
    await openSignup(tester, size: const Size(360, 740));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('step 1 refuses to advance without an organization',
      (tester) async {
    await openSignup(tester);

    expect(find.text('STEP 1 OF 3 · ORGANIZATION DETAILS'), findsOneWidget);
    await tester.ensureVisible(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('STEP 1 OF 3 · ORGANIZATION DETAILS'), findsOneWidget);
    expect(find.text('Enter your organization name'), findsOneWidget);
  });

  testWidgets('step 2 matches the admin-account mock', (tester) async {
    await openSignup(tester);
    await completeOrgStep(tester);

    expect(find.text('STEP 2 OF 3 · SUPER ADMIN ACCOUNT'), findsOneWidget);
    expect(find.text('Create your admin account'), findsOneWidget);
    // The subtitle names the organization from step 1.
    expect(find.textContaining('ABC Technologies Pvt Ltd'), findsWidgets);
    expect(find.textContaining('SUPER_ADMIN'), findsOneWidget);
    for (final label in [
      'First Name',
      'Last Name',
      'Official Email',
      'Mobile Number',
      'Username',
      'Password',
      'Confirm Password',
    ]) {
      expect(find.textContaining(label), findsWidgets, reason: label);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('the workspace slug is suggested from the organization name',
      (tester) async {
    await openSignup(tester);
    await fill(tester, 'ABC Technologies Pvt Ltd', 'ABC Technologies Pvt Ltd');
    await tester.pumpAndSettle();

    expect(
      tester
          .widgetList<EditableText>(find.byType(EditableText))
          .map((e) => e.controller.text),
      contains('ABC-TECH'),
    );
  });

  testWidgets('the username is suggested from the name', (tester) async {
    await openSignup(tester);
    await completeOrgStep(tester);

    await fill(tester, 'Ananya', 'Ananya');
    await fill(tester, 'Rao', 'Rao');
    await tester.pumpAndSettle();

    // The Username field is the one whose hint is exactly "ananya.rao"; the
    // email field's hint merely starts with it.
    expect(
      tester
          .widgetList<EditableText>(find.byType(EditableText))
          .map((e) => e.controller.text),
      contains('ananya.rao'),
    );
  });

  testWidgets('a weak password is rejected', (tester) async {
    await openSignup(tester);
    await completeOrgStep(tester);

    await fill(tester, 'Create a password', 'password');
    await tester.pumpAndSettle();
    expect(find.text('Include at least one number'), findsOneWidget);
  });

  testWidgets('mismatched passwords are rejected', (tester) async {
    await openSignup(tester);
    await completeOrgStep(tester);

    await fill(tester, 'Create a password', 'Password1!');
    await fill(tester, 'Re-enter password', 'Password2!');
    await tester.pumpAndSettle();
    expect(find.text('Passwords do not match'), findsOneWidget);
  });

  testWidgets('step 3 reviews what was entered, then creates the account',
      (tester) async {
    await openSignup(tester, size: const Size(390, 1400));
    await completeOrgStep(tester);
    await completeAccountStep(tester);

    expect(find.text('STEP 3 OF 3 · TERMS & AUTHORIZATION'), findsOneWidget);
    expect(find.text('Review and confirm'), findsOneWidget);
    expect(find.textContaining('I have read and agree'), findsOneWidget);
    expect(find.textContaining('I confirm I am authorized'), findsOneWidget);
    expect(find.textContaining('I agree to the'), findsWidgets);
    expect(find.textContaining('Send me product updates'), findsOneWidget);

    // The three required consents gate account creation.
    await tester.ensureVisible(find.text('Create account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(find.text('STEP 3 OF 3 · TERMS & AUTHORIZATION'), findsOneWidget);

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byType(Checkbox).at(i));
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(find.text('Create account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    // The welcome screen, with the new workspace address.
    expect(find.text('Welcome to One Enterprise'), findsOneWidget);
    expect(find.textContaining('abc-tech.oneenterprise.io'), findsOneWidget);
    expect(find.text('Go to sign in'), findsOneWidget);
  });

  testWidgets('Back steps through the wizard and out to login',
      (tester) async {
    await openSignup(tester);
    await completeOrgStep(tester);
    expect(find.text('STEP 2 OF 3 · SUPER ADMIN ACCOUNT'), findsOneWidget);

    await tester.ensureVisible(find.text('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('STEP 1 OF 3 · ORGANIZATION DETAILS'), findsOneWidget);

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    // Narrow windows land on the brand splash ahead of the form.
    expect(find.text('SIGN IN'), findsOneWidget);
  });

  test('register captures the wizard fields and owns a new organization',
      () async {
    final backend = DemoAuthBackend(latency: Duration.zero);
    final user = await backend.register(
      name: 'Ananya Rao',
      email: 'ananya.rao@abctech.com',
      password: 'Password1!',
      organization: 'ABC Technologies Pvt Ltd',
      mobile: '+91 98765 43210',
      username: 'ananya.rao',
    );

    // Creating a brand-new organization makes you its owner.
    expect(user.tenant?.name, 'ABC Technologies Pvt Ltd');
    expect(user.tenant?.slug, 'abctechnologiespvtltd');
    expect(user.roles.single, PlatformRole.superAdmin);
  });

  test('a duplicate username is refused', () async {
    final backend = DemoAuthBackend(latency: Duration.zero);
    await backend.register(
      name: 'Ananya Rao',
      email: 'a@abctech.com',
      password: 'Password1!',
      organization: 'ABC Technologies Pvt Ltd',
      username: 'ananya.rao',
    );

    expect(
      () => backend.register(
        name: 'Another Rao',
        email: 'b@abctech.com',
        password: 'Password1!',
        organization: 'Other Org',
        username: 'ananya.rao',
      ),
      throwsA(isA<AuthException>()),
    );
  });

  test('joining an existing organization does not grant ownership', () async {
    final backend = DemoAuthBackend(latency: Duration.zero);
    await backend.register(
      name: 'Ananya Rao',
      email: 'a@abctech.com',
      password: 'Password1!',
      organization: 'ABC Technologies Pvt Ltd',
    );
    final second = await backend.register(
      name: 'Bhavna Rao',
      email: 'b@abctech.com',
      password: 'Password1!',
      organization: 'ABC Technologies Pvt Ltd',
    );

    expect(second.roles.single, PlatformRole.employee);
  });
}
