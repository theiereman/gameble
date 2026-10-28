---
title: 'Each origin has its look'
type: 'feature'
ticket: '4'
created: '2026-10-28'
status: 'built'
baseline_revision: '6c4cae84'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'auto'
lenses_ran: []
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md'
  - '{project-root}/_bmad-output/initiative-gameble/ux-gameble/DESIGN.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** a daily capsule and a goal reward look exactly like a standard capsule on the capsule screen; the player cannot tell by sight what they are about to open.

**Approach:** the pixel art export draws one canister body per special origin (the label band and the window emblem in the origin's colour: the daily capsule yellow with the sun, the goal reward red with the cup); the capsule screen tells its root which origin is on the canister and the stylesheet swaps the body image, the LEDs and the origin line to that origin's colour.

## Boundaries & Constraints

**Always:** the emblems are the approved medium-level designs (the sun and the cup, 17 × 17 cells, one art pixel per cell) drawn through `script/pixel_art/`; the tokens are `capsule-daily` (#f4c542) and `capsule-goal` (#d6403a); the caps, the rest of the body and the standard capsule are unchanged; the origin's name stays on the capsule screen and in the information panel, there is no intro; the standard reserve shows no origin look.

**Never:** a hand edit of `app/frontend/images/pixel/`; markup built in script; a `style` attribute; a new route or database id; a change to the odds or the contents of a pack.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Daily on special tab | oldest special is a bonus pack | root `data-origin="bonus"`: yellow band, sun, yellow LEDs and origin line | none |
| Goal reward on special tab | oldest special is a reward pack | root `data-origin="reward"`: red band, cup, red LEDs and origin line | none |
| Standard tab | any | no `data-origin`, blue canister with the G | none |
| Switch tab or last special opened | reserve changes live | the attribute follows the state on the next render | none |
| Armed canister | pointer over / ready | LEDs and hazard turn orange as before | none |

</frozen-after-approval>

## Code Map

- `script/pixel_art/origin_canisters.mjs` (new) -- the two looks: band ramp, emblem grid and palette
- `script/pixel_art/export.mjs` -- `body` takes a band and an emblem; writes `canister-body-daily.png` and `canister-body-goal.png`; descriptions; the review sheet's canister section lists them
- `app/helpers/boosters_helper.rb` -- `booster_origin_kind`, `data-origin` on the root
- `app/frontend/lib/booster_render.ts` -- `originKind`, `renderOriginLook` sets or clears `data-origin`
- `app/frontend/styles/tokens.css`, `booster-canister.css` -- tokens, body image, LEDs, label text, origin line colours

## Tasks & Acceptance

**Execution:**
- [x] Pixel art: the origin looks and the two exported bodies
- [x] Root attribute from the server and from the client state
- [x] Stylesheet: tokens and per-origin rules
- [x] Tests: export test for the bodies, controller tests for the attribute, system test for the tab switch

**Acceptance Criteria:**
- Given a daily bonus first in the special reserve, then the capsule screen shows the yellow canister with the sun and names its origin.
- Given a goal reward first in the special reserve, then it shows the red canister with the cup.
- Given the standard tab, then the canister is the blue standard one.
- `node script/pixel_art/export.mjs --check` passes.

## Implementation Notes

- The emblem sits at (42, 62) in the body, the same place as the approved mockup; the generated bodies match the mockup pixel for pixel in the window and outside the band, and within a few shaded edge pixels of the band (the mockup recoloured the blue band by a transform, the export recomputes it from a six-colour ramp per origin).
- The ramps were read off the approved mockup bodies: top line, second line, body, stripe, dark line, edge.
- Not done: the hub and the packs chip do not carry the origin's look (the ticket's open unknown, left out); the reserve tabs have no small canister icon (they are text tabs since the previous ticket); the label lines on the band still read the season and the title, the origin's name is on the origin line under the canister and in the information panel.
- No test or check was run in this session (the coordinator runs them once); the export script itself was run and `--check` passed (341 files).

## Review

Own diff review, without independent reviewers:

- `body(band, origin)` keeps the standard call path identical: the default band is the previous literal colours, so `canister-body.png` is unchanged (the export wrote only the two new files).
- The edge mix colour moved from `#1f5a80` to `band.edge`, which equals it for the standard band.
- `data-origin` is only set for a non-regular kind of the special reserve; a `regular` kind in the special reserve (not produced today) gets no look.
- Specificity: the origin LED rule (0,3,0) sits before the armed rule (0,3,0) in the same file, so armed orange still wins.
- CSS files stay under 500 lines (`booster.css` 499, `booster-canister.css` 488).
- Risk: the red origin line (`#d6403a`) on the panel ground reaches about 4.2:1, as DESIGN.md already notes for the cup.

## Plan Change Log

(none)
