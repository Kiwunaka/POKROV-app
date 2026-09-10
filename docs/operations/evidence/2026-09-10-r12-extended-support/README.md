# V01 — исправление расширенного preview, 2026-09-10

Document class: EXECUTION_EVIDENCE. Статус: `PASS_SOURCE / NATIVE_PSM1_NOT_RUN`.
Полный V01 и его зависимость N03 остаются открытыми.

## Подтверждённый сбой и исправление

В реальном `PokrovDiagnosticsPresenter` активная подписанная extended policy
переключала сборщик на профиль, которому нужна системная сводка. Приложение
никогда её не передавало. Существующий тест consent/usage/replay переведён
с вручную собранного DiagnosticSnapshot на настоящий presenter: до исправления
он завершился `The selected diagnostic profile requires a system summary`.
`repro.log` сохранён как FAIL, не как успешная проверка.

Теперь shell передаёт OS family, только числовую версию ОС (unknown, если
формат не распознан), фактический process ABI и locale приложения.
Free-form строка ОС, Android build fingerprint и произвольные журналы не
передаются. Расширенный preview получает существующий ограниченный список
очищенных connection breadcrumbs: закрытая фаза, время, outcome и код каталога.
Event ID и произвольные поля в пакет не входят. Обычный summary сохраняет
прежние build/network/redaction categories. Consent, signature verification,
TTL, cumulative cap, encryption и server protocols не менялись.

Пять файлов: app-shell composition, presenter, shell, существующий support-mode
тест и canonical `docs/product/client-product-contract.md` клиента.
Tested integration `3f3f4c844077a20631789fc57ee86a38fec38125`;
signed source `cbb00f5fd8e4f1ab7ea9a00b57248e18be41dcbc`, tree
`7f5e90a625689b7122a8869bef67886261b8e5c2`.
[PR104](https://github.com/Kiwunaka/POKROV-app/pull/104): PR CI и merge CI PASS, merge `f33d79a5a8a37775eef38e2ae9319cac306e327c`.
Сравнение source trees шести затронутых пакетов с проверенным worktree PASS;
Git signature VALID. Это не подпись установщика.

## Проверки

- `flutter.bat test test/support_mode_controller_test.dart test/client_diagnostics_test.dart --reporter expanded`
  из `packages/app_shell`: 13 PASS. Активный extended presenter теперь строит
  preview с system и непустыми events; существующие consent/usage/replay/expiry
  и обычные diagnostics checks проходят. Первый исправленный harness имел
  неверное имя getter `sizeBytes`; этот compile FAIL тоже сохранён.
- `flutter.bat analyze --no-pub` в app_shell: PASS, без замечаний.
- `scripts/validate-seed.ps1 -PlatformRoot C:/Users/kiwun/Documents/ai/VPN-consolidated-plan-start -CoreRoot E:/r12core-implementation`
  и `test/docs-contract.ps1`: PASS.
- `git diff --check` и отсутствие delta `artifacts/releases/**`: PASS.
- Оба CI и финальные client seed/docs, 33 platform tests, context audit и
  714 local links PASS; логи и хеши привязаны к receipt.

## Точная граница runtime

Read-only Brain-origin 13:08:09 UTC: API active, backend
`25c6f7a13a04ee41fa6a86b84fbf90e045580a2f`. В effective startup environment
и dotenv отсутствуют ID/private key для подписи PSM1 и secret кодов активации.
Отчёт содержит только presence booleans; значения секретов не читались в вывод.
Обычный upload/worker, включённый ранее, не включает PSM1 issuance.

Канон deployment-and-access требует соответствия серверной Ed25519 подписи
pin точного клиента и отдельных RBAC/audit/rotation/rollback подтверждений.
Hosted custody/key-set signing не передаёт private key на сервер.
Поэтому native PSM1 redeem→consent→extended upload здесь НЕ ПРОВЕРЕН.
Новый binary не строился и не устанавливался. VM остаётся на предыдущем
`2edfbde`, выключена с NIC none; телефон не использовался. Новый backend deploy,
секреты, issuance, обращения и расходы не выполнялись.

Полный planted credentials/config/URL/IP/path/PII путь через native/Core/app/
bundle/upload/admin, crash data, native extended acceptance и N03 остаются
открытыми. Этот source fix не закрывает V01/V04 и не наследует полный device
acceptance предыдущих сборок.

При создании source worktree обнаружена нехватка места на E:. Git отменил
неудавшийся checkout; повтор выполнен в C:/r12ext с исключёнными из materialized
checkout историческими artifacts/releases и docs/operations/evidence.
Tracked source tree не менялся; старые сборки и evidence сохранены.

[Receipt](receipt.json).
