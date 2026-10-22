---
title: 'The lamp finds the lost games'
type: 'feature'
ticket: '4'
created: '2026-10-22'
status: 'built'
baseline_revision: '6550584e5b04c17003d8c7fd0a3eb3de080cac64'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/AGENTS.md'
  - '{project-root}/_bmad-output/initiative-gameble/ux-gameble/DESIGN.md'
  - '{project-root}/_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md'
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** The landing hero has an empty field where the designed lamp should be, so a visitor meets no interactive taste of the game.

**Approach:** Fill the hero field with six sample cards (five on the phone share the band, one hidden) under a veil, a lamp that follows a fine hovering pointer and otherwise sweeps toward the next card not yet found, a found tag and a "found games" readout; the veil is one oversized element moved by `translate3d`, its maths live in a pure tested module, and under reduced motion the lamp does not travel.

## Boundaries & Constraints

**Always:**
- Behaviour from `EXPERIENCE.md`, Component Patterns, Landing, Lamp field and Reduced motion, Landing; look from `DESIGN.md`, Components, Landing, Lamp field and `components.lamp`.
- Pointer: lamp follows a mouse over the field; 2.5s after it stops or leaves the lamp sweeps; touch always sweeps; holds 1.6s on a find; a card is found when the lamp's centre passes over it; once all are found the lamp settles on the last one and its frame loop stops; the loop runs only while the field is in view and the tab visible.
- Reduced motion (switch, system preference): no loop, the lamp jumps to the pointer over the field (finding the card there), otherwise rests on the first card, whose first two cards are already found; marks appear at once.
- Field is `aria-hidden`, nothing focusable, `pointer-events: none`. No `style` attribute or inline script: per-element values come from CSS classes or the CSSOM.
- Cards are the sample cards of the landing (a missing rarity, or no published season, shows a face-down Standard back); one slot is always a back.
- Every string in `en.yml` and `fr.yml`.

**Never:**
- Moving cards over the content, parallax, module power-on, star drift, side gauge, motion switch (other stories).
- A mask repainted per frame.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Power-on | 0..350ms after start | lamp radii zero, then five steps to full over 300ms | — |
| Pointer over field | mouse moved less than 2.5s ago | mode manual, lamp eases quickly to the pointer | — |
| Pointer idle | 2.5s without move, or touch | mode auto, lamp eases slowly to the next unfound card | — |
| Find | lamp centre within first radius + 0.4 card radius | card found once, count +1, loop holds 1.6s on it | — |
| All found | every card found | lamp settles on the last found card; frame loop stops; count stays | — |
| Reduced motion | switch or system preference | no loop; mode still; two cards found at start; pointer jump finds the card there | — |
| Hidden hero / tab | out of view or tab hidden | no frame runs | — |
| No JS | script absent | field stays fully veiled, nothing breaks | — |

</intent-contract>

## Code Map

- `app/views/landings/_hero.html.erb` -- field placeholder to fill; copy and sign-in stay.
- `app/helpers/landings_helper.rb` -- `landing_covers`, `landing_card_back`; add the lamp slots helper.
- `app/components/card_component.rb` -- card faces (sizes s, m, l); art drawn by `card-art` controller.
- `app/frontend/lib/motion.ts` -- `motionReduced`, `onMotionChange`.
- `app/frontend/lib/reveal_demo.ts` and its test -- pure module plus vitest pattern to follow.
- `app/frontend/styles/landing.css`, `tokens.css` -- hero styles, lamp tokens; phone hero hides the field today.
- `test/controllers/landings_controller_test.rb` -- landing response tests.

## Tasks & Acceptance

**Execution:**
- [ ] `app/frontend/lib/lamp.ts` + `lamp.test.ts` -- pure maths: power steps, radii, modes, easing, targets, finds, settle.
- [ ] `app/frontend/controllers/lamp_field_controller.ts` -- pointer, frame loop, visibility, CSSOM writes, reduced form.
- [ ] `app/views/landings/_hero.html.erb`, `app/helpers/landings_helper.rb` -- six slots, veil, reticle, readout.
- [ ] `app/frontend/styles/landing.css`, `tokens.css` -- lamp look, phone band, reduced-motion form.
- [ ] `config/locales/en.yml`, `fr.yml` -- found tag, readout label, three mode words.
- [ ] `test/controllers/landings_controller_test.rb` -- field markup: aria-hidden, six slots, a back, readout.

**Acceptance Criteria:**
- Given a visitor with a mouse, when the pointer moves over the field, then the lamp follows it and sweeps 2.5s after it stops.
- Given a phone, when the page loads, then the lamp sweeps on its own in the field below the copy.
- Given every card found, then the count stops and no frame runs.
- Given reduced motion, then nothing animates and the lamp jumps to the pointer.

## Implementation Notes

Implemented in the main session: this run is itself a subagent and cannot re-delegate.

## Plan Change Log

## Review Triage Log

### 2026-10-22 — Review pass
- verdicts: 7 findings — high 0, medium 3, low 4, false 0, maybe-false 0
- findings:
  - `[medium]` `patch` Manual mode ended at once when the mouse left the field — the last in-field position now holds the lamp for 2.5s after the last in-field move.
  - `[medium]` `patch` Mouse moves outside the field woke the loop or drew frames while hidden — moves wake only from inside the field, and only while the hero is in view and the tab visible.
  - `[medium]` `patch` A resize reset the found cards and the power-on — the lamp keeps its found cards and start time across a resize.
  - `[low]` `reject` Phone readout says "0 / 6" until the first frame — corrects itself on the first frame; the fix needs viewport knowledge on the server.
  - `[low]` `patch` Comments against the no-comment policy — removed from the controller, the module and the system test.
  - `[low]` `patch` No 1.6s hold on a card found on the way to another — the hold now targets the last card found; test added.
  - `[low]` `patch` Pen hover ignored — only touch pointers are excluded now.

## Auto Run Result

**Summary:** the hero's lamp field: six sample cards (five on the phone, in a band under the copy) under one oversized veil moved by `translate3d`, a lamp that follows a mouse and otherwise sweeps toward the next unfound card, found marks and tag, a readout, and a reduced-motion form with no loop.

**Files:** `app/frontend/lib/lamp.ts` and test (pure maths), `app/frontend/controllers/lamp_field_controller.ts`, `app/views/landings/_lamp.html.erb`, `_hero.html.erb`, `show.html.erb`, `app/helpers/landings_helper.rb`, `landing.css`, `tokens.css`, `en.yml`, `fr.yml`, `test/controllers/landings_controller_test.rb`, `test/system/landing_lamp_test.rb`.

**Review:** 7 findings; 6 patched (3 medium, 3 low), 1 low rejected (phone readout reads 0 / 6 for one frame). No deferrals. Follow-up review: recommended (three medium patches); the unverified risk is the reworked pointer handling (leave-hold, resize keeping progress), covered only by unit tests and the system run, not re-reviewed.

**Verification:** vitest 520 pass, typecheck, rubocop, i18n-tasks missing, zeitwerk, packwerk, bin/rails test (3011 runs), landing system tests (5) all pass.

**Residual risks:** the phone band sits under the copy rather than behind it (first screen shows its top part); pen hover is treated like a mouse.

## Design Notes

- On the phone the field is a band under the copy rather than behind it, so the lamp can never open the veil over the copy and the copy needs no extra backing.
- The veil is 300% of the stage centred on the lamp, so one transform moves a fixed hole; radii change only in the five power-on steps (CSS custom properties).

## Verification

**Commands:**
- `npm run test:js && npm run typecheck` -- expected: pass
- `bin/rails test test/controllers/landings_controller_test.rb` -- expected: pass
