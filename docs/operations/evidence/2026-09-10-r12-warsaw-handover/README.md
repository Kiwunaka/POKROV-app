# Warsaw whitelist retest and physical network handover

**RETEST_PASS_BOUNDED_PREVIOUS_FAILURE_RETAINED**, 2026-09-10 MSK / UTC
2026-09-09. Same installed client `c05b58b`, ARM64 `d030288a…f510`, Huawei API31.
[Receipt](receipt.json) binds the current result; the earlier
[egress failure](../2026-09-09-r12-installed-current/android-first-connect.json)
remains unchanged. No product or node configuration was changed for this retest;
the cause of the earlier failure is not established.

The primary Warsaw “Белые списки” variant was selected in the actual app.
After connection and a protection refresh, the app confirmed tunnel, DNS and
VPN egress. The same result held on all three physical-network samples:

| Sample | Active default network | Radio report | Foreground service / PID |
| --- | --- | --- | --- |
| Wi-Fi | 297 / WIFI | LTE,LTE available | present / 25433 |
| Mobile, Wi-Fi disabled | 303 / CELLULAR | LTE,LTE | present / 25433 |
| Wi-Fi restored | 305 / WIFI | LTE,LTE available | present / 25433 |

The collector matches the active default network ID to its exact
NetworkAgentInfo record. This does not reuse the broad list of network request
capabilities as evidence of a physical transition. Native TUN/service and the
app's own protection proof are retained; there is no independent egress/DNS leak
capture, no demonstration of an active carrier whitelist block and no complete
IPv6/NAT64/UDP53/MTU acceptance.

Disconnect removed the service/TUN and restored the route hash. Two of 20
policy-rule hashes changed. Replacing only fwmark low 16 bits 305 with the
previous Android default-network ID 297 reproduces every original rule hash;
all other bytes stay unchanged. Raw equality is recorded as false, with the
separate bounded network-ID explanation, rather than relabelled as an exact match.

Frankfurt ordinary / selected-app routing was restored. The first assertion
expected the home label to change immediately while disconnected and failed.
The locations screen already selected Frankfurt; source `_homeLocationLabel`
keeps the last verified city until successful application. Reconnecting applied
Frankfurt, confirmed protection and changed the home label; final disconnect
left VPN off, no TUN, Wi-Fi/mobile restored, unchanged APK and routes, with only
the independently explained Android network-ID rule difference above.

Run `python warsaw-handover.py` and `python restore-frankfurt-v3.py` using the
[shared task-local collector](../2026-09-10-r12-huawei-current/README.md).
All taps use fresh accessibility-tree bounds. No raw UI XML, profile, session,
account identity or customer/provider data is stored in this evidence.

D02/N03/N08 and final release stay open for the rest of their defined matrix.
The earlier Warsaw failure is currently not reproduced on these available
Wi-Fi/cellular paths; this is not a root-cause fix or a stability guarantee.

Validation: `pwsh.exe -File scripts/validate-seed.ps1 -PlatformRoot C:/Users/kiwun/Documents/ai/VPN-consolidated-plan-start -CoreRoot E:/r12core-implementation` — PASS, including client docs contract; [log](client-seed.log). `git diff --check` — PASS. No release-artifact changes.
