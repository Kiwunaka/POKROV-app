# Account entry and onboarding

The Platform [API contracts](../../../VPN/docs/architecture/api-contracts.md) own the wire fields and access rules. The client uses its install identity for device-bound sessions and stores credentials in platform secure storage.

- A new user can request a trial. The server decides eligibility and returns the account, session and access snapshot. The app opens the managed connection path after access is granted. The first protected egress check completes connection onboarding.
- A returning user restores the active session or uses the email code, Telegram or one-time cabinet pairing paths. A code opens a confirmation sheet and is consumed only on explicit submit. Malformed or ambiguous pairing links are rejected. Codes stay in memory. For a current same-account session, pairing refreshes account data without consuming another device slot.
- Android opens owned cabinet and help pages with visible origin inside the app. Payment providers, Telegram and downloads are external handoffs. Desktop uses the OS browser. The app rechecks access on return and never treats a payment return URL as payment confirmation.
- A purchase or renewal opens the hosted checkout with the selected plan and the account handoff. The marketing entry starts with checkout. The existing account is resolved by the server, and the authenticated status controls whether access can be used.
- Linking Telegram, claiming a reward and entering a promo are explicit account actions. The app displays the server's balance, eligibility and claim result. It does not create access from a local reward state.
- Acquisition and support handoffs send only their approved bounded context. App store and direct-download links are supplied by the platform download contract.

See [client product behavior](../product/client-product-contract.md) for the screens and [bootstrap](bootstrap-workflow.md) for the connection path.
