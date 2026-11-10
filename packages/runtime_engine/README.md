# POKROV runtime engine

This package validates and materializes managed profiles, negotiates Core and native host capabilities and supplies runtime lifecycle and probe adapters. The shell owns the account, user intent, current operation and result presentation. The platform host owns OS permissions and network changes.

Use the [bootstrap workflow](../../docs/architecture/bootstrap-workflow.md) for preparation and the [host contract](../../docs/architecture/platform-privilege-runtime-contract.md) for native behavior. The [build scripts](../../scripts/README.md#runtime-selection) select the local Core binding.

Candidate diagnostics keep closed operation, stage and cause fields. Missing egress proof never becomes success. Pass only the redacted result through logging or support. Run the focused Flutter test for the changed runtime behavior from this package.
