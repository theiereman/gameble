---
title: 'A not-owned card is greyed and locked on its detail too'
type: 'feature'
ticket: 26
created: '2026-10-25'
status: 'blocked'
blocked_at: '2026-10-25'
blocked_reason: 'no subagents'
baseline_revision: '9ec8aeb2f7bf1a6c773285d98ede884bb63f0144'
route: 'oneshot'
route_source: 'pinned'
review: 'quick'
review_source: 'pinned'
lenses_ran: []
review_loop_iteration: 0
followup_review_recommended: false
context: ['{project-root}/AGENTS.md']
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** The signed-in card detail (`app/views/cards/_detail.html.erb`, rendered by `cards#show` for a player or a visitor browsing a context) always draws the card's plain face at `card-l`, with rays and float for Épique and Légendaire, while Toutes les cartes, another player's full collection and a set album draw a card the viewer does not hold as the not-owned face (`CardComponent owned: false`: faded, grey, rarity effects and tilt off, pixel lock over the art). The author finds the mismatch inconsistent and reverses the 2026-10-20 call for the signed-in detail; settled 2026-10-24: the lock covers the signed-in detail and its zoom, the share preview keeps the card's plain public face.

**Approach:** Judge ownership as the grids do, by the game: a signed-in viewer holding no copy of the card's game in any edition (`@copies` nil, from `Game::HeldEditions`, copies > 0) sees the detail's card as `CardComponent.new(card: view, size: :l, owned: false)`, without `card-float` and rays; a holder of any edition, a visitor on the detail and the public card page keep the plain face. The judgment is the viewer's own holdings in every context (a player's album or grid included), as the copies row already is. The share sheet's thumbnail (the share preview) stays the plain face; the link preview tags carry no image. The detail has no zoom of its own: the lock covers its card at every width, the phone sub-view included, and each ◀ ▶ step renders the next card judged the same way. The booster's card zoom (a frozen React island showing the capsule's cards) is untouched. Update the controller test cases and the system test that asserted "never greyed", add a case for an owned card, another edition held, a visitor in a context and the share sheet thumbnail, and update EXPERIENCE.md (Card detail, Card not owned (grid) rows) and DESIGN.md (Card not owned, Card detail) and the code comments that say the detail always shows the face.

</intent-contract>

## Implementation Notes

Oneshot: one flag and the existing not-owned face; the rest is test and document updates. No new string, no JS, no CSS beyond what the component already styles; the Steam and share buttons (moved by 16.17) are not touched.

- Decision: the flag lives in the detail partial (`owned = !signed_in || copies.present?`) rather than the controller, since the partial already receives `signed_in` and `copies` (the viewer's copies across every edition, nil without one), so no new local or ivar was needed. A not-owned Épique or Légendaire drops the `card-float` wrapper and its rays, as the grids' faces carry none.
- Decision: "its zoom" has nothing to build on the detail: the detail has no zoom of its own, so the lock covers its card at every width (asserted on the phone sub-view too); the booster's card zoom (React island, bug fixes only) shows the capsule's cards just gained and is untouched.
- Files: `app/views/cards/_detail.html.erb` (the flag, the face, the header comment), `app/controllers/cards_controller.rb` and `app/views/library/_grid.html.erb` (comments that said the detail always shows the face), `test/controllers/cards_controller_test.rb` (six cases updated: not-owned within a set with the lock, no tilt or effects and the share sheet thumbnail plain; a pack's card not held; the grid's card not held; another edition held stays plain; a visitor in a context and the public page stay plain; a signed-in viewer judged by their own holdings on another player's album; the epic float case now holds the cards), `test/system/card_detail_test.rb` (the album's missing card opens a detail face with the album face's computed opacity, filter and visible lock, desktop and phone), `ux-gameble/EXPERIENCE.md` (Card detail, Card not owned (grid), card text order) and `ux-gameble/DESIGN.md` (Card not owned, Card detail).
- Surprise: the branch was cut from a stale `develop` (7e6b6570) that did not hold the ticket; it was fast-forwarded to `origin/develop` (9ec8aeb2) before the build. `npm install` rewrites `package-lock.json` in this environment; the change is reverted, not committed.
- Pre-existing, not from this change: `bin/bundler-audit` reports crass 1.0.7, and `i18n-tasks health` asks to normalize `back_office.seasons.index.confirm.one` in fr; CI runs `i18n-tasks missing`, which passes.

## Plan Change Log

## Review Triage Log

## Verification

**Commands:**
- `bin/rails test test/controllers/cards_controller_test.rb test/controllers/card_preview_tags_test.rb test/components` -- expected: pass
- `bin/rails test test/system/card_detail_test.rb test/system/library_test.rb` -- expected: pass
- `npm run test:js`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bin/rubocop`, `bundle exec i18n-tasks health`, `PARALLEL_WORKERS=2 bin/rails test` -- expected: pass

**Results (2026-10-25, Chromium 141, Postgres 16, a host loaded by eight other builds):**
- `bin/rails test test/controllers/cards_controller_test.rb test/controllers/card_preview_tags_test.rb test/components` -- 148 runs, 0 failures.
- `bin/rails test test/system/card_detail_test.rb` -- 13 runs, 0 failures; `share_card_test.rb` with `library_test.rb` 13 runs, 0 failures; `shell_test.rb` 22 runs, 0 failures; `booster_test.rb` with `public_profile_test.rb` 43 runs, 0 failures. Run all together in one process under the host's load (average 27), shell, booster, share and library tests failed on timing; each passed when rerun, and none of those failures concerned the detail's face.
- `PARALLEL_WORKERS=2 bin/rails test` -- 3171 runs, 1 failure: `Game::PioneerOfTest` "the first discoverer and the date, in one query" compares a fixture's `2.weeks.ago` within 1 minute, and the loaded run took 230 s between fixture load and that test; it passes alone (3 runs, 0 failures) and the change does not touch it.
- `npm run test:js` 561 passed; `npm run typecheck`, `bin/rails zeitwerk:check`, `bundle exec packwerk validate` and `check`, `bin/rubocop` (943 files), `bundle exec i18n-tasks missing`, `bin/brakeman` -- clean.
- `bin/bundler-audit` -- crass 1.0.7 advisory, pre-existing on `develop`; `bundle exec i18n-tasks health` -- one fr normalization (`back_office.seasons.index.confirm.one`), pre-existing on `develop`.

## Auto Run Result

Status: blocked
Blocking condition: no subagents

- Summary: a signed-in player who holds the card's game in no edition sees the card detail's `card-l` face as the grids' Card not owned face (faded, grey, pixel lock, no tilt, no effects, no float or rays), at every width and on each card ◀ ▶ reach, judged by the viewer's own holdings in every context; an owned card, a visitor's detail and the public card page stay plain, and the share sheet's thumbnail keeps the plain face. EXPERIENCE.md and DESIGN.md follow.
- Implemented, verified and committed; the review step (Quick lens, pinned) needs a subagent this session does not have, so the coordinator runs it. `tickets.py mark` was not run (refused on this store, and `gh` is unauthenticated here), so this plan's status was set by hand.
- Residual risks: "its zoom" in the author's 2026-10-24 call is read as the detail's own card (the detail has no separate zoom); if it meant the booster's card zoom, that React island is frozen to fixes and is untouched. A card of an opened pack the player has since traded away now opens locked from the booster's walk.
