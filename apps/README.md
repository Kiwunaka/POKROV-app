# Apps

This folder holds thin platform entry shells for the `app-next/` future lane.

Historical mapping note:

- older docs may still call this lane `external/pokrov-next-client/`
- `app-next/` is now the canonical path name for the same platform-owned future lane in a separate explicit worktree
- this wave does not migrate the git model or make these hosts release truth

Current host shells:

- `android_shell`
- `ios_shell`
- `macos_shell`
- `windows_shell`

All four hosts stay intentionally thin. They exist to keep the lane truthful and resumable without making this subtree the shipping truth or release truth.

Host-local `build/` outputs under these shells are regenerated local artifacts for validation only.
