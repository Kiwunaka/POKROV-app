# R12-F03 motion and native input evidence

Client source `c6f0e0b36f23cdcf01201792657001f024341889`; signed source PR136,
merged main `e8866f9d9a14bbd806eed3a6d24942862b60a0bb`. Source file bytes match.
PR and main CI pass; exact integration is retained in integration.json.

The connected breath loop was replaced by the existing finite animation.
The verified-egress widget with production loops times out before the fix and
passes afterward. Five focused shell cases and 40 design/haptic cases pass;
app_shell analyze and validate-seed pass. Busy loading retains its sweep.

Android: source-bound signed x64 APK; native tabs, profile swipe, focused
EditText and synthetic input/clear without submit. Connected motion is widget
proof; a separate native idle screenshot comparison did not complete because
the modal remained after Back. Root stayed off; the F03 starting configuration
was restored byte for byte. This does not restore older A07 metadata history.

Windows: current normal app entrypoint in a profile bundle on an offline
Windows11 VM; native click, Ctrl+1/4, wheel, focused text input, Tab, clear and
Escape. UIA only exposed FlutterView; no full accessibility-tree pass is claimed.
The independent fixture matches 301 built files plus three existing VC runtime
DLLs. All 304 installed release files match the F03 starting baseline afterward.
Before any fixture action, installed data/app.so differed from the earlier
receipt; that unexplained earlier change is retained, not repaired or relabelled.

The local production marketing check proves visible no-JS content and a static
reduced-motion showcase. Both VMs are stopped and host routes/DNS unchanged.
No final release candidate, physical device, public deployment or store claim.
The platform work order retains full commands, screenshots, failures and hashes.
