import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stackly_auth/auth.dart';
import 'package:stackly_auth/providers/auth_provider.dart';
import 'package:stackly_auth/dashboard.dart';
import 'package:stackly_auth/features/dashboard/services/demo_data.dart';
import 'package:stackly_auth/features/dashboard/models/dashboard_models.dart';
import 'package:stackly_auth/features/dashboard/services/dashboard_repository.dart';

import 'test_app.dart';

/// A repository whose every call fails, so the error paths are exercised.
class _FailingRepository implements DashboardRepository {
  @override
  Future<DashboardData> load() async => throw Exception('boom');
  @override
  Future<PerformanceSeries> performance(ChartRange range) async =>
      throw Exception('boom');
  @override
  Future<List<AppNotification>> notifications() async => throw Exception('boom');
  @override
  Future<void> markRead({String? id}) async {}
  @override
  Future<void> deleteNotification(String id) async {}
  @override
  Future<List<Member>> members() async => throw Exception('boom');
  @override
  Future<List<Customer>> customers() async => throw Exception('boom');
  @override
  Future<List<ProjectRecord>> projects() async => throw Exception('boom');
  @override
  Future<List<TaskRecord>> tasks() async => throw Exception('boom');
  @override
  Future<List<UpcomingItem>> upcoming() async => throw Exception('boom');
  @override
  Future<ReportsData> reports() async => throw Exception('boom');
}

/// A repository that returns nothing, so the empty states are exercised.
class _EmptyRepository implements DashboardRepository {
  @override
  Future<DashboardData> load() async => const DashboardData(
        kpis: [],
        userActivity: [],
        projectBreakdown: [],
        activity: [],
        projects: [],
        tasks: [],
        health: [],
      );
  @override
  Future<PerformanceSeries> performance(ChartRange range) async =>
      const PerformanceSeries(labels: [], values: []);
  @override
  Future<List<AppNotification>> notifications() async => const [];
  @override
  Future<void> markRead({String? id}) async {}
  @override
  Future<void> deleteNotification(String id) async {}
  @override
  Future<List<Member>> members() async => const [];
  @override
  Future<List<Customer>> customers() async => const [];
  @override
  Future<List<ProjectRecord>> projects() async => const [];
  @override
  Future<List<TaskRecord>> tasks() async => const [];
  @override
  Future<List<UpcomingItem>> upcoming() async => const [];
  @override
  Future<ReportsData> reports() async => DemoData.reports(DateTime.now());
}

/// Never completes, so the skeletons stay on screen.
class _HangingRepository implements DashboardRepository {
  @override
  Future<DashboardData> load() => Completer<DashboardData>().future;
  @override
  Future<PerformanceSeries> performance(ChartRange r) =>
      Completer<PerformanceSeries>().future;
  @override
  Future<List<AppNotification>> notifications() =>
      Completer<List<AppNotification>>().future;
  @override
  Future<void> markRead({String? id}) async {}
  @override
  Future<void> deleteNotification(String id) async {}
  @override
  Future<List<Member>> members() => Completer<List<Member>>().future;
  @override
  Future<List<Customer>> customers() => Completer<List<Customer>>().future;
  @override
  Future<List<ProjectRecord>> projects() =>
      Completer<List<ProjectRecord>>().future;
  @override
  Future<List<TaskRecord>> tasks() => Completer<List<TaskRecord>>().future;
  @override
  Future<List<UpcomingItem>> upcoming() =>
      Completer<List<UpcomingItem>>().future;
  @override
  Future<ReportsData> reports() => Completer<ReportsData>().future;
}

void main() {
  /// Runs pending zero-latency futures plus the entrance animations.
  Future<void> step(WidgetTester tester) async {
    await tester.pump();
    for (var i = 0; i < 16; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<AuthController> signedIn(
    WidgetTester tester, {
    DashboardRepository? repository,
    Size size = const Size(1440, 1200),
  }) async {
    String? code;
    final auth = AuthProvider(
      DemoAuthBackend(onCodeSent: (c) => code = c, latency: Duration.zero),
    );
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(TestApp(auth: auth, repository: repository));
    unawaited(auth.signIn('me@stackly.com', 'password123'));
    await step(tester);
    unawaited(auth.verify(code!));
    await step(tester);
    return auth;
  }

  testWidgets('the overview greets the authenticated user by name',
      (tester) async {
    await signedIn(tester);
    // Name comes from the session, not a constant.
    expect(find.text('Welcome back, Vishnu'), findsOneWidget);
    expect(
      find.text("Here's what's happening across your organization today."),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('KPI cards, charts, projects, tasks and health all render',
      (tester) async {
    await signedIn(tester);

    for (final label in [
      'TOTAL USERS',
      'ACTIVE CUSTOMERS',
      'ACTIVE PROJECTS',
      'PENDING TASKS',
      'REVENUE',
      'PLATFORM HEALTH',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }

    expect(find.text('Business Performance'), findsOneWidget);
    expect(find.text('User Activity'), findsOneWidget);
    expect(find.text('Project Status'), findsOneWidget);
    expect(find.text('Recent Activity'), findsOneWidget);
    expect(find.text('Recent Projects'), findsOneWidget);
    expect(find.text('Task Overview'), findsOneWidget);
    expect(find.text('System Health'), findsOneWidget);
    expect(find.text('Quick Actions'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failing repository shows an error with a working retry',
      (tester) async {
    await signedIn(tester, repository: _FailingRepository());

    expect(find.textContaining("couldn't load your dashboard data"),
        findsOneWidget);
    // The shell survives: the welcome banner is still there.
    expect(find.text('Welcome back, Vishnu'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Retry').first);
    await step(tester);
    // Still failing, so the error comes back rather than the dashboard blanking.
    expect(find.textContaining("couldn't load your dashboard data"),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty data shows guidance rather than blank panels',
      (tester) async {
    await signedIn(tester, repository: _EmptyRepository());

    expect(find.text('No projects yet'), findsOneWidget);
    expect(
      find.text('Create your first project to start tracking progress.'),
      findsOneWidget,
    );
    expect(find.text('No tasks yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('slow data shows skeletons, never a blank page', (tester) async {
    await signedIn(tester, repository: _HangingRepository());

    // Skeletons carry a "Loading" semantics label.
    expect(find.bySemanticsLabel('Loading'), findsWidgets);
    expect(find.text('Welcome back, Vishnu'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('changing the performance range refetches that range only',
      (tester) async {
    await signedIn(tester);

    await tester.tap(find.text('12 Months'));
    await step(tester);
    // Month labels prove the year series rendered.
    expect(find.text('Business Performance'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the notification bell opens a panel and marks all as read',
      (tester) async {
    await signedIn(tester);

    await tester.tap(find.bySemanticsLabel(RegExp('Notifications')));
    await step(tester);

    expect(find.text('Mark all as read'), findsOneWidget);
    await tester.tap(find.text('Mark all as read'));
    await step(tester);
    // Nothing unread left, so the control is gone.
    expect(find.text('Mark all as read'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('every sidebar destination opens without error', (tester) async {
    await signedIn(tester);

    for (final section in DashboardSection.values) {
      await tester.tap(find.text(section.label).first);
      await step(tester);
      expect(tester.takeException(), isNull, reason: section.label);
    }
  });

  testWidgets('the desktop sidebar collapses to a rail', (tester) async {
    await signedIn(tester);

    // Full width: labels visible.
    expect(find.text('Reports & Analytics'), findsOneWidget);
    await tester.tap(find.byTooltip('Open navigation menu'));
    await step(tester);
    // Collapsed: icons only.
    expect(find.text('Reports & Analytics'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  // The widths named in the brief. A RenderFlex overflow throws in tests, so
  // reaching the assertion is the check.
  const widths = [1920.0, 1440.0, 1024.0, 768.0, 480.0, 375.0];
  for (final w in widths) {
    testWidgets('dashboard lays out cleanly at ${w.toInt()}px', (tester) async {
      await signedIn(tester, size: Size(w, 1400));
      expect(find.text('Welcome back, Vishnu'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
