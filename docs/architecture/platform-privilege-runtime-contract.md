# Host privileges and native runtime

The Flutter shell owns user intent, candidate selection and presentation. The platform host owns OS permission, native process lifetime, network changes and delivery of bound results. The installed Core identifies its own capabilities. Both the host and Core must support a transport before the client can use it.

## Windows

The interactive process is unprivileged. An installed service owns the tunnel, routes, DNS and scoped cleanup. The service control channel is local and authenticated. Restrict commands and request sizes and bind them to the requesting local user and operation. Activation and tray actions are separate from privileged runtime commands.

The service snapshots settings before applying its network transaction. On failure or stop it restores owned interface, address, route and DNS state. An interrupted start is resolved within that transaction before another owner can apply changes. A native result is applied only to the expected runtime, prepared profile and operation. A tray process or readiness check does not establish a usable VPN.

## Android

The OS grants VPN consent and the foreground VPN service owns the tunnel. It protects transport sockets and uses the captured physical network for bound routing and DNS. A change to that uplink invalidates an in-flight result that belongs to the old network. Staging, start, stop, proof and state reattachment use the matching profile and service identity. Closing the Flutter UI does not transfer service ownership or cancel an otherwise valid active tunnel.

## Other hosts

Linux's private daemon path uses a local authenticated boundary and a separate platform network transaction. Apple hosts use their own signing, entitlements and VPN permissions. These hosts are engineering/readiness paths. The [repository map](folder-structure.md) links the host-specific code.

## Signed route and transport enforcement

The shell chooses a compatible mode and supplies only the current verified policy and profile. Native prepare/start, stop, proof, restriction and renewal commands are bound to the admitted Core/runtime identity. Grants are valid only for the negotiated device, network, scope and lifetime. Store a pending proof with its binding and recheck native state after UI restart before presenting it as active. Late events cannot promote another attempt or overwrite a newer restriction. A permission error is distinct from a network or transport failure.

Report only closed status and failure fields. Raw profiles, network secrets, runtime command output and session credentials stay out of diagnostics and UI.
