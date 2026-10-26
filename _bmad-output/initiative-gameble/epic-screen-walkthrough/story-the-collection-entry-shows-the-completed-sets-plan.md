---
title: 'The collection entry shows the completed sets'
type: 'feature'
ticket: '35'
created: '2026-10-26'
status: 'built'
baseline_revision: '265918abdc707729df0f203bdd666200204a7aac'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
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
- [x] `set_board.rb` + test -- `Board` gains `complete` (every complete standing, latest gained first).
- [x] `set_board_loading.rb` -- one `set_tiles` pass over both lists (one `SetShowcases` call), `closest` from EN COURS only; `@complete_tiles`.
- [x] `in_progress.html.erb`, tile partial, helper -- the COMPLETED section and the complete tile's line.
- [x] locales -- both files.
- [x] tests -- frame shows complete sets in order, hidden when none, EN COURS empty message with only complete sets, no gold frame in COMPLETED, query count unchanged with complete sets added; system test: a complete tile turns and links to its album.
- [x] DESIGN.md, EXPERIENCE.md -- record the section.

**Acceptance Criteria:**
- Given a player with 2 complete sets and 3 in progress, when the collection opens, then EN COURS shows 3 tiles and COMPLÉTÉS 2, the most recently completed first, each a link to its album.
- Given a player with no complete set, then no COMPLÉTÉS heading shows.
- Given a complete set's tile, then its recto reads COMPLET with a full gauge and the complete line, and its verso every tier reached.

## Implementation Notes

- `Game::SetBoard::Board` gains `complete`: every complete standing not in `in_progress`, latest completion first. `SetsInProgress` folds the player's `complete` tier `reached_at` into its one query as `SetStanding#completed_at`; the order falls back to `gained_at` when no completion is recorded, then `set_id`, so a duplicate gained later never moves a set.
- `load_set_tiles` reads the sets of both lists in one `SetsById` call and builds every tile in one `set_tiles` pass (one `SetShowcases` call); `set_tiles` takes `closest_among:` (default: all rows, so the public profile is unchanged) and the entry passes the EN COURS rows only. The frame's query count stays 7 with five complete sets added.
- A set completed by the latest gain (`reached_now`) is still in progress by `SetStanding#in_progress?`; it stays in EN COURS and out of COMPLÉTÉS until the next gain (author, 2026-10-26: a set never shows twice).
- `set_next_tier_line` became `set_goal_line`: a complete standing reads `library.set_tile.complete` ("Every card collected" / "Toutes les cartes obtenues"). The key sits under `library.set_tile`, beside `next_html`, since the line belongs to the shared tile; the section title is `library.entry.completed`. The public profile's complete tiles render the same line (approved by the author, 2026-10-26).
- Both sections render through `library/_set_tile_section`; the frame is a flex column with the entry's section gap.

## Plan Change Log

## Review Triage Log

### 2026-10-26 — Review pass (quick)
- verdicts: 4 findings — high 0, medium 2, low 1, false 1, maybe-false 0
- findings:
  - `[false]` `reject` The public profile's complete tiles now show the complete line, against the boundary — the author approved it on 2026-10-26 when asked.
  - `[medium]` `patch` A set completed by the latest gain showed in EN COURS and COMPLETED — the author decided it stays out of COMPLETED while in EN COURS; the board and the frame test assert it shows once.
  - `[medium]` `patch` COMPLETED was ordered by the latest copy gained, so a duplicate moved an old set to the top — ordered by the `complete` tier's `reached_at` read in the existing standings query, falling back to the latest gain; a board test covers the duplicate.
  - `[low]` `patch` The docs credited build-time copy to the author — the copy and the order are marked as chosen at build.

## Verification

**Commands:**
- `bin/rails test test/controllers/library_controller_test.rb test/packs/game/set_board_test.rb test/packs/game/set_showcases_test.rb` -- green
- `bin/rails test test/system/library_test.rb test/system/collection_set_test.rb` -- green
- `bin/rails test`, `npm run test:js`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bundle exec rubocop`, `bundle exec i18n-tasks missing` -- green; `git checkout db/schema.rb` if a test run rewrites it
