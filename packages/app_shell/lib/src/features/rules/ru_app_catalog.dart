part of pokrov_app_shell;

enum PokrovRuAppCategory {
  yandex,
  social,
  government,
  shopping,
  finance,
}

class PokrovRuAppCatalogEntry {
  const PokrovRuAppCatalogEntry({
    required this.packageId,
    required this.label,
    required this.category,
    required this.reviewedOn,
  });

  final String packageId;
  final String label;
  final PokrovRuAppCategory category;
  final String reviewedOn;
}

const pokrovRuAppCatalogVersion = '2026-08-14.1';

/// Reviewed launcher package ids used only for local classification.
///
/// The installed application list and matches never leave the device. Unknown
/// packages stay visible in the picker and can always be selected manually.
const pokrovRuAppCatalog = <PokrovRuAppCatalogEntry>[
  PokrovRuAppCatalogEntry(
    packageId: 'com.yandex.browser',
    label: 'Яндекс Браузер',
    category: PokrovRuAppCategory.yandex,
    reviewedOn: '2026-08-14',
  ),
  PokrovRuAppCatalogEntry(
    packageId: 'ru.yandex.searchplugin',
    label: 'Яндекс',
    category: PokrovRuAppCategory.yandex,
    reviewedOn: '2026-08-14',
  ),
  PokrovRuAppCatalogEntry(
    packageId: 'ru.yandex.yandexmaps',
    label: 'Яндекс Карты',
    category: PokrovRuAppCategory.yandex,
    reviewedOn: '2026-08-14',
  ),
  PokrovRuAppCatalogEntry(
    packageId: 'ru.yandex.taxi',
    label: 'Яндекс Go',
    category: PokrovRuAppCategory.yandex,
    reviewedOn: '2026-08-14',
  ),
  PokrovRuAppCatalogEntry(
    packageId: 'ru.yandex.music',
    label: 'Яндекс Музыка',
    category: PokrovRuAppCategory.yandex,
    reviewedOn: '2026-08-14',
  ),
  PokrovRuAppCatalogEntry(
    packageId: 'ru.yandex.disk',
    label: 'Яндекс Диск',
    category: PokrovRuAppCategory.yandex,
    reviewedOn: '2026-08-14',
  ),
  PokrovRuAppCatalogEntry(
    packageId: 'ru.yandex.mail',
    label: 'Яндекс Почта',
    category: PokrovRuAppCategory.yandex,
    reviewedOn: '2026-08-14',
  ),
  PokrovRuAppCatalogEntry(
    packageId: 'ru.kinopoisk',
    label: 'Кинопоиск',
    category: PokrovRuAppCategory.yandex,
    reviewedOn: '2026-08-14',
  ),
  PokrovRuAppCatalogEntry(
    packageId: 'com.vkontakte.android',
    label: 'ВКонтакте',
    category: PokrovRuAppCategory.social,
    reviewedOn: '2026-08-14',
  ),
  PokrovRuAppCatalogEntry(
    packageId: 'ru.ok.android',
    label: 'Одноклассники',
    category: PokrovRuAppCategory.social,
    reviewedOn: '2026-08-14',
  ),
  PokrovRuAppCatalogEntry(
    packageId: 'ru.mail.mailapp',
    label: 'Почта Mail',
    category: PokrovRuAppCategory.social,
    reviewedOn: '2026-08-14',
  ),
  PokrovRuAppCatalogEntry(
    packageId: 'ru.mail.cloud',
    label: 'Облако Mail',
    category: PokrovRuAppCategory.social,
    reviewedOn: '2026-08-14',
  ),
  PokrovRuAppCatalogEntry(
    packageId: 'ru.rostel',
    label: 'Госуслуги',
    category: PokrovRuAppCategory.government,
    reviewedOn: '2026-08-14',
  ),
  PokrovRuAppCatalogEntry(
    packageId: 'ru.rustore.app',
    label: 'RuStore',
    category: PokrovRuAppCategory.government,
    reviewedOn: '2026-08-14',
  ),
  PokrovRuAppCatalogEntry(
    packageId: 'com.avito.android',
    label: 'Авито',
    category: PokrovRuAppCategory.shopping,
    reviewedOn: '2026-08-14',
  ),
  PokrovRuAppCatalogEntry(
    packageId: 'com.wildberries.ru',
    label: 'Wildberries',
    category: PokrovRuAppCategory.shopping,
    reviewedOn: '2026-08-14',
  ),
  PokrovRuAppCatalogEntry(
    packageId: 'ru.ozon.app.android',
    label: 'Ozon',
    category: PokrovRuAppCategory.shopping,
    reviewedOn: '2026-08-14',
  ),
  PokrovRuAppCatalogEntry(
    packageId: 'ru.sberbankmobile',
    label: 'СберБанк Онлайн',
    category: PokrovRuAppCategory.finance,
    reviewedOn: '2026-08-14',
  ),
  PokrovRuAppCatalogEntry(
    packageId: 'ru.tinkoff.mb',
    label: 'Т-Банк',
    category: PokrovRuAppCategory.finance,
    reviewedOn: '2026-08-14',
  ),
  PokrovRuAppCatalogEntry(
    packageId: 'ru.vtb24.mobilebanking.android',
    label: 'ВТБ Онлайн',
    category: PokrovRuAppCategory.finance,
    reviewedOn: '2026-08-14',
  ),
  PokrovRuAppCatalogEntry(
    packageId: 'ru.alfabank.mobile.android',
    label: 'Альфа-Банк',
    category: PokrovRuAppCategory.finance,
    reviewedOn: '2026-08-14',
  ),
  PokrovRuAppCatalogEntry(
    packageId: 'ru.gazprombank.android.mobilebank.app',
    label: 'Газпромбанк',
    category: PokrovRuAppCategory.finance,
    reviewedOn: '2026-08-14',
  ),
];

final Map<String, PokrovRuAppCatalogEntry> _pokrovRuAppCatalogById =
    Map<String, PokrovRuAppCatalogEntry>.unmodifiable(
  <String, PokrovRuAppCatalogEntry>{
    for (final entry in pokrovRuAppCatalog) entry.packageId: entry,
  },
);
final Map<String, int> _pokrovRuAppCatalogOrder = <String, int>{
  for (final (index, entry) in pokrovRuAppCatalog.indexed)
    entry.packageId: index,
};

PokrovRuAppCatalogEntry? pokrovRuAppCatalogEntry(String packageId) =>
    _pokrovRuAppCatalogById[packageId.trim().toLowerCase()];

List<String> pokrovInstalledRuAppIds(Iterable<String> installedPackageIds) {
  final matches = installedPackageIds
      .map((id) => id.trim().toLowerCase())
      .where(_pokrovRuAppCatalogById.containsKey)
      .toSet()
      .toList(growable: false)
    ..sort(
      (left, right) => (_pokrovRuAppCatalogOrder[left] ?? 1 << 20)
          .compareTo(_pokrovRuAppCatalogOrder[right] ?? 1 << 20),
    );
  return List<String>.unmodifiable(matches);
}

String pokrovRuAppCategoryLabel(PokrovRuAppCategory category) =>
    switch (category) {
      PokrovRuAppCategory.yandex => 'Яндекс',
      PokrovRuAppCategory.social => 'Общение',
      PokrovRuAppCategory.government => 'Госсервисы',
      PokrovRuAppCategory.shopping => 'Покупки',
      PokrovRuAppCategory.finance => 'Финансы',
    };
