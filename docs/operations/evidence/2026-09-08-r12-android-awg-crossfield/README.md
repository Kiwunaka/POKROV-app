# Android packages with the cross-field Core correction

**LOCAL_PACKAGE_PREPARATION / PASS**, client `76614b1`, Core `02a091c`,
version `1.2.0+4053`, API `https://app.pokrov.space`.
[Receipt](receipt.json) retains full package/native/notices hashes and the
original build/audit provenance. Physical installation of these bytes is
**BLOCKED_BY_ACCESS**: no Android device was connected during preparation.

| Package | Bytes | SHA-256 |
| --- | ---: | --- |
| ARM64 | 101229131 | `0206cd2a0d76ae427a988bc2220af8f2157d5c153c212cbdcaa3338cf89b41ce` |
| Universal | 295231078 | `f3b2e6e28ca1342aec4e7d4005c6da5f50aa9cd1b68a336b0edd227548238752` |
| ARMv7 | 90760385 | `e2f55c74e37a76f0456aa93d792a4a1f74c4192af888a9ceb633451691791c46` |
| x86_64 | 110238890 | `b518402dd20c4c3849a070513efe829ea487497fd300f80de8e799fa3d4e6b0a` |

`E:/r12-android-awg-crossfield-20260908/build-abi-packages.ps1` and
`audit-abi-packages.py` passed. `apksigner verify` and `aapt dump badging`
verified the existing certificate, package, version, non-debuggable flag and
SDK values. Each split has its expected ABI and all Core SO hashes match the
bound AAR. Native binaries and notices agree between split and universal APKs.
Retained files were independently checked against the receipt hashes.

The ARM64 APK is 65.71% smaller than universal. This is package size evidence,
not runtime performance or device acceptance. These APKs predate the Windows
status-observer commit `68a44e5`; their source identity remains `76614b1`.
Do not rerun the original audit in a different checkout and relabel their source.

APK files remain under `E:/r12-android-awg-crossfield-20260908`; earlier packages
and device results are preserved. Exact ARM64 update, account continuity,
Wi-Fi/LTE/IPv6 and physical runtime checks remain open. No release pointer,
published download, retained `artifacts/releases/**`, or device was changed.
