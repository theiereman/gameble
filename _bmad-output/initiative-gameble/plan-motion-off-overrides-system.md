---
title: '"Non" to reduced motion plays the animations even when the system asks for less'
type: 'bugfix'
ticket: ''
created: '2026-10-10'
status: 'built'
baseline_revision: '85033f990513f2320d2ae2bb4d0b101a5ee1728a'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** "Animations réduites" offers SYSTÈME / OUI / NON, but NON behaves like SYSTÈME: the server renders `html[data-motion="reduced"]` only for OUI, and CSS and `motion.ts` always honour the OS preference, so a player whose OS asks for reduced motion gets it whatever they choose (seen on staging).

**Approach (author, 2026-10-10):** NON forces full motion even when the system asks for reduced motion; OUI forces reduced; SYSTÈME (nil) follows the OS. A signed-out visitor's `motion` cookie ("full" / "reduced") gets the same override. The server renders `data-motion="full"` for an explicit false, `"reduced"` for true, nothing for nil; every system-preference rule in CSS applies only when the page is not `html[data-motion="full"]`; `motion.ts` returns false for "full" before reading `matchMedia`.

## Boundaries & Constraints

**Always:** one source of truth per CSS block (the existing `@media` block is scoped, not copied a third time); `onMotionChange` keeps reporting both sources; strings and comments without planning ids.

**Never:** touch `pending-approvals.md`; change the settings form, the cookie format or the stored setting; JS that rewrites `data-motion` from the media query.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Player NON, OS reduces | `reduced_motion: false`, OS reduce | `data-motion="full"`, view-transition meta, loops run, `motionReduced()` false | — |
| Player OUI | `reduced_motion: true` | `data-motion="reduced"`, no meta, nothing loops | — |
| Player SYSTÈME | `reduced_motion: nil` (cookie ignored) | no `data-motion`, meta, follows OS | — |
| Visitor cookie | `motion` = "full" / "reduced" / none or junk | `full` / `reduced` / no attribute | junk cookie treated as none |

</frozen-after-approval>

## Code Map

- `app/controllers/application_controller.rb` -- `MOTION_COOKIE_VALUES` ("reduced" => true, "full" => false), `motion_setting` (player's setting else cookie), `motion_reduced?` (helper, read by `_head`), `write_motion_cookie`. Add a helper returning the attribute value (`MOTION_COOKIE_VALUES.key(motion_setting)` gives "reduced" / "full" / nil); reuse it in `write_motion_cookie`.
- `app/views/layouts/application.html.erb` -- `<html>` renders `data-motion` only for reduced; render the three states.
- `app/views/layouts/_head.html.erb` -- view-transition meta dropped only when `motion_reduced?`; already right for three states (NON keeps the meta; under SYSTÈME the CSS drops the animation). Only its comment changes.
- `app/views/layouts/turbo_rails/frame.html.erb` -- frame `<html>` is not merged into the page; untouched.
- `app/frontend/lib/motion.ts` -- `motionReduced()` and `onMotionChange()` (MutationObserver on `data-motion` plus `matchMedia` change listener); add the "full" short-circuit.
- `app/frontend/styles/{shell,hub,card,card-detail,booster-layouts}.css` -- each has one `@media (prefers-reduced-motion: reduce)` block plus a `html[data-motion="reduced"]` copy; scope every selector inside the `@media` block with `html:not([data-motion="full"])`. The repo does not use CSS nesting; write plain selectors like the existing copy.
- `test/controllers/settings_controller_test.rb` -- integration tests for the switch (`reduced?`, `transition_meta?` helpers); extend to assert "full" / "reduced" / none for player and cookie.
- `test/system/settings_test.rb` -- "under the system's reduced motion nothing loops without the setting" already emulates the OS preference over CDP; extend it with a "full" cookie that keeps the loops.
- `app/frontend/lib/motion.test.ts` -- vitest with stubbed `document`/`window`.
- `_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md` line "**Reduced motion.** Applies when ..." -- state that NON overrides the system. The spec's "Reduced motion:" bullet does not contradict; leave it.

## Tasks & Acceptance

**Execution:**
- [x] `app/controllers/application_controller.rb` -- add `motion_attribute` helper ("reduced" / "full" / nil), `motion_reduced?` built on it, cookie writer reuses the mapping -- one source for the three states.
- [x] `app/views/layouts/application.html.erb`, `_head.html.erb` -- render `data-motion` from the helper; refresh comments.
- [x] `app/frontend/lib/motion.ts` -- "full" returns false before `matchMedia`.
- [x] the five CSS files -- scope each `@media (prefers-reduced-motion: reduce)` selector with `html:not([data-motion="full"])`.
- [x] `app/frontend/lib/motion.test.ts` -- full overrides a matching query; reduced still wins; nil follows the query; a listener hears the change to "full" under a reducing system.
- [x] `test/controllers/settings_controller_test.rb` -- assert the rendered attribute for false / true / nil, player and cookie.
- [x] `test/system/settings_test.rb` -- under the emulated OS preference, a "full" cookie keeps the loops running.
- [x] `EXPERIENCE.md` -- the Reduced motion line.

**Acceptance Criteria:**
- Given the OS asks for reduced motion and the player chose NON, when any page renders, then `html[data-motion="full"]` is set, the view-transition meta renders and the looping animations run.
- Given the player chose SYSTÈME, when the OS preference flips, then CSS and `motionReduced()` follow it as before.

## Implementation Notes

Assumptions (the author is unavailable and settled the decisions in the intent):
- Plan approval at checkpoint 1 is taken as given by the author's instruction; no human halt.
- The `full` route runs without a coding subagent (none available in this session); the work is implemented directly.
- The spec's "Reduced motion:" bullet ("follows the system preference by default") does not contradict the decision; it is left unchanged.
- The quick review lens ran in this session (no subagent available), against the staged diff; the edge-case and verification-gap lenses did not run.

Built:
- `ApplicationController`: `MOTION_COOKIE_VALUES` renamed `FORCED_MOTIONS` (the names the cookie and `html[data-motion]` share); new helper `forced_motion` ("reduced" / "full" / nil); `motion_reduced?` and `write_motion_cookie` built on it. `_head`'s view-transition meta needed no change: NON keeps it, SYSTÈME keeps it with CSS dropping the animation under the system's preference.
- The five `@media (prefers-reduced-motion: reduce)` blocks keep their single copy, each selector prefixed with `html:not([data-motion="full"])` (pseudo-element and `html[...]` selectors compounded onto it). The system path now has the forced path's specificity, so both behave alike.
- Comments touched in passing lost their planning ids.
- Environment: no Docker daemon (starting it was refused) and Postgres cannot be run as root, so `bin/rails test` and the system tests did not run here. The layout's `<html>` tag and meta were rendered with a stand-in for the three settings (reduced / full / none, meta false / true / true) and `bin/vite build` confirmed the scoped selectors compile.

## Review Triage Log

Quick lens, pass 1: 0 high, 0 medium, 0 low, 0 false, 0 maybe-false. Checked: no planning ids in added code; every `data-motion` / `prefers-reduced-motion` reader covered (five CSS files, `motion.ts`, both layouts; `turbo_rails/frame` html is not merged into the page); fixtures leave `reduced_motion` nil, so no other test meets "full"; the new system assertion follows the existing cookie test's pattern (selector wait, then the loop read).

## Verification

**Commands:**
- `npm run test:js` -- expected: green, including the new `motion.test.ts` cases
- `bin/rails test` -- expected: green
- `bin/rails test test/system/settings_test.rb test/system/shell_test.rb test/system/booster_test.rb test/system/daily_bonus_test.rb test/system/card_detail_test.rb` -- expected: green
- `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bin/rubocop`, `bundle exec i18n-tasks missing`, `npm run typecheck` (if present) -- expected: clean
