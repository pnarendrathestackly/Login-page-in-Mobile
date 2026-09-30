import 'package:flutter_test/flutter_test.dart';

import 'package:stackly_auth/main.dart';

void main() {
  testWidgets('login page renders', (tester) async {
    await tester.pumpWidget(const StacklyApp());
    // Let the staggered entrance animations finish.
    await tester.pumpAndSettle();
    // The 800x600 test surface is narrow, so login opens on the brand splash.
    expect(find.text('SIGN IN'), findsOneWidget);
    await tester.tap(find.text('SIGN IN'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsOneWidget);
  });
}
