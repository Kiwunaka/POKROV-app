# Current Windows egress failure, 2026-09-09

**FAIL_EGRESS_UNCONFIRMED.** Installed client `c05b58b` / Core `c7a11f7`
matched all 304 package files in the [installation readback](../2026-09-09-r12-installed-current/README.md).
The current-origin owned Windows VM cannot establish the ordinary Milan or
Frankfurt connection. This is neither a new release candidate nor a PASS for
Windows connectivity. [Receipt](receipt.json) binds captures and instruments.

## Findings

The VM started with its virtual NIC disabled. After a graceful shutdown, NAT
was enabled and read back before boot. The isolated installation's expired
access received one day through the existing `user.extend` action-intent path.
No payment or refund occurred. Server readback later found that provisioning
reported six successful nodes out of seven; it was a partial sync. The exact
owned client is enabled on both tested nodes, and its UUID matches the backend
user and node mapping. Both report zero traffic and no last-online time.

Milan and Frankfurt UI attempts failed with `core_egress_probe_failed`; service
status returned to `config_staged`, running/DNS/egress false, and the TUN adapter
was removed. Later CLI attempts invoked the same installed service and retained
the failures. The CLI status tool's `client_source=0218e89` identifies that
instrument, not the installed product source above.

- The copied service WinHTTP probe, with diagnostic output and a static C++
  runtime, passed outside the tunnel in 219 ms: HTTP 204 and the expected marker.
- With `tun0` present, the same probe reported WinHTTP 12002 twice and 12007
  once. These mean timeout and unresolved name, respectively, according to
  [Microsoft's WinHTTP error reference](https://learn.microsoft.com/en-us/windows/win32/winhttp/error-messages).
- A separate request used the API address resolved before connection, retained
  HTTPS certificate validation, and returned curl 35 / HTTP 000 while TUN was
  still present. The following DNS query returned no address while TUN remained.
- The Core mixed listener on `127.0.0.1:12334` existed. A SOCKS5 remote-DNS request
  failed with curl 97 / HTTP 000 before tunnel rollback. The failure therefore
  is not explained solely by the Windows resolver or by a missing mixed listener.
- Frankfurt's nine panel inbound comparisons passed. Milan's configured port
  and panel inbound port differ (443 / 10443); this alone does not establish a
  delivery defect because the external forwarding path has not been compared.

The evidence narrows the next check to Core's transport/configuration failure;
it does not establish the root cause. No product code, DNS/route policy or
server keys were changed by these diagnostics.

## Instruments and remaining action

Host scripts and the compiled probe are retained under
`E:/r12-win-egress-20260909`; guest commands use the existing UUID-guarded
`E:/r12-windows-managed-20260908/invoke.ps1` and `copy.ps1` wrappers.
The relevant commands are `sample-tunnel.ps1`, `isolate-dns-v2.ps1`,
`isolate-socks.ps1`, `read-panels.py`, `read-inbounds.py` and
`read-panel-traffic.py`. Only safe projections were exported.

The first standalone probe could not start without its dynamic C++ runtime;
rebuilding the diagnostic with the static runtime resolved that instrument
problem. The first DNS-isolation script stopped on PowerShell's treatment of
native stderr; v2 retained curl's failure and completed the sample. Neither
instrument failure is attributed to the installed package. Captures in UTF-16
or UTF-8 with BOM are normalized to UTF-8/LF, with original and normalized
hashes both recorded.

Automated elevation of a protected-log reader was rejected with
`blocked by policy`, before execution. The owner was asked to run the prepared
read-only `C:/Users/Public/R12Current/read-protected.ps1` in the VM. Its output
excludes credentials and raw profiles. That readback and the product fix remain
pending. The VM remains running with NAT for this pending step; restoration to
its prior offline state is still required after testing. Huawei is disconnected
from ADB, so its post-subscription-fix readback and installed AWG checks remain
open.

Verification: `pwsh -NoProfile -File scripts/validate-seed.ps1 -PlatformRoot
C:/Users/kiwun/Documents/ai/VPN-consolidated-plan-start -CoreRoot
E:/r12core-implementation` — PASS, including the client docs contract.
All 15 retained hashes/JSON inputs and eight local instrument hashes matched.
`git diff --check` — PASS; no product source or `artifacts/releases/**` delta.
