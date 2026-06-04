# P5 WARP Application Map

Date: 2026-06-05
Status: internal design reference / owner-approved direction input
Owner: POKROV-app/main

## Purpose

This file records the generated application-map render requested by the owner
for the P5 premium-motion and WARP planning pass.

The render is a review artifact for Product Design, Creative Production, and
OpenCode consilium critique. It is not a pixel-accurate implementation spec and
not a public or release asset.

## Artifact

- Render: [assets/2026-06-05-p5-warp-application-map.png](assets/2026-06-05-p5-warp-application-map.png)
- Dimensions: `1672x941`
- Format: `PNG`
- Intended surface: internal P5/WARP design review, app-map walkthrough, and
  implementation planning.
- Release scope: not for public marketing, store listings, release notes, or
  product claims.

## Source Inputs

- Brand reference: [../../apps/android_shell/assets/brand/pokrov_mark.png](../../apps/android_shell/assets/brand/pokrov_mark.png)
- Generated source master:
  `C:/Users/kiwun/.codex/generated_images/019e88e5-9867-74d2-afaf-6a047cd8b13f/ig_0e99b0ad5b58b942016a22049301f881918c70b1cf2ca15aef.png`
- Tooling path: built-in Image Gen skill.

## Source Prompt

```text
Create one high-resolution claim-safe product design reference board for the POKROV Android + Windows client P5 design map. Use the POKROV emerald line-art hood/shield brand mark style as brand inspiration; include a clean POKROV wordmark and a small emerald brand mark. Internal design artifact only. Do NOT write 'v1.0', do NOT claim store release, do NOT claim production WARP, do NOT claim anonymity, unlimited access, faster internet, no restrictions, or extra privacy. Use only '1.0.0-beta draft' if a version label is needed. Show multiple realistic UI screens: 1) mobile Home idle with one tactile circular connect disc and two short chips; 2) mobile Home connected ring settle; 3) WARP / extended protection bottom sheet in muted preparing state with 'proof required' concept visually, and separate consent-ready draft state clearly marked as beta/proof gated, not active; 4) Rules screen with selected-app picker rows; 5) Locations sheet with auto location and simple country rows; 6) Account settings rows; 7) Rewards hub with muted wheel/calendar/rewards; 8) embedded Support chat; 9) Windows desktop shell with left sidebar and centered connect stage; 10) motion annotations for ring sweep, press scale, status crossfade, skeletons, row feedback, muted states. Visual style: Apple-like calm premium utility, Linear/iOS Settings density, neutral light canvas (#FAFAFA), off-black text, deep emerald accent only for active connection states, hairline dividers, subtle material depth, no card spam, no nested cards, no purple/blue AI gradients, no neon, no confetti, no particles, no beige one-note theme. Keep UI copy minimal and mostly abstract/short: POKROV, Home, Rules, Locations, Account, Support, Ready, Connected, Preparing, Proof required, Beta draft. Single polished 16:9 design map board, high fidelity app mockup montage, all screens aligned on a grid, generous whitespace, clear hierarchy, no raw configs or keys.
```

## Review Notes

- The generated board captures the intended premium direction: calm light
  canvas, emerald active states, one connect focus, row-based settings, compact
  screen density, and restrained motion annotations.
- Generated UI text is not product copy. Text such as `POKROV VPN Client`,
  `WARP`, or any simulated version labels on the render must not be copied into
  public UI without canon review.
- The WARP panels are visual references only. Production UI must keep WARP
  muted/preparing until provisioning, secure storage, runtime fallback,
  diagnostics, Android proof, and Windows proof are green.
- The render may be used as a critique target for Product Design and external
  model consilium. It should not override `docs/specs/2026-06-05-p5-warp-approved-design.md`.

## Next Review Prompts

Use this board with the approved P5/WARP design contract and ask reviewers to
critique:

- hierarchy and first-screen copy density;
- connect-disc motion clarity;
- WARP honesty and consent placement;
- Windows sidebar responsiveness;
- Android bottom-nav density;
- support/rewards/account row hierarchy;
- implementation risk and testability.
