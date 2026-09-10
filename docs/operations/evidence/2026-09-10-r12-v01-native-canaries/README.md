# V01 — native Windows canaries, 2026-09-10

Document class: EXECUTION_EVIDENCE. `PASS_BOUNDED_WINDOWS_NATIVE_SUMMARY_CANARIES`.
V01/V04 остаются active/I4: это Windows 11 summary, без extended/crash и Android.

## Точный установленный кандидат и ввод

Установленный client `2edfbdebb3362cba1a71881545f458bc841e3b0e`, Core
`c7a11f7d2fd974726095ad7aa0619c055273dd15`; до и после совпали все 304 файла.
Backend `25c6f7a13a04ee41fa6a86b84fbf90e045580a2f`. Новый продуктовый код,
сборка, deploy или public release в этом срезе не выполнялись.

Лабораторный C++ helper собран с service-client кодом точного установленного
кандидата. Через настоящий защищённый IPC и StageProfile переданы шесть
синтетических credentials/config/URL/IP/path/PII markers. Каждый помещён в
неизвестный outbound type: JSON проходит native validation, затем реальный
Core отклоняет профиль до создания outbound. Настоящих секретов во вводе нет.

Шесть запусков: `stage_accepted`, `core_failed_closed`, закрытая ошибка
`core_start_failed`, фаза `config_staged`, без запущенного туннеля и без маркера
в IPC response. Вызовы заняли 48–78 мс. Реальные Core callback подтверждены
в текущем и ротированном service журнале: 26 событий / 6 generations /
6 failures, коды CORE-003 (5) и CORE-005 (1); native start failures — 6.
Первая сводка только текущего файла пропускала события ротации; она сохранена
локально как неполный harness result, итоговая проверка использует оба файла.

## Журналы, preview, upload и доступ

До/после и после отправки просканированы шесть service/app diagnostic sinks,
включая текущий/предыдущий service log, stderr и app operational JSONL.
Совпадений маркеров — 0. В evidence попали только размеры, SHA-256, счётчики
и allowlisted timeline с revision/build; исходные журналы не экспортировались.
Это доказательство перечисленных sinks и выбранного failure path.

Из настоящего UI открыт preview: summary, три файла, 1470 bytes, категории
сборка/сеть/очистка, 0 удалённых полей. Явная кнопка создания обращения после
preview сформировала собственный case52. HTTPS upload/worker: `validated`,
2451 encrypted bytes, SHA-256
`a4e7d6897198a9d9419d351590c423c9b28221a53cb84d8178e9d88cfb3a98ad`.
Локальный outbox после ACK — 0 файлов / 0 bytes.

Реальные admin HTTPS lookups по case/diagnostic ID находят собственный пакет.
Без step-up доступ отклонён; controlled fixture step-up разрешил один download
точного ciphertext, `Cache-Control: no-store`; replay отклонён. Сохранены два
audit действия `grant_issued`/`downloaded`. На Brain worker key использован
в памяти для проверки скачанного пакета и трёх decoded files: маркеров нет.
Private key и plaintext не передавались на локальную машину или в evidence.
Summary содержит build/identity, network/summary и redaction/report; extended
events и crash data в этот пакет не входят. Поэтому очистка extended/crash
этим результатом не доказана. Architecture/last phase/error/attempt в admin
остаются NULL; это открытая граница V04, не успешная проверка этих полей.

Собственный case52 закрыт как cleanup изолированной fixture; ciphertext,
сообщения и audit сохранены. Временная операторская сессия отозвана,
прежние сессии не менялись. Retention/600-second expiry повторно не запускались:
их предыдущие доказательства остаются в отдельном runtime receipt.

## Восстановление лаборатории

Из-за нехватки E: официальной командой VirtualBox `movevm` перенесена только
тестовая VM в `C:/r12-v01-vm-20260910/POKROV-r12-managed-20260908`.
Четыре VDI сохранили размеры/SHA-256, прежние три snapshots сохранены.
Дополнительно сохранены snapshots до canaries и после их отправки.
Начальный move без существующего destination завершился ошибкой; повтор после
создания целевого каталога прошёл. Исходные failed logs сохранены локально.

Через обычный UI выполнены подключение и отключение: Core/DNS/egress PASS;
исходные route/DNS digests восстановлены, активных TUN — 0, 304 hashes PASS.
Приложение заново подготовило текущий рабочий профиль: JSON корректен,
outbounds есть, canaries отсутствуют. Его bytes отличаются от старого профиля;
точное побайтное восстановление профиля не заявляется. App-first state прежний,
обновлённый secure store сохранён; старый snapshot поверх свежей сессии не
восстанавливался. Лабораторный EXE удалён по точному SHA-256, файлы пакета
не удалялись. VM штатно выключена, NIC none; host network не менялась.

## Проверки и оставшаяся граница

`cmake` configure/build helper, шесть `r12_v01_probe.exe 0..5`, sink scans,
native-case readback/admin scan и recovery verification — PASS в указанном scope.
Лабораторные runners и первоначальные неудачные команды UI/доступа сохранены
в `C:/r12-v01-native-20260910/`; receipt связывает их SHA-256 с captures.
Продуктовых изменений нет, повтор Flutter/API/browser suite не выполнялся.
`scripts/validate-seed.ps1 -PlatformRoot C:/Users/kiwun/Documents/ai/VPN-consolidated-plan-start -CoreRoot C:/r12-core-c7-proof-20260910`
и `test/docs-contract.ps1` — PASS. Первоначальная seed проверка с новым
Core checkout e4ad514 корректно отказала: он не совпадал с bound c7 artifacts.
Использован отдельный чистый c7 checkout; новые исходники Core не откатывались.
Platform: `python -B -m pytest -p no:cacheprovider tests/test_agent_docs_contract.py tests/test_agent_context_packet_audit.py -q`
— 33 PASS; `agent_context_packet_audit.py --platform-context-root .`,
`validate_package.py` (716 local links) и `git diff --check` — PASS.
`git diff --name-only -- artifacts/releases` пуст. Нового CI для docs-only
среза не было.


Известное встречное доказательство: отдельный прямой Core FFI subprocess на
том же packaged c7 DLL в 13:18 UTC показал canaries в return value и stderr.
Его `FAIL_PRIVACY` сохранён в receipt этого среза. Защищённый Windows service
здесь возвращает закрытый код, но это не исправляет прямой FFI путь.
Исправление Core PR10/source c8b0461 подготовлено отдельно: на момент записи
PR открыт, release-contract CI FAIL, остальные четыре jobs PASS; новая DLL
не установлена. Полная privacy acceptance требует завершить эту поставку
и проверить исправленный кандидат, помимо extended/crash/Android.

PSM1 signer на Brain ещё не настроен; source fix PR104 не установлен в этом
кандидате. Native extended/crash, Android, остальные sinks/пути и зависимость
N03 остаются открытыми. Эта проверка не закрывает полный V01/V04 или release.

[Capture receipt](receipt.json).
