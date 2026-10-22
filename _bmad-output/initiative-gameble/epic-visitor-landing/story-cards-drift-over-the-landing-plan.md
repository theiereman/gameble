---
title: 'Cards drift over the landing'
type: 'feature'
ticket: '8'
created: '2026-10-22'
status: 'built'
baseline_revision: '465efe23d464e8812c985856b8a9c43018295c06'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/AGENTS.md'
warnings: []
deferred:
  - summary: >-
      The drop shadow turns with the card's rotation, so it points slightly sideways.
    evidence: |-
      landing.css `.moving-card__body` filter; same as the reference render.
    severity: low
  - summary: >-
      Some behaviours have no test: re-activation keeping the drag offset, the lift styling, the layer ignoring the pointer while faded.
    evidence: |-
      test/system/landing_moving_cards_test.rb covers the rest of the matrix.
    severity: low
---

<intent-contract>

## Intent

**Problem:** The landing has no moving cards: the design has a few cards pass down the gutters beside the content faster than the scroll on a wide desktop, draggable aside, and they are missing.

**Approach:** The landing renders the cards inside an inert `<template>` in an `aria-hidden` fixed layer outside `<main>`; one Stimulus controller clones them in only where they may show, positions them from the scroll with pure tested maths, lets a pointer drag move each aside for good (until reload) and fades the layer while focus is in the content.

## Boundaries & Constraints

**Always:** Shown only when ALL hold: `(hover: hover) and (pointer: fine)`, motion not reduced (`motionReduced()`, live through `onMotionChange`), and both gutters beside `.landing` hold the widest card (left gutter at least card width + 16px; right gutter at least card width + 8px + 96px clearing the side gauge). Otherwise the cards are not in the DOM at all (phone, touch, narrow window, reduced motion), and without JavaScript nothing shows. Five cards: the published season's sample cards of rarity epic, legendary, uncommon and rare (an absent sample is skipped) plus a Standard card back, alternating left and right lanes, sizes `m` and `s`, each with a fixed rotation within +-11 degrees, a speed of 1.5 to 1.9 times the scroll, a sway and a lane offset, all fixed in the helper and carried as data attributes. Position is driven by the scroll only: card `d` = distance of its anchor point (a share of the scrollable height) from the scroll position, vertical = viewport middle + d * speed (minus half the height) + drag dy; horizontal = lane centre + sin(d / 420) * sway (sway clamped to half the lane) + drag dx; rotation = base + d * 0.004 degrees. A card outside the viewport (160px margin) is hidden. Drag: primary button on the card's own box (the rotated visible box; the layer itself has `pointer-events: none`), pointer capture, offsets kept per card in the controller for as long as the page lives, even across re-activation; the dragged card lifts (scale 1.06, 3 degrees, 120ms) and settles (220ms). Cards never tilt toward the pointer (neutralise the card's tilt custom properties), are never focusable, `aria-hidden` layer. While keyboard focus is inside `<main>` the layer fades out in 150ms and ignores the pointer, and returns when focus leaves. Epic and legendary cards keep rays behind them (`card_rays` helper, `card-rays` styles, sized to the card). A hard dark drop shadow 18px below each card (on the card body only, not the rays). Layer fixed, full viewport, under the top bar (z-index below `.top-bar`), above `<main>`, below the side gauge. No `style` attribute in server HTML (positions through the CSSOM). Pure maths in `app/frontend/lib/moving_cards.ts` with a vitest file. Strings: none visible, so no locale keys. English only in code; no comments except one-line external constraints; no planning ids.

**Never:** Do not put cards over the content column, on the phone, or under reduced motion. Do not change the lamp, the power-on controller, the side gauge, the motion switch, the card component or the samples query. Do not use a continuous animation loop (scroll and drag events only, throttled by `requestAnimationFrame`). Do not make cards focusable or give them a keyboard equivalent. Do not tilt them.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Wide desktop | fine pointer, 1800px wide, motion on | cards in the layer, each in a gutter, moving faster than the scroll | none |
| Narrow window | gutters too small for the widest card | no cards in the DOM | re-checked on resize |
| Phone / touch | coarse pointer or no hover | no cards in the DOM | none |
| Reduced motion | `data-motion=reduced` or system setting | no cards in the DOM; switching it live adds or removes them | `onMotionChange` |
| Drag | pointer down on a card, move 100px right, release, scroll | card follows, stays at its offset while scrolling, kept until reload | cancel ends the drag |
| Miss | pointer on the empty part of the layer | nothing captured, content below receives the click | none |
| Keyboard focus | Tab into the content | layer fades out and ignores the pointer; back when focus leaves `<main>` | none |
| No JavaScript | scripts off | template inert, nothing shows | none |
| Missing sample | a rarity has no sample card | that mover is skipped; the card back still shows | none |

</intent-contract>

## Code Map

- `app/views/landings/show.html.erb` -- `content_for :page_aside` renders the side gauge; add the movers partial before it (DOM order puts the gauge above the cards).
- `app/helpers/landings_helper.rb` -- `LAMP_SLOTS`, `landing_card_back`, `landing_covers` are the patterns; add the mover plan and data attributes here. `card_rays` lives in `app/helpers/card_details_helper.rb`.
- `app/views/landings/_side_gauge.html.erb`, `app/frontend/controllers/side_gauge_controller.ts`, `power_on_controller.ts` -- controller style to follow (rAF-throttled scroll/resize, `onMotionChange`, clean disconnect).
- `app/frontend/lib/landing_scroll.ts` + `.test.ts` -- pure-maths style; `app/frontend/lib/motion.ts` -- `motionReduced`, `onMotionChange`.
- `app/frontend/styles/landing.css` -- add the moving-cards block; side gauge block near line 1815 (right 20px, 1440px+); lamp rotation uses `rotate`; `.landing-rarities .card { --tilt-rx: 0deg !important; --tilt-ry: 0deg !important }` is the precedent for flattening tilt. `card-rarity-effects.css` holds `.card-rays` (`--card-rays-size`).
- `app/frontend/styles/shell.css` -- `.top-bar` z-index 2, `.main` z-index 1.
- `test/controllers/landings_controller_test.rb`, `test/system/landing_power_on_test.rb` -- test style (system tests resize with `resize_to`, retrying matchers, `eventually`).
- Controllers auto-register from `app/frontend/controllers/*_controller.ts` (the name `moving_cards_controller.ts` gives `moving-cards`).
- Do not change: the lamp, `CardComponent`, `Catalog::LandingSampleCards`, any existing landing partial.

## Tasks & Acceptance

**Execution:**
- [ ] `app/frontend/lib/moving_cards.ts` + `moving_cards.test.ts` -- pure maths: gutter room check, lane bounds, card placement (position, rotation, visibility), fade decision helpers as needed -- tested edge cases of the matrix
- [ ] `app/frontend/controllers/moving_cards_controller.ts` -- activation (media query, motion, gutters; clone template in, clear out), scroll/resize placement, drag, focus fade, clean disconnect
- [ ] `app/helpers/landings_helper.rb` -- mover plan and builder for the cards (rays for epic and legendary, card back, data attributes, skipped samples)
- [ ] `app/views/landings/_moving_cards.html.erb` + `show.html.erb` -- the aria-hidden layer with the template, rendered before the side gauge
- [ ] `app/frontend/styles/landing.css` -- layer, mover, lift, drop shadow, fade, flat tilt, rays sizing
- [ ] `test/controllers/landings_controller_test.rb` -- the template carries the movers (with and without samples); no `style` attribute
- [ ] `test/system/landing_moving_cards_test.rb` -- wide desktop shows and moves cards in the gutters faster than the scroll, drag stays through scrolling, narrow window and reduced motion show none, tabbing into the content fades them, a miss reaches the content

**Acceptance Criteria:**
- Given a 1800px window with a fine pointer, when the landing loads and scrolls, then cards sit in the gutters beside the content, never overlapping the content column, and move more than the scroll distance.
- Given a window under the gutter threshold, a coarse pointer, or reduced motion, then no moving card exists in the DOM.
- Given a card dragged 100px aside, when the page scrolls, then it keeps that offset until reload.
- Given keyboard focus enters the content, then the layer is transparent and ignores the pointer; it returns when focus leaves.
- Given the layer, then it is `aria-hidden`, holds no focusable element and no card tilts.

## Implementation Notes

Headless Chrome reports no hover or fine pointer; the system test overrides that one media query. The side-gauge controller test selector became `main ~ nav` because the layer now sits between them. Cards need a viewport of about 1650px or more.

## Plan Change Log

## Review Triage Log

### 2026-10-22 — Review pass
- verdicts: 8 findings — high 0, medium 2, low 4, false 0, maybe-false 2
- findings:
  - `[medium]` `[patch]` rays size override never applied (property redeclared on the rays element) — fixed with a `.moving-card .card-rays` rule and smaller sizes
  - `[low]` `[defer]` shadow rotates with the card — same as the reference render
  - `[medium]` `[patch]` stale placement when the page height changes — ResizeObserver on body reschedules placement
  - `[medium]` `[patch]` tab test depended on the top bar's focusable count — now tabs until focus is in main
  - `[low]` `[defer]` miss, drag distance, re-activation, tilt and pointer-ignore coverage thin — deferred
  - `[low]` `[reject]` focus-visible flicker on programmatic focus — matches the keyboard-only rule
  - `[maybe-false]` `[reject]` drag ending when the hit card is hidden or capture lost — harmless, element removed or still captured
  - `[low]` `[reject]` deactivate not releasing capture — element removed

## Design Notes

The cards live in a `<template>` so a phone, a touch screen or a reduced-motion visitor never downloads or draws them and assistive technology never meets them; the controller clones them in only where they may show. Placement golden example: scrollable 4000, anchor 0.5, scroll 1000 gives d = 1000; speed 1.6 puts the card 1600px below the viewport middle (hidden); at scroll 2000 it is at the middle.

## Verification

**Commands:**
- `npm install` -- expected: success
- `npm run test:js` -- expected: all pass
- `bin/rails test test/controllers/landings_controller_test.rb` -- expected: pass
- `bin/rails test test/system/landing_moving_cards_test.rb test/system/landing_power_on_test.rb test/system/landing_lamp_test.rb` -- expected: pass
- `bin/rails zeitwerk:check` -- expected: all good
- `bundle exec packwerk check` -- expected: no offenses
- `bundle exec i18n-tasks health` (or the repo's i18n test) -- expected: pass
- `bin/rubocop` and `npx tsc --noEmit` if configured -- expected: clean

## Auto Run Result

- Summary: moving cards in an aria-hidden layer cloned from a template by a Stimulus controller on wide desktops with a fine pointer; scroll-driven placement in the gutters, draggable until reload, fade while focus is in the main content.
- Files: lib/moving_cards.ts(+test), controllers/moving_cards_controller.ts, landings_helper.rb, _moving_cards.html.erb, show.html.erb, landing.css, controller and system tests.
- Review: 3 patches applied, 2 deferred, 3 rejected.
- Follow-up review recommended: false.
- Verification: vitest 543 pass; tsc, rubocop, zeitwerk, packwerk clean; i18n-tasks no missing; landing controller and system tests 44 runs pass.
- Residual risk: not viewed in a real browser.
