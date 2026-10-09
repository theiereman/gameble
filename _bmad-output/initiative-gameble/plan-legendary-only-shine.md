---
title: 'Only Legendary cards shine, the glare appears under the pointer'
type: 'feature'
ticket: ''
created: '2026-10-08'
status: 'built'
baseline_revision: 'ec6e3d71165fb04af7be0ecf22d4adfe78382ec6'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** In the booster, Rare and Épique cards also get the holo sheen and the foil, so a shine no longer marks a Legendary; and the pointer glare appears at the card's centre and slides to the pointer when the pointer enters.

**Approach:** Holo and foil only on Legendary cards in every context (the booster's Legendary keeps holo and foil, elsewhere its holo as today). The glare stays on every card; when a pointer starts driving a card, the glare is placed under it at once and follows it from there, while the tilt keeps its easing. Tests and DESIGN.md's rarity effects follow (author, 2026-10-08).

</frozen-after-approval>

## Implementation Notes

Oneshot: about 40 lines across the card component, card.css, tilt.ts, their tests and DESIGN.md.

## Review Triage Log

- low, patch: EXPERIENCE.md's Rare reveal row still said "holo on the face"; the phrase is removed.
- false: the glare eases after its first placement; the author asked to fix only its appearance ("corrige juste l'apparition"), following with the tilt's easing is today's behaviour, kept.
- low, patch: the header comment gained an explanation and the placement was an anonymous block; the explanation is removed and the block is now `placeGlareUnderPointer`. The header's planning references predate this change and belong to epic 12's cleanup (rejected here).
- low, patch: the new test's easing check was weak; it now asserts the tilt at 0deg before a frame, then moving and between 0 and 5deg. Touch-path and system coverage of the glare rejected: the touch path calls the same `drive` then `aim`, and the cost exceeds the risk.

## Verification

**Commands:**
- `bin/rails test test/components/card_component_test.rb` -- expected: pass.
- `npm run test:js`, `npm run typecheck` -- expected: pass.
- `bin/rails test test/system/card_preview_test.rb` -- expected: pass.
- `bin/rubocop` -- expected: clean.
