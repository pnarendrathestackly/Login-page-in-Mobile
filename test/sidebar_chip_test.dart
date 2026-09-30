import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:stackly_auth/core/platform/permissions.dart';
import 'package:stackly_auth/models/menu_item_model.dart';
import 'package:stackly_auth/providers/navigation_provider.dart';
import 'package:stackly_auth/theme/app_theme.dart';
import 'package:stackly_auth/widgets/sidebar/icon_chip.dart';
import 'package:stackly_auth/widgets/sidebar/module_menu.dart';
import 'package:stackly_auth/widgets/sidebar/sidebar_constants.dart';
import 'package:stackly_auth/widgets/sidebar/sidebar_menu_item.dart';

/// The coloured icon chips must fit the collapsed rail: a chip sized for the
/// expanded sidebar overflowed it by a couple of pixels.
void main() {
  Future<void> pumpItem(
    WidgetTester tester, {
    required bool collapsed,
    required double width,
  }) async {
    final nav = NavigationProvider();
    addTearDown(nav.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: ChangeNotifierProvider<NavigationProvider>.value(
        value: nav,
        child: Scaffold(
          body: SizedBox(
            width: width,
            child: Column(
              children: [
                for (final item in kMenuItems.take(4))
                  SidebarMenuItem(
                    item: item,
                    selected: item == kMenuItems.first,
                    collapsed: collapsed,
                    onTap: () {},
                  ),
              ],
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('chips fit the collapsed rail without overflowing',
      (tester) async {
    await pumpItem(tester, collapsed: true, width: kSidebarCollapsedWidth);
    expect(tester.takeException(), isNull,
        reason: 'the icon chip overflows the ${kSidebarCollapsedWidth}px rail');
  });

  testWidgets('chips fit the expanded sidebar', (tester) async {
    await pumpItem(tester, collapsed: false, width: kSidebarWidth);
    expect(tester.takeException(), isNull);
  });

  testWidgets('every menu item gets a chip', (tester) async {
    await pumpItem(tester, collapsed: false, width: kSidebarWidth);
    expect(find.byType(SidebarIconChip), findsNWidgets(4));
  });

  testWidgets('module headers and sub-pages both get raised tiles',
      (tester) async {
    tester.view.physicalSize = const Size(400, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final nav = NavigationProvider();
    addTearDown(nav.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: ChangeNotifierProvider<NavigationProvider>.value(
        value: nav,
        child: Scaffold(
          body: SizedBox(
            width: kSidebarWidth,
            child: SingleChildScrollView(
              child: Builder(
                builder: (c) => Column(
                  children: ModuleMenu(
                    permissions: PermissionSet({Perm.all}),
                    currentPath: '/hrms/employees',
                  ).rows(c),
                ),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Module headers: one chip each, logo PNGs included.
    final headers = find.byType(SidebarIconChip).evaluate().length;
    expect(headers, greaterThan(8), reason: 'module headers have no chips');

    await tester.tap(find.text('HRMS'));
    await tester.pumpAndSettle();
    // Expanding adds a chip per sub-page.
    expect(find.byType(SidebarIconChip).evaluate().length, greaterThan(headers),
        reason: 'sub-page rows have no chips');
    expect(tester.takeException(), isNull);
  });

  test('destinations have distinct, stable hues', () {
    final hues = {
      for (final i in kMenuItems) i.section.name: sidebarHue(i.section.name),
    };
    // Stable: the same key always resolves to the same colour.
    for (final entry in hues.entries) {
      expect(sidebarHue(entry.key), entry.value);
    }
    // Varied: the rail is not one flat colour.
    expect(hues.values.toSet().length, greaterThan(4));
  });
}
