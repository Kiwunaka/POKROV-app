# Windows transport: NAT failure, bridged success

**PASS_BOUNDED_TRANSPORT_PATH_ISOLATION**, client `c05b58b268bbd789aa96fb662cb46c9768558ef0`,
Core `c7a11f7d2fd974726095ad7aa0619c055273dd15`, current-origin owned Win11 VM.
All 304 installed package files still match. This follow-up narrows the
[earlier egress failure](../2026-09-09-r12-windows-egress/README.md); it does
not prove a complete connection through the installed service or a release.
[Receipt](receipt.json) binds 23 safe captures and 16 retained instruments.

## Controlled result

The ordinary Frankfurt outbound was read from the owned user's existing
DPAPI-protected cache in its normal user context. Raw profile material stayed
in memory and was passed to an isolated Core probe over stdin. No TUN was
created and no saved profile, ACL or credential was changed.

| Path | Result | Probe time |
| --- | --- | ---: |
| VM NAT, original profile | `reality verification failed` | 156 ms |
| Same Windows probe through temporary SSH to owned DE loopback | HTTPS response received | 267 ms |
| VM bridge through physical Ethernet | HTTPS response received | 340 ms |
| NAT repeated after Windows Update | `reality verification failed` | 164 ms |
| Bridge repeated in the same boot | HTTPS response received | 252 ms |

The last two runs used the same original profile SHA-256
`716567a5451a9993a6f5e44d6c24a86a9966aae0c4f1a3979a09ab7b794299d2` and the same
probe binary. The repeat after Windows Update prevents the OS restart from
being mistaken for the cause of the improvement. The standalone URLTest
requires a successful connection and HTTPS response, but does not check the
response status or marker; these results are transport proof only.

Chrome fingerprint, the second direct Frankfurt variant, minimal TLS options
and an explicit resolved IPv4 address did not fix the NAT path. DNS resolves
to an address assigned to the owned DE node. UUID, public key, short ID and SNI
match the generated Xray inbound. Port 443 is served by Xray; its time/version
limits and the inspected iptables NAT rules do not explain the failure.

Separate **owned-de-loopback** controls passed with Xray 26.6.1 (`94ffd50`)
and a Linux build of the same Core probe. Xray's SOCKS control returned HTTP
204 from the owned authenticated-egress endpoint. Neither origin proves the
Windows TUN path. The temporary Xray client was stopped and the temporary
Linux probe removed. The host SSH tunnel was stopped after its control run.

The host had Hiddify and `tun0` active. Its two inspected configuration files
retained their hashes. The evidence isolates the failure to the NAT path
through this host; it does not identify a particular Hiddify, VirtualBox or
upstream sniffing defect. No product fix is justified by this failure alone.

## Installed-client boundary and next action

After the graceful restart, Windows installed updates and reached its login
screen. The installed POKROV service is Running, but reports `artifact_ready`:
no staged profile, no running Core, no DNS/egress proof. The owner must log in
before the pending UI-driven staging and full connection check. No Windows
authentication dialog was automated. The instrument's `client_source=0218e89`
is not the installed product source.

The VM remains running with its bridged adapter's cable **disconnected** while
waiting for login. Re-enable that link for the pending check, then restore the
original powered-off/NIC-none baseline. Host networking, Hiddify settings,
server configuration, keys and release artifacts were not changed.

Reproduction uses the UUID-guarded `invoke.ps1` / `copy.ps1` wrappers under
`E:/r12-windows-managed-20260908` and the instruments bound in the receipt.
The Windows probe was built from the exact Core worktree with Go 1.26.8,
`CGO_ENABLED=0`, `-trimpath -tags with_utls -ldflags "-s -w"`; the Linux control
additionally used `GOOS=linux GOARCH=amd64`. Original captures remain outside
Git; retained text is normalized to UTF-8/LF with both hashes recorded.

Verification: `pwsh -NoProfile -File scripts/validate-seed.ps1 -PlatformRoot
C:/Users/kiwun/Documents/ai/VPN-consolidated-plan-start -CoreRoot
E:/r12core-implementation` — PASS, including the client docs contract.
Capture hashes/JSON and the A/B assertions passed; `git diff --check` passed.
There is no `artifacts/releases/**` delta.
