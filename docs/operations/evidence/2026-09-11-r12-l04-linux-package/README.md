# R12-L04 — first signed Linux package, installed acceptance open

`PASS_LOCAL_BUILD_PACKAGE_AND_DETACHED_SIGNATURE`. Exact candidate:
`pokrov_1.2.0~beta.30-2_amd64.deb`, 32,257,190 bytes, SHA-256
`cb21072ac3552219ff63e59c9adacd323107a431ace4c7346cd9c8370f8c5f53`.
The UI embeds client `0bcb5953b522b4d162e77214dda0211cdbc6df95`; native Core
is `97ec91e3a74c96db3ce5c0c98364b715bf344964`. Core/daemon bytes match the
retained [L03 runtime inputs](../2026-09-11-r12-l03-linux-recovery/README.md).
Daemon source is unchanged from that proof. Core main promotion is still pending.

The retained client archive and commands prove a native Ubuntu 24.04 amd64
Flutter 3.38.5 release build. Package audit checks every member's root ownership,
non-writable group/other permissions, absence of setuid/setgid, fixed UI symlink,
three executable modes, LF shell hooks and shell syntax. All packaged ELF
dependencies resolve on the build VM. This is a package-content check, not
installation or a runtime permission test.

The dedicated Linux key fingerprint is
`29636EDAF204D6F6101CB083B2281E647B0EDDA0`. A detached signature authenticates
the unchanged deb; `gpgv` passed both locally on Windows and natively on Ubuntu
with the single exported public key. The [signing pin](../../../../apps/linux_shell/packaging/signing-key.v1.json)
and public key are source artifacts. Private key material remained in the
protected operator signing home, encrypted with a DPAPI-protected passphrase;
no private key was exported. No Ubuntu archive trust or public availability
is claimed. Original assembly metadata remains `UNSIGNED`; the separate
signature receipts describe the later signing operation without rewriting it.

Retained failures are part of the evidence: build 01 lacked `ld.lld`; build 02
lacked `llvm-ar`; installing `lld-18` and `llvm-18` enabled build 03. Candidate
revision 1 had 20 group-writable package paths inherited from the builder's
umask and was neither installed nor signed. Commit `0bcb595` normalizes package
permissions; fresh build 04 and candidate revision 2 pass the content audit.
The first SDK initialization also lacked unzip; the unchanged pinned SDK
completed after dependencies were installed. The initial apt download was
interrupted before dpkg ran after IPv6 mirror failure was observed; an IPv4
download retained the cache and completed.

The latest public build-defines capture belongs to build 04. Earlier build
recipes retain their literal original revision and public pins; their shared
temporary defines path was subsequently reused. Earlier recipes are not proof
of the final candidate; build 04 and its archive are authoritative here.

**Open:** clean desktop VM install, actual UI/polkit approval, installed
file/socket permissions, update and state preservation, uninstall and exact
DNS/IPv6/full/RU-mode tests on this artifact. No package was installed or publicly
published in this slice. L04 is active/I3, not final candidate acceptance.

The [receipt](receipt.json) hashes all retained captures. Local package and
signature remain at `E:/r12-linux-promotion-20260911/`; guest copies are in the
owned L04 package directory. [Packaging instructions](../../../../apps/linux_shell/packaging/README.md)
define the assembly and signature-verification steps.
