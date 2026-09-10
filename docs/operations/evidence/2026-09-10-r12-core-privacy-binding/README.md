# Core lifecycle privacy binding — 2026-09-10

Evidence for source `c8b0461c1975ef96e32024774300a5829b9fdc43`, not an installed
client or public release. The previous Core c7 DLL exposed planted data in
stderr and FFI errors. The fixed DLL returns a catalog code while preserving
the typed internal cause. Six canaries are absent from FFI return, diagnostic
stderr/files and structured callbacks in the retained direct-call fixture.

[Binding](binding.json), [before](ffi-before.json), [after](ffi-after.json),
[Android two-build evidence](android-evidence.json), [Windows two-build evidence](windows-evidence.json)
and [previous manifest](previous-runtime-binding.json) retain exact provenance.
Full build trees and the original failure remain under `C:/r12-v01-core-20260910`.
The evidence helper's CI label denotes local execution with empty hosted run IDs.

Full Core tests, two builds per platform, four Android ABIs, 15 Windows exports
and 100 proxy-only Windows start/stop cycles pass. Dependency/license source
files did not change; source SBOM warnings remain separate from license clearance.
81 runtime tests, 8 Android Flutter tests, runtime analyze, exact-source seed and docs checks pass. The opt-in runtime test skip is covered by the separate 100-cycle check. Core/client CI convergence and installed acceptance remain separate gates.
