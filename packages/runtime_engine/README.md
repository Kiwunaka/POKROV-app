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
- Core `1.1.0` is the separate `PRE_CANDIDATE_LOCAL` replacement target for
  product `1.2.0`; this label does not claim an artifact or candidate
- a private `awg2_lab` boundary for Android and Windows: an `awg` endpoint is
  accepted only with the exact `pokrov.awg2.endpoint.v1` ID/SHA, an enabled
  generation marker and `useIntegratedTun=false`; host metadata is stripped
  before Core sees the sing-box JSON

Current limits:

- iOS still needs its complete built framework/device lane
- Apple signing, notarization, and store submission stay outside this package
- the package proves runtime wiring, not production rollout by itself
- AWG2 source/host tests do not prove an exact AAR/DLL, physical device,
  battery/thermal behavior or RU-origin reachability
