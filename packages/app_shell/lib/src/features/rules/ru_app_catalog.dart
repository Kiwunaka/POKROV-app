enum PokrovRuAppCategory {
  yandex,
  social,
  government,
  shopping,
  finance,
  operator,
  transport,
  media,
  services,
}

class PokrovRuAppCatalogEntry {
  const PokrovRuAppCatalogEntry(this.packageId, this.label, this.category);

  final String packageId;
  final String label;
  final PokrovRuAppCategory category;
}

const pokrovRuAppCatalogVersion = '2026-11-24.2';

/// Exact package IDs for local classification and Android TUN bypass.
const pokrovRuAppCatalog = <PokrovRuAppCatalogEntry>[
  PokrovRuAppCatalogEntry(
      'com.yandex.browser', 'Яндекс Браузер', PokrovRuAppCategory.yandex),
  PokrovRuAppCatalogEntry(
      'ru.yandex.searchplugin', 'Яндекс Старт', PokrovRuAppCategory.yandex),
  PokrovRuAppCatalogEntry(
      'ru.yandex.yandexmaps', 'Яндекс Карты', PokrovRuAppCategory.yandex),
  PokrovRuAppCatalogEntry(
      'ru.yandex.yandexnavi', 'Яндекс Навигатор', PokrovRuAppCategory.yandex),
  PokrovRuAppCatalogEntry(
      'ru.yandex.metro', 'Яндекс Метро', PokrovRuAppCategory.yandex),
  PokrovRuAppCatalogEntry(
      'ru.yandex.rasp', 'Яндекс Электрички', PokrovRuAppCategory.yandex),
  PokrovRuAppCatalogEntry(
      'ru.yandex.taxi', 'Яндекс Go', PokrovRuAppCategory.yandex),
  PokrovRuAppCatalogEntry(
      'ru.yandex.uber', 'Uber Russia', PokrovRuAppCategory.yandex),
  PokrovRuAppCatalogEntry(
      'ru.yandex.travel', 'Яндекс Путешествия', PokrovRuAppCategory.yandex),
  PokrovRuAppCatalogEntry(
      'ru.yandex.music', 'Яндекс Музыка', PokrovRuAppCategory.yandex),
  PokrovRuAppCatalogEntry(
      'ru.yandex.disk', 'Яндекс Диск', PokrovRuAppCategory.yandex),
  PokrovRuAppCatalogEntry(
      'ru.yandex.mail', 'Яндекс Почта', PokrovRuAppCategory.yandex),
  PokrovRuAppCatalogEntry(
      'ru.yandex.translate', 'Яндекс Переводчик', PokrovRuAppCategory.yandex),
  PokrovRuAppCatalogEntry(
      'ru.yandex.weatherplugin', 'Яндекс Погода', PokrovRuAppCategory.yandex),
  PokrovRuAppCatalogEntry(
      'ru.beru.android', 'Яндекс Маркет', PokrovRuAppCategory.yandex),
  PokrovRuAppCatalogEntry(
      'ru.foodfox.client', 'Яндекс Еда', PokrovRuAppCategory.yandex),
  PokrovRuAppCatalogEntry(
      'com.yandex.bank', 'Яндекс Пэй', PokrovRuAppCategory.yandex),
  PokrovRuAppCatalogEntry(
      'com.yandex.iot', 'Дом с Алисой', PokrovRuAppCategory.yandex),
  PokrovRuAppCatalogEntry('com.yandex.mobile.realty', 'Яндекс Недвижимость',
      PokrovRuAppCategory.yandex),
  PokrovRuAppCatalogEntry('ru.auto.ara', 'Авто.ру', PokrovRuAppCategory.yandex),
  PokrovRuAppCatalogEntry(
      'ru.kinopoisk', 'Кинопоиск', PokrovRuAppCategory.yandex),
  PokrovRuAppCatalogEntry(
      'com.vkontakte.android', 'ВКонтакте', PokrovRuAppCategory.social),
  PokrovRuAppCatalogEntry(
      'ru.ok.android', 'Одноклассники', PokrovRuAppCategory.social),
  PokrovRuAppCatalogEntry(
      'ru.mail.mailapp', 'Почта Mail', PokrovRuAppCategory.social),
  PokrovRuAppCatalogEntry(
      'ru.mail.cloud', 'Облако Mail', PokrovRuAppCategory.social),
  PokrovRuAppCatalogEntry('ru.oneme.app', 'МАКС', PokrovRuAppCategory.social),
  PokrovRuAppCatalogEntry('ru.cmtt.dtf', 'DTF', PokrovRuAppCategory.social),
  PokrovRuAppCatalogEntry(
      'ru.rostel', 'Госуслуги', PokrovRuAppCategory.government),
  PokrovRuAppCatalogEntry(
      'ru.gosuslugi.goskey', 'Госключ', PokrovRuAppCategory.government),
  PokrovRuAppCatalogEntry(
      'ru.fns.lkfl', 'Налоги ФЛ', PokrovRuAppCategory.government),
  PokrovRuAppCatalogEntry(
      'ru.gnivc.lkip', 'Личный кабинет ИП', PokrovRuAppCategory.government),
  PokrovRuAppCatalogEntry(
      'ru.sigma.gisgkh', 'Госуслуги Дом', PokrovRuAppCategory.government),
  PokrovRuAppCatalogEntry(
      'ru.boloid.giszkh2', 'ГИС ЖКХ New', PokrovRuAppCategory.government),
  PokrovRuAppCatalogEntry('ru.spb.iac.ourspb', 'Наш Санкт-Петербург',
      PokrovRuAppCategory.government),
  PokrovRuAppCatalogEntry(
      'com.avito.android', 'Авито', PokrovRuAppCategory.shopping),
  PokrovRuAppCatalogEntry(
      'com.wildberries.ru', 'Wildberries', PokrovRuAppCategory.shopping),
  PokrovRuAppCatalogEntry(
      'ru.ozon.app.android', 'Ozon', PokrovRuAppCategory.shopping),
  PokrovRuAppCatalogEntry(
      'ru.aliexpress.buyer', 'AliExpress Россия', PokrovRuAppCategory.shopping),
  PokrovRuAppCatalogEntry(
      'ru.megamarket.marketplace', 'Мегамаркет', PokrovRuAppCategory.shopping),
  PokrovRuAppCatalogEntry(
      'ru.citilink', 'Ситилинк', PokrovRuAppCategory.shopping),
  PokrovRuAppCatalogEntry(
      'ru.mvm.eldo', 'Эльдорадо', PokrovRuAppCategory.shopping),
  PokrovRuAppCatalogEntry(
      'ru.onlinetrade.app', 'Онлайнтрейд', PokrovRuAppCategory.shopping),
  PokrovRuAppCatalogEntry(
      'ru.leroymerlin.mobile', 'Лемана ПРО', PokrovRuAppCategory.shopping),
  PokrovRuAppCatalogEntry(
      'ru.sunlight.sunlight', 'SUNLIGHT', PokrovRuAppCategory.shopping),
  PokrovRuAppCatalogEntry(
      'ru.sbcs.store', 'Самокат', PokrovRuAppCategory.shopping),
  PokrovRuAppCatalogEntry(
      'ru.vkusvill', 'ВкусВилл', PokrovRuAppCategory.shopping),
  PokrovRuAppCatalogEntry(
      'ru.lenta.lentochka', 'Лента Онлайн', PokrovRuAppCategory.shopping),
  PokrovRuAppCatalogEntry(
      'com.icemobile.lenta.prod', 'ЛЕНТА', PokrovRuAppCategory.shopping),
  PokrovRuAppCatalogEntry(
      'ru.perekrestok.app', 'Перекрёсток', PokrovRuAppCategory.shopping),
  PokrovRuAppCatalogEntry(
      'ru.myspar', 'Мой SPAR', PokrovRuAppCategory.shopping),
  PokrovRuAppCatalogEntry(
      'ru.dodopizza.app', 'Додо Пицца', PokrovRuAppCategory.shopping),
  PokrovRuAppCatalogEntry(
      'ru.devcluster.mafia', 'Pizza Mafia', PokrovRuAppCategory.shopping),
  PokrovRuAppCatalogEntry(
      'ru.devcluster.sushiwok', 'Sushi Wok', PokrovRuAppCategory.shopping),
  PokrovRuAppCatalogEntry(
      'ru.tokyocity.tokyocity', 'ТОКИО-CITY', PokrovRuAppCategory.shopping),
  PokrovRuAppCatalogEntry(
      'ru.gdeshaverma.android', 'Где Шаверма', PokrovRuAppCategory.shopping),
  PokrovRuAppCatalogEntry(
      'com.platfomni.vita', 'Аптека Вита', PokrovRuAppCategory.shopping),
  PokrovRuAppCatalogEntry(
      'ru.sberbankmobile', 'СберБанк Онлайн', PokrovRuAppCategory.finance),
  PokrovRuAppCatalogEntry(
      'com.idamob.tinkoff.android', 'Т-Банк', PokrovRuAppCategory.finance),
  PokrovRuAppCatalogEntry(
      'ru.tinkoff.investing', 'Т-Инвестиции', PokrovRuAppCategory.finance),
  PokrovRuAppCatalogEntry('ru.vtb24.mobilebanking.android', 'ВТБ Онлайн',
      PokrovRuAppCategory.finance),
  PokrovRuAppCatalogEntry(
      'ru.alfabank.mobile.android', 'Альфа-Банк', PokrovRuAppCategory.finance),
  PokrovRuAppCatalogEntry(
      'ru.alfabank.oavdo.amc', 'Альфа-Бизнес', PokrovRuAppCategory.finance),
  PokrovRuAppCatalogEntry('ru.gazprombank.android.mobilebank.app',
      'Газпромбанк', PokrovRuAppCategory.finance),
  PokrovRuAppCatalogEntry(
      'ru.nspk.mirpay', 'Mir Pay', PokrovRuAppCategory.finance),
  PokrovRuAppCatalogEntry('ru.sovcomcard.halva.v1', 'Халва — Совкомбанк',
      PokrovRuAppCategory.finance),
  PokrovRuAppCatalogEntry(
      'ru.tsk.ftc.bender.qpay', 'KoronaPay', PokrovRuAppCategory.finance),
  PokrovRuAppCatalogEntry(
      'ru.cardsmobile.mw3', 'Кошелёк', PokrovRuAppCategory.finance),
  PokrovRuAppCatalogEntry(
      'ru.mts.mymts', 'Мой МТС', PokrovRuAppCategory.operator),
  PokrovRuAppCatalogEntry(
      'ru.megafon.mlk', 'МегаФон', PokrovRuAppCategory.operator),
  PokrovRuAppCatalogEntry(
      'ru.beeline.services', 'билайн', PokrovRuAppCategory.operator),
  PokrovRuAppCatalogEntry(
      'ru.tele2.mytele2', 't2', PokrovRuAppCategory.operator),
  PokrovRuAppCatalogEntry(
      'ru.dublgis.dgismobile', '2ГИС', PokrovRuAppCategory.transport),
  PokrovRuAppCatalogEntry(
      'ru.rzd.pass', 'РЖД Пассажирам', PokrovRuAppCategory.transport),
  PokrovRuAppCatalogEntry(
      'ru.tutu.trainrusapp', 'Туту ЖД', PokrovRuAppCategory.transport),
  PokrovRuAppCatalogEntry(
      'ru.aviasales', 'Авиасейлс', PokrovRuAppCategory.transport),
  PokrovRuAppCatalogEntry(
      'ru.ostrovok.android', 'Островок', PokrovRuAppCategory.transport),
  PokrovRuAppCatalogEntry(
      'com.citymobil', 'Ситимобил', PokrovRuAppCategory.transport),
  PokrovRuAppCatalogEntry(
      'com.punicapp.whoosh', 'Whoosh', PokrovRuAppCategory.transport),
  PokrovRuAppCatalogEntry(
      'ru.urentbike.app', 'Юрент', PokrovRuAppCategory.transport),
  PokrovRuAppCatalogEntry(
      'ru.berizaryad', 'Бери заряд', PokrovRuAppCategory.transport),
  PokrovRuAppCatalogEntry(
      'ru.farpost.dromfilter', 'Дром Авто', PokrovRuAppCategory.transport),
  PokrovRuAppCatalogEntry(
      'ru.drom.numbers', 'Номерограм', PokrovRuAppCategory.transport),
  PokrovRuAppCatalogEntry(
      'ru.drom.pdd.android.app', 'Дром ПДД', PokrovRuAppCategory.transport),
  PokrovRuAppCatalogEntry('org.reactivephone.pdd.lite', 'Экзамен ПДД',
      PokrovRuAppCategory.transport),
  PokrovRuAppCatalogEntry('com.nixesea.travelcardreader', 'Баланс проездного',
      PokrovRuAppCategory.transport),
  PokrovRuAppCatalogEntry(
      'com.vk.vkvideo', 'VK Видео', PokrovRuAppCategory.media),
  PokrovRuAppCatalogEntry(
      'ru.rt.video.app.mobile', 'Wink', PokrovRuAppCategory.media),
  PokrovRuAppCatalogEntry('ru.rutube.app', 'RUTUBE', PokrovRuAppCategory.media),
  PokrovRuAppCatalogEntry(
      'rtb.mobile.android', 'RUTUBE', PokrovRuAppCategory.media),
  PokrovRuAppCatalogEntry(
      'ru.rutube.studio', 'Студия RUTUBE', PokrovRuAppCategory.media),
  PokrovRuAppCatalogEntry(
      'ru.rtb.studio', 'Студия RUTUBE', PokrovRuAppCategory.media),
  PokrovRuAppCatalogEntry(
      'ru.vk.store', 'RuStore', PokrovRuAppCategory.services),
  PokrovRuAppCatalogEntry(
      'ru.rt.key', 'Ростелеком Ключ', PokrovRuAppCategory.services),
  PokrovRuAppCatalogEntry(
      'ru.domclick.mortgage', 'Домклик', PokrovRuAppCategory.services),
  PokrovRuAppCatalogEntry('ru.cian.main', 'Циан', PokrovRuAppCategory.services),
  PokrovRuAppCatalogEntry(
      'ru.showroom', 'Кабинет-жителя.рф', PokrovRuAppCategory.services),
  PokrovRuAppCatalogEntry(
      'com.fsgpay', 'Квартплата+', PokrovRuAppCategory.services),
  PokrovRuAppCatalogEntry(
      'ru.cryptopro.mydss11', 'КриптоПро myDSS', PokrovRuAppCategory.services),
  PokrovRuAppCatalogEntry(
      'ru.hh.android', 'hh.ru', PokrovRuAppCategory.services),
  PokrovRuAppCatalogEntry(
      'com.bitrix24.android', 'Битрикс24', PokrovRuAppCategory.services),
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
      PokrovRuAppCategory.operator => 'Связь',
      PokrovRuAppCategory.transport => 'Транспорт',
      PokrovRuAppCategory.media => 'Видео',
      PokrovRuAppCategory.services => 'Сервисы',
    };
