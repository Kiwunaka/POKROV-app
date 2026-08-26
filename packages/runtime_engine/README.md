# POKROV Runtime Engine

This package carries the non-UI runtime lane for the Wave 7 next-client program.

Current scope:

- POKROV Core desktop ABI 2 negotiation for `Windows` and `macOS`
- artifact discovery from local host folders or `POKROV_CORE_ROOT`
- staging and starting a managed profile payload once a real config exists
- native runtime bridges for `Windows`, `Android`, and the partial `iOS` lane
- fail-closed capability/event ABI negotiation; the exact retained 1.0.3
  identity remains an explicit legacy mode, while release 1.2.0 requires the
  structured operational-event capability
- Core `1.1.0` is the exact reproducible `PRE_CANDIDATE_LOCAL` replacement
  bound for product `1.2.0`; it does not claim a tag, signed candidate or
  publication
- private, separate `awg2_lab` and `awg31_lab` boundaries for Android and
  Windows: an `awg` endpoint is accepted only with the exact contract ID/SHA,
  an enabled generation marker and `useIntegratedTun=false`; AWG 3.1 also
  requires its explicit endpoint contract ID. Host metadata is stripped before
  Core sees the sing-box JSON

Current limits:

- iOS still needs its complete built framework/device lane
- Apple signing, notarization, and store submission stay outside this package
- the package proves runtime wiring, not production rollout by itself
- AWG source/host tests do not prove an exact AAR/DLL, owned-server
  interoperability, physical-device behavior, battery/thermal behavior or
  mobile/RU-origin reachability
