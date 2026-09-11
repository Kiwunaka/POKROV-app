# Psiphon uTLS file attribution

Status: PASS_BOUNDED source attribution and exact local package checks.
PR111 merged; post-merge CI is recorded separately below.
Core `904e440aca98cb6419744c5c04c83223a6d6380e` retains the same five library outputs.

The 77 selected Psiphon uTLS Go files match the exact upstream Git blobs in
all five fresh Core 904 dependency graphs. `u_prng.go` is selected on every
platform and its original header explicitly releases the file under the
[uTLS license](https://github.com/refraction-networking/utls/blob/37f7eb6d8aac00e15d4e4235189a9c5c26616dfb/LICENSE).
The common notice asset contained that exact BSD body already, but omitted
the Psiphon copyright/header. The original header is now appended verbatim,
with a reference to the existing license section. All prior asset bytes and
185 recorded license bodies are unchanged.

The [pinned fork](https://github.com/Psiphon-Labs/utls/tree/24497d415a8de0d11c20c3a47724fb88897ed725)
still lacks a root LICENSE. The official release-branch.go1.26 snapshot
`7a1fc711853d6dd31c10eca10bbd53bf3b082aac` has the authentic root BSD text,
but its history diverges and only 38 of the 77 selected files have identical
Git blobs. This does not establish licensing clearance for the whole older
fork. `missing_root_license_modules` remains unchanged.

[Source binding](source-license-binding.json), [assembly](assembly.json),
[original header](u_prng-header.txt), [reference license](upstream-LICENSE.txt)
and [upstream projection](upstream-projection.json) retain the exact hashes.
Local runners and full public API readbacks: `E:/r12-c05-utls-license-20260911/`.
No dependency, Core bytes, protocol behavior or public release changed.


## Exact package checks

Client source `a24b211f9c1c4bf83bb5fde9b8a9c98185ea1028`, merge
`f4a0a5037ca861b75edbef89bd8bf1186eb93b81`, identical tree
`0f10fc048705186f9803e1ae80844a88389f5e7e`, Core 904 above.
Four Direct APKs, one Store AAB and Windows setup `1.2.0+4053` built locally.
[Android audit](android-package-audit.json) checks ABI, exact native libraries,
notices, signing receipt and namespace inventory. [Windows audit](windows-package-audit.json)
checks 304 staged files, 11 required hashes and 15 PE imports.
301 files match the older installed e18/Core c8 bundle; the app library,
Core DLL and notice asset differ. This is not installed-current-package proof.

[Fresh Go scans](core-scan.json) retain nine advisory IDs and 21 records with
function names per binary. [Exact extraction](symbol-extraction.json) returns
zero symbols on all four binaries. govulncheck v1.7.0 binary.go:107–113 uses
allKnownVulnerableSymbols in this case; the function records do not establish
extracted symbols or a reachable call graph. [Static binding](static-triage-binding.json)
compares five current source graphs, 6757 selected inputs (6488 Go/Cgo),
eight source matches and unchanged affected package registrations.
4109 external selected files still match the independently authenticated bytes.
The bounded prior nine-ID assessment applies under those unchanged inputs;
this does not clear other native dependencies or the whole application.
[Binary SBOMs](binary-sboms.json) and the full scan/tool output are retained in
[package evidence](package-evidence.zip). Failed harness iterations are included.

Build commands: `build.ps1` (offline bootstrap, Core sync, Windows reproducible
release helper, Android production build); `python audit-windows.py`,
`python audit-android.py`, `python scan-core.py`, `python binary-sboms.py`,
`python bind-static-triage.py`, `python extract-symbols.py` and
`python retain-packages.py` — PASS for their stated scopes. Windows build
skipped repeated analyze/tests; product change is notice-only and required CI
runs the standard suites. Initial CRLF diff failure was corrected by scoped
.gitattributes; original captured bytes remain unchanged.

Android uses the existing self-managed production certificate. Windows
Authenticode is SKIPPED_BY_OWNER under the existing direct-beta exception.
Installer internal extraction and installation: NOT_PERFORMED_THIS_SLICE.
Phone, VM, installed payload and public pointers were not changed. No store
submission, public package upload or new candidate tag was performed.


## Final CI

[PR CI](client-ci-pr.json) run 34542966927 and [merge CI](client-ci-merge.json)
run 34543786539: PASS on the exact source and merge revisions above.
[Receipt](receipt.json) retains six artifact hashes, evidence/archive hashes
and explicit limitations. Both source commits remain distinct from this local
final evidence update; package bytes were built from the reviewed source tree.

[Final documentation checks](final-verification.json): client seed and docs
contracts PASS; platform 33 tests, context audit and 755 local links PASS.
Both diff checks PASS; no artifacts/releases delta.
