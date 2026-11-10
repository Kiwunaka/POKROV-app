# pokrov_app_ui

The app uses four tabs (Защита, Доступ, Помощь, Настройки), configurable shortcuts on the protection screen and one settings search.

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
| `HomeScreen` | `HomeViewData`, `HomeTile` | `home_surface.dart`, `home_tiles.dart` |
| `HomeTilesSheet` | `HomeTileOption` | `home_tiles.dart`; choice saved by `PokrovFileHomeTilesStore` |
| `StatusSheet` | `StatusViewData` | protection center checks, mapped to three plain rows |
| `LocationsScreen` | `LocationsViewData` | `locations_surface.dart` |
| `RulesScreen` | `RulesViewData` | `rules_surface.dart`; page «Что идёт через POKROV», expert settings behind «Для опытных» |
| `AccessScreen` | `AccessViewData` | `profile_surface.dart` (`_ProfilePart.access`) |
| `HelpScreen` | phase and callbacks | `help_surface.dart` |
| `SettingsScreen` | `SettingsEntry` | `profile_surface.dart` (`_ProfilePart.settings`) |
| `RenewScreen` | `RenewViewData` | tariffs from the platform catalog; payment opens the existing checkout URL |
| `SupportScreen` | `SupportViewData` | `support_chat.dart` |
| `BonusesScreen` | `BonusesViewData` | `rewards_hub.dart` |
| `DiagnosticsScreen` | `DiagnosticsViewData` | `client_diagnostics.dart`; raw evidence behind «Технические детали» |

Notes for the integration:

- Fonts are shared with the cabinet and site: Onest for text (`pokrovFontFamily`) and Unbounded for titles and the wordmark (`pokrovDisplayFontFamily`). The static TTF weights were cut from the OFL variable fonts; licenses are in `assets/fonts/OFL-*.txt`.
- The connected state repeats soft waves around the button (reduced motion stops them). The same motion rule is documented in [DESIGN.md](../../DESIGN.md).
- The support code must already be masked when it reaches `DiagnosticsViewData`.
