# Artifact Boundary

This source repository contains three distinct artifact classes. Do not merge
their roles.

## Active Runtime Dependencies

Committed client runtime binaries live only in their host bundle paths:

- Android: `apps/android_shell/android/app/libs/pokrov-core.aar`
- Windows: `apps/windows_shell/windows/runner/resources/runtime/pokrov-core.dll`
- Windows dependency: `apps/windows_shell/windows/runner/resources/runtime/libcronet.dll`

Their exact source commit, sizes, and SHA-256 values are owned by
`config/runtime-artifacts.seed.json`. Use
`scripts/sync-pokrov-core-runtime.ps1` to copy them from the separate
POKROV Core checkout.

## Historical Evidence Only

Versioned content under `artifacts/releases/**` is `HISTORICAL_EVIDENCE_ONLY`:
retained release lineage, rollback material, and exact evidence for its
recorded versions. It is not the signed public release index and it is not a
destination for a new candidate. Runtime sync, candidate assembly, and normal
development must not modify it.

The root `artifacts/releases/release-handoff.json` is the sole controlled
exception: an explicitly authorized release or rollback may atomically replace
that stable pointer with exact bytes from a target listed in
`config/release-rollback-catalog.seed.json`. The operation must use the
optimistic lock, external backup, and receipt enforced by
`scripts/set-release-stable-pointer.ps1`. It never rewrites a versioned target.

## Local Candidate Staging

Android and Windows build outputs remain under ignored `apps/**/build/**`.
When a candidate needs an assembled local handoff, use the ignored
`artifacts/candidate-staging/**` (`LOCAL_CANDIDATE_STAGING`) or a temporary
directory outside this checkout. A strict-v2 handoff generated there is local
input only; it does not prove signing or publication.

## Public Release Index

`PUBLIC_RELEASE_INDEX` means the separate signed publication repository bound
into strict-v2 metadata by exact repository and revision. It owns published
manifests, checksums, SBOM/provenance references, and same-byte promotion
identity. This client source tree does not own or mirror that signed index.
A private signed candidate contract retained in Actions is not a published
release index. Read candidate publication and promotion state from
`config/cutover-readiness.seed.json`; access to a repository or artifact alone
does not establish either state.

Generated build output and local caches are not release truth and remain
untracked.
