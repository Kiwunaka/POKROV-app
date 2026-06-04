# Client Design Notes

Status: active  
Last updated: 2026-06-03

The root `DESIGN.md` in this repo is the client design source for the Open Beta v4 wave. This file tracks client-specific implementation notes and screenshot evidence.

The platform design source for this branch lands with `C:/Users/kiwun/Documents/ai/VPN/DESIGN.md`, with machine-readable tokens in `C:/Users/kiwun/Documents/ai/VPN/shared/design-tokens.json`. Until that platform branch is merged, the existing shared token JSON remains the minimum active baseline.

## Current V2 Direction

The next Android/Windows client UI pass must start from
`docs/design/2026-06-03-client-premium-shell-v2-brief.md`.

That brief is an owner-feedback override after the first MVP shell was rejected
as too card-heavy, text-heavy, mobile-stretched, and not premium enough. When it
conflicts with earlier `Quiet Emerald` notes, the Premium Shell V2 brief wins
for the next implementation pass.

## Screenshot Plan

- Android small phone.
- Android common phone.
- Windows compact window.
- Windows wide window.
- Profile, support, route-mode, and subscription states.
- Outside-store beta download available and account-gated unavailable states.
- Android audit `OPERATOR_ATTESTED` beta state plus raw-audit manual-test state.
- Windows unsigned beta warning state.

## Evidence Rule

Screenshots may show UI states, but must not show raw configs, secrets, tokens, private links, payment customer data, or full user identifiers.
