---
title: 'Duels and the duel screen on desktop'
type: 'feature'
ticket: 9
created: '2026-11-17'
status: 'built'
baseline_revision: '940317c64aa1a7d9c787a2f3e62497f71f7d07f9'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context: ['{project-root}/AGENTS.md', '{project-root}/docs/design-system.md']
warnings: []
deferred:
  - summary: >-
      Tab order on desktop visits the hand at the foot before the stats above it.
    evidence: |-
      The grid places the hand in the last row while the markup keeps the hand group first, as on the phone.
    location: >-
      app/frontend/styles/duel-desktop.css
    severity: low
---

<intent-contract>

## Intent

**Problem:** At desktop width the Duels screen stacks the challenge block over the decks and the duel keeps the phone column, so a wide window is left empty.

**Approach:** Lay both screens out for a desktop window in CSS and view classes only: the Duels screen in its 1120px column with a 400px left column beside the decks, the duel filling the window with both decks on the sides, the choices in the centre and the hand at the foot. No behaviour changes.

## Verification contract

At desktop width, as boards 11 and 12 and the Duels design rules draw them: the Duels screen keeps the 1120px column and puts DÉFIER UN AMI and EN LIGNE in a 400px left column beside the decks; Défier un ami opens as a centred dialog (the Modal pattern) instead of the phone sheet; the challenge received stays the Modal; a duel fills the window without the hub menu, the opponent's deck on the left and the player's on the right, each a 3 × 4 grid at 74px tall with names, the choices in the centre (stats and directions side by side, then ANNONCER), the hand of three at the foot, the chosen card raised 12px; the reveal and the result keep their phone order. No behaviour changes.

</intent-contract>

## Implementation Notes

Oneshot, a layout change in CSS plus three view hooks. The sheet already renders as a centred modal from 720px, and the screen has no tab bar or back button, so those parts needed no change.

- `app/frontend/styles/duels.css` -- from 1180px `.duels` is a grid: 400px column for the challenge and online panels, the decks in the wide column; the sheet's host div is `display: contents`.
- `app/frontend/styles/duel-desktop.css` (new, imported after `duel-board.css`) -- from 1180px the live board is a four-track grid (opponent deck, stat, direction, player deck); the hand and its form are `display: contents` so the hand group drops to the foot row and the stat and direction groups sit side by side above the button; decks are 3 × 4 cells of 74px with the card name; the chosen card is raised 12px. The header, reveal, result and waiting line keep the phone column width.
- `app/views/duels/_deck.html.erb` -- a visible, `aria-hidden` card name beside the existing hidden title (shown only on desktop).
- `app/views/duels/_hand_group.html.erb` -- `duel-group--hand` modifier on the hand fieldset.
- `app/views/duels/_sheet.html.erb` -- `duel-sheet-host` class on the controller's wrapper.
- `test/system/duel_desktop_test.rb` -- two desktop sessions: the layout of the Duels screen, the centred dialog, a round played, the window restored.

The "Derniers duels" group the design draws in the left column does not exist yet (the record belongs to the next epic); the column holds the two groups that exist.

## Plan Change Log

## Review Triage Log

### 2026-11-17 — Review pass
- verdicts: 7 findings — high 0, medium 1, low 3, false 1, maybe-false 0 (two reported as stated deviations or test depth, rejected)
- findings:
  - `[low]` `[defer]` Tab order follows the hand, stat, direction, button while the hand sits at the foot on desktop — the order is the order of the choices; moving the hand in the markup would change the phone screen and the controller's selectors, so it needs its own change.
  - `[medium]` `[patch]` Spacing doubled in the waiting state, none between the button and the hand — margins moved onto the table, the groups and the button; the hand has none.
  - `[low]` `[reject]` Played mark overlays the new name strip and the name is not dimmed — the mark still reads over the cell; the fix adds a rule for no named harm.
  - `[low]` `[reject]` A card with no image shows its name at the top of the cell — every card has a cover image in the catalogue; the guard would add a branch for a state not shown reachable.
  - `[false]` `[reject]` "Fills the window" capped at 1280px — the shell's `.main` content cap applies to every screen; the duel is as wide as the shell allows.
  - `[low]` `[reject]` Test depth (result and waiting line at desktop, 1179px boundary, answer turn) — the answer turn runs in the test; the other layouts reuse the phone rules unchanged.
  - `[low]` `[reject]` DERNIERS DUELS group missing — stated in the plan: the record is built by the next epic.

## Verification

**Commands:**
- `bin/rails test test/system/duel_desktop_test.rb test/system/duel_challenge_test.rb test/system/duel_play_test.rb test/system/duel_deadline_test.rb test/system/duels_test.rb` -- expected: pass
- `npm run test:js`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `npm run format:check`, `npm run lint:css`, `script/check_planning_references`, `script/check_file_sizes` -- expected: pass

## Auto Run Result

- Summary: the Duels screen and the duel screen laid out for a desktop window, in CSS with three view hooks and one system test.
- Files: `duels.css`, new `duel-desktop.css` (imported in `application.css`), `_deck.html.erb`, `_hand_group.html.erb`, `_sheet.html.erb`, `duel_desktop_test.rb`, this plan.
- Review: 1 patch applied (spacing), 1 deferred (tab order), 5 rejected with reasons above.
- Follow-up review recommended: false.
- Verification: desktop, challenge, play, deadline and Duels system tests pass; vitest, zeitwerk, packwerk, prettier, stylelint, planning references and file sizes pass. One unrelated sign-in flake seen once in duel_play_test at phone width, not reproduced in five reruns.
- Residual risks: layout not compared with boards 11 and 12 (not in the repository); not seen in a real desktop browser.
