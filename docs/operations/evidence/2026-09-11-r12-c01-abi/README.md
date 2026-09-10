# R12-C01 — ABI and artifact consumer acceptance

Document class: EVIDENCE. 2026-09-11. C01 verified at I3 for its original
source/artifact/consumer DoD; this is not final device or release acceptance.
Client source `e18fa6073d310623fae003689af439fb11d4dc5e`, merge
`503979fd1f12f2586e33064386d7f3375425ad0a`; Core
`c8b0461c1975ef96e32024774300a5829b9fdc43`.

The prior C01 register entry referred only to the old HANDOFF. Its original DoD
requires the Android/Windows ABI/config/event/capability matrix, compile/link/
symbol checks and consumers on the pinned Core. It does not require ABI3 or a
new public release. The current evidence now covers those checks explicitly.

| Contract | Android | Windows |
| --- | --- | --- |
| Artifact/source | Exact pinned AAR, four ELF ABIs and generated libbox classes; both retained builds match | Exact pinned DLL/header/Cronet; both retained builds match |
| ABI/consumer | Generated Java libbox API, compiled by real direct/store Gradle test tasks in exact merge CI | Live DLL ABI marker 2, all 15 exports resolve; ordinary installed UI/service uses that DLL |
| Config | Existing materialized-profile host path compiled against AAR; current Core full-test evidence retained | Current consumer accepts materialized config and rejects a nonmaterialized profile; real pinned FFI rejects malformed config with CORE-005 |
| Events | Event ABI1 generated OperationalEvent/Handler and CommandServer classes; existing Kotlin fence tests in exact merge CI | Live descriptor event ABI1; retained real callback sequence initialize/start/failure matches the schema |
| Capability | Current AWG2/AWG3.1/HY2 contracts verified; this does not enable a gated transport | Exact live descriptor equals canonical descriptor: six capabilities and nine lifecycle phases |

## Checks executed for this acceptance

- `python C:/r12-c01-20260911/audit.py` — PASS. Eight consumer Git objects
  match the tested source, five artifacts match both builds, all recorded Core
  build-input hashes and old log hashes still match. Four ELF architecture
  headers and required generated classes match. Actual DLL descriptor/export
  readback, exact CI source trees and 304-file installed receipts match.
- From Core: `scripts/verify-abi-contract.ps1`,
  `scripts/verify-observability-contracts.ps1 -PlatformRoot C:/Users/kiwun/Documents/ai/VPN-consolidated-plan-start`,
  `scripts/verify-awg2-contract.ps1`, `scripts/verify-awg31-contract.ps1`,
  `scripts/verify-hy2-contract.ps1` — five PASS. The first shell invocation
  stopped after ABI because an unset LASTEXITCODE was compared to zero; the
  remaining four were then executed successfully. No skipped script is counted.
- From `packages/runtime_engine`:
  `flutter test --no-pub test/runtime_engine_test.dart --name 'desktop ABI'`
  — six PASS: ABI2 compatibility, exact negotiation, incompatible ABI/schema/
  events/capabilities refusal, and materialized-profile boundary.

The [audit](audit.json) contains hashes and exact original input paths.
The [script](audit.py) is a fixed-input evidence helper, not product code.
Local logs are retained beside it. Original build/runtime receipts remain in
their prior evidence directories and are not relabelled as newly executed.

## Retained proof and limits

[Core binding](../2026-09-10-r12-core-privacy-binding/README.md) retains the
two builds per platform, full Core tests, 81 runtime tests, 8 Android Flutter
tests, real FFI callbacks and 100 proxy-only Windows cycles on this Core.
Exact client merge [CI34528129188](https://github.com/Kiwunaka/POKROV-app/actions/runs/34528129188)
passed `Run client unit and Android flavor tests`. That task runs
`:app:testDirectDebugUnitTest :app:testStoreDebugUnitTest` against the LFS AAR;
the Android host imports generated Core classes directly. Core merge
[CI34494732027](https://github.com/Kiwunaka/pokrov-core/actions/runs/34494732027)
and its exact source-tree binding are retained as well.
[Installed Windows](../2026-09-10-r12-crash-support/README.md) retains the clean
Windows build, ordinary wizard, 304 hashes and actual UI/service/Core route,
DNS and egress path for this exact client source.

No new build, lifecycle run, hosted CI run, device access, deployment, signing
or publication was performed. Android native JNI execution for this Core,
Win10, full route/origin matrices, C02 race/resource and C05 license/privacy
acceptance remain separate. No evidence is transferred to later source or
artifact bytes. The full consolidated plan remains active.

Final documentation checks: explicit-root client validate-seed and docs-contract
PASS; platform 33 tests and context audit PASS; 712 work-order local links and
all new cross-repository evidence links PASS. Both Git diff checks PASS; no
artifacts/releases delta. Documentation/evidence commits remain local.

Staged hash verification initially found Git CRLF normalization in the new
evidence. The local .gitattributes preserves this directory byte for byte;
original captures remain unchanged. Staged blob hashes were then rechecked.
