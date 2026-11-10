# Client release procedure

Public release state belongs to the [Platform production snapshot](../../../VPN/docs/operations/current-state.md). Use the [build scripts](../../scripts/README.md) for the selected host and the [Platform publication runbook](../../../VPN/docs/operations/publishing-and-signing-guide.md) for GitHub assets, downloads and rollback.

1. Set the intended client version and verify parity for the affected host. Use the same Core manifest, dependency inputs and production trust config for validation and packaging.
2. Run the checks for the changed behavior. Build from the checked source when the release requires a changed binary. Reuse the selected Core if its source and binding are unchanged.
3. For Android use the production signer and direct APK for outside-store distribution. Verify install and the changed behavior on the test phone when the release calls for it. For an ordinary connectivity check, sign in and open an ordinary site through the app after connecting. Check trusted signing or store-specific packages only when that distribution is in scope.
4. For a changed Windows build, check installation, activation and the affected runtime behavior on the approved Windows host. A Windows source check does not exercise the installed privileged service. Store promotion and trusted-signing acceptance are separate from outside-store packaging.
5. Keep the accepted package set and versioned handoff until publication, runtime readback and the rollback path are verified. Promote the checked artifacts through the Platform procedure.
