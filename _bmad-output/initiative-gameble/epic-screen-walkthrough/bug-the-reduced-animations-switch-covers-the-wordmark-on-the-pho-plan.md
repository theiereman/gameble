---
title: 'The reduced-animations switch covers the wordmark on the phone landing'
type: 'bugfix'
ticket: '16'
created: '2026-10-25'
status: 'built'
baseline_revision: '9ec8aeb2f7bf1a6c773285d98ede884bb63f0144'
route: 'oneshot'
route_source: 'pinned'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context: ['{project-root}/AGENTS.md']
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** On the signed-out landing the top bar renders the « Animations réduites » switch (`button.motion-switch` in `app/views/shell/_top_bar.html.erb`, styled in `app/frontend/styles/shell.css`) before the Steam sign-in image, and under 720px it sits over the gameble wordmark (author, 2026-10-23, on staging).

**Approach:** Hide the switch under 720px from `shell.css`'s phone block (`display: none`, which also takes it out of the tab order and the accessibility tree), so a phone visitor's motion follows the system setting (and a cookie the switch set earlier, still read by the server); the desktop keeps the switch and its toggle. Per the author's settlement (2026-10-24), EXPERIENCE.md and DESIGN.md say a phone visitor sets reduced motion nowhere on the landing: it follows the system, and a signed-in player finds the setting in Profil et paramètres. A system test in `test/system/landing_motion_switch_test.rb` checks, at a 390 px phone in French and in English, that the wordmark and the Steam sign-in image show, the switch does not, and the wordmark is not overlapped; the existing desktop tests keep covering the toggle.

</intent-contract>

## Implementation Notes

Oneshot: one CSS rule in the existing phone media query, one phone system test, and the UX documents' lines that describe the switch on the phone (DESIGN.md top bar rows, EXPERIENCE.md top bar, motion switch, moving content and landing-on-the-phone rows).

- Files: `app/frontend/styles/shell.css` (`.motion-switch` joins `.rarity-counter` under `display: none` in the `max-width: 719px` block; same specificity as the base rule and later in the file, so it wins), `test/system/landing_motion_switch_test.rb` (one phone test per locale at 390 px: wordmark and Steam image visible, no visible switch, no button named after it, wordmark and Steam image not overlapping), `ux-gameble/DESIGN.md`, `ux-gameble/EXPERIENCE.md`. The server still renders the switch (CSS cannot know the width at render), so `test/controllers/motions_controller_test.rb` stays as it is; `display: none` takes it out of the tab order and the accessibility tree on the phone.
- A cookie set on a desktop still applies on that browser at a phone width; a phone has its own cookies, so in practice its motion follows the system, as settled.
- The new phone tests fail on the baseline CSS ("expected not to find visible css .motion-switch, found 1 match", in both locales) and pass with the fix.
- Surprise, left out of scope: the Steam sign-in image (180 px) and the wordmark (132 px) need about 340 px of the top bar. At a 360 px viewport with no classic scrollbar they clear by 4 px; at 345 px of client width (360 px with a desktop scrollbar) or 320 px the Steam image sits over the wordmark's end. That is the same top bar on every signed-out page, and was so before this change; resizing Valve's official image is a design decision for the author.
- Verification results (2026-10-25, a 4-core machine shared with eight other builds, load average 16 to 30): `landing_motion_switch_test.rb` 4 runs, 0 failures; the landing and shell system tests (`landing_*`, `shell_test.rb`) 54 runs, 1 failure in `ShellTest` "several toasts stay through a morph refresh of the hub" (a signed-in hub toast timing, untouched here), which passed 3 times out of 3 alone. Full suite with `PARALLEL_WORKERS=2`, twice: 3171 runs, 0 errors; the only failure common to both runs is `Catalog::SetBuilderTest` "15,000 rows build quickly" (5.4 s and 6.0 s against a 5 s ceiling), which passes alone; the first run's second failure was cut from its output and did not recur. `bin/rubocop`, `packwerk check`, `i18n-tasks missing`, `npm run typecheck`, `npm run test:js` (561 tests), `zeitwerk:check` and `brakeman`: clean. Screenshots at 390 px (French) and on a 1400 px desktop confirmed the phone bar holds only the wordmark and the Steam image and the desktop bar keeps the switch.
- Run note: the worktree was cut from an older commit than `origin/develop`; the branch was fast-forwarded to `origin/develop` (9ec8aeb2) before any change.

## Verification

**Commands:**
- `bin/rails test test/system/landing_motion_switch_test.rb` -- expected: all pass, the new phone test among them
- `bin/rails test test/system/shell_test.rb test/system/landing_roadmap_test.rb` -- expected: pass (other phone top-bar checks)
- `PARALLEL_WORKERS=2 bin/rails test` -- expected: 0 failures, 0 errors
- `bin/rubocop`, `bundle exec packwerk check`, `bundle exec i18n-tasks missing`, `npm run typecheck`, `npm run test:js`, `bin/rails zeitwerk:check`, `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error` -- expected: clean

## Auto Run Result

Status: built

- Summary: under 720px the top bar hides the reduced-motion switch (as it hides the rarity counter), so the phone landing shows the wordmark and the Steam sign-in clear; the desktop keeps the switch and it still toggles; a phone visitor's motion follows the system setting, or a cookie set earlier on a desktop.
- Files: `app/frontend/styles/shell.css` (`.motion-switch` hidden in the phone block); `test/system/landing_motion_switch_test.rb` (a phone test per locale: wordmark and Steam image visible, no switch, no overlap); `ux-gameble/DESIGN.md` and `EXPERIENCE.md`.
- Review: the Quick lens ran from the coordinating session after the unattended run halted on `no subagents`. 2 findings, both patched (low); nothing deferred or rejected.
- Follow-up review recommended: false.
- Verification (unattended run, Postgres 16, Chromium 141): the phone tests fail on the old CSS and pass with the fix; `landing_motion_switch_test.rb` 4 runs, 0 failures; the full suite 3171 runs twice, its only failure the load-bound `set_builder_test.rb` timing test, green alone; rubocop, packwerk, i18n-tasks, typecheck, vitest 561, zeitwerk, brakeman clean. The patches touch a comment and a document only.
- Residual risks: under about 352px of width the 180px Steam image still overlaps the wordmark's end on every signed-out top bar, as before this change; whether to shrink Valve's image is the author's call.
