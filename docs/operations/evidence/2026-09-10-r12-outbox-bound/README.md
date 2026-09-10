# R12-V03 — ограничение зашифрованной очереди диагностики

Document class: EXECUTION_EVIDENCE. Срез: 2026-09-10. Требование —
R12-V03: bounded spool без блокировки VPN и без raw payload.

## Дефект и изменение

`PokrovFileSupportBundleOutbox.save` принимал новые diagnostic IDs без общего
лимита. Проверка размера отдельного envelope выполнялась только при чтении,
уже после записи. Параллельные вызовы могли независимо занимать остаток места.

Теперь новые пакеты принимаются в пределах **24 МиБ** с учётом сохранённых
файлов и незавершённых временных записей. Это выбранный в рамках полномочий
владельца предел отдельной support-очереди, равный существующему меньшему
бюджету диагностических журналов; суммарный бюджет обоих хранилищ не выдаётся
за 24 МиБ. Размер одного envelope ограничен прежними 2,5 МиБ до записи.
Существующий механизм сериализации app-state writers используется для всех
service instances в app isolate; новых зависимостей и очистки истории нет.

При заполнении новый ID получает `outbox_full`, а существующий ID возвращает
свои исходные зашифрованные bytes для повторной отправки. Удаление подтверждённо
отправленного объекта освобождает место. Уже превышающая лимит очередь
сохраняется; новые поступления в неё запрещены. Незавершённый файл своего ID
заменяется прежним атомарным save-путём; чужие временные записи не удаляются.

## Проверка

Один новый тест использует реальные temporary files и реальные encrypted
summary bundles с разными diagnostic IDs. Остаток места занят синтетическим
незавершённым файлом. На исходном `1824683` два service instances приняли оба
пакета и проверка упала (`red-v2.log`: Too many elements). После исправления:

- принят один пакет, второй отклонён с `outbox_full`;
- общий логический размер файлов не превышает 24 МиБ;
- сохранённый пакет возвращается побайтно тем же при повторе;
- незавершённый файл остаётся на месте с прежним размером;
- удаление подтверждённого объекта разрешает приём второго пакета.

Первая версия test fixture не содержала system summary для standard profile
и упала до проверки лимита. Fixture исправлена на два summary-пакета; этот
harness failure сохранён отдельно и не считается дефектом продукта.

`flutter analyze` — PASS. В app_shell
`flutter test --no-pub test/support_bundle_delivery_test.dart test/client_observability_test.dart`
— 11 PASS. В support_bundle `flutter test --no-pub` — 15 PASS.
Client seed с явными platform/Core roots и docs contract — PASS.
Команды и SHA-256 логов находятся в local-verification.json.

## Поставка и границы

Implementation `f87b956`; signed source `f318265bbac942222cd770baac03b51797113433`.
Шесть package trees подписанного source побайтно совпадают с проверенными.
[PR #102](https://github.com/Kiwunaka/POKROV-app/pull/102) merged `e54701616a1e5f77967cb451ca56fc2068d6dabd`.
PR CI и merge CI PASS. Trees совпадают, обе подписи проверены.

Это source-level проверка на Windows filesystem. Новый installer не собирался
и не устанавливался; Android/Windows package acceptance для этой правки ещё
не выполнен. Предыдущие disk-full и VPN fault evidence относятся к `6816aaba`
и не заменяют доказательство для новой сборки. Телефон не использовался,
backend не менялся, публичные binaries не публиковались. V03 остаётся active/I4,
зависимость V01 и полная приёмка общего релиза не закрыты.

[Receipt](receipt.json).

Финальные client seed/docs contract, 33 platform tests, context audit,
709 local file links и diff check PASS. Команды и hash logs в receipt.
