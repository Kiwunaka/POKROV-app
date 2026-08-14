# POKROV 1.0.6 stable

Прямой stable-релиз Android и Windows без магазина:
<https://github.com/Kiwunaka/pokrov/releases/tag/v1.0.6>.

## Что скачивать

- `pokrov-android-arm64-v8a.apk` — большинство современных телефонов.
- `pokrov-android-armeabi-v7a.apk` — старые 32-битные Android-устройства.
- `pokrov-android-x86_64.apk` — LDPlayer и другие x86_64-эмуляторы.
- `pokrov-android-universal.apk` — большой fallback, если ABI неизвестен.
- `pokrov-windows-setup-x64.exe` — обычная установка Windows.
- `pokrov-windows-portable-x64.zip` — portable-вариант Windows.

Android APK подписаны production-сертификатом POKROV с SHA-256
`0A0602A7DF5D96A0B427909D004F3DDF26DEF86587634BF16694DA8D654B2500`.
Windows-сборка распространяется напрямую без trusted publisher signature и
может показать SmartScreen/«неизвестный издатель».

Тяжёлые бинарные копии намеренно не дублируются в Git. Канонические файлы —
в GitHub release, локальный staging хранится на `E:`. Проверяйте загрузки по
`SHA256SUMS.txt`.
