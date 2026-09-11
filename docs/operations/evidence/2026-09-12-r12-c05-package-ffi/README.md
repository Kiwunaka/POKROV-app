# Core2662 package FFI privacy — 2026-09-12

Document class: EXECUTION_EVIDENCE. **PASS_BOUNDED_PACKAGE_FFI**.
Client build source `212bd2f30c9f91d80fd3a6c08fb5557be8457f1c`, Core
`2662f76a3303a0518bb07fbbdc449c066de2f95b`, exact packaged DLL
SHA-256 `e77cc0ab979becc635ec578b8b44248b1146dd96ba34cd4de72e62130089ce2c`.
[Receipt and capture hashes](receipt.json), [FFI result](packaged-ffi.json).

The DLL was copied from the versioned development release bundle into an
isolated user fixture on the existing Windows 11 VM. The 45-second bounded
PowerShell/C# child calls the actual exported setup/start/freeString functions
with debug disabled and a deliberately invalid synthetic configuration.
It returns `CORE-005`; credential, config, URL, IP, path and PII markers are
absent from the FFI return, stdout and stderr. Stdout is empty; stderr contains
398 bytes. Raw streams were scanned in memory and were not exported.

This checks the previous direct-FFI leak regression for the exact new package.
It does not cover every runtime logging path or installed service/TUN behavior.
The current guest API token is not elevated. Installation and ordinary UI
acceptance were deferred while the owner was occupied; no elevation was attempted.
All 304 files of the existing client7ed/Core904 installation still match before
and after the fixture. Session and secure-storage hashes, empty outbox and
idle UI are unchanged. No live profile was used by the FFI subprocess.

The guest was shut down normally. [Restoration](vm-restoration.json) proves
poweroff, NIC none, all 13 retained snapshots, unchanged old rollback-leaf hash,
and 3,355,443,200 bytes growth within the 4 GiB budget. Host route/DNS digests
match their baseline. A window capture returned the occluding game instead of
the VM; direct VirtualBox capture returned E_FAIL. No host input or focus change
was sent, and no VM screenshot is claimed.

Commands: the retained `baseline.ps1`, `ffi-run.ps1`/`ffi-child.ps1` and final
baseline projection ran through the existing bounded guest-control wrapper.
`shutdown.exe /s /t 0 /d p:0:0` shut down the guest; native VBox readback and
SHA-256 checks produced the restoration receipt. The first DLL copy used the
wrong unversioned host directory and stopped before copying it; the corrected
versioned bundle path supplied the verified bytes. Public release, production
deploy and installed-candidate acceptance were not performed.
