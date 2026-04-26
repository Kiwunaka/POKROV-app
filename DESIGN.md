---
name: POKROV Client Design System
status: active
updated: 2026-04-26
---

# POKROV Client Design System

POKROV client UI should feel calm, premium, and operationally honest.

## Principles

- One-tap connection is the primary app affordance.
- Consumer copy avoids raw transport jargon.
- Diagnostics are available behind details, not first-layer UI.
- Android and Windows availability labels must reflect gate status.
- Motion should be quiet and respect reduced-motion settings.

## Tokens

Client tokens must stay aligned with the platform `shared/design-tokens.json` and `shared/design-tokens.schema.json` sources until a generated Flutter export exists.

## Components

- Protection connect surface.
- Location list with beta/fallback states.
- Rules and route-mode picker.
- Profile with subscription, devices, support, and settings.
- Warning and blocked-state panels.

## Do Not

- Do not present Android as public-safe before the physical audit.
- Do not expose raw configs or local control surfaces in consumer UI.
- Do not use generated images as release evidence.
- Do not use direct public product wording with `VPN` except legacy compatibility labels or unavoidable identifiers.
