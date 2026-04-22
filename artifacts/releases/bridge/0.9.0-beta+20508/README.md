# Bridge Release Bundle `0.9.0-beta+20508`

Built on `2026-04-23` from the retained bridge workspace:

- source workspace: `C:/Users/kiwun/Documents/ai/VPN/external/client-fork/app`
- local packaging workspace: `external/client-fork/app/out/`
- mirrored archive path: `C:/Users/kiwun/Documents/ai/POKROV-app/artifacts/releases/bridge/0.9.0-beta+20508/`

Included artifacts:

- `pokrov-android-universal.apk`
- `pokrov-android-market.aab`
- `pokrov-windows-setup-x64.exe`
- `pokrov-windows-setup-x64.msix`
- `pokrov-windows-portable-x64.zip`

Signing state:

- Android: local release build succeeded, but no production keystore was configured during this run, so `APK` and `AAB` used the debug-keystore fallback and are valid only for alpha/beta/operator testing
- Windows: local packaging succeeded, but production signing was not applied in this run; `EXE` and `MSIX` are unsigned smoke/handoff artifacts

Required before public release:

- production Android keystore path and final signed `APK` / `AAB`
- physical-device Android localhost/control-surface audit on the release-installed build
- trusted Windows signing identity and signed `EXE` / `MSIX`
- published GitHub Release URLs plus runtime `APP_*` handoff sync
