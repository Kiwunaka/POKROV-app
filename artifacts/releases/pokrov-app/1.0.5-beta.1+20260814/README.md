# POKROV 1.0.5 beta.1

Прямой outside-store beta-релиз для Android и Windows.

## Что скачивать

- `pokrov-android-arm64-v8a.apk` — основной APK для большинства современных телефонов.
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

- прямой platform-aware download с сайта и одноразовый безопасный acquisition-handoff в клиент;
- явный выбор «Обычный / Белые списки» для доступных локаций;
- обновлённые UX локаций, маршрутов, плитки, уведомлений, поддержки и checkout;
- цены: первый полный месяц за 99 ₽ один раз, затем 239 ₽; 3/6/9/12 месяцев — 669/1199/1699/1999 ₽;
- нативная AI-поддержка с конкретными действиями и честной эскалацией к человеку;
- бонусы явно недоступны на триале и открываются сразу после первой реальной оплаты.

## Проверка

Сборки прошли Flutter, Android Gradle, Windows bundle, web/admin и backend release gates.
Физические Huawei endurance/WARP/Wi-Fi↔LTE и Windows TUN/DNS остаются
честно отмеченными manual gates и не заявляются как exact-final PASS.

Проверяйте скачанные файлы по `SHA256SUMS.txt`.
