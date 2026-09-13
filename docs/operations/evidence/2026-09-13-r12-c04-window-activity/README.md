# C04 Windows native activity evidence

Registry class: `EVIDENCE`. [Exact results](acceptance.json).

**PASS_WINDOWS_HIDDEN_STARTUP_FIX** on client0651e83/Core0138, Flutter3.38.5,
owned offline Windows11 x64 VM build26200. Actual native --startup changes
from hidden ticking on abe95c9 to hidden muted on0651e83. Normal and startup
blur/hide/resume pass; modal retained in440 samples. Initial null lifecycle is
valid before its first event; native inactive after hiding is sufficient.

One exact profile bundle; no synthetic lifecycle or input-queue attachment.
The earlier lifecycle diagnostics do not establish general delivery failure.
No release-installer, CPU/battery/frame or physical-device claim. C04 remains
active/I3: Android, runtime-tick and traffic-rate acceptance are still open.

Installed304 unchanged, fixture305 hashes verified, UI0/service Running/Wintun0;
VM off/NICnone/snapshots13, host network hashes match. Preparation errors and
protocol restoration limits are retained. Raw evidence is in the platform work
order evidence/c04-window-activity-20260913/evidence.zip. Profile ZIPs remain
outside repositories. [Documentation validation](validation.json).
