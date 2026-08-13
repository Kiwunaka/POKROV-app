# POKROV 1.0.4 beta.1

Прямой outside-store beta-релиз для Android и Windows.

## Что скачивать

- `pokrov-android-arm64-v8a.apk` — основной APK для почти всех современных телефонов.
- `pokrov-android-armeabi-v7a.apk` — старые 32-битные Android-устройства.
- `pokrov-android-x86_64.apk` — LDPlayer и другие x86_64-эмуляторы.
- `pokrov-android-universal.apk` — большой запасной APK, если ABI неизвестен.
- `pokrov-windows-setup-x64.exe` — обычная установка Windows.
- `pokrov-windows-portable-x64.zip` — portable-вариант Windows.

Все Android APK подписаны боевым сертификатом POKROV с SHA-256
`0A0602A7DF5D96A0B427909D004F3DDF26DEF86587634BF16694DA8D654B2500`.
Windows beta пока не подписана доверенным Windows-сертификатом и может показать
SmartScreen/«неизвестный издатель».

## Главное в релизе

- крупная центрированная кнопка и более ясные состояния подключения;
- честные флаги, ping/load, ручное обновление и безопасный выбор вариантов локации;
- исправленная Quick Settings плитка, системное уведомление и фоновые сетевые события;
- WARP и маршруты приложений не маскируют несовместимые или неподтверждённые состояния;
- нативная AI-поддержка сначала даёт конкретные шаги, умеет приложить диагностику и не отправляет к человеку без причины;
- компактнее тарифы, checkout, mobile site/help/cabinet при сохранении приветственного полного месяца за 99 ₽;
- цены после welcome: 239 / 669 / 1199 / 1699 / 1999 ₽ за 1 / 3 / 6 / 9 / 12 месяцев.

## Проверка

ARM64-кандидат байт-в-байт совпал с установленным APK на Huawei Android 12.
На exact-final хеше прошли экран вариантов, live AI, обычный tunnel, три
дополнительных stop/start цикла, уведомление и disconnect action. WARP,
раздельный маршрут Chrome/Яндекс и Wi-Fi→LTE→Wi-Fi прошли на непосредственно
предшествующем production-signed `1.0.4+13` с тем же runtime-кодом; из-за
финальной UI-пересборки это supporting evidence, а не exact-final WARP claim.

Windows setup и portable собраны с POKROV Core 1.0.3. Exact EXE запустился,
оставался responsive и корректно скрывался в трей при закрытии окна.

Проверяйте скачанные файлы по `SHA256SUMS.txt`.
