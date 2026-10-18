# pokrov_app_ui

Screens of the redesign the owner approved on 2026-10-18. The frame was built from the 1.5.0 screens: same circle button, chips, tabs, emerald and Golos Text, with plain «ты» texts, technical detail moved to a second layer, and live motion.

The package is presentation only. Screens take view data (`lib/src/models.dart`) and callbacks; they never read runtime, network or storage. `example/lib/sample_data.dart` holds the fake data used only by the preview app and tests.

## Preview app

`example/` is a clickable dummy («POKROV макет», `space.pokrov.pokrov_app_ui_preview`). It installs next to the real app. The connection is a timer, and every third attempt fails so the error state can be seen.

```powershell
cd packages/app_ui/example
flutter build apk --release --target-platform android-arm64,android-x64
```

## Wiring into the app

Map app state to the view data and pass the real actions:

Feature filenames below belong to the existing
[app_shell adapters](../app_shell/lib/src/features/); release status belongs to
[cutover readiness](../../docs/operations/cutover-readiness.md).

| Screen | Data | Comes from today |
|---|---|---|
| `HomeScreen` | `HomeViewData` | `home_surface.dart`, `protection_center.dart` |
| `StatusSheet` | `StatusViewData` | protection center checks, mapped to three plain rows |
| `FirstConnectSheet` | `FirstRouteChoice` | first-connect route question in [seed_shell.dart](../app_shell/lib/src/shell/seed_shell.dart) |
| `LocationsScreen` | `LocationsViewData` | `locations_surface.dart` |
| `RulesScreen` | `RulesViewData` | `rules_surface.dart`; expert settings stay behind «Для опытных» |
| `ProfileScreen` | `ProfileViewData` | `profile_surface.dart`; interface mode switches inline |
| `RenewScreen` | `RenewViewData` | tariffs from the platform catalog; payment opens the existing checkout URL |
| `SupportScreen` | `SupportViewData` | `support_chat.dart` |
| `BonusesScreen` | `BonusesViewData` | `rewards_hub.dart` |
| `DiagnosticsScreen` | `DiagnosticsViewData` | `client_diagnostics.dart`; raw evidence behind «Технические детали» |

Notes for the integration:

- Font family is `packages/pokrov_app_ui/Golos Text`; this package owns the bundled font files used by the shell.
- The connected state repeats soft waves around the button (reduced motion stops them). The same motion rule is documented in [DESIGN.md](../../DESIGN.md).
- The support code must already be masked when it reaches `DiagnosticsViewData`.
