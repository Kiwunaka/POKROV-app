# Android extended support and bounded network recovery — 2026-09-12

Document class: EVIDENCE. [Exact source, hashes and captures](receipt.json).

Owned LDPlayer14 index3 upgraded in place to client `2c370af8`, Core `6b271dec`,
production-signed x86_64 APK `8dc6c2e6`. Rootless guest startup passed. The
corrected consent sheet displays its actions fully and an ordinary Enable tap
activates the signed policy. The persistent banner opens diagnostics and survives
an app/guest restart. Preview exposes the selected categories and local size.

Actual UI submission created case60: validated8631-byte ciphertext,6105-byte
plaintext, five files including29 recent events and the four allowlisted system
fields. Build identity is4053/direct. Normal HTTPS admin lookup, no-step-up denial,
one-use no-store download, replay denial and audit increments pass. Decryption
used the existing worker key only in memory. The first scan failed on an incorrect
test expectation for the event filename; its failure and audit records are kept.
The corrected expectation uses the implemented `events/recent.jsonl` path.

Cases61/62 repeat the identical diagnostic content and leave usage at1/2, as the
ledger deduplicates diagnostic IDs. After process restart, case63 contains a new
four-file1728-byte payload without in-memory events; its2795-byte ciphertext
validated and the UI reports2/2. A fresh connect/disconnect then creates a third
distinct preview, which the normal Create action rejects before creating a case.
The own-account readback proves cases60–63 are the complete new set. Manual
disable returns to the three-file summary; the consumed code is rejected while
still within its lifetime. The separate five-minute policy expires automatically
without tapping Disable; its timed UI observations are retained below `expiry/`.

Ordinary connection establishes TUN/service and ten owned HTTPS probes return
their expected204 marker. Ordinary disconnect removes TUN/service and restores
IPv4/DNS hashes. Raw IPv6 hashes differ solely because one observed route expiry
countdown changes: full-text hashes match after normalizing only that field.
The earlier raw-only mismatch remains unresolved in its original record.

All boots retain disk/space guards and end stopped; root mode is false. Host
route/DNS hashes are unchanged. Phone and Hiddify are untouched. Initial boots
without ready ADB are recorded as fixture failures, never as app passes. Source
PR123 and exact merged main566d547 CI pass with unchanged protection policy.
This is source promotion and internal QA. Only the new x86_64 QA APK was built;
the similarly named universal output contains x86_64 only. Full final Android,
AAB and Windows packages remain pending. Native planted-input propagation,
Android crash, licensing and complete R12/release acceptance remain open.
