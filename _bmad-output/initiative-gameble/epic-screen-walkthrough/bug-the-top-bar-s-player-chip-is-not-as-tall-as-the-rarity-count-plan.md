---
title: "The top bar's player chip is not as tall as the rarity counter and the capsules chip"
type: 'bugfix'
ticket: '20'
created: '2026-10-24'
status: 'built'
baseline_revision: '8dcacbf74d26517c0b7a5f4eb95dbb3ea42e003f'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
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

### 2026-10-24 — Review pass
- verdicts: 4 findings — high 0, medium 1, low 2, false 1, maybe-false 0
- findings:
  - `[low]` `patch` The comment added over `.player-chip__avatar` explains a design choice over two lines, against the comment rule — removed, the original one-line comment kept.
  - `[low]` `reject` `assert_chip_heights` rewrites `eventually`'s synchronize loop by hand — deliberate: its failure message carries the measured heights, which `eventually` fixes before measuring; folding it in needs a new parameter on the shared helper.
  - `[false]` `reject` The new constants and helpers sit mid-class instead of at the top — the file already keeps topic helpers beside their tests (`refresh_with_turbo` at line 208, `sign_in_with_three_cards` at line 413).
  - `[medium]` `patch` With no vertical padding the 32px avatar covers 1px of the chip's 2px inset border top and bottom, hides the hover ring over its width, and its outline spills 2px past the chip — the avatar is now 30px, the chip's inner height, which restores the old fit (outline 1px past the edge, border and rings clear).

## Verification

**Commands:**
- `bin/rails test test/system/shell_test.rb` -- expected: all pass, the new chip-height test included
- `npm run test:js`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bin/rails test` -- expected: pass

**Manual checks (if no CLI):**
- On staging, the author sees the three chips at one height on the hub, the library and a card page, desktop and phone.

## Auto Run Result

Status: built

- Summary: the player chip loses its vertical padding and its avatar is 30px, so from 720px up it stands at the chips' 34px height beside the rarity counter and the capsules chip, the avatar inside the chip's border; under 720px every chip stays 44px.
- Files: `app/frontend/styles/shell.css` (`padding-block: 0` on `.player-chip__button`, the avatar at 30px); `test/system/shell_test.rb` (the visible chips' heights against the chip-height token on the hub, the library, a card and the booster at 1400, 1000, 800, 390 and 360px).
- Review: the Quick lens ran from the coordinating session after the unattended run halted on `no subagents`. 4 findings: 2 patched (1 medium, 1 low), 2 rejected (1 low, 1 false) with their reasons above; nothing deferred.
- Follow-up review recommended: false (one medium patched, no high).
- Verification: after the patch, `bin/rails test test/system/shell_test.rb` 22 runs, 0 failures on Chromium 141; the unattended run's `bin/rails test`, vitest, typecheck, zeitwerk, packwerk, i18n-tasks, rubocop and brakeman passed.
- Residual risks: the avatar is 2px smaller on the phone's 44px chip too; the author's look on staging settles it.
