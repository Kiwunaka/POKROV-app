# Windows 10 lab access — 2026-09-08

**BLOCKED_BY_ACCESS: WINDOWS10_EVALUATION_NOT_LICENSED.** POKROV was not
installed and no Windows 10 application acceptance was run. The intended local
package is client `e88dff9` / Core `02a091c`, installer SHA-256
`29a87a13906909e400037a947f1e4f876ca59821e7e34c73060e623f2d9fbeea`.
The [receipt](receipt.json) binds the retained media, baseline and failures.

A separate owned VM was prepared with Windows 10 Enterprise LTSC 2021
Evaluation, 21H2 / `10.0.19044.1288`, 2 vCPU and 4 GiB configured RAM.
The 4,898,582,528-byte ISO was downloaded from Microsoft and its SHA-256 matched
the retained official hash PDF. The first unattended setup stopped at the
license-terms dialog; omitting the generated empty ProductKey node allowed
installation to finish. Both attempts are retained. No product key was supplied.

The ordinary test account is not an administrator. UAC and Defender remained
enabled, no setup bypass key or persistent autologon password was present,
Guest Additions ran after a normal reboot, and POKROV UI/service were absent.
The evaluation immediately reported LicenseStatus 5 and zero grace minutes.
Normal elevated `slmgr.vbs /ato` attempts at 05:52 and 05:58 UTC both returned
`0x87E10BC6`; status and grace remained unchanged. The clock was not backdated,
the evaluation timer was not reset, and no key or license was purchased.

Temporary NAT was confined to this VM for activation. The primary Microsoft
activation endpoint completed authenticated TLS 1.2; the legacy endpoint probe
failed. These observations do not establish the cause or permanence of the
activation failure. Access to an existing licensed Windows 10 stand has been
requested from the owner; no answer or scope exception is inferred.

Final state: VM powered off with NIC none, ISO unmounted from the host,
host routes/DNS unchanged, POKROV absent. The existing source and Windows 11
test VMs remained off. Credentials and unattended answer media remain private;
the receipt contains only selected redacted artifacts. Full W01/W02/W05 and
final-channel acceptance remain open. No build, promotion, publication or deploy
was performed in this slice.

Validation: `python -B E:/r12-win10-lab-20260908/retain-evidence.py` verified
23 artifact references including the ISO and asserted activation/cleanup state.
`pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/validate-seed.ps1 -PlatformRoot C:/Users/kiwun/Documents/ai/VPN-consolidated-plan-start -CoreRoot E:/r12core-implementation`
PASS, including client docs contract (`E:/r12-win10-lab-20260908/client-seed.log`).
`git diff --check` PASS; `artifacts/releases/**` unchanged. Concurrent generated
registrants were preserved.
