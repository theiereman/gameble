---
title: "A visitor's collection entry suggests sets to discover"
type: 'feature'
ticket: 7
created: '2026-10-20'
status: 'built'
baseline_revision: '78423faff04bc35e30dc1d458192c753d73e992e'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** A signed-out visitor on the collection entry (/library) sees EN COURS's empty line "Aucun set en cours pour l'instant. Cherchez-en un ci-dessus.", a progress line that means nothing signed out, and no set to start from.

**Approach:** For a visitor only, the entry shows, in EN COURS's place (after the search results frame), a section with the h2 "À DÉCOUVRIR" / "TO DISCOVER" listing four popular sets of the published season (`Catalog::PopularSets`, as `Game::SetBoard.hub` fills a visitor's hub), each a visitor set row (`library/set_progress_row` with `progress: false`: name and kind, no count, bar or tier) opening its album; no EN COURS and no empty line. A signed-in player's entry and public profiles are unchanged. Strings `library.entry.discover` in en.yml and fr.yml.

</intent-contract>

## Implementation Notes

Oneshot: about 40 lines across the set board concern, the library controller, the entry partial, two locale files and the library controller test.

- `app/controllers/concerns/set_board_loading.rb` -- `load_discover(season)`: `Catalog::PopularSets` ids (limit 4), named through `Catalog::SetsById`, kept in popularity order.
- `app/controllers/library_controller.rb#show` -- calls it when `current_player` is nil.
- `app/views/library/_entry.html.erb` -- for a visitor (`progress` false) the discover section in EN COURS's place; for a player EN COURS or its empty line as before.
- `config/locales/en.yml`, `fr.yml` -- `library.entry.discover`: "To discover" / "À découvrir" (uppercased by `.set-entry__title`, as "En cours").
- `test/controllers/library_controller_test.rb` -- the visitor half of the empty-entry test now expects To discover and no empty line; a new test covers the four popular sets in popularity order, visitor rows with no progress, album links, fr and en, no set id, and a signed-in player's unchanged empty line.
- A season with no set leaves a visitor's entry with the search alone (no heading, no line).

## Review Triage Log

### 2026-10-20 — Review pass
- verdicts: 3 findings — high 0, medium 0, low 3, false 0, maybe-false 0
- findings:
  - `[low]` `[patch]` `app/controllers/library_controller.rb:1-4` the header comment's rewrap left a ragged line — rewrapped the paragraph.
  - `[low]` `[reject]` a visitor's search frame requests also run the two discover queries — the same full-page render already loads a player's EN COURS on every frame request; two indexed queries on a public, throttled page, not worth a frame-specific branch.
  - `[low]` `[reject]` no test of a visitor's entry in a season with no set — the behavior (search alone) matches the intent; a published season always has sets in practice, and the test adds little.

## Verification

**Commands:** (prefix Rails commands with `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w14_7`; never run system tests)
- `bin/rails test` -- 0 failures
- `npm run test:js`, `npm run typecheck`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bin/rubocop`, `bundle exec i18n-tasks missing`, `bin/brakeman --quiet --no-pager --exit-on-warn` -- clean

## Auto Run Result

- Summary: on /library a signed-out visitor sees, after the set search, "À DÉCOUVRIR" / "TO DISCOVER" with the published season's four most popular sets (`Catalog::PopularSets`), as visitor set rows (name and kind, no count, bar or tier), each opening its album; no EN COURS and no empty line. A signed-in player's entry and public profiles are unchanged.
- Files: `app/controllers/concerns/set_board_loading.rb` (`load_discover`), `app/controllers/library_controller.rb` (calls it for a visitor), `app/views/library/show.html.erb`, `_entry.html.erb`, `config/locales/en.yml`, `fr.yml`, `test/controllers/library_controller_test.rb`.
- Review (quick): 3 low findings; 1 patched (comment rewrap), 2 rejected (see the triage log). No deferral.
- Follow-up review recommended: false (one low patched).
- Verification: `bin/rails test` 2913 runs, 0 failures; `npm run test:js` 492 passed; typecheck, zeitwerk, packwerk, rubocop (853 files), i18n-tasks missing and brakeman clean. After the comment-only patch, rubocop and the library controller test rerun clean. No system tests run.
- Residual risk: the section's layout is checked from the markup only, reusing the existing set entry and visitor row styles; not seen in a browser.
