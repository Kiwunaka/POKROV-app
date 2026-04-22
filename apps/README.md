# Apps

This folder holds thin platform entry shells for the canonical `POKROV-app` client lane.

Historical mapping note:

- older docs may still call this lane `external/pokrov-next-client/` or `app-next/`
- the first local snapshot for this repo was bootstrapped from `C:/Users/kiwun/Documents/ai/VPN/app-next/`
- this wave does not make these hosts public release truth yet

Current host shells:

- `android_shell`
- `ios_shell`
- `macos_shell`
- `windows_shell`

All four hosts stay intentionally thin. They exist to keep the lane truthful and resumable without making this subtree the shipping truth or release truth.

Public promise note:

- `android_shell` and `windows_shell` form the current public delivery scope of this lane
- `ios_shell` and `macos_shell` stay checked-in engineering and readiness hosts only

Host-local `build/` outputs under these shells are regenerated local artifacts for validation only.
