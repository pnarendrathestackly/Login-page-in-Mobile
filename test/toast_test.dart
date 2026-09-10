import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stackly_auth/widgets.dart';

void main() {
  Future<void> pumpHost(WidgetTester tester) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showToast(context, 'Account created'),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );

  testWidgets('toast appears and auto-dismisses', (tester) async {
    await pumpHost(tester);
    expect(find.text('Account created'), findsNothing);

    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Account created'), findsOneWidget);

    // Past the 3s lifetime plus the exit animation.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.text('Account created'), findsNothing);
  });

  testWidgets('toast sits in the top-right', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpHost(tester);
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final box = tester.getRect(find.text('Account created'));
    expect(box.top, lessThan(100)); // near the top edge
    expect(box.right, greaterThan(1200 / 2)); // right half
  });

  testWidgets('toast survives the route that showed it being popped',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (inner) => Scaffold(
                    body: TextButton(
                      onPressed: () {
                        showToast(inner, 'Account created. Please sign in.');
                        Navigator.of(inner).maybePop();
                      },
                      child: const Text('create'),
                    ),
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('create'));
    await tester.pumpAndSettle();

    // Back on the first screen, with the toast still up.
    expect(find.text('open'), findsOneWidget);
    expect(find.text('create'), findsNothing);
    expect(find.text('Account created. Please sign in.'), findsOneWidget);
  });

  testWidgets('close button dismisses immediately', (tester) async {
    await pumpHost(tester);
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Account created'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.text('Account created'), findsNothing);
  });
}
