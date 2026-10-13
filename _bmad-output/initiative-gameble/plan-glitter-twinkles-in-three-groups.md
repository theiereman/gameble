---
title: 'The Légendaire glitter twinkles in three groups'
type: 'refactor'
ticket: ''
created: '2026-10-13'
status: 'built'
baseline_revision: '29819538eeed5a606ac19cffa6ce02cbc978a8d5'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: true
context: ['{project-root}/AGENTS.md']
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** A Légendaire's glitter runs one infinite twinkle animation per flake (9 on a card-s, 18 on a card-m, 40 on a card-xl), which breaks the architecture's budget of at most six infinite animations visible at once on a phone view (author's decision, 2026-10-13, on the deferred finding of the studio reflection story).

**Approach:** Split each card's flakes into 3 groups, drawn from the same seed as their positions, and twinkle each group with ONE stepped opacity animation, each group with its own period (2.4 to 6 s) and negative delay (0 to -6 s), so a face runs at most 3 infinite animations and still looks randomly twinkling. Everything else of the glitter stays: the flash from the tilt, the levels, the static 0.18 under reduced motion and on still booster cards, running only in view. Update AD-27's budget line and resolve the deferred-work entry.

## Boundaries & Constraints

**Always:** the same seed draws the same flakes, groups and group rhythms on every render; a flashing flake shows exactly as before (glint opacity 1 × its level), whatever its group's twinkle; a still face (reduced motion chosen or from the system, face-down booster card, a phone booster's lower cards) shows every glint at 0.18 and no flash, as before; the twinkle runs only on `.card[data-in-view]`; infinite animations animate only `opacity`.

**Never:** an animation, `--flake-period` or `--flake-delay` on a flake or a glint; a `style` attribute written by the server; touching the reflection, the tilt or the flash maths; running system tests.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Grouped field | any seed, card-s / card-m / card-xl | exactly 3 group elements, each with its own `--flake-period` in [2.4, 6) s and `--flake-delay` in (-6, 0] s; all flakes inside them; no flake carries a period or a delay | No error expected |
| Deterministic | same seed twice; another seed | same groups, same membership, same rhythms; another seed differs | No error expected |
| Flash | tilt faces a flake's normal | the flake gets `data-flash` and its level, and leaves its group for the glitter container (so the group's opacity does not dim it); when the flash ends it goes back into its group | No error expected |
| Twinkle in CSS | stylesheet | `card-glitter-twinkle` is applied once, to `.card[data-in-view] .card__flake-group`; no rule animates a flake or a glint | No error expected |
| Still | reduced motion (chosen / system), face-down booster card, a phone booster's non-top card | groups `animation: none`; a flashing flake's glint at 0.18 | No error expected |

</intent-contract>

## Code Map

- `app/frontend/lib/glitter.ts` -- `flakeField(seed, w, h)` draws per-flake `period`/`delay` from `randomFrom(seed)`; `flakeElement` writes them as `--flake-period`/`--flake-delay`; `attachGlitter` puts the flakes straight into the container and toggles `data-flash` / `--flake-level` in `update`. Reuse `randomFrom`, `onPixelGrid`, `flakeFlash`, `flakeLevel` unchanged.
- `app/frontend/lib/glitter.test.ts` -- vitest, node environment, a `FakeElement` stand-in (no DOM); stylesheet tests read `card.css`, `booster.css`, `booster-layouts.css` raw with a `rule(stylesheet, selector)` helper.
- `app/frontend/styles/card.css` -- header comment (lines 13-17), glitter section (~460-535): `.card__flake-glint { opacity: 0.18 }`, `.card__flake[data-flash] .card__flake-glint { opacity: 1 }`, the per-flake twinkle rule `.card[data-in-view] :where(.card__flake:not([data-flash])) .card__flake-glint`, `@keyframes card-glitter-twinkle` (keep as is), the two reduced-motion blocks.
- `app/frontend/styles/booster.css:738-742` -- face-down card: glint `animation: none; opacity: 0.18`.
- `app/frontend/styles/booster-layouts.css:219-229` -- phone lower cards: same.
- `app/frontend/controllers/tilt_controller.ts` -- calls `attachGlitter(container, {seed, width, height})`; unchanged API, comment only if it names per-flake twinkles.
- `app/components/card_component.html.erb:37` -- the `.card__glitter` span the JS fills; no change expected.
- `test/system/card_preview_test.rb:124,148` -- assert the twinkle on `.card__flake:not([data-flash]) .card__flake-glint`; point them at `.card__flake-group` (do not run system tests).
- `_bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md:308` -- AD-27 motion bullet naming "holo and foil".
- `_bmad-output/initiative-gameble/deferred-work.md:200-202` -- the twinkle budget entry.

## Tasks & Acceptance

**Execution:**
- [x] `app/frontend/lib/glitter.ts` -- export `TWINKLE_GROUPS = 3`; a seeded field returns the 3 group rhythms (`period` 2.4 + r·3.6, `delay` -r·6) and flakes with a `group` index (drawn from the same generator) instead of `period`/`delay`; `attachGlitter` builds 3 `span.card__flake-group` elements carrying `--flake-period`/`--flake-delay`, puts each flake in its group, and in `update` moves a flake to the container while it flashes and back into its group when it stops; `detach` empties the container. Update the header comment.
- [x] `app/frontend/lib/glitter.test.ts` -- adapt the fake element (a moved child leaves its old parent); prove: 3 groups at every size with in-range rhythms and all flakes inside; no flake has `--flake-period`/`--flake-delay`; same seed → same groups/membership/rhythms, other seed differs; flash moves the flake out and back; the stylesheets apply `card-glitter-twinkle` exactly once, on the group rule, and the still rules stop the group and keep a flashing glint at 0.18.
- [x] `app/frontend/styles/card.css` -- `.card__flake-group` (absolute, inset 0, `mix-blend-mode: screen`, `opacity: 0.18`); glint opacity 1 by default; the twinkle rule moves to `.card[data-in-view] .card__flake-group`; reduced motion: group `animation: none`, `.card__flake[data-flash] .card__flake-glint { opacity: 0.18 }`; update the header comment.
- [x] `app/frontend/styles/booster.css`, `app/frontend/styles/booster-layouts.css` -- same pair of still rules for a face-down card and a phone's lower cards.
- [x] `test/system/card_preview_test.rb` -- the two twinkle assertions target `.card__flake-group`.
- [x] `architecture-gameble.md` AD-27 -- replace "holo and foil run only on cards in the viewport" with the Légendaire's glitter (three stepped opacity animations per Légendaire face, only on faces in the viewport) and keep the six-animation phone budget coherent by counting the glitter apart from it.
- [x] `deferred-work.md` -- one `resolved:` line under the twinkle budget entry.

**Acceptance Criteria:**
- Given a Légendaire face of any size, when its glitter is attached, then it runs at most 3 distinct twinkle animations, and none on a flake or glint.
- Given the full suite, when `npm run test:js`, `npm run typecheck`, `bin/rails test`, `bin/rails zeitwerk:check`, `bundle exec packwerk check` and `bin/rubocop` run, then all pass.

## Implementation Notes

- Full route, one implementing subagent. `flakeField` now returns `{ groups, flakes }`: the 3 group rhythms are drawn first from the seed, then each flake with a `group` index (flake positions differ from before for the same seed; the card face baselines were already stale and deferred). `attachGlitter` builds 3 `span.card__flake-group` carrying `--flake-period`/`--flake-delay`; a flashing flake moves to the bare container and back, only when its flash state changes.
- Review patch: the twinkle selector became `.card[data-in-view] :where(.card__flake-group)` so every still rule outranks it.

## Plan Change Log

## Review Triage Log

### 2026-10-13 — Review pass
- verdicts: 2 findings — high 1, medium 0, low 1, false 0, maybe-false 0
- findings:
  - `[high]` `[patch]` Reduced motion no longer stops the twinkle: `.card[data-in-view] .card__flake-group` (0,3,0) beats `html[data-motion="reduced"] .card__flake-group` and `html:not([data-motion="full"]) .card__flake-group` (0,2,1); the face-down booster rule only ties and wins by import order — verified by specificity; fixed by wrapping the group in `:where()` (0,2,0), as the old rule did, and pinning that selector in the stylesheet test.
  - `[low]` `[reject]` Empty groups still run an infinite animation (about 1 card-s seed in 13 leaves a group empty; a zero-size face runs 3 animations on nothing) — still within 3 per face, an empty span's stepped opacity costs nothing visible, and the plan's matrix pins exactly 3 groups; the fix would add filtering for no user-visible gain.

## Design Notes

CSS opacity composites a whole subtree, so a group's twinkle opacity caps a flashing flake inside it. Hence a flashing flake leaves its group for the bare `.card__glitter` container while it flashes (a DOM move only when its flash state changes) and returns after. Visual identity with today: rest = group 0.18 × glint 1 × level 0.5 (was glint 0.18 × level 0.5); twinkle peak = group 1 (was glint 1); flash = glint 1 × level, outside any group. The group gets `mix-blend-mode: screen` because an isolated group would otherwise blend its flakes against transparency instead of the art. Still states keep the group at its resting 0.18 and pin a flashing glint at 0.18, as the old rules pinned every glint.

## Verification

**Commands:**
- `npm run test:js` -- expected: all pass
- `npm run typecheck` -- expected: no errors
- `bin/rails test` -- expected: 0 failures, 0 errors (run `npm install` first if assets missing; Postgres via `docker compose up -d`)
- `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bin/rubocop` -- expected: clean

## Auto Run Result

- **Summary:** a Légendaire face's flakes twinkle in 3 seeded groups, one stepped opacity animation each with its own period (2.4–6 s) and negative delay, instead of one animation per flake (9 to 40). Flash, levels, still states (reduced motion, face-down and lower phone booster cards) and in-view gating look as before.
- **Files:**
  - `app/frontend/lib/glitter.ts` — `TWINKLE_GROUPS`, grouped seeded field, group elements, flashing flake leaves its group.
  - `app/frontend/lib/glitter.test.ts` — 3 groups at every size, no per-flake rhythm, determinism, flash move, one twinkle rule outranked by every still rule, no flake or glint animated.
  - `app/frontend/styles/card.css` — `.card__flake-group` (opacity 0.18, screen blend), twinkle on the group, still rules stop the group and pin a flashing glint at 0.18.
  - `app/frontend/styles/booster.css`, `app/frontend/styles/booster-layouts.css` — the same still rules for face-down and lower phone cards.
  - `test/system/card_preview_test.rb` — twinkle assertions target the group (not run: system tests disabled).
  - `architecture-gameble.md` AD-27 — the phone budget counts the Légendaire's glitter (3 stepped opacity animations per face in view) apart; holo and foil gone.
  - `deferred-work.md` — the twinkle budget entry resolved.
- **Review:** 1 patch (high, reduced-motion specificity), 0 deferred, 1 rejected (empty groups, low: within budget, invisible cost, plan pins 3 groups).
- **Follow-up review recommended:** true — the patched high (CSS specificity) is proven only by a selector-text test; that reduced motion really stops the twinkle on a face in view is unverified in a browser while system tests are disabled.
- **Verification:** `npm run test:js` 277 passed; `npm run typecheck` clean; `bin/rails test` 2414 runs, 0 failures; `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bin/rubocop` clean (rerun after the patch).
- **Residual risks:** blending the group as a whole with `screen` may look very slightly different from each flake screened alone; not looked at in a browser.
