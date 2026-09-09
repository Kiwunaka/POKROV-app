# Candidate.33 retention readback — 2026-09-09

**RETENTION_VERIFIED.** This closes the preservation scope of consolidated
R12-G02. Candidate.33 remains private and blocked; its bytes do not validate
the continuing client/Core sources or a new release.

The candidate remains at
`E:/POKROV-tools/release-candidates/pokrov-1.2.0-candidate.33`.
[Local readback](local-preservation.json) hashes every one of its 24 files:
21 match digests already pinned in the September 5 freeze, cutover seed or
candidate provenance; the three auxiliary files have newly observed digests,
not invented historical expectations. All six binaries, strict handoff,
manifest, detached signature, signing receipt, SBOM, provenance, supply
validation, signing reports and Windows manifest remain present. Nothing
in that directory was changed or rebuilt; no binary copies were made.

The three signer outputs downloaded from artifact `9928470408` match the
retained local manifest/signature/receipt byte for byte. Both source SBOMs
match the hashes referenced by candidate.33 provenance. Five dependency
manifests were read directly from the exact retained Git commits; the report
distinguishes exact Git bytes from original Windows CRLF checkout bytes.
Removed temporary source worktrees were not recreated.

## Actual hosted retention

[Fresh GitHub API observations and archive/member hashes](remote-retention.json)
retain each deadline separately. All five archives had `expired=false` and
were downloaded successfully; their SHA-256 matched GitHub's archive digest,
and the eight extracted members passed ZIP CRC and were hashed locally.

| Run / artifact | Expires at UTC | Original archive bytes |
| --- | --- | ---: |
| `33851401873` / `9928470408` signed manifest | 2026-09-18 08:01:25 | 7,955 |
| `33303561763` / `9729751245` Core source SBOM | 2026-09-13 09:17:34 | 55,454 |
| `33303561763` / `9729813473` Apple receipt | 2026-09-13 09:22:10 | 1,924 |
| `33303561763` / `9729818862` Windows receipt | 2026-09-13 09:22:34 | 1,330 |
| `33303561763` / `9729821940` Android receipt | 2026-09-13 09:22:47 | 1,271 |

All archives and exact extracted files are retained in
`E:/r12-g02-retention-20260909`, indexed by artifact ID. Their aggregate archive
size is 67,934 bytes. The source repository retains hash reports and helpers;
it does not publish the private candidate manifest, signature or binaries.
These local files have no GitHub expiry metadata; indefinite local retention
is not promised. Preserve both local directories during later cleanup.

Client run `33849479969` currently lists zero artifacts. No hosted client
build artifact can be retained from that run; the observation alone does not
establish whether anything was previously uploaded or expired. The exact
local candidate binaries remain the retained copies. None of the five named
remote artifacts was missing or expired at this readback; the signer's
September 18 date is not used as a deadline for other files.

## Reproduction and boundaries

```powershell
python -B E:/r12-g02-retention-20260909/retain-remote.py
python -B E:/r12-g02-retention-20260909/check-local.py
```

Both commands completed. The downloader refuses to overwrite existing archives;
it is retained as the executed collector, not a scheduled refresh job.
[Receipt](receipt.json) binds the reports and helper bytes. The archive download
used existing GitHub authentication without exposing credentials. Signing keys
were not accessed or copied. Signature bytes were compared; Ed25519 verification
and signing custody were not re-executed. Retention does not close candidate.33's
runtime gates, create a new candidate, publish a release or authorize promotion.

Client validation passed with `pwsh -NoProfile -ExecutionPolicy Bypass -File
./scripts/validate-seed.ps1 -PlatformRoot C:/Users/kiwun/Documents/ai/VPN-consolidated-plan-start
-CoreRoot E:/r12core-implementation`, including repository hygiene and docs
contracts. The existing clean Core checkout temporarily selected the client's
bound `02a091c` for this check, then returned to `c7a11f7` on its original
feature branch. No extra checkout was created. `git diff --check` passed;
`artifacts/releases/**` has no delta. No Android or Windows build was run.
