---
title: "The signed-in card detail's actions are sorted instead of stacked"
type: 'feature'
ticket: 25
created: '2026-10-25'
status: 'built'
baseline_revision: '27b677d308e8106cc52d312bb30f36340222094b'
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

**Problem:** Under the signed-in card detail's panel (`app/views/cards/_detail.html.erb`) the actions pile up in no order: "VOIR SUR STEAM" (the one filled, lime button) and "PARTAGER", then "REPOSTER", then "METTRE EN VITRINE" with its "Vitrine pleine" line, four buttons of two weights where the filled one is not the card's main action; on the phone they fill a pinned bar three or four rows tall (author, on staging, 2026-10-23). Settled by the author, 2026-10-24: REPOSTER is the card's main action, the one filled button; the showcase, share and Steam actions are secondary.

**Approach:** Sort the actions by weight and purpose, in this DOM, keyboard and visual order: the holder's actions first, "REPOSTER" (primary, filled) then the showcase choice (secondary: add, remove, or disabled add with the showcase-full line under the holder's buttons); then the card's links, "PARTAGER" then "VOIR SUR STEAM" (both secondary, Steam's new-tab name kept). On a desktop the two groups share one row, the holder's at the left and the links at the right; on the phone the pinned bar holds one row per group (the holder's, then the links), so it is two rows tall for a holder (plus the full line) and one for anyone else, the page's scroll padding following. Nothing folds away (the author's call names every action main or secondary). A card not held, a visitor and a not-owned card (16.26's greyed, locked face) show the links row alone, with no filled button. The actions stay outside the panel (16.17). DESIGN.md's Primary button and Card detail lines and EXPERIENCE.md's Card detail and Repost action rows follow. The hub's own showcase actions (`pages/_showcase_actions`) and the public card page are not this screen's actions and are unchanged.

</intent-contract>

## Implementation Notes

Oneshot: one partial's action block regrouped, its stylesheet's action rules, the tests that pinned the old order and weight, and two design documents; no string, controller, operation or JS change.

- Decision: two groups inside `.card-detail__actions`, in DOM, keyboard and visual order. `.card-detail__holder-actions` (rendered only when there is a repost or a showcase choice, which both need the viewed card-season held): the repost form (`ButtonComponent`, now the default primary variant), then `.card-detail__showcase` holding the one showcase button, then, when full, `p.card-detail__showcase-full` as the group's last child. `.card-detail__card-links`: the share button, then the Steam link (now `button--secondary`, its icon and "(new tab)" name kept). Accessible names are unchanged; the keyboard now meets the card's main action first.
- Decision: on a desktop both groups share one row, the links pushed to the panel's right edge by `margin-left: auto`; the showcase-full line is `flex: 1 0 100%` with `contain: inline-size`, so it wraps under the holder's two buttons without widening the group (two lines in French, under REPOSTER and METTRE EN VITRINE). Alone (a card not held, a visitor, 16.26's not-owned face), the links start at the left and no button is filled.
- Decision: on the phone the pinned bar is a column of the two groups. The holder's group is a grid `auto 1fr` (REPOSTER at its width, the showcase choice filling the rest, the full line spanning both columns), so a long label ("RETIRER DE LA VITRINE" at 360 px) wraps inside its button instead of pushing the button to a row of its own; the links share their row by content (`flex: 1 1 auto`). Measured: 390 × 844 and 360 × 740, FR and EN, every state is two rows (132 px) for a holder, plus the line (176 px) when full, one row (72 px) otherwise, down from up to four rows. The scroll padding rules follow (one extra row for the holder's group, plus the line's two lines and gap when full).
- Decision: nothing folds behind a more-actions control: the author's call names each action main or secondary, none folded away. The hub's showcase actions (`pages/_showcase_actions`, named in the ticket) are the hub's empty-showcase button, not this screen's actions, and are unchanged; so are the public card page and the hub's own secondary REPOSTER.
- Files: `app/views/cards/_detail.html.erb` (the two groups, the header and `showcase` local comments), `app/frontend/styles/card-detail.css` (desktop and phone action rules, scroll padding), `test/controllers/cards_controller_test.rb` (the Steam link secondary and no primary for a non-holder; the groups' order with REPOSTER the one primary; the full line closing the holder's group), `test/system/card_detail_test.rb` (the action order and fill on the desktop with the groups at the panel's edges, on the pinned phone bar as two rows, for a card not held and a visitor; a new test: a full showcase's line under the holder's buttons on the desktop and the phone), `ux-gameble/DESIGN.md` (Primary button list, Card detail), `ux-gameble/EXPERIENCE.md` (Card detail, Repost action).
- Surprise: running the shell, booster and public profile system files together (66 tests) crossed the parallelization threshold and forked onto the full suite's worker databases while it ran; the full suite was stopped and rerun alone, and the system files were rerun with `PARALLEL_WORKERS=1`.

## Plan Change Log

## Review Triage Log

### 2026-10-24 — Review pass
- verdicts: 2 findings — high 0, medium 0, low 2, false 0, maybe-false 0
- findings:
  - `[low]` `patch` The new desktop, full-showcase and phone layout checks read `getBoundingClientRect()` once, while the layout can still move when the web font swaps in — each is an `eventually` check with the same condition and message.
  - `[low]` `patch` Comments added or expanded in `card-detail.css`, `card_detail_test.rb` and `cards_controller_test.rb` restated the code — removed or cut back to their original line; `_detail.html.erb`'s header comment, an existing one kept accurate, stays.

## Verification

**Commands:**
- `bin/rails test test/controllers/cards_controller_test.rb test/controllers/card_preview_tags_test.rb` -- expected: pass, with the new order, the one primary being REPOSTER for a holder and none otherwise
- `bin/rails test test/system/card_detail_test.rb test/system/share_card_test.rb` -- expected: pass, the actions in order on the desktop and the phone, in view above the tab bar
- `PARALLEL_WORKERS=2 bin/rails test` -- expected: pass
- `npm run test:js`, `npm run typecheck`, `bin/rubocop`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bundle exec i18n-tasks missing` -- expected: pass

**Manual checks:**
- Desktop (1400 wide) and phone (390 × 844) screenshots, French and English: a holder with room in the showcase, a holder whose card is in it, a holder with a full showcase, a card not held.

**Results (2026-10-25, Chromium 141, Postgres 16, a host shared with other builds):**
- `bin/rails test test/controllers/cards_controller_test.rb test/controllers/card_preview_tags_test.rb test/controllers/showcases_controller_test.rb test/controllers/reposts_controller_test.rb` -- 103 runs, 0 failures.
- `bin/rails test test/system/card_detail_test.rb test/system/share_card_test.rb` -- 20 runs, 0 failures (the new full-showcase test included).
- `PARALLEL_WORKERS=1 bin/rails test test/system/public_profile_test.rb test/system/shell_test.rb test/system/booster_test.rb` (they open the detail) -- 66 runs, 0 failures.
- `PARALLEL_WORKERS=2 bin/rails test` -- 3188 runs, 33614 assertions, 0 failures, 0 errors.
- `npm run test:js` 580 passed; `npm run typecheck`, `bin/rubocop` (945 files), `bundle exec packwerk validate` and `check`, `bundle exec i18n-tasks missing`, `bin/rails zeitwerk:check`, `bin/brakeman` -- clean.
- Screenshots, desktop 1400 × 1000, phone 390 × 844 and 360 × 740, FR and EN, card to add, card in the showcase, full showcase, card not held (a scratch system test outside the repo): desktop one row, REPOSTER (lime) and the showcase choice at the left, PARTAGER and VOIR SUR STEAM at the panel's right edge, the full line in two lines under the holder's pair; phone two pinned rows (132 px) for a holder, 176 px with the full line, one row (72 px) for a card not held; at 360 px "RETIRER DE LA VITRINE" wraps inside its button, which keeps its 48 px height.

## Auto Run Result

Status: built

- Summary: the signed-in card detail's actions are two groups in DOM, keyboard and visual order: the holder's, REPOSTER (the only filled button) then the showcase choice, with the disabled add and "Vitrine pleine" under them when the showcase is full; then the card's links, PARTAGER and VOIR SUR STEAM, secondary. On the desktop both groups share one row, the links at the right; the phone's pinned bar has one row per group. A card not held, a visitor and a not-owned card show the links only. 16.17's placement and 16.26's not-owned face are kept; accessible names unchanged.
- Files: `app/views/cards/_detail.html.erb`, `app/frontend/styles/card-detail.css`, `test/controllers/cards_controller_test.rb`, `test/system/card_detail_test.rb`, DESIGN.md (Primary button, Card detail) and EXPERIENCE.md (Card detail, Repost action).
- Review: the Quick lens ran from the coordinating session after the unattended run halted on `no subagents`. 2 findings, both low, both patched; nothing deferred or rejected.
- Follow-up review recommended: false.
- Verification: after the patches, `cards_controller_test.rb`, `card_detail_test.rb` and `share_card_test.rb` 78 runs, 0 failures, twice, on Chromium 141; rubocop clean; the unattended run's cards, preview tags, showcases and reposts controller tests (103 runs), the public profile, shell and booster system tests (66 runs), the full suite (3188 runs, 0 failures), vitest 580, typecheck, packwerk, i18n-tasks, zeitwerk and brakeman passed.
- Residual risks: the layout is a reading of the author's call (nothing folded behind a more-actions control), for a look on staging; a card not held has no filled button; at 360px "RETIRER DE LA VITRINE" wraps inside its button.
