# Client product behavior

POKROV is the Android and Windows client for the managed service. [Design](../../DESIGN.md) owns the four tabs and screen presentation. [Platform API contracts](../../../VPN/docs/architecture/api-contracts.md) own account access, payment and reward decisions.

- **Защита** starts, cancels or stops the active connection. It shows protection after the app verifies the chosen route's egress. The user can choose eligible locations and arrange the home screen shortcuts. Availability comes from the current account and route data. A cached list or ping cannot grant access or prove protection.
- **Доступ** shows remaining access, account, devices, purchase/renewal and rewards. Checkout is hosted and access refreshes from the server. Private credentials and profiles stay outside UI and logs.
- **Помощь** offers a connection check, guidance and the support flow. Sending a diagnostic bundle is explicit. Tickets and operator actions remain owned by the Platform support service.
- **Настройки** groups routing and app controls, diagnostics and updates. Full and selective protection keep their distinct meaning. If a selected route is unavailable, preserve the choice and explain what the user can change. WARP is a separate user choice with its own proof. [Smart Access](../architecture/smart-access-dns.md) requires eligible signed provider scope.

See [onboarding](../architecture/app-first-onboarding-flow.md) for account entry and [bootstrap](../architecture/bootstrap-workflow.md) for runtime and update behavior.
