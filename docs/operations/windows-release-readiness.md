# Windows release checks

Use the [client release procedure](cutover-readiness.md) and the [Windows build script](../../scripts/build-windows-release.ps1). Check the installer and executable versions, selected Core DLL and required sidecars before deployment. Trusted signing and store packaging are separate distribution choices.

For an installed runtime change, exercise activation, connect/cancel or disconnect as relevant and verify that the privileged service restores the network. Check usable traffic when connection behavior changes. The tray and normal startup stay separate from service commands. Check repeat activation when installer or activation wiring changes.
