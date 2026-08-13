# POKROV 1.0.3 beta.1

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

- centered Android connection control, finite wait state and compact status pill;
- honest five-day trial and explicit paid-only rewards;
- 14-day conservative roulette, Telegram +5 days and referral +10 days after the first held payment;
- compact checkout with 99 / 239 / 669 / 1199 / 1699 / 1999 ruble plans;
- manual locations, device latency refresh, flags, load and freshness;
- per-app routing, direct-RU controls, WARP guidance and Android system surfaces;
- native support flow with the exact `deepseek/deepseek-v4-flash-0731` route;
- remote in-app campaign card controlled from admin without an app update.

## Evidence limits

The exact Android x86_64 candidate passed signed update-install and UI/API QA in
LDPlayer. The exact Windows bundle passed packaging, manifest/hash checks and
launch smoke. Huawei tunnel, WARP, per-app egress, Quick Settings and notification
proof remain `MANUAL_OWNER_TEST`; LDPlayer is not tunnel-core evidence.
