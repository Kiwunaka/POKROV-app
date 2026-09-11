# Current Windows package — client/main d9763e8, Core904

**PASS_LOCAL_PACKAGE**, 2026-09-11. The package is built from exact client
`d9763e8cd7aba9b215015e07c0576f667c1dec09` and existing Core
`904e440aca98cb6419744c5c04c83223a6d6380e`. It is not installed or published.
The retained candidate.33 release baseline and its decision are unchanged.

Installer: `C:/r12-current-windows-source-20260911/apps/windows_shell/build/release_bundle/pokrov-windows-x64-1.2.0+4053-setup.exe`,
29,279,009 bytes, SHA-256 `230ef3ebe2d0880a9a92721792a1c093d8ee23b69961d46e1bbb17288ec6ce52`.
The owning [Windows readiness](../../windows-release-readiness.md) keeps
installed and locally packaged evidence separate.

## What changed in the package

Only `navigation_shell.dart` and its existing test file differ between product
sources at previously installed `7ed18c9` and current `d9763e8`. Among all 304
staged payload files, 303 hashes match the previous bundle. Only `data/app.so`
changed: SHA-256 `bc17cf420f38ec7bbf61d4f29447d041cde3019d9483778346f33424460b8ba7`.
The AOT payload contains the expected full new revision and does not contain
the previous full revision. Native Windows, Core904, Flutter DLL and packaged
dependency files remain byte-identical to that earlier bundle.

All eleven manifest-required file hashes, all 304 staged files, fifteen PE
inventories, Core/libcronet/Flutter identities and required notices passed the
static package audit. The installer SHA matches its manifest. This does not
prove its internal installed payload: the available innoextract 1.9 was already
shown incompatible with this installer generation, so extraction is
`NOT_RUN_KNOWN_TOOL_LIMIT`, with the older failure referenced honestly.

Signing remains `SKIPPED_BY_OWNER` under the existing 1.2.0 unsigned direct-beta
exception. No trusted-signing, Store, new public candidate or installed-client
claim follows from this local package.

## Capacity and exact inputs

C: held the new build checkout because E: had only 0.38 GiB above the required
40 GiB floor. The preflight reserved 2.5 GiB on C: and 0.1 GiB on E:. Tracked
non-release source was 59,549,155 bytes; only two retained rollback JSON files
(16,920 bytes) were added for the mandatory seed gate. Release archive binaries
were not copied. Exact existing AAR/DLL dependencies were synchronized from
the pinned local Core outputs; no native Core or Android build was run.

After build, C: had 42.23 GiB and E: 40.38 GiB. The old package and VM were
untouched. VM capacity is still insufficient under its measured prior growth;
no VM start, snapshot, install, phone action or host-route change occurred.

The first seed run rejected an unhydrated Android AAR LFS pointer. The second
rejected the missing historical rollback metadata. Both logs are retained;
existing exact Core bytes and the two Git metadata files satisfied those
checks, and the complete seed gate subsequently passed. Git stat status lists
six LFS/CRLF paths after tool generation, but `git diff HEAD --exit-code` has no
logical content delta; the exact compiled component hashes are independently
recorded. No product code was edited.

## Commands and results

All final commands exited 0. From the new exact source checkout:

```powershell
pwsh -NoProfile -File scripts/validate-seed.ps1 -CoreRoot C:/r12corec02 -PlatformRoot C:/Users/kiwun/Documents/ai/VPN-consolidated-plan-start
pwsh -NoProfile -File E:/r12-current-windows-package-20260911/build.ps1
```

The saved build harness invokes the canonical reproducible Windows packager
with the pinned public trust keys, `-OfflinePubGet -SkipValidateSeed -SkipAnalyze
-SkipTests`; seed is executed immediately before packaging. Existing source
regression evidence is retained in the [C04 record](../2026-09-11-r12-inactive-tab-builds/README.md).
The changed behavior was also checked again on this exact main checkout:

```powershell
flutter test --no-pub test/pokrov_seed_app_test.dart --name "windows observes service loss after a long connected session|seed shell lazily builds tabs and keeps opened tabs alive|tab changes animate through the shared tab transition wrapper" --reporter expanded
flutter analyze --no-pub
python -B E:/r12-current-windows-package-20260911/audit-windows.py
python -B E:/r12-current-windows-package-20260911/compare.py
```

Three focused widget tests PASS, app-shell analyze PASS, package audit PASS.
The exact main [Release v2 Contract CI](https://github.com/Kiwunaka/POKROV-app/actions/runs/34559266717)
is completed/success. This is not a new Windows clean-host workflow: that
manual workflow still targets retained candidate.25, and was not dispatched
as supposed proof of these bytes.

[Receipt and capture hashes](receipt.json) retain 21 source/build/audit captures,
including both preparation failures. [Documentation validation](validation.json)
records the final documentation checks. Full installed network/fault coverage,
current Android packages/device gates and the complete R12 objective remain
open. Evidence commits are local; no push, merge, deploy or publication.
