# Platform Contracts

Current responsibility:

- engine selection contract
- connect and disconnect lifecycle contracts
- permissions and elevation contracts
- platform adapter interfaces and host capability boundaries

The bootstrap contract describes the host, required permissions, runtime-core
defaults and selected-app routing capability. See
[lib/platform_contracts.dart](lib/platform_contracts.dart) and the
[platform privilege/runtime contract](../../docs/architecture/platform-privilege-runtime-contract.md).

Host capabilities do not by themselves prove device acceptance or publication;
those remain in [cutover readiness](../../docs/operations/cutover-readiness.md).
