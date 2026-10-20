---
title: 'The collection entry leads with the search and all cards, without À DÉCOUVRIR'
type: 'bugfix'
ticket: '18'
created: '2026-10-19'
status: ready-for-dev
baseline_revision: 'dc48b5b24e2afc02ed43ea44047680fd3c896fab'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/AGENTS.md'
warnings: [oversized]
deferred: []
---

<intent-contract>

## Intent

**Problem:** On the author's staging check of entry 7, "À DÉCOUVRIR" made little sense, and the set search with "TOUTES LES CARTES ▸" sat at the bottom of the collection entry, the button a faint link.

**Approach:** The entry (own collection `/library`, public and friends' profiles `brothers/:token`) drops "À DÉCOUVRIR" and reads: h2 "CHERCHER UN SET", the search field with "TOUTES LES CARTES ▸" as a filled primary button on the same row (under the field, full width, below 720 px; not on a profile), the search status line, then "EN COURS" (or one line pointing to the search when there is none), then the RÉSULTATS frame. The hub's "SETS EN COURS" keeps its fill (touched sets, then popular ones).

## Boundaries & Constraints

**Always:**
- Order inside `.set-entry`: search section (h2 `#set-search-title` "Chercher un set" / "Find a set"; the `role="search"` GET form labelled by it, field `#set-search-field`, `<noscript>` submit; the all-cards link when `all_cards_url`), the polite status line (`p.set-search__status[role=status]`), then EN COURS (h2 `#set-entry-in-progress-title`) or the pointer line, then `turbo-frame#set-search-results`. The h2 list reads "Chercher un set", "En cours" (then "Résultats" with a query).
- No set in progress (a new player, a visitor, an owner with none): no EN COURS heading; one `p.set-entry__empty` line — en "No set in progress yet. Find one above.", fr "Aucun set en cours pour l'instant. Cherchez-en un ci-dessus." (same line on a profile).
- "TOUTES LES CARTES ▸": `ButtonComponent` variant `:primary` linking to `library_cards_path`, its label `library.entry.all_cards` followed by the pixel icon `arrow-small-right` (aria-hidden); same height as the field; on the phone (< 720 px) full width under the field.
- Typing never moves EN COURS: results render below it; the status line keeps one line of height when empty, so the count appearing does not push EN COURS down.
- Search behaviour unchanged (300 ms debounce, Turbo frame, URL replaced, Esc clears, focus stays, works without JavaScript); the Stimulus controller moves from the form to the search section so the status line can sit outside the form, and submits its `form` target.
- `Game::SetBoard.call(player, season:, in_progress: 10)` answers `Board(in_progress:, standings:)` — no discover list, no popular fill, so one query (none for a nil player or season). `Game::SetBoard.hub` unchanged (touched then popular fill), `Catalog::PopularSets` and `Catalog::SetFigures` stay (hub, search).
- Every string in `en.yml` and `fr.yml`; delete `library.entry.discover` and any other key left unused; no `style` attribute; no planning ids or explanatory comments in code; English in repo text.
- EXPERIENCE.md (Collection opening, Set album's heading list, Set search, Copy deck's Collection row, the Collection screen table's purpose) and DESIGN.md's Collection entry bullet describe the new order without À DÉCOUVRIR.

**Never:**
- No change to the hub panel, the album, the grid at `/library/cards`, the set rows' rendering, the friend profile dialog, the search matching rules.
- Do not edit `<frozen-after-approval>` blocks or `pending-approvals.md`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Player with progress | sets at 2/3, 29/62… | h2s "Find a set", "In progress"; primary "All cards" link before EN COURS; no "To discover" | — |
| New player | no holding | search, primary button, pointer line; no EN COURS heading, no set row | — |
| One game held only | theme 1/18 | not shown on the entry (found by the search) | — |
| Visitor on `/library` | signed out | search, button, pointer line | — |
| Profile, owner with progress | signed out visitor | search (no button), owner's EN COURS rows to `brother_set_path` | hidden owner → 404 as today |
| Profile, owner with nothing | — | search, pointer line | — |
| Search | `q=souls` | RÉSULTATS after EN COURS; status "1 set trouvé" | — |
| Hub | player with one touched set, visitor | unchanged: fill from touched then popular sets | — |

</intent-contract>

## Code Map

- `packs/game/app/queries/game/set_board.rb` -- drop `discover` from `Board`, `call`'s `discover:` option and its fill; `call` = `SetsInProgress` + `ranked_in_progress`; keep `hub`, `ranked_touched`, `popular`.
- `app/controllers/concerns/set_board_loading.rb` -- no `@discover`; sets named = in-progress ones.
- `app/views/library/show.html.erb`, `app/views/public_profiles/{show,_profile}.html.erb` -- stop passing `discover`; fix `_profile`'s locals comment.
- `app/views/library/_entry.html.erb` -- new order; renders `library/set_search` (search section + status) then EN COURS or `.set-entry__empty`, then the results frame (move the `turbo_frame_tag` block out of `_set_search` into its own partial `library/_set_results.html.erb` or into `_entry`). Keep `.set-entry`'s `data-controller="last-album"` and its action.
- `app/views/library/_set_search.html.erb` -- section `.set-search` carries `data-controller="set-search"`, `data-set-search-frame-value`, `data-action="turbo:frame-load@document->set-search#loaded"`; h2; `.set-search__row` holding the form (`data-set-search-target="form"`, its input/compositionend/keydown/submit actions, field, noscript submit) and the primary button; the status `p` after the row, inside the section.
- `app/frontend/controllers/set_search_controller.ts` -- `Controller<HTMLElement>`, target `form` (`HTMLFormElement`), `requestSubmit` on it. `app/frontend/lib/set_search.ts` unchanged.
- `app/frontend/styles/collection.css` -- remove `.set-search__head` rules; `.set-search__row` flex row (form `flex: 1`, button `flex: none; margin: 0`), column with full-width button under 720 px; `.set-search__form` keeps field + noscript submit; `.set-search__status` `min-height: 1lh`; `.set-entry__empty` muted body text like `.set-results__none`.
- `config/locales/{en,fr}.yml` -- remove `library.entry.discover`; add `library.entry.no_progress`. `_entry` uses literal keys (no `"library.entry.#{section}"`).
- `packs/game/test`: `test/packs/game/set_board_test.rb` -- discover tests become hub tests (nothing → four popular; started set fills before popular; touched set not in progress) or are dropped when the hub test already covers them; query counts: board 1, nil player 0.
- `test/controllers/library_controller_test.rb` -- header comment; h2 order; primary link `.set-search a.button--primary[href='/en/library/cards']` before EN COURS; new-player and visitor pointer line; earlier-edition test reads the count through EN COURS (hold a second game) or the search; query count drops (popular + figures gone: expect 9, confirm by running); status outside the form.
- `test/controllers/public_profiles_controller_test.rb` -- no discover rows; profile shows no all-cards link (`.set-search a`, false); owner with nothing shows the pointer line; French h2s `[ "Chercher un set", "En cours" ]`.
- `test/controllers/library_set_test.rb:312` -- give the player a set in progress so the entry has an `a.set-row`.
- `_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md` lines ~31, 102, 233, 234, 235; `DESIGN.md` line ~911 (Collection entry bullet; not frozen).

## Tasks & Acceptance

**Execution:**
- [x] `set_board.rb`, `set_board_loading.rb`, `set_board_test.rb` -- board without discover.
- [x] `_entry`, `_set_search`, results partial, `show`, `_profile`, `public_profiles/show` -- new order, primary button, pointer line.
- [x] `set_search_controller.ts` -- controller on the section, `form` target.
- [x] `collection.css` -- row, phone stacking, status height, empty line.
- [x] `en.yml`, `fr.yml` -- remove discover, add the pointer line.
- [x] Controller tests adapted for every matrix row; hub tests untouched and green.
- [x] `EXPERIENCE.md`, `DESIGN.md` -- new order, no À DÉCOUVRIR.

**Acceptance Criteria:**
- Given a player with sets in progress, when they open `/fr/library`, then the first h2 is "Chercher un set", a primary "Toutes les cartes" link to `/fr/library/cards` follows the field, "En cours" follows, and no "À découvrir" appears.
- Given a player with no set in progress, when they open the collection, then they see the search, the button and "Aucun set en cours pour l'instant. Cherchez-en un ci-dessus.", and no set row.
- Given a public profile, when a signed-out visitor opens it, then it shows the search without the all-cards button and the owner's EN COURS, and no À DÉCOUVRIR.
- Given the hub, when a new player or a visitor opens it, then "Sets en cours" still lists four popular sets.
- Given the change, when `bin/ci`, `npm run test:js`, `npm run typecheck`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bundle exec i18n-tasks missing` and `unused` run, then they pass (unused: only the pre-existing `rate_limit.*`).

## Implementation Notes

- The results frame moved to its own partial, `library/_set_results.html.erb`; `_entry` computes the status text once for the status line and the frame's hidden summary.
- `Game::SetBoard.call` now runs one query (none for a nil player or season); the entry costs 9 queries instead of 11, a profile 5 / 10 / 12 instead of 7 / 12 / 13. A search on a profile pays one query for the figures of sets the owner has not started, which the discover fill used to preload.
- Under 720 px the shell gives buttons 48px (`--space-button-height-phone`), so the field takes the same height there (review patch).
- Rebased onto origin/develop after the tier-renaming docs change: the EXPERIENCE.md and DESIGN.md conflicts were resolved by applying only this change's sentences to the upstream rows.
- Layout checked in headless Chrome on a scratch database: `/fr/library` signed out (search, primary button, pointer line) at 1280 and 390 px; a public profile with a search at 1280 and 390 px (no button, EN COURS, RÉSULTATS below). Not checked: the signed-in collection with sets in progress (same partial as the profile, plus the button).

## Plan Change Log

## Review Triage Log

### 2026-10-19 — Review pass
- verdicts: 1 findings — high 0, medium 0, low 1, false 0, maybe-false 0
- findings:
  - `[low]` `[patch]` Below 720 px the full-width "All cards" button is 48px (shell.css phone `.button` min-height) under a 44px field, against "same height as the field" — fixed: `.set-search__field` takes `min-height: var(--space-button-height-phone)` in collection.css's phone block.

## Design Notes

- **Status line outside the form:** inside the form it would sit between the field and the phone's full-width button; moving the controller up one element keeps field, button, count in that order on every width.
- **Board without discover:** with no À DÉCOUVRIR the entry needs neither the touched list nor the popular fill; the hub keeps both through `SetBoard.hub`.

## Verification

**Environment:** run every Rails command (tests, `bin/ci`, zeitwerk, i18n-tasks) with `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w1318` (created and loaded; Postgres already runs, never start one); `npm install` is done; do not run system tests; do not commit, push or touch git history. `npm install` rewrites `package-lock.json`'s "name" to the worktree's: revert that file before finishing.

**Commands:**
- `bin/rails test test/controllers/library_controller_test.rb test/controllers/public_profiles_controller_test.rb test/controllers/library_set_test.rb test/packs/game/set_board_test.rb test/controllers/pages_controller_test.rb` -- expected: green
- `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w1318 bin/ci` -- expected: green (revert a stray `package-lock.json` "license" line if it writes one)
- `npm run test:js`, `npm run typecheck`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bundle exec i18n-tasks missing`, `bundle exec i18n-tasks unused` -- expected: green (unused: `rate_limit.*` only)

**Manual checks (if no CLI):**
- `/fr/library` at 1280 px and 390 px in a headless browser if available: search row, button beside / under the field, EN COURS below.

## Auto Run Result

- **Summary:** the collection entry (`/library`, public and friends' profiles) drops "À découvrir" and opens on "Chercher un set": the search field with "Toutes les cartes ▸" as a filled primary button on its row (full width under it on the phone; absent on a profile), the search's status line, then "En cours", or with none the line "Aucun set en cours pour l'instant. Cherchez-en un ci-dessus.", then the results. The hub's "Sets en cours" keeps its fill from touched and popular sets. `Game::SetBoard.call` no longer builds a discover list.
- **Files:**
  - `packs/game/app/queries/game/set_board.rb`, `app/controllers/concerns/set_board_loading.rb` — the board without discover.
  - `app/views/library/{_entry,_set_search,_set_results,show}.html.erb`, `app/views/public_profiles/{show,_profile}.html.erb` — the new order, the primary button, the pointer line.
  - `app/frontend/controllers/set_search_controller.ts` — the controller on the search section, submitting its `form` target.
  - `app/frontend/styles/collection.css` — the search row, the phone stacking, the status line's kept height, the pointer line.
  - `config/locales/{en,fr}.yml` — `library.entry.discover` removed, `library.entry.no_progress` added.
  - `app/controllers/library_controller.rb`, `app/views/pages/_set_progress.html.erb` — comments.
  - Tests: `set_board_test.rb`, `library_controller_test.rb`, `public_profiles_controller_test.rb`, `library_set_test.rb`.
  - `EXPERIENCE.md` (Collection purpose, copy deck, Collection opening, Set album's h2s, Set search), `DESIGN.md` (Collection entry).
- **Review:** 1 patch applied (low); 0 deferred; 0 rejected.
- **Follow-up review:** false — one low patched.
- **Verification (after rebase onto origin/develop):** `bin/ci` green (2708 runs, 0 failures; rubocop, brakeman, audits, seeds); `npm run test:js` 407 passed; `npm run typecheck`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `i18n-tasks missing` green; `i18n-tasks unused` lists `rate_limit.*`, `date.*` and `time.*`, none touched by this change. `npm install`'s `package-lock.json` name rewrite reverted.
- **Residual risks:** the signed-in collection with sets in progress was not viewed in a browser; `min-height: 1lh` needs Safari 16.4+ / Firefox 120+ (older browsers let the count push EN COURS down by one line); system tests were not run.
