# R12-L04 — exact package10 acceptance

`VERIFIED / I4 / ALREADY_FIXED` for the declared conditional Ubuntu24.04
amd64 beta. This accepts the install/update/remove, permissions, non-root UI,
DNS, IPv6 and full/RU-mode scenario. It does not publish Linux or expand its
support matrix. Source promotion is recorded separately after its PR/CI gates.

The signed `pokrov_1.2.0~beta.30-10_amd64.deb` is 30,992,518 bytes,
SHA256 `d4c3ead8786cfdd91ff7851e3634d7025e899323db13636803f3064551628f17`.
Its detached signature verifies with the existing conditional-beta signer
`29636EDAF204D6F6101CB083B2281E647B0EDDA0`; distribution archive trust is not
claimed. UI source is `361b0e4`, daemon/packaging source is `318801a`
(unchanged at the UI revision), and Core source is `86aca40`.

The [receipt](receipt.json) identifies all source/artifact hashes, custody,
checks and limitations. [proof.zip](proof.zip) retains 47 named receipts,
build/test logs, scripts and desktop captures with an internal hash manifest.
Private profiles, keys and raw packet contents are excluded.

## Results

The owned MINI QEMU guest runs Ubuntu24.04.4 amd64, Xfce/X11 and LightDM with
systemd, NetworkManager, resolved and nftables. Results belong to this guest
origin, not RU-origin. The original clean installation and earlier recovery
evidence keep their original package identities.

| Scenario | Exact package10 result |
| --- | --- |
| Connected 9→10 upgrade | APT exit0; all302 installed entries and permissions match; profile/keyring retained; account/mode read back in the new GUI |
| Ordinary desktop use | UID1000 GUI, real production polkit prompt; no persistent sudo UI or fixture authorization grant |
| Full/RU routing | Both GUI sessions pass app HTTPS200, API marker204, system DNS and owned IPv6 reject; exact captured profiles give full0 versus RU3 direct SYN packets on the physical interface |
| Connected purge | APT exit0; units, socket, binaries and processes removed; profile/settings/keyring bytes preserved; seven network baselines restored |
| Reinstall | Normal APT installation of the same signed bytes; all302 installed entries verified; socket root:0666, state root:0700; private state preserved |
| Reinstalled GUI recovery | Connect/HTTPS204, Core SIGKILL, restored network and visible error, GUI Retry/reconnect, final disconnect; health evidence clears after stop/crash |

The runtime fixes supply bounded DNS and selected-proxy-leaf HTTPS health
after network setup and use the direct IPv4 resolver for Linux proxy endpoint
bootstrap. Otherwise resolving that endpoint through resolved's redirected
DNS can depend on a tunnel that has not connected yet. Existing 13 bootstrap
tests and focused native Core/service tests pass; build and seed logs are retained.

## Failed observations and limits

The upgrade observer returned `FAIL` for a changing live GUI settings-file hash.
That receipt remains intact. The migration conclusion uses profile/keyring
hashes, functional account/mode readback and unchanged schema; it does not
claim byte-identical live settings or invent the cause of that write. Closing
the GUI before purge/reinstall allowed all settings bytes to be compared and
preserved.

An automatic path failed HTTPS with curl35. The selected Frankfurt ordinary
path passed in both modes. One RU GUI start reported failed initial DNS health
although its subsequent DNS/HTTPS worked; the exact saved profile passed both
health checks in later isolated fixtures. Health records establishment, not
continuous monitoring. These failures are retained and do not become an
all-endpoint, automatic-selection or uninterrupted-network claim.

The initial route observer counted unrelated proxy endpoint connections at the
same address/443. Port22/80 established-socket attempts were inconclusive;
the first packet observer also used an incoming-only protocol subscription.
The final physical-interface `ETH_P_ALL` observation excludes all proxy ports
and proves the full/RU difference without retaining packets. Earlier failed
and inconclusive records remain in the archive.

The Core recovery receipt inherited a misleading “read-only observer” label.
Its actual script performs one scoped root SIGKILL of the owned Core child;
connect, reconnect and disconnect are ordinary GUI/polkit actions. Root IPC
profile replay belongs only to the separately labelled routing diagnostics.

L03's prior crash/suspend/reboot, partial rollback and negative authorization
evidence is not relabelled as package10. The affected Core-health/GUI recovery
path was repeated here. No public release, alternate desktop/distro/architecture,
distribution signing trust or final Android/Windows matrix is implied.
