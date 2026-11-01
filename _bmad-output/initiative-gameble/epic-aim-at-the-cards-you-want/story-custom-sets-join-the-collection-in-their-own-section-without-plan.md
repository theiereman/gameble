---
title: 'Custom sets join the collection in their own section, without tiers or reward'
type: 'feature'
ticket: 5
created: '2026-11-01'
status: 'built'
baseline_revision: '438ef8b0c978b4abbe848030ccb12bc6f32e4314'
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
deferred:
  - summary: >-
      The build's base is develop 438ef8b0, three commits behind develop 570c8773; landing it there breaks one system test and conflicts in one controller test.
    evidence: |-
      570c8773 adds to test/system/steam_library_test.rb an assertion on `.steam-library__kind` ("STEAM · 2 CATALOG GAMES") inside section.steam-library, markup this change replaces with the set tile (assert `.set-tile__face--recto .set-tile__kind` instead, as this change does elsewhere in that file). test/controllers/library_controller_test.rb's query-count block (about lines 1416-1424) was changed on develop to 16 / 7 / 10 with an invitations comment; this change moves the old 15 / 7 / 9 to 14 / 8 / 8, so after the merge the counts must be measured again (by arithmetic 15 / 8 / 9, unrun) keeping develop's comment.
    location: >-
      test/system/steam_library_test.rb, test/controllers/library_controller_test.rb
    severity: medium
---

<intent-contract>

## Intent

**Problem:** MES SETS and MA LUDOTHÈQUE STEAM are plain link rows from the tracer and library entries, "+ NOUVEAU SET" is a button, and the set search finds only the published season's game sets, so a player cannot follow a custom set like a game set nor find it by name.

**Approach:** Render the player's custom sets in MES SETS, and the Steam library set in its section, as set progress tiles without tiers (owned / total in the header, "SET PERSO · n JEUX" kind line, a gauge without ticks, "Plus que X pour COMPLET", a single COMPLET node on the verso), close the MES SETS grid with the design's new set tile, and make the set search rank the player's custom sets and synced library set among the game sets it finds, as tiles too.

## Boundaries & Constraints

**Always:**
- MES SETS: kicker "MES SETS" with "Visibles par vous seul · n / 10" beside it, muted; the custom sets (kind `custom` only, in creation order) as set progress tiles in a `.set-tiles` grid like EN COURS; the **new set tile** closes the grid and opens the Custom set editor (`dialog-opener` on `custom-set-editor`, `aria-haspopup="dialog"`), with a "+" square, "NOUVEAU SET" and "3 à 50 jeux · 10 sets au plus". At 10 sets the tile and the editor are absent and the line reads "Visibles par vous seul · 10 / 10 · retirez un set pour en créer un autre".
- Phone (< 720px): MES SETS shows the first two sets and the new set tile (a 120px row: a 44px "+" square beside its text), then, with more than two sets, a "et 1 autre set · Tout voir" / "et n autres sets · Tout voir" button that unfolds the rest in place (the sets keep their DOM order before the new tile; the button then disappears and focus goes to the third set's tile). Desktop never shows the button.
- Custom set tile (MES SETS and search): the tile's two faces as for game sets; header name = the set's name, kind line "SET PERSO · 14 JEUX" ("CUSTOM SET · 14 GAMES"); the recto's header right shows "owned/total" in the count-large style in place of the rank chip; recto cards follow the game set rule (≤ 5 games: every game, owned at its best edition, missing as a "?" silhouette in its latest published face's rarity; more: the three best owned and "+N"); foot gauge with no ticks and `set_goal_line` ("Plus que X pour COMPLET", or "Toutes les cartes obtenues" when complete); verso: owned/total, the COMPLET node only, the card last gained among its games, "VOIR L'ALBUM ▸"; href `custom_set_path(token:)`; accessible name "Jeux que je déteste, set perso, 2 cartes sur 5" (", complet" when complete). Never a gold frame, never a rank or tier mark.
- Steam library tile: the same tile, name "Ma ludothèque Steam", kind line `steam_library_kind_line`, accessible name `steam_library_tile_name`; its section keeps the sync line above the tile and stays absent until `ever_synced?`.
- Set search (`library#show`, `q`): the results hold the published season's matching game sets (unchanged rule) and the player's custom sets and synced library set whose display name contains the normalized query (the library by its localized name; never by kind), ranked together by `SetSearch`'s order (prefix match first, then normalized name), six per page with CHARGER PLUS, counted in "n sets trouvés". A typed query hides OBJECTIFS, MES SETS, MA LUDOTHÈQUE STEAM, EN COURS and COMPLÉTÉS (existing `:has(.set-results)` rules, kept).
- Game sets only, unchanged: EN COURS, COMPLÉTÉS, the hub's sets, the card detail's sets, the grid's set filter, the public profile's sets and its collection; a custom set or library set never appears for another player.
- A custom set earns nothing: completing it writes no tier, feed, title, back or allocation row and announces nothing (no celebration, no toast) unless it is a goal (the existing goal toast).
- Reads only: no table, migration or operation; tokens only in HTML and URLs; no `style` attribute; no markup built in script; every new string in en.yml and fr.yml (U+202F rules); `_set_progress_tile` keeps working for the public profile.

**Never:** goal edges or bookmarks on tiles (bookmark entry); the library set's settings switch; changing the editor; tiers or a rank chip on a custom or library tile; custom sets in EN COURS, COMPLÉTÉS, the hub, the card detail, the grid filter or any public page; a hand-edited `app/frontend/images/pixel/` file.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Big custom set | 20 games, 7 held | MES SETS tile "7/20", "SET PERSO · 20 JEUX", 3 best cards + "+4", "Plus que 13 pour COMPLET"; not in EN COURS/COMPLÉTÉS | No error expected |
| Small custom set | 3 games, 1 held | 1 card face up, 2 rarity "?" silhouettes | No error expected |
| Complete custom set | every game held | "Toutes les cartes obtenues", in MES SETS only | No error expected |
| No custom set | 0 sets | "· 0 / 10", grid holds only the new set tile | No error expected |
| Ten sets | 10 custom sets | no new set tile, no editor, "10 / 10 · retirez…" line | No error expected |
| Search a custom name | q "favo", set "Mes favoris" | its tile in RÉSULTATS, counted | No error expected |
| Search library | q "ludo" (fr) / "steam" (en), synced | library tile found; unsynced library not found | No error expected |
| Search by kind word | q "thème" | game theme sets only, no custom set | No error expected |
| Another player | profile owner's sets | a visitor's search and pages never show them | No error expected |
| Completion | last game of a custom set credited by a pack | no tier/feed/title/back/allocation row for it; no toast unless a goal | No error expected |

</intent-contract>

## Code Map

- `app/controllers/library_controller.rb#show` -- loads `@custom_sets` (kind custom) and `@steam_library` (`ever_synced?`) after `load_set_search`; load the player's standings once (both kinds) and pass the custom and synced library ones to the search so the entry and the more-results frame (`MORE_RESULTS_FRAME`) share them.
- `app/controllers/concerns/set_board_loading.rb` -- `load_set_search`, `SetTile`, `TilePage`, `TILES_PER_PAGE`, `set_tiles`, `next_offset`; add an own-set tile (standing + showcase, no `closest`) and merge it into the results page and count.
- `app/models/set_search.rb` -- `call`, `ranked` (private), `normalize`, `clean`; extend so own sets (display names) rank in the same order as game sets; `in_kind` (grid set filter) must stay game sets only.
- `app/domains/game/app/queries/game/set_showcases.rb` -- the recto/verso picks (`SMALL_SET`, `BEST_SHOWN`, `pick`, `showcase`, `best`) over `catalog_set_memberships`; add a custom-set entry point keyed by token whose members are `game_custom_set_games` rows (order by `id`) with each game's latest published rated face for the missing silhouette rarity (`Catalog::LatestPublishedCardSeasons` holds that rule), reusing `editions` and the pick logic, not copying them.
- `app/domains/game/app/queries/game/custom_set_standings.rb` -- `Standing` (`token`, `name`, `kind`, `card_ids`, `held_card_ids`, `custom?`, `steam_library?`, `ever_synced?`, `to_set_standing` = `SetStanding.measured(tiers: {})`), `call(player, tokens:, kind:)`.
- `app/helpers/set_rows_helper.rb` -- `set_goal_line`, `set_tier_path` (tiers `{}` → one COMPLET node), `set_tier_ticks?` (false without tiers), `set_album_value_text`, `set_progress_sentence(set, standing)` (catalog sets only); `app/helpers/custom_sets_helper.rb` -- `custom_set_display_name`, `steam_library_kind_line`, `steam_library_tile_name`, `steam_library_sync_lines`; add the custom kind line and tile sentence here. `library.entry.goals.custom_kind` ("Set perso" / "Custom set") exists.
- `app/views/library/_set_progress_tile.html.erb` (66 lines; also rendered by `public_profiles/_sets.html.erb` with `last_gained: false`), `_set_tile_page.html.erb` (results and EN COURS pages; renders each tile with `library_set_path`), `_set_results.html.erb`, `more_results.html.erb`, `_custom_sets.html.erb`, `_steam_library.html.erb`, `_entry.html.erb` -- share the tile markup between game and own sets (locals or a small presenter for name, kind line, head right, href, sentence) rather than a second 66-line copy.
- `app/components/button_component.rb#opener_options` -- the `dialog-opener` wiring the new set tile must carry; `app/views/custom_sets/_editor.html.erb` renders once in MES SETS below 10 sets (keep).
- `app/frontend/styles/collection-custom-sets.css` (old `.custom-sets__list/__link/__name/__count`, `.steam-library__link/__heading/__kind/__bar` rules become dead: remove), `collection-set-tiles.css` (295 lines, `.set-tiles` grid, `.set-tile__head`, `.set-tile__count`, `.set-tile__total`, the 720px phone rules), `tokens.css` (`--font-count-large`, `-phone`, colours `--color-panel-sunken`, `--color-panel`, `--color-line`, `--color-line-deep`); keep each CSS file under 500 lines.
- `app/frontend/controllers/` -- registered by glob; a tiny unfold controller for "Tout voir" (no markup in script; toggle a class/attribute and focus the third tile); a TS lib + vitest only if it holds logic.
- `config/locales/{en,fr}.yml` `library.entry.custom_sets` (`count`, `new`, `title`) -- add the ten-sets line, the new tile's two lines, the kind line (count plural with `zero`), the phone "et n autres sets · Tout voir" (plural with `zero`), the tile sentence kind; drop `new` if unused.
- Tests: `test/controllers/library_controller_test.rb` (entry markup asserts MES SETS / steam library structure; query counts), `test/controllers/library_goals_test.rb`, `test/system/library_test.rb` (tab order through MES SETS), `test/system/custom_sets_test.rb` (opens the editor from "+ New set"), `test/system/steam_library_test.rb`, `test/system/goals_test.rb`, `test/domains/game/` for a showcase query test; helpers `test/support/custom_sets.rb` (`create_custom_set`, `create_library_set`, `fixture_card_ids`), `test/support/catalog_seeds.rb` (`published_cards(n)`), `test/domains/game/goals_reached_test.rb` (pack-crediting pattern with `create_pack`, `hold`).

## Tasks & Acceptance

**Execution:**
- [ ] `app/domains/game/app/queries/game/set_showcases.rb` -- custom-set showcases by token over their games, sharing the pick rules -- the tile's cards and last gained.
- [ ] `app/models/set_search.rb`, `app/controllers/concerns/set_board_loading.rb`, `app/controllers/library_controller.rb` -- own sets in the ranked results and count, standings loaded once -- search finds them.
- [ ] `app/helpers/custom_sets_helper.rb` (+ `set_rows_helper.rb` if a shared piece moves) -- kind line and tile sentence for own sets.
- [ ] `app/views/library/{_set_progress_tile,_set_tile_page,_custom_sets,_steam_library}.html.erb` (+ a new set tile partial if it reads better) -- shared tile, MES SETS grid with the new set tile and the phone unfold button, library tile.
- [ ] `app/frontend/controllers/<unfold>_controller.ts` -- reveal the remaining sets and move focus.
- [ ] `app/frontend/styles/collection-custom-sets.css`, `collection-set-tiles.css` -- new set tile (hatch, inner edge, "+" square, phone row), header count in place of the rank, phone hiding of sets beyond two until unfolded; remove dead row rules.
- [ ] `config/locales/en.yml`, `fr.yml` -- the new strings in both locales.
- [ ] Tests: showcase query (small/large custom set, missing rarity, last gained, library set); controller (`library#show` MES SETS tiles with owned/total and no rank chip or tick for a 20-game set; new set tile below 10 and its absence plus the ten-sets line at 10; library tile; search results with a custom set, the synced library, not an unsynced one, not by kind word; count line; another player's sets never on a profile; the hub/card detail/grid filter carry no custom set name; GET writes nothing); a domain test that a pack completing a custom set writes no tier/feed/title/back/allocation row for it; system tests: MES SETS tiles and new set tile opening the editor, a typed query replacing every section and finding a custom set, the phone "Tout voir" unfold (restore window size), the library tile.

**Acceptance Criteria:**
- Given a player with a custom set of 20 games, 7 held, when they open the collection, then MES SETS shows its tile with "7/20" and no tier, EN COURS and COMPLÉTÉS do not list it, and the new set tile closes the grid and opens the editor.
- Given that player types the set's name in the set search, then RÉSULTATS shows its tile among any matching game sets, the status line counts it, and OBJECTIFS, MES SETS, MA LUDOTHÈQUE STEAM, EN COURS and COMPLÉTÉS are hidden until the query is cleared.
- Given a phone-width collection with four custom sets, then two sets, the new set tile and "et 2 autres sets · Tout voir" show; pressing it shows all four and focuses the third.
- Given a pack completes a custom set that is not a goal, then nothing is recorded or announced for it.

## Implementation Notes

**Decisions**
- Tiles: `SetBoardLoading::OwnSetTile` (`own_set`, `showcase`; `standing` = `own_set.to_set_standing`, `closest` false) beside `SetTile`; both answer `own?`. `_set_progress_tile` stays one partial: `set_tile_label(tile)` (name, kind line, sentence) and `set_tile_path(tile)` in `SetRowsHelper` pick the game-set or own-set wording and href; the recto head shows the `.set-tile__count` instead of the rank chip when `own?`. The public profile's call is unchanged.
- Showcases: `Game::SetShowcases.custom_sets(player, tokens:, season:, locale:)` swaps only the `members` CTE (custom set games by `id`, scoped to the player's tokens, joined to `Catalog::LatestPublishedCardSeasons.rarities` for the missing silhouette); the `editions` CTE, final select and the pick/showcase/best logic are shared with game sets. Two queries for any number of own sets.
- Search: `SetSearch.call(..., own_sets: { standing => display name })`; game sets and own sets are ranked together by prefix then normalized name (ties: game sets by id first, then own sets in creation order). Own sets match by display name only, never by a kind word. `in_kind` (grid filter) stays game sets only. The controller computes display names with `helpers.custom_set_display_name` so the library set is found by its localized name.
- `library#show` reads `Game::CustomSetStandings` once (both kinds), keeps custom sets and the ever-synced library set, passes them to the search (entry and the more-results frame) and builds the MES SETS and library tiles with one showcase call. The entry's query count went 15 → 14 with a search and 9 → 8 without; the more-results frame went 7 → 8 (it now reads the own sets).
- New set tile: a hand-written `<button>` carrying the same `dialog-opener` wiring as `ButtonComponent#opener_options` (the component's `.button` classes do not fit the tile). Its "+" is a new `plus` pixel icon added to `script/pixel_art/export.mjs` and exported (no hand edit).
- Phone unfold: `set_fold_controller.ts` adds `is-unfolded` to the list, hides its button and focuses the first tile that was hidden (the third set). CSS hides `li:nth-child(n + 3)` except the new set tile under 720px; the button is `button--link` and `display: none` on desktop. `CustomSetsHelper::SHOWN_ON_PHONE = 2` drives the "et n autres sets" count. No TS lib/vitest: the controller holds no logic beyond the DOM toggle.
- The tile sentence reuses `library.entry.goals.custom_kind` ("Set perso", downcased) rather than a new key for the same word. `library.entry.custom_sets.new` became "New set" / "Nouveau set" (uppercased by CSS); new keys `count_full`, `kind` (zero/one/other), `new_rule`, `unfold` (zero/one/other). The ten-sets line is two explicit `t` calls so i18n-tasks sees both keys.
- "Visibles par vous seul" carries the lock icon of the mockup (aria-hidden).

**Files touched**
- `app/domains/game/app/queries/game/set_showcases.rb`, `app/domains/catalog/app/queries/catalog/latest_published_card_seasons.rb` (`rarities`)
- `app/models/set_search.rb`, `app/controllers/concerns/set_board_loading.rb`, `app/controllers/library_controller.rb`
- `app/helpers/custom_sets_helper.rb`, `app/helpers/set_rows_helper.rb`
- `app/views/library/{_set_progress_tile,_set_tile_page,_custom_sets,_steam_library,_entry,show}.html.erb`
- `app/frontend/controllers/set_fold_controller.ts`, `app/frontend/styles/collection-custom-sets.css` (dead `.custom-sets__list/__link/__name/__count` and `.steam-library__link/__heading/__kind/__bar` removed), `app/frontend/images/pixel/plus.svg` (generated), `script/pixel_art/export.mjs`
- `config/locales/en.yml`, `config/locales/fr.yml`
- Tests: new `test/controllers/library_own_sets_test.rb`, `test/domains/game/custom_set_earns_nothing_test.rb`; extended `test/domains/game/set_showcases_test.rb`, `test/system/custom_sets_test.rb` (search finds a custom set, phone unfold); updated `test/controllers/library_controller_test.rb` (library tile, query counts), `test/controllers/custom_sets_controller_test.rb`, `test/system/{custom_sets,steam_library,library}_test.rb` for the new markup.

**Surprises**
- `collection-set-tiles.css` holds no phone rule; the one-column `.set-tiles` rule lives in `collection-grid.css`, so it was left untouched and the new rules went to `collection-custom-sets.css` only.
- A completed custom set already earned nothing (tiers, feed, backs, achievements and allocation are keyed by catalog sets); the new domain test pins it by comparing with the same opening for a player without the set.

**Verification**: targeted controller/domain/helper tests, the five system files (34 runs), `PARALLEL_WORKERS=3 bin/rails test` (3972 runs, 0 failures), `npm run test:js`, `format:check`, `lint:css`, `zeitwerk:check`, `packwerk check`, `check_planning_references`, `check_file_sizes`, `i18n-tasks missing/unused`, `rubocop`, `export.mjs --check`: all clean.

## Plan Change Log

## Review Triage Log

### 2026-11-01 — Review pass
- verdicts: 2 findings — high 0, medium 1, low 1, false 0, maybe-false 0
- findings:
  - `[medium]` `[defer]` Quick: the change is built on develop 438ef8b0 while develop is at 570c8773; after landing, `test/system/steam_library_test.rb` (570c8773's `.steam-library__kind` assertion) fails and `test/controllers/library_controller_test.rb`'s query-count block conflicts — verified with `git log 438ef8b0..develop` and the file diffs; not caused by this change alone but by a parallel build, and the fix is an integration step (rebase, re-measure counts) for whoever brings the branch onto develop; recorded in `deferred` with the exact edits.
  - `[low]` `[patch]` Quick: two new intent comments in `app/frontend/styles/collection-custom-sets.css` break the AGENTS.md rule to comment only external constraints — both deleted; `format:check`, `lint:css`, `check_file_sizes` and the touched system and controller tests (117 runs) pass after it.

## Design Notes

Own-set tiles reuse the game set tile so the turn, the iris and the layout stay one component; only the header right (owned/total instead of the rank chip), the kind line, the href and the accessible name differ. A custom set's `SetStanding` has no tiers, so the existing helpers already give a tick-less gauge, a COMPLET-only path and "Plus que X pour COMPLET".

The search ranks own sets with the game sets' rule (prefix first, then name) rather than pinning them first: the design names one result list, and the same order keeps a typed name predictable whichever kind of set it names.

## Verification

**Commands:**
- `bin/rails test test/controllers/library_controller_test.rb test/controllers/library_goals_test.rb test/controllers/custom_sets_controller_test.rb test/controllers/public_profiles_controller_test.rb test/domains/game test/helpers` -- expected: pass
- `bin/rails test test/system/library_test.rb test/system/custom_sets_test.rb test/system/steam_library_test.rb test/system/goals_test.rb test/system/collection_set_test.rb` -- expected: pass
- `PARALLEL_WORKERS=3 bin/rails test` -- expected: pass
- `npm run test:js`, `npm run format:check`, `npm run lint:css`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `script/check_planning_references`, `script/check_file_sizes`, `bundle exec i18n-tasks missing`, `bundle exec i18n-tasks unused`, `bin/rubocop` -- expected: clean

## Auto Run Result

Status: built.

**Change.** MES SETS and MA LUDOTHÈQUE STEAM now show set progress tiles without tiers. Each tile has owned/total in the header where a game set shows its rank, the kind line "SET PERSO · n JEUX" or "STEAM · n JEUX DU CATALOGUE", the recto cards of the game set rule (every game for 5 or fewer, missing ones as rarity silhouettes; otherwise the three best owned and "+N"), a gauge without ticks with "Plus que X pour COMPLET" or "Toutes les cartes obtenues", and a verso with the COMPLET node only and the card last gained. The hatched new set tile closes the MES SETS grid and opens the editor; at 10 sets it and the editor are gone and the line reads "… · 10 / 10 · retirez un set pour en créer un autre". On the phone MES SETS shows two sets and the new set tile, then "et n autres sets · Tout voir", which unfolds the rest in place and focuses the third. The set search ranks the player's custom sets and synced Steam library set (by name, never by kind) among the game sets it finds, as tiles counted and paged with them. EN COURS, COMPLÉTÉS, the hub, the card detail, the grid filter and public pages still list game sets only, and completing a custom set records and announces nothing (pinned by a test).

**Files.**
- `app/domains/game/app/queries/game/set_showcases.rb`, `app/domains/catalog/app/queries/catalog/latest_published_card_seasons.rb`: custom-set showcases by token, sharing the editions and pick rules.
- `app/models/set_search.rb`, `app/controllers/concerns/set_board_loading.rb`, `app/controllers/library_controller.rb`: own sets ranked into the search; own sets read once; `OwnSetTile`.
- `app/helpers/set_rows_helper.rb`, `app/helpers/custom_sets_helper.rb`: tile label, path, kind line and sentence for both tile kinds.
- `app/views/library/{_set_progress_tile,_set_tile_page,_custom_sets,_steam_library,_entry,show}.html.erb`: one shared tile partial, the MES SETS grid with the new set tile and unfold button, the library tile.
- `app/frontend/controllers/set_fold_controller.ts`, `app/frontend/styles/collection-custom-sets.css`: phone unfold; new set tile look; dead row rules removed.
- `script/pixel_art/export.mjs`, `app/frontend/images/pixel/plus.svg` (generated by the script): the "+" icon.
- `config/locales/en.yml`, `fr.yml`: `count_full`, `kind`, `new_rule`, `unfold`, `new` reworded.
- Tests: new `test/controllers/library_own_sets_test.rb` and `test/domains/game/custom_set_earns_nothing_test.rb`. Extended `test/domains/game/set_showcases_test.rb` and `test/system/custom_sets_test.rb`. Updated library, custom-set and Steam library controller and system tests.

**Review (quick).** 2 findings: 1 patched (low: two intent comments deleted), 1 deferred (medium: the stale base, see `deferred`), none rejected.

Follow-up review recommended: false. This pass patched 1 entry, low (high 0, medium 0).

**Verification** (pass):
- `PARALLEL_WORKERS=3 bin/rails test`: 3972 runs, 0 failures.
- Targeted controller, domain and helper tests: 1107 runs, 0 failures.
- The system tests `library`, `custom_sets`, `steam_library`, `goals` and `collection_set`: 34 runs, 0 failures. Re-run after the patch with the library controller tests: 117 runs, 0 failures.
- Clean: `npm run test:js` (795), `format:check`, `lint:css`, `zeitwerk:check`, `packwerk check`, `check_planning_references`, `check_file_sizes`, `i18n-tasks missing` / `unused`, `rubocop`, `export.mjs --check`.

**Copy the UX did not specify.** English "Custom set · n games", "n to n games · 10 sets at most", "New set", "Visible to you only · 10 / 10 · remove a set to create another", "and n more sets · See all". The `zero` forms "Set perso · 0 jeu" / "Custom set · 0 games" and "et aucun autre set · Tout voir" / "and no more set · See all" are never shown. At ten sets, "Visibles par vous seul" is kept in front of "10 / 10 · retirez un set pour en créer un autre". A lock icon from the mockup sits before "Visibles par vous seul".

**Residual risks.**
- The base is three commits behind develop. Landing it needs the `steam_library_test` selector change and re-measured query counts (deferred).
- Search order (chosen at build): own sets rank with game sets, prefix match first then name, not pinned first.
- After "Tout voir", script moves focus to the third tile. Whether its focus ring shows depends on the browser's focus-visible heuristic.
- The new set tile's fixed 280px height is meant to match a set tile's height. It is not checked against the tile at every width.
- A large Steam library goes through the showcase query's editions CTE over all its games on each collection visit. This is unmeasured on staging.

