# POKROV Core Hysteria2 Pre-Candidate Binding

Status: refreshed locally on 2026-08-29 for POKROV `1.2.0+4046`; no candidate,
tag, publication or promotion was created.

## Decision

Android binds POKROV Core `1.1.0` commit
`3c2b1147c1b42e39026231525c08558a50bc3d0f`. This additive source change keeps
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
| Size | `107408874` bytes |
| SHA-256 | `b42a548910b7369f64fcd484c5acf74180583d77299629ce4d2f9156fc598007` |
| ABI set | `armeabi-v7a`, `arm64-v8a`, `x86`, `x86_64` |
| Reproducibility | `PASS_BYTE_IDENTICAL_TWO_BUILDS` |

Windows now binds the same Core commit through `pokrov-core.dll`, size
`55417856`, SHA-256
`58e329eaddb2dd1f40c1663b380a03a0c7c34c5a3e8506eb2c692611234ac082`.
Two builds are byte-identical and expose all 15 required ABI symbols. This
closes local platform-source convergence only. Physical-device source/artifact launch evidence may prove
default-off safety, but Hysteria2 connectivity remains `MANUAL_OWNER_TEST`
until an owned exact server artifact and encrypted endpoint material exist.
