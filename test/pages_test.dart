import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stackly_auth/auth.dart';
import 'package:stackly_auth/providers/auth_provider.dart';
import 'package:stackly_auth/dashboard.dart';
import 'package:stackly_auth/router/app_router.dart';

import 'test_app.dart';

/// Covers the directory pages: content renders, search and filters narrow the
/// table, sorting reorders it, and the forms/dialogs work.
void main() {
  Future<void> step(WidgetTester tester) async {
    await tester.pump();
    for (var i = 0; i < 16; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// Signs in and navigates to [section].
  Future<TestAppState> open(
    WidgetTester tester,
    DashboardSection section, {
    Size size = const Size(1600, 1400),
  }) async {
    String? code;
    final auth = AuthProvider(
      DemoAuthBackend(onCodeSent: (c) => code = c, latency: Duration.zero),
    );
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(TestApp(auth: auth));
    unawaited(auth.signIn('me@stackly.com', 'password123'));
    await step(tester);
    unawaited(auth.verify(code!));
    await step(tester);

    final app = tester.state<TestAppState>(find.byType(TestApp));
    app.router.go(pathForSection(section));
    await step(tester);
    return app;
  }

  // ---------------------------------------------------------------- Users
  group('Users', () {
    testWidgets('renders KPIs and real user rows', (tester) async {
      await open(tester, DashboardSection.users);

      expect(find.text('TOTAL USERS'), findsOneWidget);
      expect(find.text('ACTIVE USERS'), findsOneWidget);
      expect(find.text('INACTIVE USERS'), findsOneWidget);
      expect(find.text('PENDING INVITATIONS'), findsOneWidget);

      // Real names, not placeholder text.
      expect(find.text('Arun Kumar'), findsWidgets);
      expect(find.text('Priya Raman'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('search narrows the table', (tester) async {
      await open(tester, DashboardSection.users);
      expect(find.text('Arun Kumar'), findsWidgets);

      await tester.enterText(find.byType(TextField).last, 'priya');
      await step(tester);

      expect(find.text('Priya Raman'), findsWidgets);
      expect(find.text('Arun Kumar'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a search with no matches shows a distinct empty state',
        (tester) async {
      await open(tester, DashboardSection.users);

      await tester.enterText(find.byType(TextField).last, 'zzzznotarealname');
      await step(tester);

      // "No matching" (filtered), not "No users yet" (genuinely empty).
      expect(find.text('No matching users'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sorting by name reorders and toggles direction',
        (tester) async {
      await open(tester, DashboardSection.users);

      Future<void> tapUserHeader() async {
        await tester.tap(find.bySemanticsLabel(RegExp('^User, tap to sort|'
            '^User, sorted')));
        await step(tester);
      }

      await tapUserHeader();
      expect(find.bySemanticsLabel(RegExp('User, sorted ascending')),
          findsOneWidget);

      await tapUserHeader();
      expect(find.bySemanticsLabel(RegExp('User, sorted descending')),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Add User validates, then adds a row', (tester) async {
      await open(tester, DashboardSection.users);

      await tester.tap(find.text('Add User'));
      await step(tester);
      expect(find.text('Send invite'), findsOneWidget);

      // Submitting empty is refused.
      await tester.tap(find.text('Send invite'));
      await step(tester);
      expect(find.text('Full name is required.'), findsOneWidget);

      // Address the dialog's fields by hint: the page's own search boxes come
      // first in tree order.
      Finder field(String hint) => find.widgetWithText(TextField, hint);
      await tester.enterText(field('Full name'), 'Test Person');
      await tester.enterText(field('Email address'), 'not-an-email');
      await tester.enterText(field('Role'), 'Engineer');
      await tester.enterText(field('Department'), 'Engineering');
      await tester.tap(find.text('Send invite'));
      await step(tester);
      // Email shape is validated too.
      expect(find.text('Enter a valid email address.'), findsOneWidget);

      await tester.enterText(
          field('Email address'), 'test.person@thestackly.com');
      await tester.tap(find.text('Send invite'));
      await step(tester);

      expect(find.text('Send invite'), findsNothing); // dialog closed
      expect(find.text('Test Person'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('deleting asks for confirmation first', (tester) async {
      await open(tester, DashboardSection.users);

      await tester.tap(find.byTooltip('More actions').first);
      await step(tester);
      await tester.tap(find.text('Delete').last);
      await step(tester);

      // Nothing is removed until the dialog is confirmed.
      expect(find.textContaining('cannot be undone'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await step(tester);
      expect(tester.takeException(), isNull);
    });
  });

  // ------------------------------------------------------------ Customers
  testWidgets('Customers renders KPIs, top accounts and rows', (tester) async {
    await open(tester, DashboardSection.customers);

    expect(find.text('TOTAL CUSTOMERS'), findsOneWidget);
    expect(find.text('AT-RISK CUSTOMERS'), findsOneWidget);
    expect(find.text('Top Accounts'), findsOneWidget);
    expect(find.text('Northwind Ltd'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  // ------------------------------------------------------------- Projects
  testWidgets('Projects renders KPIs and project rows', (tester) async {
    await open(tester, DashboardSection.projects);

    expect(find.text('TOTAL PROJECTS'), findsOneWidget);
    expect(find.text('DELAYED'), findsOneWidget);
    expect(find.text('Atlas Migration'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  // ---------------------------------------------------------------- Tasks
  group('Tasks', () {
    testWidgets('renders the five KPI tallies and task rows', (tester) async {
      await open(tester, DashboardSection.tasks);

      for (final label in [
        'TOTAL TASKS',
        'TO DO',
        'IN PROGRESS',
        'COMPLETED',
        'OVERDUE',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('the overdue filter narrows to overdue work only',
        (tester) async {
      await open(tester, DashboardSection.tasks);

      await tester.tap(find.text('Overdue only'));
      await step(tester);

      // This task is not overdue, so it drops out.
      expect(find.text('Ship portal design tokens'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  // -------------------------------------------------------------- Reports
  testWidgets('Reports renders every analytics panel', (tester) async {
    await open(tester, DashboardSection.reports);

    expect(find.text('TOTAL REVENUE'), findsOneWidget);
    expect(find.text('Revenue Performance'), findsOneWidget);
    expect(find.text('Customer Growth'), findsOneWidget);
    expect(find.text('Task Completion Analysis'), findsOneWidget);
    expect(find.text('Project Performance'), findsOneWidget);
    expect(find.text('Customer Distribution by Industry'), findsOneWidget);
    expect(find.text('Team Productivity'), findsOneWidget);
    expect(find.text('Report Controls'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // -------------------------------------------------------------- Profile
  testWidgets('Profile shows the session user and detail sections',
      (tester) async {
    await open(tester, DashboardSection.profile);

    // Identity comes from the session, not a constant.
    expect(find.text('Vishnu Vardhan'), findsWidgets);
    expect(find.text('me@stackly.com'), findsWidgets);
    expect(find.text('Personal Information'), findsOneWidget);
    expect(find.text('Contact Information'), findsOneWidget);
    expect(find.text('Professional Information'), findsOneWidget);
    expect(find.text('Account Information'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // ------------------------------------------------------------- Settings
  group('Settings', () {
    testWidgets('switches between tabs', (tester) async {
      await open(tester, DashboardSection.settings);

      expect(find.text('Application name'), findsOneWidget);

      await tester.tap(find.text('Security').last);
      await step(tester);
      expect(find.text('Login alerts'), findsOneWidget);

      await tester.tap(find.text('Notifications').last);
      await step(tester);
      expect(find.text('Email notifications'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('destructive actions confirm before running', (tester) async {
      await open(tester, DashboardSection.settings);

      await tester.tap(find.text('Danger Zone').last);
      await step(tester);
      await tester.tap(find.text('Delete'));
      await step(tester);

      expect(find.textContaining('cannot be undone'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await step(tester);
      expect(tester.takeException(), isNull);
    });
  });

  // -------------------------------------------------------- Notifications
  group('Notifications', () {
    testWidgets('renders category tabs and notification rows', (tester) async {
      await open(tester, DashboardSection.notifications);

      for (final tab in ['All', 'Unread', 'Mentions', 'Tasks', 'Projects']) {
        expect(find.text(tab), findsWidgets, reason: tab);
      }
      expect(
        find.text('Project Phoenix has reached 80% completion'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a category tab filters the list', (tester) async {
      await open(tester, DashboardSection.notifications);

      await tester.tap(find.text('Mentions').first);
      await step(tester);

      expect(find.text('Priya Raman mentioned you'), findsOneWidget);
      // A project notification is filtered out.
      expect(
        find.text('Project Phoenix has reached 80% completion'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('mark all as read clears the unread state', (tester) async {
      await open(tester, DashboardSection.notifications);

      expect(find.text('Mark all as read'), findsOneWidget);
      await tester.tap(find.text('Mark all as read'));
      await step(tester);

      expect(find.text('Mark all as read'), findsNothing);
      expect(find.text('You have no unread notifications.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('clear all confirms before emptying the inbox', (tester) async {
      await open(tester, DashboardSection.notifications);

      await tester.tap(find.text('Clear all'));
      await step(tester);
      expect(find.textContaining('cannot be undone'), findsOneWidget);

      await tester.tap(find.text('Clear all').last);
      await step(tester);

      expect(find.text("You're all caught up"), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  // ------------------------------------------------------------ Responsive
  // Every page at every width named in the brief. A RenderFlex overflow throws
  // in tests, so reaching the assertion is the check.
  for (final section in [
    DashboardSection.users,
    DashboardSection.customers,
    DashboardSection.projects,
    DashboardSection.tasks,
    DashboardSection.reports,
    DashboardSection.profile,
    DashboardSection.settings,
    DashboardSection.notifications,
  ]) {
    for (final width in [1920.0, 1440.0, 1024.0, 768.0, 480.0, 375.0]) {
      testWidgets('${section.label} lays out cleanly at ${width.toInt()}px',
          (tester) async {
        await open(tester, section, size: Size(width, 2200));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
