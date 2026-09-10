import 'package:flutter_test/flutter_test.dart';

import 'package:stackly_auth/main.dart';

void main() {
  testWidgets('login page renders', (tester) async {
    await tester.pumpWidget(const StacklyApp());
    // Let the staggered entrance animations finish.
    await tester.pumpAndSettle();
    expect(find.text('Welcome Back'), findsOneWidget);
  });
}
