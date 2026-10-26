---
title: 'The collection entry shows the completed sets'
type: 'feature'
ticket: '35'
created: '2026-10-26'
status: 'in-progress'
baseline_revision: '265918abdc707729df0f203bdd666200204a7aac'
route: 'full'
route_source: 'auto'
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/initiative-gameble/ux-gameble/mockups/key-collection-in-progress.html'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A set leaves the collection entry the moment it is complete: EN COURS shows only sets in progress, so the player's finished sets, the reward of the game, are found again only by a search (author, 2026-10-26: "sinon ça n'a pas grand intérêt").

**Approach:** Add a COMPLÉTÉS / COMPLETED section under EN COURS, in the same lazy frame, showing every complete set of the published season as a set progress tile, most recently completed first (the latest card gained in the set, as no completion date is stored). Hidden when the player has none.

## Boundaries & Constraints

**Always:** Reuse `library/_set_progress_tile` and its CSS; a complete set's tile: rank chip COMPLET (the `complete` tier chip), recto cards as for any set (all of a set of five or fewer, else the three best and "+N"), the gauge full, the line under it states the set is complete in place of "Plus que X pour Y"; verso: every path node reached, the card last gained, "VOIR L'ALBUM ▸". The gold frame stays on EN COURS only. Same two-column grid, turn, fade and touch rules as EN COURS. The tile data for both sections comes from a fixed number of queries (one `SetShowcases` call for all tiles). The EN COURS empty message still shows when nothing is in progress, even if sets are complete. Strings in en.yml and fr.yml. GET never writes; no ids in markup; no `style` attribute.

**Never:** Change the hub, the search results, the public profile or the set album. Show sets of another season.

</frozen-after-approval>

## Code Map

- `app/controllers/concerns/set_board_loading.rb:18` `load_set_tiles` → builds `@tiles` from `Game::SetBoard.call(...).in_progress`; `set_tiles` calls `Game::SetShowcases` once and marks `closest`.
- `packs/game/app/queries/game/set_board.rb`: `ranked_in_progress`, `ranked_touched`; add the complete sets ordered by `gained_at` desc then `set_id` (standings come from `SetsInProgress`, `SetStanding#complete?`, `#gained_at`).
- `app/views/library/in_progress.html.erb`: the frame; add the COMPLETED section after EN COURS (`set-entry__section`, its own heading id for `aria-labelledby`).
- `app/views/library/_set_progress_tile.html.erb`, `app/helpers/set_rows_helper.rb` (`set_rank_chip`, `set_next_tier_line`, `set_tier_path`): check each renders the complete case as above (the next-tier line returns nil once complete today: render the "complete" line instead).
- `config/locales/{en,fr}.yml` under `library.entry`: section title ("COMPLÉTÉS" / "COMPLETED"), the complete line.
- Tests: `test/controllers/library_controller_test.rb` (frame action tests), `test/packs/game/set_board_test.rb`, `test/system/library_test.rb`.
- Docs: `ux-gameble/DESIGN.md` (Collection entry, Set progress tile), `ux-gameble/EXPERIENCE.md` (Collection opening row).

## Tasks & Acceptance

**Execution:**
- [ ] `set_board.rb` + test -- `Board` gains `complete` (every complete standing, latest gained first).
- [ ] `set_board_loading.rb` -- one `set_tiles` pass over both lists (one `SetShowcases` call), `closest` from EN COURS only; `@complete_tiles`.
- [ ] `in_progress.html.erb`, tile partial, helper -- the COMPLETED section and the complete tile's line.
- [ ] locales -- both files.
- [ ] tests -- frame shows complete sets in order, hidden when none, EN COURS empty message with only complete sets, no gold frame in COMPLETED, query count unchanged with complete sets added; system test: a complete tile turns and links to its album.
- [ ] DESIGN.md, EXPERIENCE.md -- record the section.

**Acceptance Criteria:**
- Given a player with 2 complete sets and 3 in progress, when the collection opens, then EN COURS shows 3 tiles and COMPLÉTÉS 2, the most recently completed first, each a link to its album.
- Given a player with no complete set, then no COMPLÉTÉS heading shows.
- Given a complete set's tile, then its recto reads COMPLET with a full gauge and the complete line, and its verso every tier reached.

## Implementation Notes

## Plan Change Log

## Review Triage Log

## Verification

**Commands:**
- `bin/rails test test/controllers/library_controller_test.rb test/packs/game/set_board_test.rb test/packs/game/set_showcases_test.rb` -- green
- `bin/rails test test/system/library_test.rb test/system/collection_set_test.rb` -- green
- `bin/rails test`, `npm run test:js`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bundle exec rubocop`, `bundle exec i18n-tasks missing` -- green; `git checkout db/schema.rb` if a test run rewrites it
