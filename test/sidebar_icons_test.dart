import 'package:flutter_test/flutter_test.dart';
import 'package:stackly_auth/core/platform/modules.dart';

void main() {
  test('every module page has an icon', () {
    final missing = <String>[];
    for (final m in kModules) {
      for (final p in m.pages) {
        if (p.icon == null) missing.add('${m.id}/${p.slug}');
      }
    }
    expect(missing, isEmpty, reason: 'pages without an icon: $missing');
  });

  test('every module has a logo asset', () {
    final missing = [
      for (final m in kModules)
        if (m.logoAsset == null) m.id,
    ];
    expect(missing, isEmpty, reason: 'modules without a logo: $missing');
  });

  test('sibling pages inside a module have distinct icons', () {
    for (final m in kModules) {
      final icons = m.pages.map((p) => p.icon).toList();
      expect(
        icons.toSet().length,
        icons.length,
        reason: '${m.id} reuses an icon across its pages: $icons',
      );
    }
  });
}
