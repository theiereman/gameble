---
title: 'EN COURS shows sets as two-faced tiles'
type: 'feature'
ticket: '34'
created: '2026-10-26'
status: 'built'
baseline_revision: '12e9f09cb3f5325240e607365ed209b016fb4402'
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

**Problem:** The collection entry's EN COURS is a list of identical progress rows (the author finds it flat), and it stops at ten sets.

**Approach:** Render every set in progress as a two-faced tile, loaded after the page, as settled in DESIGN.md (Set progress tile, Collection entry, Public profile SETS), EXPERIENCE.md (Set progress tile, Collection opening) and the mockup. The public profile's SETS take the same tile, six sets, without the card last gained. The hub's SETS EN COURS and the search results keep the rows.

## Boundaries & Constraints

**Always:** Both faces are server-rendered in the HTML and have one fixed size; turning never moves the grid. Recto: header with the set's name, kind and rank chip (highest tier reached, in its colour; "AUCUN PALIER" dashed and dim when none); body with the cards (a set of ≤5 cards shows every card, missing ones as dashed silhouettes in their rarity's faded colour; a larger set shows its three best owned cards, best edition, and "+N" for its other owned cards); foot with the gauge and its tier ticks and "Plus que X pour Y" (Y the next tier chip, or COMPLET). Verso: header with owned/total; the tier path (reached ✓ in colour, next outlined with its missing count, later dim with theirs, a set without tiers has the COMPLET node only); the card last gained in the set with its title and how long ago (absent on another player's profile); "VOIR L'ALBUM ▸" full width. Hover or keyboard focus turns the tile; reduced motion (`html[data-motion="reduced"]` and the media query, as card.css does) fades; `@media (hover: none)` never turns. The whole tile is the one link to the album; its accessible name stays `set_progress_sentence`; the faces' visual parts are `aria-hidden`; the CTA is a styled span inside the link, not a nested control. The set closest to its next tier (fewest cards missing, ties by list order) wears the gold frame, one per list. The last-opened album keeps its `aria-current` marking (`last-album` controller). Two columns from 720px, one below. EN COURS shows every set in progress, loaded by a lazy Turbo frame after the page; the search works before and while it loads. Tile data for all tiles comes from a fixed number of queries, never one per tile. Strings in en.yml and fr.yml (French plurals with `zero`). No `style` attribute, no ids in markup, GETs never write.

**Never:** Change the hub's SETS EN COURS or the search results rows. Build markup in script. Add React. Change the set album page.

</frozen-after-approval>

## Code Map

- `app/controllers/library_controller.rb:21` `show` → `SetBoardLoading#load_set_board` (`app/controllers/concerns/set_board_loading.rb:7`) builds `@in_progress` (`SetRow(set, standing)`) and the search results.
- `packs/game/app/queries/game/set_board.rb:7` `call(player, season:, in_progress: 10)` caps EN COURS at 10; `ranked_in_progress` :23 orders it (just gained first, then missing, share). `HUB_ROWS` path stays as is.
- `packs/game/app/models/game/set_standing.rb`: `held total tiers gained_at`, `thresholds` :14, `reached_tier` :20, `next_tier` :24, `next_required` :28, `missing` :32, `complete?`. `Catalog::TierTable.tiered?` (≥5 cards); smaller sets have `complete` only.
- `app/helpers/set_rows_helper.rb`: `set_kind_name`, `set_tier_name`, `set_progress_sentence`, `set_tier_mark`, `set_tier_ticks?`, `set_tier_ticks`, `rank_mark`, `tier_words`. Reuse for the gauge, ticks and tier names.
- Album data to mirror for the tile cards: `app/controllers/concerns/set_album_loading.rb:16` (`Catalog::SetAlbum.call` members, `Game::HeldGames.editions` best edition first with `gained_at`, `Catalog::CardViews.call`). Build a batched equivalent for many sets (new query in the right pack per packwerk: Game → Catalog allowed), returning per set the best owned card views (≤3, or every member with owned flag and rarity for ≤5) and the last gained card (`game_holdings.last_gained_at`).
- `app/components/card_component.rb`: sizes `s m l xl :grid`; `owned: false`. Missing silhouettes are plain styled boxes, not card faces.
- Views: `app/views/library/_entry.html.erb` (EN COURS list → lazy `turbo_frame_tag` with `src:` to a new GET action rendering the tile grid; pattern: `app/views/friends/_profile_dialog.html.erb:10`); `app/views/library/_set_progress_row.html.erb` stays for results and hub; new `library/_set_progress_tile.html.erb`.
- Public profile: `app/controllers/public_profiles_controller.rb:20` `MOST_COMPLETE_SETS_SHOWN = 20` → 6; `app/views/public_profiles/_sets.html.erb` renders tiles with `brother_set_path` and no last gained card.
- Routes `config/routes.rb:31-34`; every action needs a Pundit policy (`authorize :page, :play?` as `show`).
- Styles: `app/frontend/styles/collection.css:79` `.set-entry__list`, :195 `.set-row[aria-current]`; `hub.css:497-707` `.set-row*`, `.set-tier`; `profile.css:410` `.profile-sets`. Tokens only, no new colours.
- Tests relying on `.set-entry__list a.set-row` / `.profile-sets .set-row`: `test/controllers/library_controller_test.rb` (~:109, :731, :993-1072), `test/system/library_test.rb:42-53,110`, `test/system/collection_set_test.rb:62,89`, `test/system/shell_test.rb:439`, `test/controllers/library_set_test.rb:268`, `test/controllers/public_profiles_controller_test.rb` (:27, :63, :110, :156, :182, :669, :746), `test/system/public_profile_test.rb:47`. Hub tests (`pages_controller_test.rb:203,386`, `hub_test.rb`) must stay green unchanged.

## Tasks & Acceptance

**Execution:**
- [ ] `packs/game/app/queries/game/set_board.rb` -- EN COURS uncapped (keep the hub's cap) -- the author wants every set.
- [ ] new batched query (Game pack) + its unit test -- per set: best owned cards, small-set members with ownership and rarity, last gained card -- fixed query count.
- [ ] `app/controllers/library_controller.rb`, `config/routes.rb`, policy -- a GET action rendering the EN COURS frame; `show` no longer loads EN COURS rows.
- [ ] `app/views/library/_entry.html.erb`, new `_set_progress_tile.html.erb` (+ helper methods in `set_rows_helper.rb` for the rank chip, "Plus que" line, path nodes) -- the tile per Boundaries.
- [ ] `public_profiles_controller.rb`, `_sets.html.erb` -- six tiles, no last gained card.
- [ ] CSS (`collection.css`, `profile.css`, a `set-tile` block) -- grid, faces, turn, fade, `hover: none`, gold frame, phone one column.
- [ ] `config/locales/en.yml`, `fr.yml` -- "Plus que %{count} pour %{tier}" (fr: zero/one/other), "AUCUN PALIER", "+%{count}", "Dernière obtenue", "VOIR L'ALBUM", path node words.
- [ ] Tests listed in the Code Map -- move EN COURS assertions to the frame action and the tile selectors; add: small set shows missing silhouettes, large set shows three cards and "+N", rank chip and "AUCUN PALIER", gold frame on the closest set, uncapped list, public profile six tiles without last gained, verso CTA present, system test: focus turns a tile without changing its box (retrying matchers).
- [ ] `ux-gameble/EXPERIENCE.md` -- "the first one framed in gold" → the set closest to its next tier (the list leads with just-progressed sets).

**Acceptance Criteria:**
- Given a player with 12 sets in progress, when the collection opens, then the search is usable at once and all 12 tiles arrive after the page, each a link to its album with the progress sentence as its name.
- Given a 3-card set with 2 owned, then its recto shows 2 faces and 1 silhouette in the missing card's faded rarity colour, "AUCUN PALIER", "Plus que 1 pour COMPLET", and its verso the COMPLET node only.
- Given the pointer over a tile or keyboard focus on it, then the verso shows with the same box size; with reduced motion it fades; on a touch device it never turns.
- Given another player's public profile, then six tiles show, the verso without the card last gained.

## Implementation Notes

- Keyboard focus (`:focus-visible`) turns a tile at every hover capability; only `:hover` sits under `@media (hover: hover)`. A tap never matches `:focus-visible`, so touch still never turns, and headless Chrome (which reports `hover: none`) can test the focus turn.
- The face turned away also gets `visibility: hidden` halfway through the turn: a legendary card's 3D layers on the verso showed through the recto otherwise. Under reduced motion both faces stay visible and only opacity changes.
- `GET /:locale/library/in-progress` answers only a Turbo Frame request; opened as a page it redirects to the entry. The entry's search no longer reads the standings unless a query finds sets.
- Query budgets: the frame costs 7 queries whatever the number of sets (`Game::SetShowcases` is 2); the entry without a search 5, with one 9; the public profile 13 for a visitor (was 11), 20 signed in, 19 for the owner.

- Accepted by the author, 2026-10-27: keyboard focus turns a tile at every hover capability, touch devices included.

## Plan Change Log

## Review Triage Log

### 2026-10-26 — Review pass (quick)
- verdicts: 7 findings — high 0, medium 3, low 3, false 0, maybe-false 1
- findings:
  - `[low]` `patch` `.set-tile:focus-visible { box-shadow: none; }` dropped the global focus ring's gap fill — rule deleted.
  - `[maybe-false]` `patch` A two-line set name with the 44px phone button might clip the verso's CTA — measured at 1400, 900, 760, 390 and 360px in both locales: the CTA sits 5px or more inside the face; nothing changed.
  - `[medium]` `patch` Tier names on a 6-node path were ellipsised at 720–900px and on the phone — no truncation now; names spill into free space, 9px under a 290px path; checked for overlap at five widths in both locales.
  - `[medium]` `patch` `SetShowcases` built card views for every held member of every set — it picks the shown members and the last gained first; the unit test asserts 3 ids for a 12-card set.
  - `[low]` `patch` `SetBoard::Board.standings` was no longer read — removed with its test assertions.
  - `[medium]` `patch` The last-opened album's `aria-current` on a tile was untested — the collection set system test finds the marked tile after going back.
  - `[low]` `patch` New explanatory comments broke the comment rule — removed, the one-line note on 3D layers kept.

## Verification

**Commands:**
- `bin/rails test test/controllers/library_controller_test.rb test/controllers/public_profiles_controller_test.rb test/controllers/pages_controller_test.rb test/controllers/library_set_test.rb` -- green
- `bin/rails test test/system/library_test.rb test/system/collection_set_test.rb test/system/public_profile_test.rb test/system/hub_test.rb test/system/shell_test.rb` -- green
- `bin/rails test` (full, non-system), `npm run test:js`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bundle exec rubocop`, `bundle exec i18n-tasks missing` -- green; `git checkout db/schema.rb` if a test run rewrites it
