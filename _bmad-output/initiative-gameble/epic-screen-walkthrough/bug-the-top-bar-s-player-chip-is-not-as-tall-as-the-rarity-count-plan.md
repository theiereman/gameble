---
title: "The top bar's player chip is not as tall as the rarity counter and the capsules chip"
type: 'bugfix'
ticket: '20'
created: '2026-10-24'
status: 'blocked'
baseline_revision: '8dcacbf74d26517c0b7a5f4eb95dbb3ea42e003f'
route: 'oneshot'
route_source: 'auto'
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** In the signed-in top bar the rarity counter and the capsules chip (and the booster's static reserve chip) are 34px tall (`--space-chip-height`), but the player chip is 36px from 720px up: its 32px avatar plus the chips' shared 2px vertical padding (`app/frontend/styles/shell.css`, `.rarity-counter__button, .packs-chip, .player-chip__button` and `.player-chip__button`). Measured in headless Chromium on the hub, the library, a card page and the booster at 1400, 1000 and 800px: 34 / 34 / 36. Under 720px all chips already take the 44px touch height.

**Approach:** Drop the player chip's vertical padding so its height comes from the shared `--space-chip-height` minimum, which the 32px avatar fits inside; its horizontal padding, avatar, name, dot and the phone's 44px hit area stay as they are. DESIGN.md's `chip-height: 34px` decides the shared height, so the other chips do not grow. A shell system test measures the chips' heights on the hub, the library and a card page at desktop, medium and phone widths, comparing each visible chip with the others and with the token.

</intent-contract>

## Implementation Notes

Oneshot: one CSS declaration and one system test, well under 100 lines. On the library the bar shows its status and the player chip only (and no player chip on the phone), so there the test compares the player chip with the hub's chip height; the booster's static reserve chip shares the rule and is checked too.

- `app/frontend/styles/shell.css`: `.player-chip__button` gets `padding-block: 0`; the chip is now `--space-chip-height` (34px) from 720px up, the avatar 1px from its top and bottom edges; under 720px every chip keeps `--space-chip-height-touch` (44px). The avatar's 3px outline already reached past the chip's 2px frame before (1px), it now reaches 2px past it, on the dark bar.
- `test/system/shell_test.rb`: "the rarity counter, the capsules chip and the player chip stand at one height, at every width" visits the hub, the library, a card and the booster at 1400, 1000, 800, 390 and 360px and compares the visible chips' heights with the chip-height token for that width (retrying through Capybara's synchronize). Against the old CSS it fails on the hub at 1400px: player chip 36px, the others 34px.
- Verified in headless Chromium 141: shell and settings system tests (33 runs) pass; `bin/rails test` (3169 runs, 2 workers), `npm run test:js` (561), `npm run typecheck`, `bin/rails zeitwerk:check`, `bundle exec packwerk validate` and `check`, `i18n-tasks missing`, rubocop and brakeman pass. `bin/bundler-audit` reports crass 1.0.7, already on develop and untouched here. `bin/ci` itself was not run: its setup and schema steps need Postgres 18; no migration is involved.

## Plan Change Log

## Review Triage Log

## Verification

**Commands:**
- `bin/rails test test/system/shell_test.rb` -- expected: all pass, the new chip-height test included
- `npm run test:js`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bin/rails test` -- expected: pass

**Manual checks (if no CLI):**
- On staging, the author sees the three chips at one height on the hub, the library and a card page, desktop and phone.

## Auto Run Result

Status: blocked
Blocking condition: no subagents. The review step's Quick lens needs a context-free reviewer subagent; this unattended run had no tool to launch one, so no review pass ran and `## Review Triage Log` is empty. `tickets.py mark` was not run: the ticket store is GitHub and `gh` is not authenticated in this container, so `status` was written here by hand.

- Summary: the player chip loses its vertical padding, so from 720px up it stands at the chips' 34px height (`--space-chip-height`) beside the rarity counter and the capsules or reserve chip; under 720px every chip was and stays 44px (`--space-chip-height-touch`).
- Files changed:
  - `app/frontend/styles/shell.css` -- `padding-block: 0` on `.player-chip__button`, and its comment.
  - `test/system/shell_test.rb` -- a test comparing the visible chips' heights with the chip-height token on the hub, the library, a card and the booster at 1400, 1000, 800, 390 and 360px.
- Verification: see Implementation Notes; the new test fails against the old CSS (36px against 34px) and passes with the fix; the shell and settings system tests, `bin/rails test`, vitest, typecheck, zeitwerk, packwerk, i18n-tasks, rubocop and brakeman pass.
- Residual risks: no independent review ran. The avatar's 3px outline now reaches 2px past the chip's frame at top and bottom (1px before), on the dark top bar; the author's check on staging settles whether that reads. The code is implemented and verified, waiting on its review pass: rerun `bmad-build-auto` on this plan where subagents are available (a `blocked` plan halts at once, so set its `status` back to `in-review` first).
