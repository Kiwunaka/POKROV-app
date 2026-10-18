# Apps

Platform hosts own OS integration and consume the shared packages.

| Host | Role |
| --- | --- |
| [android_shell](android_shell/README.md) | Public Android app, VPN service, permissions and Kotlin runtime bridge |
| [windows_shell](windows_shell/README.md) | Public Windows app, installed privileged service, tray and host integration |
| [ios_shell](ios_shell/README.md) | Engineering/readiness host; no public delivery claim |
| [macos_shell](macos_shell/README.md) | Engineering/readiness host; no public delivery claim |
| [linux_shell](linux_shell/README.md) | Engineering host and daemon work; outside the current public pair |

UI composition belongs to `packages/app_shell` and `packages/app_ui`; protocol
materialization and native calls belong to `packages/runtime_engine` and the
platform host. Host-local `build/` directories and native runtime slots are
generated, ignored artifacts.

Use the [repository map](../docs/architecture/folder-structure.md) for source
entrypoints and [packaging guide](../scripts/README.md) for runtime bindings.
Older `external/pokrov-next-client` / `app-next` names describe historical paths.
