---
title: 'A not-owned card is greyed and locked on its detail too'
type: 'feature'
ticket: 26
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

### 2026-10-24 — Review pass
- verdicts: 5 findings — high 0, medium 0, low 5, false 0, maybe-false 0
- findings:
  - `[low]` `patch` `cards_controller.rb`'s header and `card-detail.css`'s still said the detail shows the card's face held or not — the stale clauses are dropped.
  - `[low]` `patch` The showcase test's name said it shows the face, while its `moderator` viewer holds nothing and now sees it locked — renamed, and it asserts the not-owned face in the `brother` context.
  - `[low]` `patch` DESIGN.md's Card detail bullet opened with the card's effects, then contradicted it; EXPERIENCE.md's Card not owned (grid) row ended oddly — both now say the effects belong to a held card or a visitor's, and the grid's face opens a detail showing the same face.
  - `[low]` `patch` New test comments restated their tests — removed.
  - `[low]` `patch` The album's computed-style read ran right after `visit` — a retrying `assert_selector` for the not-owned face now precedes it.

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

Status: built

- Summary: a signed-in player who holds a card's game in no edition sees its detail card faded, grey and locked, the same Card not owned face as in the grids, at every width and on every card ◀ ▶ steps to, judged by the viewer's own holdings; an owned card, a visitor and the public card page keep the plain face, and the share sheet's thumbnail stays plain.
- Files: `app/views/cards/_detail.html.erb` (the owned flag and the not-owned face), `app/controllers/cards_controller.rb` and `app/views/library/_grid.html.erb` (comments), `app/frontend/styles/card-detail.css` (comment), `test/controllers/cards_controller_test.rb`, `test/system/card_detail_test.rb`, EXPERIENCE.md and DESIGN.md.
- Review: the Quick lens ran from the coordinating session after the unattended run halted on `no subagents`. 5 findings, all low, all patched; nothing deferred or rejected.
- Follow-up review recommended: false.
- Verification: after the patches, `cards_controller_test.rb` and `card_detail_test.rb` 71 runs, 0 failures on Chromium 141, rubocop clean; the unattended run's cards, preview tags and component tests (148 runs), the share, library, shell, booster and public profile system tests (each file alone), the full suite (one load-bound `pioneer_of_test.rb` failure, green alone), vitest 561, typecheck, zeitwerk, packwerk, i18n-tasks and brakeman passed.
- Residual risks: "the lock covers its zoom" was read as the detail's own card, the detail having no separate zoom; a pack card traded away since now shows locked when walking that pack from the booster.
