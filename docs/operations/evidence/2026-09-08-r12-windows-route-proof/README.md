# Installed Windows route proof and AWG correction — 2026-09-08

**PASS_BOUNDED** for installed client `3784352` / Core `02a091c`, Windows 11,
owned VM with VirtualBox NAT, managed AWG3.1, current-origin. This local package
is version `1.2.0+4053`, installer SHA-256
`83c253ce8a1cc5d64aa615e259ae2a0f6d5d978442fd3732965d7778d14d6063`.
All 305 installed files match after installation and at cleanup. The
[receipt](receipt.json) binds seven traffic samples and 62 retained artifacts.
This is bounded N03/N08 progress, not complete routing or release acceptance.

## Failure and correction

On prior installed source `e88dff9`, selecting PowerShell in the stock Windows
picker and connecting with AWG3.1 failed before runtime dispatch:
`connect_unexpected_managed_profile_refresh`. Routes and DNS stayed at baseline.
An empty selected-app list correctly returned the user to Rules without a TUN.

`applyPokrovRoutingPreferences` found AWG endpoint targets only through
`route.final`; selected-app mode uses a direct final and a process-specific AWG
rule. The focused regression reproduced a FormatException. Commit `3784352`
resolves an endpoint referenced by an existing route rule after outbound
candidates. It preserves the direct final, process selection and unused-endpoint
behavior. The architecture owner was updated in that implementation commit.

## Independent counters

Windows Packet Monitor uses an exact IPv4 TCP80 filter to the owned brain
endpoint, NIC components and counters only. No packets, ETL or pcap are saved.
Each row executes three ordinary-user HTTP requests, all HTTP 200. Rx/Tx below
counts the same filtered destination, independently of the application's proof.

| Source / mode / process | TUN Rx/Tx | Physical Ethernet Rx/Tx |
| --- | --- | --- |
| e88dff9 / disconnected / curl | absent | 15/15 |
| e88dff9 / Russia directly / curl | 15/15 | 0/0 |
| e88dff9 / full tunnel / curl | 15/15 | 0/0 |
| 3784352 / selected PowerShell / PowerShell | 15/15 | 0/0 |
| 3784352 / selected PowerShell / unselected curl | 15/15 | 15/15 |
| 3784352 / full tunnel / curl | 15/15 | 0/0 |
| 3784352 / Russia directly / curl | 15/15 | 0/0 |

The selected/unselected pair has the same active profile hash, direct final,
`powershell.exe` rule to `pokrov-awg31-lab`, and AWG3.1 contract. Curl's physical
traffic is the intended direct path for an unselected process. Both streams
are visible at TUN ingress; physical counters distinguish their subsequent path.
All connected samples retain Core/DNS/egress/effective-stage proof. Profile
hashes remain stable during each capture that collected profile metadata.

## Installation and return

The first automated hidden installation returned launcher exit 0 but matched
only 304/305 files: `data/app.so` was old and the installation log was incomplete.
Defender recorded `Behavior:Win32/SuspClickFix.G2` and removal actions. This
attempt is a failure; `PASS_INSTALL_EXIT` in its local receipt is not installation
acceptance. The same installer subsequently completed through the ordinary
interactive wizard, with all 305 hashes and saved session/experience unchanged.
Defender remained enabled throughout; no exclusions or security changes were
made. Its final readback contains the same seven initial events and no new ones.
The automated-install/AV issue remains open despite the successful second path.

Final disconnect restores original routes, DNS, routing preferences and empty
selected-app list. Stock Rules returns to Russia directly. UI exits, the Auto
LocalSystem service remains installed, Pktmon is idle with no filters, temporary
capture/inspection/click tasks are absent. The guarded backend restore matches
the full original configuration hash. VM is off/NIC none, source VM is off,
host routes/DNS unchanged. Raw credentials, profiles and connection keys are not
exported. The IPC helper's embedded `0218e89` labels only the existing helper.

An earlier extra picker click selected the wrong mode; its state and cancelled
capture labels are not selected-mode evidence. Only the corrected failure and
the `fixed-*` counter samples establish the selected-mode result. The raw
collector's nullable `process_paths_count` is excluded from proof. Final identity
has a null `routing_mode` field; it is not used to establish the restored mode.

## Validation and limits

Implementation: `flutter test test/client_routing_preferences_test.dart
test/app_first_runtime_bootstrap_test.dart` — 119 PASS; `flutter analyze` PASS;
explicit-root seed validation PASS; red regression retained. Local lab build
and packaging completed against the committed source, with preexisting generated
registrant line-ending dirt excluded from the commit. Release artifacts were
not modified. `python -B E:/r12-windows-route-proof-20260908/retain-evidence.py`
PASS for seven samples, 62 hashes and cleanup. Host `finish.ps1` PASS.

Evidence/docs verification:
`scripts/validate-seed.ps1 -PlatformRoot C:/Users/kiwun/Documents/ai/VPN-consolidated-plan-start -CoreRoot E:/r12core-implementation`
PASS including the docs contract (`evidence-seed.log`). `git diff --check`
PASS and `git diff --name-only -- artifacts/releases` empty. Preexisting
generated registrants remain outside the evidence commit.

One non-RU IPv4 destination does not prove Russian banking/services, DNS paths,
IPv6, LAN, all applications, all protocols, actual public egress location,
Windows 10 or the final channel. Windows exposes three routing modes; Android's
excluded-app UI is not a Windows test. Full N03/N08 and signing/channel gates
remain open. No push, publication, promotion or deploy occurred.
