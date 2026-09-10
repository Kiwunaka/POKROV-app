# Windows: native support delivery и фон диагностики — 2026-09-10

Статус: `PASS_BOUNDED`. V01/V04 остаются active/I4; все требования приватности
и release acceptance этим срезом не закрыты.

## Точная сборка и обновление

- Первый пакет: client `f318265bbac942222cd770baac03b51797113433` (PR102,
  merge `e547016`), Core `c7a11f7d2fd974726095ad7aa0619c055273dd15`.
  Setup SHA-256 `5527e8a78076fad7bd7cc55bb9ac2c0796bfd2654a032f0d7e853dd9c004ff1a`.
- При работе обнаружен чёрный фон отдельного экрана диагностики. Тёмные
  заголовки и действия были почти не видны. Причина: прозрачный Scaffold
  основной оболочки наследовался новым route без подложки. Исправление
  задаёт этому Scaffold существующий `theme.canvasColor`.
- [PR103](https://github.com/Kiwunaka/POKROV-app/pull/103): tested `e73dcb9`,
  signed source `2edfbdebb3362cba1a71881545f458bc841e3b0e`, merge
  `c17936960dd3c77649d5eda5fe06f0a7bba85db8`. Source/merge tree одинаковый,
  подписи Git-коммитов проверены. PR CI и merge CI PASS.
- Второй setup SHA-256
  `e26d231ba7f1975c0b8cdbb7b8b1c002635035e248d1f3286a95c0fa36a763df`,
  29 266 919 bytes. Из 304 файлов изменился только `data/app.so`.
- Оба пакета установлены обычным wizard в выделенной Windows 11 VM:
  304/304 hashes, сохранённые state/secure-store bytes, служба LocalSystem
  Running — PASS. Это локальные release-mode сборки с неизвестным
  Authenticode publisher; подписи Git не являются подписью установщика.
- На новой установленной сборке светлый canvas `#F5F7F6` и тёмный `#111715`
  подтверждены снимками и RGB readback одного участка. Заголовки, preview
  и действия читаются. Исходная системная тема восстановлена.

## Native → HTTPS → worker → admin

На первом пакете обычным UI пройден путь «Профиль → Сведения для поддержки →
Создать обращение с пакетом». До действия показан summary preview: три файла,
1477 plaintext bytes, категории сборка/сеть/очистка. Это явное действие
передачи показанного summary; отдельный extended-consent здесь не проверялся.

Создано собственное тестовое обращение №51. Worker принял зашифрованные
2461 bytes, SHA-256
`f2bcc4d5bb352e7c5a4f1926b30bad4a5bb08d2932ab75c50d9f0a024d7e5d57`,
статус `validated`, профиль `summary`. В локальном outbox после подтверждения
нет файлов. Этот readback доказывает очистку после передачи, но не наблюдение
содержимого outbox до подтверждения. App event `app.support.bundle.finished`
имеет `succeeded`, точный source `f318265` и build `4053`.

Реальные HTTPS admin read routes находят обращение по номеру и diagnostic code.
В карточке: Windows, app version `1.2.0+4053`, manifest build ID
`pokrov-local-client`, proof `failed` при отключённом VPN. Architecture, last
phase/error и attempt link отсутствуют: они не подменены догадками. Known-issue
lookup — `NOT_APPLICABLE_NO_OBSERVED_ERROR_CODE`.

Каждый серверный read/cleanup ограничен конкретной VM: SHA-256 install ID,
единственный app user, account ownership, номер и время создания обращения.
Временная admin fixture session отозвана; прежние sessions не изменены.
External OIDC/step-up этим срезом не проверялись. Обращение закрыто прямым
cleanup собственного fixture; это не проверка operator command. Сообщения,
шифротекст и штатный retention clock сохранены, внешних сообщений не отправлено.

## Проверки и границы

- `flutter.bat test test/client_diagnostics_test.dart`: 10 PASS, включая
  существующий widget test с прозрачной темой, воспроизводящей дефект.
- `flutter.bat analyze --no-pub` в app_shell: PASS.
- `scripts/validate-seed.ps1 -PlatformRoot ...VPN-consolidated-plan-start
  -CoreRoot E:/r12core-implementation`, `test/docs-contract.ps1`: PASS.
- Две Windows build команды и точные package/installed readbacks: PASS.
- PR CI и merge CI PASS. Финальные документационные проверки и их логи
  привязаны к receipt.

`current-origin` — управляемая Windows 11 VM; `brain-origin` — обработка и
admin HTTPS на backend `25c6f7a`. RU-origin и physical Android не выполнялись;
телефон не использовался. Backend deploy и public binary release не выполнялись.

Полный V01 planted credentials/config/URL/IP/path/PII через все native/Core/
app/bundle/admin sinks остаётся открытым. Новый пакет не наследует полного
fault/connection acceptance прежнего `6816aab`: здесь проверены обновление,
запуск и темы; summary delivery относится к первому f318265. Повторной матрицы V03 нет. Полные Win10,
подпись/канал выдачи и другие зависимости остаются открытыми.

VM завершена через ACPI, её NIC отключён (`none`), хостовая сеть не менялась.
Оба установщика и manifest оставлены для отката. Секреты, raw journals,
профили и расшифрованные пакеты в evidence не копировались.

[Receipt](receipt.json).

Финальные client seed/docs contract, 33 platform tests, context audit,
712 local file links и diff check PASS. Команды и hash logs в receipt.
