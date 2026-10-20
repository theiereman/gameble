---
title: 'The card detail shows the face of a card not owned'
type: 'feature'
ticket: 3
created: '2026-10-20'
status: 'built'
baseline_revision: '3dfbe28a193dfc9d68641485ea063975fccbe8ae'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: []
deferred:
  - summary: >-
      The system tests still expect the faded card back in the detail and the missing slots in Toutes les cartes.
    evidence: |-
      test/system/card_detail_test.rb (the visitor clicking an empty slot expects .card-detail__back, opacity 0.55, "NON POSSÉDÉE" and no share button; other cases click .collection-grid .missing-slot) and test/system/library_test.rb (counts .missing-slot in the grid) describe the behaviour this epic removed. System tests are disabled until rebuilt, so they do not run; they need rewriting with the rebuild.
    location: >-
      test/system/card_detail_test.rb:169, test/system/library_test.rb:71
    severity: low
---

<intent-contract>

## Intent

**Problem:** The card detail (`CardsController#show`, `cards/_detail`) shows a card the viewer does not hold, inside a browse context (grid, pack, set, a player's album), as the viewer's card back, faded, and offers PARTAGER only to a signed-in holder. The author decided on 2026-10-20 (superseding the ticket's description) that the detail always shows the real card.

**Approach:** The detail always renders the card's face (`CardComponent` at `:l`, with its rays and float for Épique and Légendaire, never greyed or locked), owned or not, signed in or not; the faded back goes. PARTAGER and its share sheet appear on every card for every viewer of the detail. REPOSTER and the showcase buttons stay for owned cards only. For a signed-in player, a card not owned reads "Aucun" / "None" in the copies row and "Aucune" / "None" in an ÉDITIONS row that is now always present; a visitor has neither row.

## Boundaries & Constraints

**Always:** ◀ ▶ and the way back keep walking each context as today; the share link stays this card-season's own public page, naming no one; no database id; strings in both `en.yml` and `fr.yml`; no planning ids in code or tests; no `style` attribute.

**Never:** change the public card page (`cards/_public`, a visitor on the card's own page without a context), the grid (ticket 2, built), the visitor's grid ownership parts (ticket 4), the repost or showcase rules, or `Game::CardBacks` (the pack opening still uses `active_key`).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Player, owned | holds the card | unchanged: face, copies, ÉDITIONS lines, PARTAGER, REPOSTER, showcase | none |
| Player, not owned, from grid | `grid` context, no edition held | face (rays/float for epic+), copies "None", ÉDITIONS "None", PARTAGER with share sheet, no REPOSTER, no showcase | none |
| Player, not owned, from set / pack / another player's album | set, pack or `brother` context | face, never `.card-detail__back` | none |
| Visitor browsing a context | signed out, `grid` or set | face, PARTAGER and share sheet, no copies row, no ÉDITIONS row, no REPOSTER, no showcase, the invitation to play | none |
| Visitor, card's own page | signed out, no context | the public card page, unchanged | none |
| French | `fr` | "Aucun", "Aucune", "Partager" | none |

</intent-contract>

## Code Map

- `app/controllers/cards_controller.rb` -- `show`: `@share_url = share_url if @copies && current_player` becomes unconditional; drop `@faded`, `@back_key` and `owner_holds?` (only used for the fade). Rewrite the class comment's faded-back and share paragraphs (and "its cards faded as that player holds them") to the new rule.
- `app/views/cards/show.html.erb` -- stop passing `faded:` / `back_key:`; its comment "a holder can share it" becomes everyone.
- `app/views/cards/_detail.html.erb` -- remove the `faded` / `back_key` locals and the `if faded` branch (keep the face branch with `card-float` + `card_rays` for top rarities); the ÉDITIONS row renders for a signed-in player always, its value the lines when `editions.any?`, else `t("card_details.no_editions")`; update the header comment (share for every card, editions "None"). `repostable` already requires an edition of this season held: keep it.
- `app/helpers/card_details_helper.rb` -- delete `card_back_image` (its only caller was the faded back) and the "faded card back" mentions in the module and `link_to_card_detail` comments.
- `app/views/library/_grid.html.erb` -- its comment says the detail "shows a card the viewer does not hold as their faded card back": correct it.
- `app/frontend/styles/card-detail.css` -- delete the `.card-detail__back*` and `.card-detail__not-owned` rules (lines ~161-232).
- `config/locales/en.yml`, `fr.yml` -- add `card_details.no_editions` ("None" / "Aucune"); remove the now unused `card_details.not_owned`.
- `test/controllers/cards_controller_test.rb` -- every `.card-detail__back` case follows the new rule: a not-owned card in a grid, set, pack or album shows `.card-detail__card .card` (rays for epic), PARTAGER (`.card-detail__share-button`) and the share sheet for player and visitor, no repost or showcase; a player's not-owned card reads copies "None" and ÉDITIONS "None" (fr "Aucun" / "Aucune"); a visitor has no copies or editions row. Delete the `card_back_image` helper test. Adjust query-count assertions only for the queries removed, stating why.

## Tasks & Acceptance

**Execution:**
- [x] `app/controllers/cards_controller.rb`, `app/views/cards/show.html.erb` -- share for everyone, no fade.
- [x] `app/views/cards/_detail.html.erb` -- always the face; ÉDITIONS "None" for a player's card not owned.
- [x] `app/helpers/card_details_helper.rb`, `app/views/library/_grid.html.erb`, `app/frontend/styles/card-detail.css`, `config/locales/en.yml`, `config/locales/fr.yml` -- remove the faded back's leftovers, add `no_editions`.
- [x] `test/controllers/cards_controller_test.rb` -- the matrix rows.

**Acceptance Criteria:**
- Given a player opening from the grid a card they do not own, when the detail renders, then it shows the card's face with its effects, PARTAGER, copies "None" and ÉDITIONS "None", and no REPOSTER or showcase button.
- Given an owned card, when its detail renders, then nothing changes from today.
- Given a visitor browsing a grid, when they open a card, then they see its face and PARTAGER, and no copies or ÉDITIONS row.

## Implementation Notes

- The detail always renders the face; `@faded`, `@back_key`, `owner_holds?`, `card_back_image` and the faded back's CSS and `card_details.not_owned` key are gone. `@share_url` is set for every viewer; REPOSTER keeps its rule (an edition of this season held), the showcase its own.
- A signed-in player's ÉDITIONS row is always there, reading `card_details.no_editions` when no edition is held.
- The public card page (a visitor without a context) is unchanged.

## Plan Change Log

## Review Triage Log

### 2026-10-20 — Review pass
- verdicts: 6 findings — high 0, medium 0, low 6, false 0, maybe-false 0
- findings:
  - `[low]` `[patch]` card_preview_tags_test's holder-or-not test still says a non-holder has no share block, with a vacuous `.card-detail__share` assertion — renamed the test and asserted the non-holder's PARTAGER button and share sheet.
  - `[low]` `[patch]` A vacuous `.card-detail__share` false assertion in cards_controller_test's share sheet test — deleted.
  - `[low]` `[defer]` System tests still expect the faded back and missing grid slots — system tests are disabled until rebuilt; recorded in `deferred`.
  - `[low]` `[patch]` `_share_sheet` header says a holder opens it — now any viewer of the detail.
  - `[low]` `[patch]` Unused `card-detail__no-editions` class hook — removed.
  - `[low]` `[patch]` Edited comments not rewrapped, keeping planning ids in the rewritten headers — rewrapped `_detail`, `cards_controller.rb` and the test header, planning ids dropped from those two headers.

## Verification

**Commands:** (prefix every Rails command with `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w14 CHROME_BIN=/usr/bin/chromium`, this worktree's own test database; never run system tests; call git as `/usr/bin/git`; do not commit)
- `bin/rails test test/controllers/cards_controller_test.rb test/controllers/library_controller_test.rb test/helpers test/integration` -- pass
- `bundle exec i18n-tasks missing` and `bundle exec i18n-tasks unused` -- clean
- `npm run test:js` -- pass

## Auto Run Result

- Summary: the card detail always shows the real card with its effects, owned or not, signed in or not; PARTAGER and its share sheet are on every card for every viewer of the detail; REPOSTER and the showcase stay for owned cards; a player's card not owned reads "None"/"Aucun" in copies and "None"/"Aucune" in ÉDITIONS; a visitor has neither row.
- Files: `app/controllers/cards_controller.rb`, `app/views/cards/show.html.erb`, `_detail.html.erb`, `_share_sheet.html.erb` (comment), `app/helpers/card_details_helper.rb`, `app/views/library/_grid.html.erb` (comment), `app/frontend/styles/card-detail.css`, both locales, `test/controllers/cards_controller_test.rb`, `test/controllers/card_preview_tags_test.rb`.
- Review (quick): 6 low findings; 5 patched, 1 deferred (system tests), none rejected.
- Follow-up review recommended: false (only low entries patched).
- Verification: `bin/rails test` 2879 runs, 0 failures; `npm run test:js` 486 passed; typecheck, zeitwerk, packwerk, rubocop (846 files), i18n-tasks missing and brakeman clean.
- Residual risk: the stale system tests above.
