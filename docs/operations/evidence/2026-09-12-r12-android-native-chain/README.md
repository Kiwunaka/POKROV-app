# Android native-input support chain and crash recovery — 2026-09-12

Document class: EVIDENCE. [Receipt, exact source and hashes](receipt.json).

Owned LDPlayer14 index3, client2c370af8/Core6b271dec, production-signed x86_64
QA APK8dc6c2e6. Only this fixture temporarily enabled root. Its current valid
profile/preferences were verified and copied inside the guest to an app-owned
0700 directory/0600 files. No live profile was exported. Nine synthetic marker
categories were combined into one invalid outbound type with the correct staged
profile digest: credential, authorization, cookie, config, URL, IP, path, PII and
provider data. The actual foreground-service restore path reached session_started
then failed without TUN. The same process opened the app showing connection
failure and a safe diagnostic preview. No force-stop occurred between the native
failure and the completed support upload/admin scan.

Both complete values and their distinguishing fragments (17 needles) are absent
from the native journal, operational events, previous-exit marker, available
app-PID logcat and current UI. The original full-value scan is also retained.
Under a normal confirmed L2 signed policy, ordinary consent and Create produced
case64: validated2787-byte ciphertext,1722-byte plaintext/four files. Audited
HTTPS search/detail/download and worker-key in-memory decryption show no needles
in any file or metadata. Build identity is4053/direct. The network summary is
blocked with unknown DNS/egress/host health; absent pre-UI attempt phase/reason
remain null/unknown. No timeline file exists for this background-before-UI path,
and no causal attempt correlation is claimed. This complements the prior six
separate native failure inputs; it is one combined parser-failure path, not every
possible native sink/error. No private key, plaintext bundle or credential is
exported; operator fixture revoked, old sessions unchanged, case64 left open.

Mode was disabled normally. Profile/preferences were restored byte-exact inside
the guest, then the fixture stopped and root=false was restored with all other
current config fields unchanged. Next boot confirms guest su127. Ordinary VPN
works again: nine of ten HTTPS probes pass, one SocketException is retained, and
three follow-up probes pass without reconnect. This is not a10/10 pass. Ordinary
disconnect removes TUN/service and restores IPv4/DNS hashes plus IPv6 full text
after normalizing only its observed expiry countdown.

## Separate controlled process crash

In that rootless boot, a new ordinary connection is established. Android's
`am crash --user current` targets the verified own-package PID. Its actual fatal
RemoteServiceException terminates that PID. TUN disappears and route/DNS state
returns to baseline. Android retains a ServiceRecord whose app=null; the earlier
network helper's vpn_service_running field detects record presence, not a live
service process. That original capture is preserved with the explicit corrected
interpretation in crash/result.json. The app relaunches disconnected; ordinary
Connect works, three HTTPS probes pass, and Disconnect removes both TUN and the
service record. Native crash-marker/stack collection and crash-bundle readback
remain unproven, as does the hang matrix. No raw stack/logcat is exported.

Both boots end stopped with less than512MiB growth and sampled C/E free above
40GiB, other disks unchanged, host route/DNS hashes unchanged, root disabled.
The physical phone and Hiddify are untouched. Complete final packages, full
privacy/observability matrix, licensing and release acceptance remain open.
