import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_shell.dart';

void main() {
  test('RU app catalog uses unique exact Android package ids', () {
    expect(pokrovRuAppCatalogVersion, isNotEmpty);
    expect(pokrovRuAppCatalog, isNotEmpty);
    final ids = pokrovRuAppCatalog.map((entry) => entry.packageId).toList();
    expect(ids.toSet(), hasLength(ids.length));
    for (final entry in pokrovRuAppCatalog) {
      expect(
        entry.packageId,
        matches(RegExp(r'^[a-z0-9_]+(?:\.[a-z0-9_]+){1,}$')),
      );
      expect(entry.label.trim(), isNotEmpty);
      expect(entry.reviewedOn, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    }
  });

  test('installed RU classification is exact, local and deterministic', () {
    expect(
      pokrovInstalledRuAppIds(const <String>[
        'com.android.chrome',
        'RU.YANDEX.TAXI',
        'com.yandex.browser',
        'com.yandex.browser.fake',
        'ru.sberbankmobile',
      ]),
      <String>[
        'com.yandex.browser',
        'ru.yandex.taxi',
        'ru.sberbankmobile',
      ],
    );
    expect(pokrovRuAppCatalogEntry('com.yandex.browser.fake'), isNull);
  });
}
