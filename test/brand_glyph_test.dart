import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stackly_auth/theme/app_theme.dart';
import 'package:stackly_auth/widgets.dart';

/// The brand glyph is drawn, not an asset, so its geometry has to stay inside
/// the box it is given — an earlier version painted past its own bounds.
void main() {
  for (final size in [26.0, 28.0, 64.0, 140.0]) {
    testWidgets('glyph paints within its ${size.toInt()}px box',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: Center(child: BrandGlyph(size: size))),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final box = tester.getSize(find.byType(BrandGlyph));
      expect(box.width, size);
      expect(box.height, size);
    });
  }

  testWidgets('the brand mark pairs the glyph with the wordmark',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: BrandMark())),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(BrandGlyph), findsOneWidget);
    expect(find.textContaining('Stackly'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
