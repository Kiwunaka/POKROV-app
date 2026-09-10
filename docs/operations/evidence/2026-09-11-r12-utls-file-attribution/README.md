# Psiphon uTLS file attribution

Status: source notice correction; exact package checks pending.
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
