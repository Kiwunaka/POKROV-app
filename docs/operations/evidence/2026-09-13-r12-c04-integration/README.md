# C04 Windows integration and Android preparation

Registry class: `EVIDENCE`. [Exact results](acceptance.json).

Windows activity fix 0651e83 was promoted by [PR 137](https://github.com/Kiwunaka/POKROV-app/pull/137) to
main `780dba6fe72179b8e9f005b70aebba1995e55014`. Signed exact tree and both required CI runs pass;
code/test bytes match the retained 440-sample VM proof. No new release claim.

An isolated x86_64 Android profile companion was built and its Core hash checked.
Two owned LDPlayer boots never exposed ADB, so it was not installed or launched
and no Android samples were captured. SDK acceleration also lacks its driver.
All local emulators stopped, root stayed false, host route/DNS hashes match.
Generated emulator config changes are retained; full config equality is not
claimed. No device data, production signing, server or account mutation.

The UI reads traffic only on diagnostic collection; Android's native counter
stream is 1 Hz and Windows exposes no numeric rates. A source cadence experiment
on unchanged Core 0138 passes 73 samples at1/2/4 Hz with synthetic manager inputs;
all deltas match cumulative totals. Device/UI2–4Hz and overhead comparisons
remain NOT_RUN. C04 remains active/I3 with reference Android and remaining
runtime/performance proof open. [Validation](validation.json).
