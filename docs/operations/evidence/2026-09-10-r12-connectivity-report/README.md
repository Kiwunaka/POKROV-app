# Connectivity report: source and package evidence

Document class: EVIDENCE. 2026-09-10 MSK.

Client `64fe01d6d4577f0989dc690e0d4e4e900b67534a` reports fetched, staged and
effective profile references, protocol families and the observed proof stage
through the existing runtime-stats API. Observation time is not renewed by polling;
attachment to an already running service leaves that time unknown. Profile paths,
raw configuration and content digests are excluded. The platform separately hashes
revision references and binds server assignment to receipt time. This remains
client-reported state, not independent traffic proof.

[PR97](https://github.com/Kiwunaka/POKROV-app/pull/97) merged as
`bf3d1c4f400d58a2cd3411e0f4553670dd8dbb13`. Exact PR and merge CI PASS;
[binding](client-merge-binding.json) confirms signed source and merge have the same tree.

Validation: app_shell focused bootstrap/report tests 110 PASS; native_runtime
suite 81 PASS and one existing exact-DLL backtest SKIPPED because
POKROV_REAL_CORE_ROOT was absent. Both package analyses and seed/docs PASS.
The first shell run had two outdated event-list expectations; those were updated
and the successful rerun retained. Original logs and hashes are in [receipt](receipt.json).

The clean signed source produced four APKs; signer, ABI, Core and notices checks
PASS. [Package audit](abi-package-audit.json) binds version 1.2.0+4053 to the
unchanged Core `c7a11f7d2fd974726095ad7aa0619c055273dd15`. ARM64 SHA-256:
`c0fca985da6a1ee3491d3ef620e534d96935094f61dff91a3759756c740a7e52`.

Physical installation and an actual client-to-server report remain pending:
the owner is using the phone. The installed c691 always-on APK is an earlier
candidate; its device evidence cannot validate this new APK. Public downloads
and artifacts/releases are unchanged. Full O03 and N01/N03 acceptance remain open.

Documentation validation: ./scripts/validate-seed.ps1 -PlatformRoot C:/Users/kiwun/Documents/ai/VPN-consolidated-plan-start -CoreRoot E:/r12core-implementation; ./test/docs-contract.ps1 — PASS. `git diff --check` and local links PASS.
