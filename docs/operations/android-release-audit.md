# Android release checks

Use the [client release procedure](cutover-readiness.md) and the [Android build script](../../scripts/build-android-production.ps1). Confirm that the affected APK has the intended application ID, version, ABI and production signing lineage. The direct build supplies the verified local installer handoff. The store build has no direct APK installer.

When physical acceptance is required, install the selected APK on the approved test device and exercise the changed behavior. For a connectivity change, sign in, connect and verify usable traffic. A release requiring a fresh localhost audit needs the release build checked before connect, while connected and after disconnect. Keep the public claim within the actual audit scope.
