---
title: "The card detail's Steam and share buttons sit on the card information's background"
type: 'bugfix'
ticket: '17'
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
context: []
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** On the card detail (`app/views/cards/_detail.html.erb`, rendered for a player on the card's own page and when browsing a grid, set or opened pack), the bracketed panel is the `article.card-detail` itself, so its `--color-panel` background wraps the actions row too: "Voir sur Steam", "Partager" and the holder's "Reposter" and showcase choice stand on the same background as the card's information (author, on staging, 2026-10-23).

**Approach:** Keep `article.card-detail` as the detail's unstyled outer box (its controllers, data values and accessible name unchanged), move the bracketed panel to an inner `div.card-detail__panel` holding the header, the card and its information only, and render `.card-detail__actions` after the panel, outside its background, at every width: under the panel on a desktop, still pinned above the tab bar on a phone, on the page's ground colour rather than the panel's. DESIGN.md's card detail section says the buttons stand under the panel, outside it. The visitor's public card page (`cards/_public`) already has no information background and is not changed; the not-owned card's look on the stage is another ticket's.

</intent-contract>

## Implementation Notes

Oneshot: one partial, its stylesheet, DESIGN.md's card detail line and the request test pinning the panel's place; no behaviour, controller or string change.

- `app/views/cards/_detail.html.erb`: the outer box is a plain `tag.article.card-detail` carrying the sub-view and share controllers, their values and `aria-labelledby`; a `PanelComponent` (`div.card-detail__panel`, brackets) holds the header and the stage/information columns; `.card-detail__actions` and the share sheet follow the panel inside the article, so `share#copy` and the sub-view targets keep their controller. The panel's content is re-indented one level (whitespace only over the stage and facts; a whitespace-ignoring diff shows the real change).
- `app/frontend/styles/card-detail.css`: the phone padding moves from `.card-detail` to `.card-detail__panel`; the phone's pinned actions lose the negative margin that reached over the panel's padding and stand on `--color-ground` instead of `--color-panel`, keeping their top line. The desktop needs no new rule: `.card-detail` is a flex column with a `--space-6` gap, which clears the bottom-right bracket.
- `_bmad-output/initiative-gameble/ux-gameble/DESIGN.md`: the card detail's buttons stand under the panel, outside its background.
- `test/controllers/cards_controller_test.rb`: the panel sits inside the article, the actions follow it, and no button is inside the panel. `test/system/card_detail_test.rb`: on a desktop the actions start below the panel's bottom, on a different background.
- The visitor's public card page (`cards/_public`) has no information background and its Steam link is not inside one; unchanged.
- Surprise: the worktree started 282 commits behind `origin/develop`; the branch was fast-forwarded to `origin/develop` (9ec8aeb2) before planning, since the ticket was not in the older tree.

## Plan Change Log

## Review Triage Log

### 2026-10-24 — Review pass
- verdicts: 3 findings — high 0, medium 1, low 2, false 0, maybe-false 0
- findings:
  - `[medium]` `patch` The `.card-detail` flex gap now spaces the article's children, so the header sat flush against the card and its information inside the new panel — `.card-detail__panel` is a flex column with the same `--space-6` gap.
  - `[low]` `patch` The desktop system check's background comparison always passed (the actions have no desktop background) — the check keeps only the geometry: the actions start at or below the panel's bottom.
  - `[low]` `patch` Two new test comments restated their assertions, against the comment rule — removed.

## Verification

**Commands:**
- `bin/rails test test/controllers/cards_controller_test.rb` -- expected: pass, the panel inside the article and the actions outside the panel
- `bin/rails test test/system/card_detail_test.rb test/system/share_card_test.rb` -- expected: pass (the actions stay in view above the phone's tab bar)
- `PARALLEL_WORKERS=2 bin/rails test` -- expected: pass
- `npm run test:js`, `bin/rubocop`, `bundle exec erb_lint` (if present), `bin/rails zeitwerk:check`, `bundle exec packwerk check` -- expected: pass

**Manual checks:**
- Desktop and phone screenshots of the detail: the panel's background ends above the buttons.

**Results (2026-10-25):**
- `bin/rails test test/controllers/cards_controller_test.rb`: 58 runs, 0 failures.
- `bin/rails test test/system/card_detail_test.rb test/system/share_card_test.rb`: 19 runs, 0 failures; `test/system/shell_test.rb -n /back button/` (2 runs) and `test/system/booster_test.rb -n /opens its card page/` (1 run), which open the detail: 0 failures.
- `PARALLEL_WORKERS=2 bin/rails test`: 3171 runs, 2 failures, both timing budgets unrelated to the change, on a machine shared by nine builds (`pioneer_of_test.rb:14`, 68.8 s against 60; `set_builder_test.rb:350`, 5.88 s against 5); both files pass alone (69 runs, 0 failures).
- `npm run test:js` (561 tests), `npm run typecheck`, `bin/rubocop`, `bundle exec packwerk validate` and `check`, `bundle exec i18n-tasks missing`, `bin/rails zeitwerk:check`, `bin/brakeman`: pass. No ERB linter is installed.
- Screenshots (desktop 1400 wide, phone 390 × 844): on the desktop the panel's background ends above SEE ON STEAM, SHARE, REPOST and ADD TO SHOWCASE; on the phone the pinned bar stands on the page's ground over the scrolling panel.

## Auto Run Result

Status: built

- Summary: on the signed-in card detail the information background is an inner panel holding the header, the card and its information; the Steam and share buttons and the share sheet stand after it, outside its background, on the desktop under the panel and on the phone pinned above the tab bar on the page's ground.
- Files: `app/views/cards/_detail.html.erb` (the inner `card-detail__panel`), `app/frontend/styles/card-detail.css` (the panel's column and gap, the phone's pinned actions), `test/controllers/cards_controller_test.rb` and `test/system/card_detail_test.rb` (the actions outside the panel), `ux-gameble/DESIGN.md` (card detail). The visitor's public card page has no information background and is unchanged.
- Review: the Quick lens ran from the coordinating session after the unattended run halted on `no subagents`. 3 findings, all patched (1 medium, 2 low); nothing deferred or rejected.
- Follow-up review recommended: false (one medium patched).
- Verification: after the patches, `cards_controller_test.rb`, `card_detail_test.rb` and `share_card_test.rb` 77 runs, 0 failures on Chromium 141; the unattended run's full suite 3171 runs with two load-bound timing failures unrelated to this change (`pioneer_of_test.rb:14`, `set_builder_test.rb:350`, both green alone), vitest 561, typecheck, rubocop, packwerk, i18n-tasks, zeitwerk, brakeman clean.
- Residual risks: the template was re-indented, so 16.25 and 16.26 may conflict on whitespace; the phone's pinned bar hides the starfield behind it, for the author's look on staging.
