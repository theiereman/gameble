---
title: 'Shared rarity rays and idle float outside the booster'
type: 'feature'
ticket: ''
created: '2026-10-16'
status: 'in-progress'
baseline_revision: '7e6b6570113952a90fb6fb4ef0fbc8d8ee4140f0'
route: 'full'
route_source: 'pinned'
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md'
  - '{project-root}/_bmad-output/initiative-gameble/ux-gameble/DESIGN.md'
  - '{project-root}/_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Épique and Légendaire cards show rarity rays and a sense of depth only during a booster opening. The same cards look flat on the detail page, the hub showcase, and their public page.

**Approach:** Extract the rays into a shared visual treatment used by the booster and the three card screens. Add a slow idle float and breathing ground shadow to those three screens, with all movement stopping under reduced motion while the rays remain visible.

## Boundaries & Constraints

**Always:** Keep the booster opening visually unchanged during normal motion. Show rays only for Épique and Légendaire cards. Animate a wrapper so the card's pointer tilt can keep owning its transform. Honor both the account/site reduced-motion setting and the system preference.

**Never:** Add inline styles, change card data or server operations, introduce translations, animate layout, or expand the scope to the landing, card backs, collection grid, or other card surfaces.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Top rarity | Épique or Légendaire on a target screen | Purple or gold rays appear behind the card and it floats over a breathing shadow | No error expected |
| Lower rarity | Commune or Rare on detail or public page | No rays and no float | No error expected |
| Reduced motion | Account or system motion is reduced | Rays remain still; card and ground shadow do not move | No error expected |
| Booster opening | Any rarity and booster state | Existing reveal timing, rays, zoom and phone pile remain visually unchanged | No error expected |

</frozen-after-approval>

## Code Map

- `app/frontend/components/BoosterCard.tsx` and `BoosterZoom.tsx` -- current React rays markup and reveal/zoom states; preserve these state hooks while adopting the shared treatment.
- `app/frontend/styles/booster.css` and `booster-layouts.css` -- current ray colors, geometry, spin, zoom size, phone pile behavior and reduced-motion rules.
- `app/frontend/entrypoints/application.css` -- imports the global stylesheets; a shared card-effects stylesheet belongs here.
- `app/views/cards/_detail.html.erb`, `app/views/cards/_public.html.erb`, and `app/views/pages/_showcase.html.erb` -- target screens render the shared `CardComponent` with separate ground-shadow elements.
- `app/frontend/styles/card-detail.css` and `app/frontend/styles/hub.css` -- target stages and existing shadows; float must be on their wrapper, not `.card`.
- `app/frontend/styles/tokens.css` -- already defines `--idle-float-max: 2px`.
- `app/frontend/lib/glitter.test.ts`, `test/controllers/cards_controller_test.rb`, and `test/controllers/pages_controller_test.rb` -- existing CSS-source and rendered-page regression coverage patterns.

## Tasks & Acceptance

**Execution:**
- [ ] `app/frontend/styles/card-rarity-effects.css` and `app/frontend/entrypoints/application.css` -- define and import shared rarity rays and reduced-motion-safe idle keyframes -- one effect system serves React and Rails screens.
- [ ] `app/frontend/components/BoosterCard.tsx`, `BoosterZoom.tsx`, and `app/frontend/styles/booster.css` / `booster-layouts.css` -- adopt shared rays while retaining reveal, zoom, phone pile and existing motion rules -- booster behavior remains intact.
- [ ] `app/views/cards/_detail.html.erb`, `_public.html.erb`, and `pages/_showcase.html.erb` -- add rays for the rendered card's top rarity and a wrapper hook for idle float -- lower rarities remain unaffected.
- [ ] `app/frontend/styles/card-detail.css` and `hub.css` -- apply the 14-second, 2px float and breathing shadow to target stages -- reduced motion keeps both still.
- [ ] `app/frontend/lib/glitter.test.ts` and the named controller tests -- cover shared rays, rarity boundaries, rendered markup and reduced-motion rules -- prevent regression without system tests.

**Acceptance Criteria:**
- Given an Épique or Légendaire card on detail, hub showcase, or public page, when it is idle, then it shows purple or gold rays and floats over a breathing shadow.
- Given a Commune or Rare card on detail or public page, when rendered, then it has neither rays nor float.
- Given reduced motion is active, when any target screen renders, then its rays stay visible and static and its card and shadow do not move.
- Given the booster opens under normal motion, when any card is revealed, then its rays, reveal sequence, zoom, and phone pile look as before.

## Implementation Notes

Implementation handoff: add regression coverage, but do not run tests, commit, or push. Leave test verification to CI.

## Plan Change Log

## Review Triage Log

## Design Notes

Keep the card face's tilt transform independent from idle motion. Reuse the existing maximum-float token and compose rays and float at the stage/card wrapper level. Retain the booster-specific reveal gate and the zoom's larger rays size as modifiers on the shared visual treatment.

## Verification

**Commands:**
- `npm run test:js` -- expected: Vitest passes, including shared-effect assertions.
- `bin/rails test` -- expected: Rails regression suite passes in CI; do not run Rails tests locally.
- `git diff --check` -- expected: no whitespace errors.

**Manual checks (if no CLI):**
- Compare booster reveal and zoom under normal motion; inspect all three target screens at top and lower rarities and with reduced motion enabled. Confirm rendered HTML has no inline `style` attributes.
