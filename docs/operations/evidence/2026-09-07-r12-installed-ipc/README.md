# Installed Windows service IPC — 2026-09-07

The exact local installer from the [standard-account lifecycle run](../2026-09-07-r12-standard-installer/README.md)
remains installed in the owned offline Win11 clone. A dedicated protocol probe
runs as its ordinary installation owner R12Standard, with no administrator
membership/elevation. On every connection, its named-pipe server PID matches
the running POKROVService PID in SCM (3084). [Receipt](receipt.json).

Eight cases PASS: ordinary status; replayed nonce rejection; wrong session
rejection; expired deadline rejection; valid status after those failures;
oversized declared frame disconnection; prior-session token rejection; and
valid status in the fresh session after the malformed connection. The same
probe under pokrovtest's filtered non-owner token receives Win32 error 5
(access denied). Elevated administrators are allowed by the existing contract
and are not mislabeled unauthorized by this test.

The independent readback retains all 305 expected installed file hashes,
LocalSystem automatic running service, the same SCM PID, only the two stock
uninstaller files beyond the bundle, and no TUN/up adapter. The helper stays
outside the installation and changes no product, profile or network state.

The first collector's null exit-code FAIL and the five passing response rows
remain retained. Its process-handle capture was corrected; the final eight-case
worker returns exit 0. A guestcontrol credential child produced no result before
desktop login and received no credit. The successful ordinary-user worker was
launched from the logged-in guest desktop. No password or session token is in
the retained reports. Raw protocol bodies are not logged.

Source `46ba68d`, installed bundle source `98c39d6`, Core `8dc57a8`, unsigned
local `1.2.0+4053` with a loopback API. This is actual installed-service protocol
proof; it does not close final-channel W06. Cancellation/concurrent mutation,
WFP/firewall/other-VPN coexistence, managed network and Win10 remain OPEN.
The test uses only hello/status requests and an invalid header. No network
transaction, product source change, new candidate, push, merge or deploy.

The clone remains running offline with its idle installed service. Existing
snapshot, installation, evidence and source branches are preserved. Runtime
commands, exact helper/source hashes and follow-up validation are in the receipt.
