# Client build scripts

Use the [release procedure](../docs/operations/cutover-readiness.md) for the sequence from a tested change to handoff.

## Runtime selection

[config/runtime-artifacts.seed.json](../config/runtime-artifacts.seed.json) defines the default binding. Pass `-RuntimeArtifactsPath` for an approved alternate binding and use that same manifest for parity, sync and packaging. `-WindowsReleasePath` selects a paired Windows packaging config when needed.

- [check-client-version-parity.ps1](check-client-version-parity.ps1) validates version and selected-platform artifact identity. Use `-Platforms android` or `-Platforms windows` for a single-platform check.
- [sync-pokrov-core-runtime.ps1](sync-pokrov-core-runtime.ps1) verifies the clean Core source and the artifact/dependency identities before copying. It reads `CoreRoot/dist/<platform>` or an explicit `-CoreArtifactDirectory` for one platform. It does not fetch from a release tag. Windows needs the selected Cronet and local-DPI files. Keep required notices with selected dependencies.
- [build-android-production.ps1](build-android-production.ps1) validates the staged AAR. Use `-SyncRuntime` or an explicit `-CoreArtifactDirectory` to copy the selected Android binding. It validates the signed outputs, versions and ABIs. Use the existing signer under `%LOCALAPPDATA%/POKROV/android-signing`. [configure-android-production-signing.ps1](configure-android-production-signing.ps1) provisions signing for an authorized setup. Keep passwords and key files outside the checkout. Do not replace an existing signing lineage.
- [build-windows-release.ps1](build-windows-release.ps1) validates the runtime and sidecars, executable versions, installer identity and the requested signing mode. `-SkipBuild` requires matching existing outputs. The [reproducible wrapper](build-windows-release-reproducible.ps1) uses a temporary drive mapping. Use the existing approved certificate configuration for a trusted-signed release.
- Both production builders require `-CandidateRankerModelPath` for the approved v1 model and validate the bundled asset. The model source is external to the repository. Normal source tests use test assets.

## Development checks

Run `flutter analyze` and focused `flutter test` in the affected package or host. [run-tests.ps1](run-tests.ps1) runs the listed workspace and Android flavor checks when the affected scope requires it. [check-release-source-logging.ps1](check-release-source-logging.ps1) checks the release logging boundary. Packaging outputs and signing material stay out of git.
