# POKROV Core Hysteria2 Pre-Candidate Binding

Status: accepted locally on 2026-08-28 for POKROV `1.2.0+4046`; no candidate,
tag, publication or promotion was created.

## Decision

Android binds POKROV Core `1.1.0` commit
`e8eb7721fc6eaac6813d3a888ac90d0da1f541a1`. This additive source change keeps
the existing host-owned TUN architecture and embeds no second transport engine.
It exposes Hysteria2 only through the managed `pokrov.hy2.outbound.v1` contract
already implemented by pinned sing-box `1.13.0` with `with_quic`.

The owner lab is disabled and killed by default. A profile requires an exact
contract hash, an allowlisted active device and platform, fresh encrypted
device-bound material, verified TLS with SNI and ALPN `h3`, one server port and
bounded bandwidth. Raw `hysteria2://` and `hy2://` conversion, port hopping,
insecure TLS, raw node-catalog material and a second TUN are rejected.

## Exact Android And Windows Artifacts

| Field | Value |
| --- | --- |
| Artifact | `pokrov-core.aar` |
| Size | `107390782` bytes |
| SHA-256 | `7c392883ee8a09c15e414a0e9d70a4d4d3cb259032e51c5481cd14a571950745` |
| ABI set | `armeabi-v7a`, `arm64-v8a`, `x86`, `x86_64` |
| Reproducibility | `PASS_BYTE_IDENTICAL_TWO_BUILDS` |

Windows now binds the same Core commit through `pokrov-core.dll`, size
`55403008`, SHA-256
`73aacd2ccbb3414573284c0c2a253f29c6ed4a56ddf2ff8bb6cc9ae7ca371488`.
Two builds are byte-identical and expose all 15 required ABI symbols. This
closes local platform-source convergence only. Physical-device source/artifact launch evidence may prove
default-off safety, but Hysteria2 connectivity remains `MANUAL_OWNER_TEST`
until an owned exact server artifact and encrypted endpoint material exist.
