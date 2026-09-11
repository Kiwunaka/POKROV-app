# Core2662 exact development packages — 2026-09-11

Document class: EXECUTION_EVIDENCE. **PASS_BOUNDED_EXACT_PACKAGES**.
Client source `212bd2f30c9f91d80fd3a6c08fb5557be8457f1c`; Core
`2662f76a3303a0518bb07fbbdc449c066de2f95b`; development line `1.2.0+4053`.
[Receipt](receipt.json) lists six artifacts, signing scope and every retained file hash.

- Four direct APKs and store AAB pass the production signing helper. Core and
  Flutter bytes and four notice sources match in every package. Direct/store
  DEX were parsed independently; four direct APKs share exact DEX bytes.
- Windows installer and its staged payload pass 304-file comparison after
  unprivileged, network-isolated extraction in the existing Ubuntu lab VM.
  The extractor still emits 304 multipart-checksum warnings; independent
  SHA-256 readback of every file is the identity oracle. The VM is powered off.
- All nine Windows native CTest cases pass. 75 Pub and 63 Maven public coordinates
  return zero OSV IDs. Both Android flavor graphs are exactly equal.
- [Native scan binding](package-native-scan-binding.json) ties packaged libraries
  to the [fresh Core scans](../2026-09-11-r12-c05-utls-binding/README.md).
  Nine advisory IDs remain at module precision; no reachable-vulnerability
  clearance is inferred from stripped binaries.
- The first Windows attempt failed with missing generated C++ wrapper files.
  Preserving and invalidating old Flutter output cache allowed the unchanged
  source to build. Failed logs and all previous output hashes remain available.
  Completed Android intermediates were compressed with exact before/after
  SHA-256 checks to restore the 40 GiB disk floor.

The source review archive contains 3693 verified entries. Its own root uTLS
license is authenticated; full license compatibility, corresponding-source
assessment and native reconstruction remain open. These packages have not
been installed, publicly released or submitted to a store. Older installed
receipts retain their exact earlier bytes. Windows Authenticode remains
`SKIPPED_BY_OWNER` for the existing direct-beta exception.
