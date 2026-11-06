---
title: 'Each card leaving the capsule gives a haptic tap'
type: 'feature'
ticket: '1'
created: '2026-11-06'
status: 'built'
baseline_revision: '784255beddc20bfbf44c8fb1ba733652d164fd36'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** In the native apps the only haptic of an opening is the one on each card reveal; the touch on the capsule and the cascade of cards leaving it are silent.

**Approach:** The opening sequence announces the touch and each card it deals through two new gameble events; the haptics bridge component turns each into a light impact. A five-card capsule gives five taps in the deal's cascade, a bonus capsule three; a skipped deal stops the remaining taps.

</frozen-after-approval>

## Implementation Notes

Oneshot: about 40 lines over the events map, the opening sequence and the haptics bridge component, with their tests. Author's go-ahead for the whole epic (2026-11-06, "jusqu'à ce que ça soit terminé review et push sur develop") stands for the plan checkpoint.

## Verification

**Commands:**
- `npx vitest run app/frontend/lib/booster_opening_sequence.test.ts` -- expected: the touch event and one card event per dealt card, in deal order
- `npm run test:js && npm run format:check && npm run lint` -- expected: green

## Review Triage Log

Pass 1 (quick): 1 medium, 1 low, 1 rejected low, 1 false.

- medium, patch — a skipped deal's pending card taps could fire after the next opening re-armed the skip flag. Each deal now has its own number and its timers act only within it (`laterInThisDeal`), the land shake included.
- low, patch — the cascade test checked only the count; it now checks the touch then the cards in `dealOrder`.
- low, rejected — no unit test for the haptics bridge component: the mapping is three one-line listeners and the bridge needs a native host to test; the events it listens to are covered.
- false — the touch tap fires before the server answers: intended, the touch itself is what it answers.
