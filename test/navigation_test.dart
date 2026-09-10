import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stackly_auth/auth.dart';
import 'package:stackly_auth/dashboard.dart';
import 'package:stackly_auth/providers/auth_provider.dart';
import 'package:stackly_auth/providers/navigation_provider.dart';
import 'package:stackly_auth/router/app_router.dart';

import 'test_app.dart';

/// The sidebar contract: Provider holds the state, the router owns the URL,
/// and clicking a subheading updates both.
void main() {
  Future<void> step(WidgetTester tester) async {
    await tester.pump();
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<TestAppState> signedIn(
    WidgetTester tester, {
    Size size = const Size(1400, 1600),
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
    return tester.state<TestAppState>(find.byType(TestApp));
  }

  group('NavigationProvider', () {
    test('starts on the overview and follows the route', () {
      final nav = NavigationProvider();
      addTearDown(nav.dispose);
      expect(nav.selectedSection, DashboardSection.overview);

      nav.syncWithRoute(DashboardSection.projects);
      expect(nav.selectedSection, DashboardSection.projects);
      expect(nav.selectedGroup, SidebarGroup.main);
    });

    test('sidebar and drawer state toggle independently', () {
      final nav = NavigationProvider();
      addTearDown(nav.dispose);

      expect(nav.isSidebarExpanded, isTrue);
      nav.toggleSidebar();
      expect(nav.isSidebarExpanded, isFalse);

      expect(nav.isMobileDrawerOpen, isFalse);
      nav.openDrawer();
      expect(nav.isMobileDrawerOpen, isTrue);
      nav.closeDrawer();
      expect(nav.isMobileDrawerOpen, isFalse);
    });

    test('groups are expanded by default and toggle', () {
      final nav = NavigationProvider();
      addTearDown(nav.dispose);

      expect(nav.isGroupExpanded(SidebarGroup.main), isTrue);
      nav.toggleGroup(SidebarGroup.main);
      expect(nav.isGroupExpanded(SidebarGroup.main), isFalse);
      nav.toggleGroup(SidebarGroup.main);
      expect(nav.isGroupExpanded(SidebarGroup.main), isTrue);
    });
  });

  testWidgets('every sidebar subheading routes to its page', (tester) async {
    final app = await signedIn(tester);

    // Each destination reachable from the sidebar, driving both the URL and
    // the highlight. Messages/Help render a placeholder but still route.
    for (final section in DashboardSection.values) {
      final label = find.text(section.label);
      if (label.evaluate().isEmpty) continue;

      await tester.tap(label.first);
      await step(tester);

      expect(app.router.location, pathForSection(section),
          reason: section.label);
      expect(app.navigation.selectedSection, section, reason: section.label);
    }
  });

  testWidgets('the highlight follows a URL change, not just a tap',
      (tester) async {
    final app = await signedIn(tester);

    // A deep link (or browser back) must move the sidebar selection too.
    app.router.go(AppRoutes.tasks);
    await step(tester);
    expect(app.navigation.selectedSection, DashboardSection.tasks);

    app.router.go(AppRoutes.customers);
    await step(tester);
    expect(app.navigation.selectedSection, DashboardSection.customers);
  });

  testWidgets('exactly one item is selected at a time', (tester) async {
    final app = await signedIn(tester);

    app.router.go(AppRoutes.users);
    await step(tester);

    final selected = DashboardSection.values
        .where((s) => s == app.navigation.selectedSection)
        .toList();
    expect(selected, [DashboardSection.users]);
  });

  testWidgets('selecting from the mobile drawer closes it', (tester) async {
    final app = await signedIn(tester, size: const Size(500, 1200));

    // Narrow: the sidebar is a drawer behind the menu button.
    await tester.tap(find.byTooltip('Open navigation menu'));
    await step(tester);
    expect(app.navigation.isMobileDrawerOpen, isTrue);

    // Tap the item inside the Drawer specifically: at this width it is the
    // only sidebar in the tree, but be explicit rather than relying on order.
    final inDrawer = find.descendant(
      of: find.byType(Drawer),
      matching: find.text(DashboardSection.projects.label),
    );
    expect(inDrawer, findsOneWidget);
    await tester.tap(inDrawer);
    await step(tester);

    expect(app.router.location, AppRoutes.projects);
    expect(app.navigation.isMobileDrawerOpen, isFalse);
  });
}
