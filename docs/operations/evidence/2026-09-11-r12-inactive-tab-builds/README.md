# C04 — inactive tab builds, 2026-09-11

Class: EVIDENCE. [Receipt, source identity and capture hashes](receipt.json).
Tested `9b97fec`; signed PR source `b3e435c`, identical product tree.

An opened Profile was reconstructed by `_LazyIndexedStack` whenever the shared
shell rebuilt, even while another tab was visible. Offstage/TickerMode and a
repaint boundary did not prevent that widget build. The existing Windows
service-status test now uses Flutter's rebuild observer: before the fix it
fails with one hidden Profile build after a health change; after the fix it
observes zero on both loss and recovery. Reopening Profile displays the latest
health state. This measures actual Flutter widget builds with synthetic host
snapshots; it is not a physical-device CPU/frame/battery measurement.

The existing stack retains widget configurations for inactive tabs and invokes
the latest builder for the selected tab. The nullable cache replaces the prior
initialization flags. Opened elements, local state, Offstage, TickerMode and
RepaintBoundary stay in place. Root and part count, dependencies and polling
cadence are unchanged. Runtime traffic stats already use a separate path;
this fix concerns hidden content rebuilt after shell status updates.

Commands from `packages/app_shell`:

- `flutter test test/pokrov_seed_app_test.dart --plain-name "windows observes service loss after a long connected session" --reporter expanded`: original FAIL retained.
- `flutter test test/pokrov_seed_app_test.dart --name "windows observes service loss after a long connected session|seed shell lazily builds tabs and keeps opened tabs alive|tab changes animate through the shared tab transition wrapper" --reporter expanded`: 3 PASS.
- `flutter test --no-pub test/pokrov_seed_app_test.dart --reporter expanded`: 191 PASS, including navigation, hidden tab state, status and deterministic critical-state goldens.
- `flutter analyze --no-pub`: PASS, no issues.

Client root `validate-seed.ps1` with explicit platform/Core roots and
`test/docs-contract.ps1` pass for the checked source. CI/promotion and evidence
documentation verification are recorded after completion. No new Windows or
Android package, VM run, phone action, Core library or public release occurred.
C04 remains open for its traffic experiment, reference Android/Windows traces,
C03 dependency and packaged acceptance. No CPU/frame improvement is claimed.

Source delivery: PR114 merged `d9763e8cd7aba9b215015e07c0576f667c1dec09`, signed source
`b3e435cf9036049d416a9895f7fb400502990aee`, same tree and verified signature. Exact PR and
merge Release v2 Contract CI both PASS. Current evidence docs: client docs
contract, 33 platform docs checks, platform-context audit, local links and
`git diff --check` PASS. [Validation capture hashes](validation.json).
Documentation/evidence commits remain local. No new installable package or
device performance acceptance; installed Windows remains `7ed18c9 / Core904`.
