import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stackly_auth/auth.dart';
import 'package:stackly_auth/providers/auth_provider.dart';
import 'package:stackly_auth/dashboard.dart';
import 'package:stackly_auth/features/admin/super_admin_dashboard.dart';
import 'package:stackly_auth/router/app_router.dart';
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
  Future<List<AppNotification>> notifications() async =>
      throw Exception('boom');
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
    // An HR admin sees the workspace overview; platform admins land on the
    // Super Admin dashboard instead (covered at the end of this file).
    String email = 'hr@onecloud.com',
  }) async {
    String? code;
    final auth = AuthProvider(
      DemoAuthBackend(onCodeSent: (c) => code = c, latency: Duration.zero),
    );
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(TestApp(auth: auth, repository: repository));
    unawaited(auth.signIn(email, 'password123'));
    await step(tester);
    unawaited(auth.verify(code!));
    await step(tester);
    return auth;
  }

  testWidgets('the overview greets the authenticated user by name',
      (tester) async {
    await signedIn(tester);
    // Name comes from the session, not a constant.
    expect(find.text('Welcome back, Priya'), findsOneWidget);
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
    expect(find.text('Welcome back, Priya'), findsOneWidget);

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
    expect(find.text('Welcome back, Priya'), findsOneWidget);
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
    await signedIn(tester, email: 'me@stackly.com');

    await tester.tap(find.bySemanticsLabel(RegExp('Notifications')));
    await step(tester);

    expect(find.text('Mark all as read'), findsOneWidget);
    await tester.tap(find.text('Mark all as read'));
    await step(tester);
    // Nothing unread left, so the control is gone.
    expect(find.text('Mark all as read'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('every workspace destination opens without error',
      (tester) async {
    await signedIn(tester, email: 'me@stackly.com');
    final router = tester.state<TestAppState>(find.byType(TestApp)).router;

    for (final section in DashboardSection.values) {
      router.go(pathForSection(section));
      await step(tester);
      expect(tester.takeException(), isNull, reason: section.label);
    }
  });

  // The widths named in the brief. A RenderFlex overflow throws in tests, so
  // reaching the assertion is the check.
  const widths = [1920.0, 1440.0, 1024.0, 768.0, 480.0, 375.0];
  for (final w in widths) {
    testWidgets('dashboard lays out cleanly at ${w.toInt()}px', (tester) async {
      await signedIn(tester, size: Size(w, 1400));
      expect(find.text('Welcome back, Priya'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  group('super admin', () {
    testWidgets('platform admins land on the Super Admin dashboard',
        (tester) async {
      await signedIn(tester, email: 'me@stackly.com');
      expect(find.text('Super Admin Dashboard'), findsWidgets);
      expect(find.text('Welcome back, Super Admin'), findsOneWidget);
      for (final label in [
        'PLATFORM OVERVIEW',
        'SYSTEM STATUS',
        'RESOURCE UTILIZATION',
        'QUICK NAVIGATION',
        'Security alerts',
        'Recent login activities',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('a quick navigation card opens its page', (tester) async {
      await signedIn(tester, email: 'me@stackly.com');
      final router = tester.state<TestAppState>(find.byType(TestApp)).router;
      await tester.ensureVisible(find.text('Reports').last);
      await tester.tap(find.text('Reports').last);
      await step(tester);
      expect(router.location, AppRoutes.reports);
    });

    testWidgets('Global Dashboard in the sidebar opens its page',
        (tester) async {
      await signedIn(tester, email: 'me@stackly.com');
      await tester.tap(find.text('Global Dashboard').first);
      await step(tester);
      final router = tester.state<TestAppState>(find.byType(TestApp)).router;
      expect(router.location, '/admin/global');
      expect(find.text('Recent activities'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    group('platform configuration', () {
      Future<void> open(WidgetTester tester) async {
        await signedIn(tester, email: 'me@stackly.com');
        await tester.tap(find.text('Platform Configuration').first);
        await step(tester);
      }

      Finder field(String text) => find.widgetWithText(TextFormField, text);
      Finder save() => find.text('Save Changes');

      setUp(() => platformConfig.value = (
            name: 'Java Enterprise Suite',
            url: 'https://app.javasuite.enterprise',
            timeZone: 'UTC +05:30 (India Standard Time)',
            language: 'ENGLISH',
            integrations: const {},
          ));

      testWidgets('saving stores the values and shows the banner',
          (tester) async {
        await open(tester);
        await tester.enterText(field('Java Enterprise Suite'), 'Acme Cloud');
        await tester.ensureVisible(save());
        await tester.tap(save());
        await step(tester);
        expect(platformConfig.value.name, 'Acme Cloud');
        expect(find.text('Your changes has been saved successfully.'),
            findsOneWidget);
      });

      testWidgets('a non-https URL blocks the save', (tester) async {
        await open(tester);
        await tester.enterText(
            field('https://app.javasuite.enterprise'), 'ftp://nope');
        await tester.ensureVisible(save());
        await tester.tap(save());
        await step(tester);
        expect(find.text('Enter an https:// address'), findsOneWidget);
        expect(platformConfig.value.url, 'https://app.javasuite.enterprise');
      });

      testWidgets('cancel restores the saved values', (tester) async {
        await open(tester);
        await tester.enterText(field('Java Enterprise Suite'), 'Draft name');
        await tester.ensureVisible(find.text('Cancel'));
        await tester.tap(find.text('Cancel'));
        await step(tester);
        expect(field('Java Enterprise Suite'), findsOneWidget);
        expect(find.text('Draft name'), findsNothing);
      });
    });

    group('platform branding', () {
      final initial = platformBranding.value;
      setUp(() => platformBranding.value = initial);

      Future<void> open(WidgetTester tester) async {
        await signedIn(tester, email: 'me@stackly.com');
        await tester.tap(find.text('Platform Branding').first);
        await step(tester);
      }

      Finder field(String text) => find.widgetWithText(TextFormField, text);

      testWidgets('an invalid hex colour blocks the save', (tester) async {
        await open(tester);
        await tester.enterText(field('#1976D2'), 'blue');
        await tester.ensureVisible(find.text('Save Changes'));
        await tester.tap(find.text('Save Changes'));
        await step(tester);
        expect(find.text('Use a hex value like #1976D2'), findsOneWidget);
        expect(platformBranding.value.primary, '#1976D2');
      });

      testWidgets('a valid edit is saved', (tester) async {
        await open(tester);
        await tester.enterText(field('Oracle Corporation'), 'Acme Inc');
        await tester.enterText(field('#1976D2'), '#112233');
        await tester.ensureVisible(find.text('Save Changes'));
        await tester.tap(find.text('Save Changes'));
        await step(tester);
        expect(platformBranding.value.companyName, 'Acme Inc');
        expect(platformBranding.value.primary, '#112233');
        expect(tester.takeException(), isNull);
      });
    });

    group('feature management', () {
      final initial = platformFeatures.value;
      setUp(() => platformFeatures.value = initial);

      Future<void> open(WidgetTester tester) async {
        await signedIn(tester, email: 'me@stackly.com');
        await tester.tap(find.text('Feature Management').first);
        await step(tester);
      }

      testWidgets('shows the first page and live counts', (tester) async {
        await open(tester);
        for (final name in [
          'User Management',
          'Workflow Engine',
          'AI Assistant',
          'Reports',
          'API Access',
        ]) {
          expect(find.text(name), findsWidgets, reason: name);
        }
        expect(find.text('65'), findsOneWidget);
        expect(find.text('52'), findsOneWidget);
        expect(find.text('13'), findsWidgets);
      });

      testWidgets('search filters the table', (tester) async {
        await open(tester);
        await tester.enterText(find.byType(TextField).last, 'webhook');
        await step(tester);
        expect(find.text('Webhooks'), findsOneWidget);
        expect(find.text('Workflow Engine'), findsNothing);
      });

      testWidgets('enabling a disabled feature updates the counts',
          (tester) async {
        await open(tester);
        await tester.tap(find.text('Enable').first);
        await step(tester);
        expect(find.text('53'), findsOneWidget);
        expect(find.text('12'), findsOneWidget);
      });

      testWidgets('disabling asks for confirmation first', (tester) async {
        await open(tester);
        await tester.tap(find.text('Disable').first);
        await step(tester);
        expect(find.text('Disable User Management?'), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await step(tester);
        expect(find.text('52'), findsOneWidget);
      });

      testWidgets('paging moves to the next five', (tester) async {
        await open(tester);
        await tester.ensureVisible(find.text('2').last);
        await tester.tap(find.text('2').last);
        await step(tester);
        expect(find.text('Showing 6-10 of 65 features'), findsOneWidget);
      });
    });

    group('license management', () {
      final initial = platformLicenses.value;
      setUp(() => platformLicenses.value = initial);

      Future<void> open(WidgetTester tester) async {
        await signedIn(tester, email: 'me@stackly.com');
        await tester.tap(find.text('License Management').first);
        await step(tester);
      }

      int count(LicenseStatus s) =>
          platformLicenses.value.where((l) => l.status == s).length;

      test('seed matches the design counts', () {
        expect(initial.length, 2458);
        expect(count(LicenseStatus.active), 2104);
        expect(count(LicenseStatus.expiring), 142);
        expect(count(LicenseStatus.suspended), 36);
        expect(initial.first.key, 'LIC-4421-MNPR');
        expect({for (final l in initial) l.key}.length, 2458,
            reason: 'keys are unique');
      });

      testWidgets('shows the counts and first page', (tester) async {
        await open(tester);
        expect(find.text('2,458'), findsOneWidget);
        expect(find.text('2,104'), findsOneWidget);
        expect(find.text('LIC-4421-MNPR'), findsOneWidget);
        expect(find.text('Showing 1 to 5 of 2,458 entries'), findsOneWidget);
      });

      testWidgets('bulk actions need a selection, then apply to it',
          (tester) async {
        await open(tester);
        final suspend = find.widgetWithText(OutlinedButton, 'Suspend');
        await tester.ensureVisible(suspend);
        expect(tester.widget<OutlinedButton>(suspend).onPressed, isNull);

        await tester.tap(find.byType(Checkbox).first);
        await step(tester);
        await tester.ensureVisible(suspend);
        await tester.tap(suspend);
        await step(tester);
        await tester.tap(find.widgetWithText(FilledButton, 'Suspend'));
        await step(tester);
        expect(platformLicenses.value.first.status, LicenseStatus.suspended);
        expect(count(LicenseStatus.suspended), 37);
      });

      testWidgets('the status filter narrows the list', (tester) async {
        await open(tester);
        await tester.tap(find.text('Status'));
        await step(tester);
        await tester.tap(find.text('Suspended').last);
        await step(tester);
        expect(find.text('Showing 1 to 5 of 36 entries'), findsOneWidget);
      });
    });

    testWidgets('the phone dashboard shows every overview section',
        (tester) async {
      await signedIn(tester, email: 'me@stackly.com', size: const Size(390, 2600));

      for (final label in [
        'PLATFORM OVERVIEW',
        'SYSTEM STATUS',
        'RESOURCE UTILIZATION',
        'QUICK NAVIGATION',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('Super Admin Dashboard'), findsOneWidget);
      expect(find.text('TOTAL USERS'), findsOneWidget);
      expect(find.text('Security alerts'), findsOneWidget);
      expect(find.text('Recent login activities'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Platform Administration opens its overview', (tester) async {
      await signedIn(tester, email: 'me@stackly.com');
      await tester.tap(find.text('Platform Administration').first);
      await step(tester);
      expect(find.text('PLATFORM UPTIME'), findsOneWidget);
      expect(find.text('Platform Health Overview'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final w in widths) {
      testWidgets('super admin pages lay out cleanly at ${w.toInt()}px',
          (tester) async {
        await signedIn(tester, email: 'me@stackly.com', size: Size(w, 1400));
        expect(find.text('Welcome back, Super Admin'), findsOneWidget);
        expect(tester.takeException(), isNull);
        tester.state<TestAppState>(find.byType(TestApp)).router.go(
              '/admin/overview',
            );
        await step(tester);
        expect(find.text('PLATFORM UPTIME'), findsOneWidget);
        expect(tester.takeException(), isNull);
        tester.state<TestAppState>(find.byType(TestApp)).router.go(
              '/admin/global',
            );
        await step(tester);
        expect(find.text('Platform Health Status'), findsOneWidget);
        expect(find.text('System Health'), findsOneWidget);
        expect(tester.takeException(), isNull);
        tester.state<TestAppState>(find.byType(TestApp)).router.go(
              '/admin/settings',
            );
        await step(tester);
        expect(find.text('Security Handling'), findsOneWidget);
        expect(tester.takeException(), isNull);
        tester.state<TestAppState>(find.byType(TestApp)).router.go(
              '/admin/branding',
            );
        await step(tester);
        expect(find.text('Theme Configuration'), findsOneWidget);
        expect(tester.takeException(), isNull);
        tester.state<TestAppState>(find.byType(TestApp)).router.go(
              '/admin/features',
            );
        await step(tester);
        expect(find.text('FEATURE NAME'), findsOneWidget);
        expect(tester.takeException(), isNull);
        tester.state<TestAppState>(find.byType(TestApp)).router.go(
              '/admin/licenses',
            );
        await step(tester);
        expect(find.text('LICENSE KEY'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
