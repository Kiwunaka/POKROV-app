# Standard-account Windows installer — 2026-09-07

The current Windows installer failed clean installation from a separate ordinary
account after UAC used another administrator: exit 7, unable to resolve the
installation owner. The generated script asked the original user to write
`whoami` output inside the elevated installer's protected temporary directory.
Inno documents this [temporary-directory protection](https://jrsoftware.org/is6help/topic_securitymeasures.htm)
and the original-credential behavior of [ExecAsOriginalUser](https://jrsoftware.org/ishelp/topic_isxfunc_execasoriginaluser.htm).

`scripts/build-windows-release.ps1` now reads the original SID through that
child process's exit status. Tagged 16-bit pieces preserve unsigned 32-bit SID
components and distinguish shell failure codes; the installer reconstructs the
existing supported SID form. There is no shared writable identity file or ACL
relaxation. The existing owner-reuse fallback for upgrades is unchanged.
The actual test account contains a SID component above signed Int32 and still
matches the installed owner exactly. [Receipt](receipt.json) binds the source
base, exact changed script blob, patch, before/after installers and retained logs.

The same linked offline Win11 baseline, separate `R12Standard` account and
`pokrovtest` UAC administrator reproduce failure before and success after.
The account is not an Administrators member. The fixed installer returns 0,
installs all 305 expected bundle files byte-for-byte, and starts the automatic
LocalSystem service. The stock UI runs as R12Standard; the fresh private service
journal records accepted IPC and a successful status response. No probe EXE was
added to the installation. The only extra installed files are the stock Inno
uninstaller and its data file.

The actual stock uninstaller, started by the standard account with administrator
UAC, returns 0 and reports no reboot needed. Independent readback finds no
service, installation directory, owner registry, UI/service processes or TUN.
A subsequent installation of the same fixed bytes also returns 0 and passes the
305-file identity and standard-account UI/IPC checks. A planned forced guest
reboot then starts the service automatically under LocalSystem before any user
login or Explorer/UI process. The original owner binding and executable hashes
persist. No profile or connection was used in these runs.

Before installer SHA-256: `c02d6429d108284327c4ead5830bebb03d9030c6842b5144981f5cddfbbec6fa`.
Fixed installer SHA-256: `d792f4215b1feae486f84c8b077b74a3b840bcdc437048a03dabfe5ec15b8ed9`.
Bundle source `98c39d6`, Core `8dc57a8`; unsigned `1.2.0+4053` with unavailable
loopback API. This is exact local-package proof, not final channel acceptance.

Build command: `scripts/build-windows-release.ps1 -SkipBuild -SkipTests
-SkipAnalyze -SkipValidateSeed -OfflinePubGet -CoreRoot E:/r12core-implementation
-EmergencySigningKeyId <canonical-public-pin> -EmergencySigningPublicKey
<canonical-public-pin> -MsvcRuntimeDirectory <retained-bundle>`. It reuses the
already checked unchanged UI/Core bundle; Inno compiles the changed installer.
Runtime commands and source snapshots are retained under the receipt's lab path.

An initial static parser wrongly read raw Inno `{{` escaping as a PowerShell
syntax error. The corrected post-expansion parse passes; both collector receipts
are retained. There is no uninstaller command change in the final source diff.

Automatic approval review rejected an initial temporary-password transfer before
execution. The replacement creates the test password inside the guest, retaining
only guest DPAPI ciphertext in a private administrator-owned directory. Neither
password nor ciphertext is in these artifacts. The test account remains available.
The evaluation image's licensing shutdown limitation remains applicable.

Open: actual managed transport/TUN/DNS/IPv6/routes, connected crash/sleep/handoff,
upgrade while connected, Win10, downloaded final channel and full W01–W03 matrix.
No push, merge, production deploy, new candidate or retained release mutation.
The installer clone remains running offline with its installed idle auto service;
source VM and earlier SCM clone/evidence are preserved.

Validation: before/after Inno builds PASS; client seed/docs PASS; platform docs
33 PASS; context audit PASS; package 13 imports/83 R12/378 legacy/281 links
PASS; diff check PASS; no retained release-artifact delta. Exact validation
commands and log hashes are in the receipt.
