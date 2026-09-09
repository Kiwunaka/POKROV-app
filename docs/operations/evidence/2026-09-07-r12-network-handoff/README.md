# Huawei network handoff — 2026-09-07

Bounded current-origin observation; [receipt](receipt.json). Same installed ARM64
APK `d849d273…e14d2`, client `9334d46`, Core `8dc57a8`. No app rebuild or install.

The first resumed UI showed protection, but after Wi-Fi disable and a protection
refresh the native service was absent. Its native pre-handoff baseline was not
recorded. This remains an unresolved observation, not a proven code regression
or a discarded failure. An explicit Wi-Fi retry restored the connection.

The controlled repeat asserts native service/TUN before switching. Samples at
0/10/20/30 seconds on mobile and 0/10/20/30 after restoring Wi-Fi retain the same
PID, foreground VPN service and TUN. No connect/disconnect action occurs during
that sequence. A separate mobile repeat with explicit protection refresh retains
the service; the app confirms tunnel/DNS/VPN egress on mobile. The protection
refresh after restored Wi-Fi also confirms protection. This is the app's
observer evidence, not independent capture, leak or full routing-matrix proof.

Final installed SHA-256 equals the earlier retained ARM64 artifact. Wi-Fi is on
and VPN remains connected, as observed at this slice's start. The earlier D03
slice's final disconnected state remains correct for its earlier time. No user
account, profile, route preferences or battery settings were changed. The first
interruption, IPv6/MTU/UDP53, OEM/API/endurance and final channel remain open.
