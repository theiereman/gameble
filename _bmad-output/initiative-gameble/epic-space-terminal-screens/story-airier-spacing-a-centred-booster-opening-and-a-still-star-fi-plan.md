---
title: 'Airier spacing, a centred booster opening and a still star field'
type: 'feature'
ticket: '6'
created: '2026-10-07'
status: 'built'
baseline_revision: '4cb65b1bf4c67092cb1a1bac6972c63a7c57f508'
route: 'full'
route_source: 'auto'
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/initiative-gameble/ux-gameble/DESIGN.md'
  - '{project-root}/_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** On a large window the booster opening sits close to the top with its parts packed together, panels everywhere feel tight, and the star field slides sideways at every screen change, which irritates the author.

**Approach:** Raise the layout spacing across the screens by about one step, centre the booster opening in the window without resizing it, and replace the star shift with a still field where a few stars twinkle softly (DESIGN.md "Breathing room", "Atmosphere"; EXPERIENCE.md "Screen change").

## Boundaries & Constraints

**Decided by the author (2026-10-07):** the raised spacing also applies to the phone, by a smaller step (gutters and page padding 16px to 20px); the plan keeps its full size.

**Always:** Nothing is resized: the page keeps its sizes (DESIGN.md "No scaling"); a short window still scrolls. The screen's own slide and the `html[data-screen-change=same]` mark stay. Twinkling is a slow, soft fade (period of 3 s or more, below `blink-max-rate` 1Hz) and stops under the system preference and `html[data-motion=reduced]`. Raised values are tuned on the built screens; information must stay easy to tell apart.

**Never:** No change to component-internal gaps (button, chip or badge insides), card sizes or touch targets. No new filter, collection or booster behaviour (story 7, epic 9). No ticker work.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Large window | Booster screen on a desktop window taller than the opening | The opening is centred horizontally and vertically, more room between its parts, sizes unchanged | No error expected |
| Short window | Window shorter than the opening | Top-aligned, the page scrolls, nothing clipped | No error expected |
| Screen change | Visit to another screen | Stars do not move; the screen slides as before | No error expected |
| Reduced motion | System preference or setting on | No twinkle, no shift, no screen slide | Read live, not only at load |

</frozen-after-approval>

## Code Map

- `app/frontend/styles/tokens.css` (lines ~139-176) -- layout tokens: `--space-panel-padding` (16px 18px; DESIGN.md already says 20px 24px), `--space-page-padding-*`, `--space-column-gap-*`, `--space-grid-gap-columns`; raise these, not the `--space-1..8` scale used inside components.
- `shell.css` (`.main` line 75), `hub.css`, `collection.css`, `card-detail.css`, `booster.css`, `profile.css`, `settings.css` -- literal or scale gaps between panels, rows and cards (e.g. `.booster__info` gap 18px, `.booster` gap `--space-8`); raise each by one step.
- `booster.css` (`.booster` line 52, `.booster__stage` min-height 520px, stacked layout under 1260px at line ~977, phone `data-layout="phone"` at ~1100) -- centring: let `.main` holding a `.booster` fill the free height and centre it (`:has(> .booster)`), above `--space-breakpoint-two-columns` only; use `min-height`, never a fixed height.
- `shell.css` (`.atmosphere__stars` lines 105-114, reduced-motion block lines ~1100-1140), `app/views/shell/_atmosphere.html.erb`, `app/frontend/images/pixel/starfield.svg` -- drop the 480px-wider layer and `.is-shifting`; add a twinkle layer of about a dozen 2px and 4px stars with staggered `steps()` opacity loops, covered by the media query and `html[data-motion=reduced]`.
- `app/frontend/controllers/starfield_controller.ts` -- remove offset, SHIFT, `place`, `shiftIfPending` and the `tile` value; keep the `turbo:visit` logic that sets `html[data-screen-change=same]` and its comment.
- Tests to change: `test/system/shell_test.rb` (`assert_star_shift`, "Back and Forward are screen changes..." expects `--star-shift` -160/-320), `test/integration/shell_test.rb:186`, the `getAnimations()` motion checks of story 10.4 (booster, hub, public card page) which must still pass.

## Tasks & Acceptance

**Execution:**
- [ ] `tokens.css` -- raise panel padding to 20px 24px and the page, column and grid gaps by one step -- DESIGN.md Breathing room
- [ ] `hub.css`, `collection.css`, `card-detail.css`, `profile.css`, `settings.css`, `shell.css` -- raise the gaps between panels, rows and cards by one step -- same
- [ ] `booster.css` -- centre the opening, more room between its parts, short windows scroll -- I/O matrix
- [ ] `_atmosphere.html.erb`, `shell.css`, `starfield.svg` -- still field plus the twinkle layer with its reduced-motion pairs
- [ ] `starfield_controller.ts` -- keep only the screen-change mark
- [ ] `test/system/shell_test.rb`, `test/integration/shell_test.rb` -- stars stay at screen changes; the mark and the slide still work; no animation runs under reduced motion

**Acceptance Criteria:**
- Given a desktop window taller than the booster opening, when the booster screen shows, then the opening is centred with its sizes unchanged.
- Given any screen change, when the page loads, then no `--star-shift` is set and the stars have not moved.
- Given reduced motion, then no star twinkles and `getAnimations()` is empty on the hub, booster and public card page.
- Given the hub, collection and card detail, then panels and rows show more space than at baseline.

## Implementation Notes

Decisions taken unattended (author away):
- Tokens raised one step: panel padding 20px 24px; page padding wide 32 32 40, medium 24 28 32, phone 20 20 28; column gaps 32/24; grid gaps 16/20; phone gutter 20. Layout gaps raised in hub, collection, card-detail, profile, settings and booster (a gap already at 32px, as in the public card page, stays: the scale stops there).
- Booster centring: `.main:has(.booster-island)` is a flex column centred above 720px (the island wraps `.booster`, so `:has(> .booster)` did not match). The booster grid gap is 40px, the info column gap 24px.
- AD-27 limits infinite animations to six on a phone view: only 3 of the 12 twinkling stars show under 720px. The twinkle places and rhythms are `nth-child` rules in shell.css because the CSP forbids inline styles.
- `baseline_revision` kept as planned; the worktree branch was fast-forwarded to `develop` (fa1676d) before work, as it lacked the plan.
- Review `quick`: self-review of the diff, no findings.

## Plan Change Log

## Review Triage Log

## Design Notes

Raise layout-level values only; the 2 to 32px scale stays, so small component gaps keep their look. "About one step" is the author's wording and an assumption: start at the next value of the scale (16 to 20, 20 to 24, 24 to 32), compare on screen, and keep information easy to tell apart. About a dozen stars twinkle with delays between 0 and 6 s and periods from 3 to 6 s.

## Verification

**Commands:**
- `bin/rails test` and `bin/rails test test/system/shell_test.rb test/system/booster_test.rb test/system/hub_test.rb` -- expected: pass
- `npm run typecheck`, `npm run test:js`, `bin/rubocop`, `bundle exec i18n-tasks missing` -- expected: pass

**Manual checks:**
- Booster screen at 1920 × 1080 and 1440 × 800: centred, spaced, nothing resized; at 1280 × 600 it scrolls. Hub, collection and card detail look airier at 390 px and 1440 px.
