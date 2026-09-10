# Windows PSM1 — нативная проверка 2026-09-10

Document class: EVIDENCE. Итог: PASS_BOUNDED_WITH_OPEN_FINDINGS.
Клиент установлен в owned Win11 VM; серверные проверки — brain-origin.
Это не Android, crash-profile, RU-origin или общая release acceptance.

## Исправления и точный пакет

PR106 устранил отказ preview при частичной политике: необязательные категории,
не разрешённые политикой, больше не добавляются. Source `56654ce9c4d483f43e91b25577bcf80fc31db4e1`,
merge `196fac4c9a04aeb30fd79fee0d83a9af4843391c`, оба CI PASS.
Нативный upload этого пакета выявил следующий дефект: пустой events JSONL
содержал только LF. Case53 отвергнут сервером с `jsonl_invalid`; исходный отказ
и ciphertext сохранены, серверная валидация не ослаблена.

PR107 исключает пустые events/crash файлы и обновляет открытый экран при
изменении расхода/окончании режима. Source
`45d495956ee8f8e557d4ea3bd257685e7ed89ee4`, merge
`f19f5027d386e5c2f7ae0ab7c4bda98d764d36b0`, tree
`1bf4ba6510693eb7a99dc002f239b96eacd52525`.
PR CI34511566796 и merge CI34512925716 PASS; подписи и дерево сверены.
Core неизменён: `c8b0461c1975ef96e32024774300a5829b9fdc43`.

Windows setup 29220031 bytes, SHA-256
`bb9a3c1f4de2b2f78aefa255268ac04981e58bb806bc472d061dc3fb884a863d`.
В сравнении с 566 изменён только `data/app.so`, остальные 303 файла прежние.
Обычный мастер установки: 304 hashes PASS, state/secure store сохранены при
установке. Финальный runtime readback также подтвердил 304 hashes.
Публичный release, tag, trusted signing и Android build не выполнялись.

## Нативные результаты

- Настоящий код PSM1 активирован с согласием в установленном UI. При отсутствии
  событий preview имеет четыре файла; case54 validated, 2850 ciphertext bytes.
  После обычного подключения/отключения preview включает events: case55
  validated, 8490 ciphertext bytes, пять файлов, 5999 plaintext bytes.
- Для обоих cases реальные HTTPS admin lookup по case/diagnostic ID дали один
  собственный результат. Download без step-up запрещён; после контролируемого
  fixture step-up скачан точный ciphertext, no-store; повтор grant запрещён.
  По две audit rows сохранены, временные сессии отозваны. В памяти worker
  проверены четыре/пять файлов: ноль шести canary markers, plaintext не экспортирован.
  External OIDC этим fixture не перепроверялся.
- На неизменном Core c8 до обновления app.so шесть native failures прошли через
  настоящий IPC; шесть sinks содержат ноль markers. Временный probe удалён
  по точному hash. Это отдельное доказательство, не повторный injection на 45.
- Save As: отмена не создала файл; экспорт создал только зашифрованный
  `.pokrov-support`, 2850 bytes. Его SHA-256 `9cb3ed62e9422b30e09b60f9e1db38f5884d2c1638c512f9e139777a7b3db9ec`.
  Payload/manifest совпадают с outbox, ciphertext отличается из-за nonce.
  Upload и export одного diagnostic ID расходуют один лимит: 1769 bytes / 1.
- Экран оставался открыт до настоящего срока policy3: режим выключился,
  session удалена, preview стал summary. Часы/TTL не изменялись.
- Для policy5 два разных отчёта дали 5999 + 9474 = 15473 bytes и 2/2.
  Третий изменённый отчёт отклонён до срока; расход прежний, новый case не создан.
  Сохранённая очередь второго отчёта остаётся открытым дефектом ниже.
- Policy6 выключена вручную до срока; повтор того же кода через UI запрещён.
  Server readback: первый redeem 200, повтор 409; локальный nonce ledger сохранён.
  Неподходящий signing key ранее отвергнут самим установленным клиентом.

## Открытые дефекты и границы

1. Первый upload case54 несколько раз завершился сетевой ошибкой. Ciphertext
   сохранился; после перезапуска приложения отправлен тот же ID/ciphertext,
   validated без дубля. Причина первоначального transport failure не установлена.
2. Case56 получил все 13123 bytes, но остался `uploading`: completion не подтверждён.
   В локальном outbox один ciphertext. После изменения событий/истечения режима
   экран готовит другой ID, а deliver загружает очередь только по текущему ID.
   Отдельного выбора старого отчёта нет. Требование доступности старых ID для retry
   пока не выполнено для этого нативного пути. Ручной completion не выполнялся.
3. Достижение лимита показывает общую ошибку передачи с предложением повторить.
   Ограничение работает, сообщение вводит в заблуждение. Исправление ещё не поставлено.

Own cases53–56, audit rows и ciphertext сохранены; pending56 оставлен для
повторного нативного proof после исправления. Не заявляется успешная повторная
отправка 56, crash/Android или полная V01/V03/V04 acceptance.

## Восстановление и проверки

Route/DNS digests совпали с исходными, активных TUN нет. User state прежний;
secure store изменился при нормальных сетевых операциях, поэтому его финальная
побайтная неизменность не заявляется. Root-only service profile не читался
непривилегированным helper. VM штатно выключена, NIC none; все восемь прежних
snapshots и новый `02d29785-db85-41ca-8feb-f8cc0a883a9c` сохранены.
Шифрованный экспорт и pending outbox остаются внутри VM. Телефон не затрагивался.

Для PR107: 7 collectors + 15 bundle tests, 210 shell tests и три analyze PASS;
исходные RED для пустого JSONL и устаревшего экрана сохранены. Client seed/docs
и build-windows PASS; внутренние повторные tests/analyze/seed в build явно
пропущены после проверки тождественности исходников. Для PR106 — 13 focused
checks/analyze/seed/docs и PR/merge CI PASS. Полные локальные логи и scripts:
`C:/r12-psm-runtime-20260910/`; hash inventory сохранён рядом.

[Проверенные captures](receipt.json). Platform provisioning/enable/rollback
описан в платформенном EXECUTION-PSM-NATIVE-2026-09-10.md и отдельном receipt.

Финальные client `scripts/validate-seed.ps1` с exact Core/platform roots и
`test/docs-contract.ps1` — PASS; platform 33 docs tests, context audit,
package validator (83 R12 IDs / 729 links), оба `git diff --check` — PASS.
Client `artifacts/releases` delta пуст. Новых product tests/build после
документации не запускалось. Логи связаны hashes в receipt; PowerShell host
stream seed/docs показал успех в command completion, но не попал в redirection.
