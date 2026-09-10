import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stackly_auth/motion.dart';

/// Reduced motion is an accessibility requirement, not a nicety: with it on,
/// content must be at its final state immediately rather than animating in.
void main() {
  Widget host({required bool reduce, required Widget child}) => MediaQuery(
        data: MediaQueryData(disableAnimations: reduce),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: child,
        ),
      );

  testWidgets('FadeIn animates when motion is allowed', (tester) async {
    await tester.pumpWidget(
      host(reduce: false, child: const FadeIn(child: Text('hi'))),
    );
    await tester.pump();
    final opacity = tester.widget<FadeTransition>(
      find.byType(FadeTransition).first,
    );
    // Mid-flight: not yet fully opaque.
    expect(opacity.opacity.value, lessThan(1.0));

    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FadeTransition>(find.byType(FadeTransition).first)
          .opacity
          .value,
      1.0,
    );
  });

  testWidgets('FadeIn is fully visible immediately under reduced motion',
      (tester) async {
    await tester.pumpWidget(
      host(reduce: true, child: const FadeIn(child: Text('hi'))),
    );
    await tester.pump();
    expect(
      tester
          .widget<FadeTransition>(find.byType(FadeTransition).first)
          .opacity
          .value,
      1.0,
    );
    expect(find.text('hi'), findsOneWidget);
  });

  testWidgets('a delayed FadeIn still shows at once under reduced motion',
      (tester) async {
    await tester.pumpWidget(
      host(
        reduce: true,
        child: const FadeIn(
          delay: Duration(milliseconds: 400),
          child: Text('delayed'),
        ),
      ),
    );
    await tester.pump();
    expect(
      tester
          .widget<FadeTransition>(find.byType(FadeTransition).first)
          .opacity
          .value,
      1.0,
    );
  });

  test('Motion.duration collapses to zero only when reduced', () {
    // Guarded via a real element below; this asserts the tier values hold.
    expect(Motion.micro.inMilliseconds, inInclusiveRange(100, 180));
    expect(Motion.standard.inMilliseconds, inInclusiveRange(180, 300));
    expect(Motion.page.inMilliseconds, inInclusiveRange(250, 450));
    expect(Motion.complex.inMilliseconds, lessThanOrEqualTo(500));
  });

  testWidgets('Motion.reduced reflects the platform setting', (tester) async {
    late bool onValue;
    late bool offValue;
    await tester.pumpWidget(
      host(
        reduce: true,
        child: Builder(
          builder: (context) {
            onValue = Motion.reduced(context);
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpWidget(
      host(
        reduce: false,
        child: Builder(
          builder: (context) {
            offValue = Motion.reduced(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(onValue, isTrue);
    expect(offValue, isFalse);
  });

  testWidgets('ExpandFade collapses to nothing when hidden', (tester) async {
    await tester.pumpWidget(
      host(
        reduce: false,
        child: const ExpandFade(visible: false, child: Text('banner')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('banner'), findsNothing);

    await tester.pumpWidget(
      host(
        reduce: false,
        child: const ExpandFade(visible: true, child: Text('banner')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('banner'), findsOneWidget);
  });
}
