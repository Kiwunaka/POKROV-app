# POKROV 1.0.3 beta.2

Direct outside-store beta for Android and Windows.

## Downloads

- Android ARM64 is the default for nearly all current phones.
- Android ARMv7 is the smaller compatibility build for old 32-bit phones.
- Android x86_64 is for emulators, including LDPlayer.
- Android universal is the large fallback when the device ABI is unknown.
- Windows setup is the normal install path; portable ZIP is the secondary path.

All Android APKs are production-signed with certificate SHA-256
`0A0602A7DF5D96A0B427909D004F3DDF26DEF86587634BF16694DA8D654B2500`.
The Windows beta remains unsigned and may show Microsoft SmartScreen.

## Main changes

- fixed a first-load account race that could leave bonuses in an error state;
- roulette, Telegram bonus and referral history now load after subscription refresh;
- removed the duplicated roulette cooldown action;
- shortened the animated connection status so it fits the centered control;
- retained the centered Home, split APK delivery, locations, routing, native support,
  exact DeepSeek Flash 0731 route and remotely managed in-app campaign card.

## Evidence limits

The exact Android x86_64 candidate passed signed update-install, installed-file
SHA-256 equality and UI/API QA in LDPlayer. The exact Windows bundle passed
packaging, manifest/hash checks and build/analyze verification. Huawei tunnel,
WARP, per-app egress, Quick Settings and notification proof remain
`MANUAL_OWNER_TEST`; LDPlayer is not tunnel-core evidence.
