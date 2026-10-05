import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stackly_auth/auth.dart';
import 'package:stackly_auth/providers/auth_provider.dart';

import 'test_app.dart';

// Temporary: real-font render of the phone sign-in form.
Future<void> _font(String family, List<String> files) async {
  final l = FontLoader(family);
  for (final f in files) {
    l.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
  }
  await l.load();
}

/// The SDK's bundled Material fonts, found via FLUTTER_ROOT (set by
/// `flutter test`) rather than a fixed install path.
final _fonts =
    '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts';

void main() {
  testWidgets('signin shot', (tester) async {
    await tester.runAsync(() async {
      await _font('Roboto', [
        '$_fonts/roboto-regular.ttf',
        '$_fonts/roboto-medium.ttf',
        '$_fonts/roboto-bold.ttf',
      ]);
      await _font('Consolas', ['C:/Windows/Fonts/consola.ttf']);
      await _font('MaterialIcons', ['$_fonts/materialicons-regular.otf']);
    });
    tester.view.physicalSize = const Size(360, 889);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      TestApp(auth: AuthProvider(DemoAuthBackend(latency: Duration.zero))),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('SIGN IN'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      for (final e in find.byType(Image).evaluate()) {
        final w = e.widget as Image;
        await precacheImage(w.image, e);
      }
    });
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/signin.png'));
  });
}
