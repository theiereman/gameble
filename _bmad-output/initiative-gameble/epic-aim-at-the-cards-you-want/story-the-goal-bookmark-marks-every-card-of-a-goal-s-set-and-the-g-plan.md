---
title: 'The goal bookmark marks every card of a goal''s set, and the grid filters on goals'
type: 'feature'
ticket: 10
created: '2026-11-01'
status: 'built'
baseline_revision: '877f7fc9705a15955f60e69a18009cc7af1157f4'
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

**Problem:** A player's goals show only in OBJECTIFS and on the album button; nothing marks the cards of a goal's set where the player meets them, and the card grid cannot narrow to a goal.

**Approach:** Read the player's goals once per request (`Game::GoalNeeds`), turn them into per-card goal marks in the web layer, and draw the numbered Goal bookmark on every card of a goal's set, owned or not, in the player's own grid, albums, capsule reveal and card detail (with its OBJECTIFS row), on the goal set's tiles, and as an OBJECTIFS chip group in the grid's filter zone. Nothing is stored.

## Boundaries & Constraints

**Always:**
- Placement (DESIGN.md "Goal bookmark", the author insists): the bookmarks hang from the top edge of the card's **image** (`.card__art`), in its top-left corner, 4px in from the image's left edge; never on the card's frame or band. Several goals: side by side in number order, 4px apart (3px on `card-s`, 5px on `card-l`/`card-xl`). Size 18×22 with an 11px number on `grid`, `s`, `m`; 22×27 with 13px on `l`, `xl` (existing `goal-bookmark` / `goal-bookmark--large` classes). On a card not owned they stay at full colour: the marks are a direct child of `.card`, outside `.card__body` (which carries the grey and 45% opacity), positioned like `.card__lock` from the footer and art heights.
- `CardComponent.new(..., goals: [])` takes goal numbers (1–5, ascending) and renders the marks aria-hidden; every caller passes nothing unless listed below.
- Goal marks are the signed-in player's own goals, read live from `Game::GoalNeeds.call` (card ids per goal; owned and missing alike); removing a goal removes its marks on the next render. Shown only on the player's own pages: `library#cards`, `library#set`, `custom_sets#show`, the booster screen (live and restored opening), the opened pack page (`packs#show`), `cards#show` for a signed-in viewer. Never on a public profile's collection, album or tiles (`grid_another?`, `context[:brother]`), the hub, feeds, showcases, public card pages, the editor, trade boards or for a signed-out visitor.
- A goal's own album leaves that goal's bookmark off its cards (other goals' stay): `library#set` and `custom_sets#show` already hold `@goal` (the target aimed at by the album).
- Accessible names: bookmarks are aria-hidden; the card's name ends with its goals, "objectif 1 : Roguelike, objectif 4 : Supergiant Games" ("goal 1: Roguelike, goal 4: Supergiant Games"), set names from `goal_set_name`. Grid/album/pack page: appended to `card_detail_open_label`'s link label. Booster: the revealed hit button and tray slot name carry it through new strings (`face_up_goals`, `face_up_store_goals`, tray equivalent) with `%{goals}` before the trailing sentence; the capsule live-region announcement (`announceCardLine`) and `label` stay unchanged.
- Capsule reveal: the face HTML (`pack_faces`, `boosters/_opened.html.erb`) carries the marks; they appear with the face at the flip, never before (`.booster-card:not([data-revealed])` hides them), on every revealed card of a goal, new or not; no text line, no effect. The card JSON gains `goals` (the goal words string, "" when none), validated in `opening.ts` and read back from restored templates.
- Card detail (signed-in viewer only): an "OBJECTIFS" fact row right after SETS when any goal holds the card: one line per goal in number order, right-aligned, the small bookmark then the set's name in the goal's colour, bold, underlined (3px offset), linking to `goal_album_path`; the row has a 2px `--color-line-deep` inner edge; the `card-l` card carries the large bookmarks. Custom set goals count.
- Grid filter: an "OBJECTIFS" group between state and rarity in `library/_filters`, only on the player's own grid with at least one goal (never in an album's zone, on a profile, for a visitor): one checkbox chip per goal in number order, the small bookmark (aria-hidden) before the set's name, accessible name "Objectif 1 : Roguelike". Param `goals[]`, value `kind:key` for a game set or the custom set token (never a position or database id). OR within the group, AND with others: the grid keeps the cards whose `card_id` belongs to a chosen goal's set, owned and missing. Unknown values are ignored. Counted in the filter count (server and client), cleared by TOUT EFFACER, carried in paging and in the card detail's `grid` context (`LIST_FILTERS`), so ◀ ▶ browse the filtered grid.
- Goal set tile (EN COURS, COMPLÉTÉS, MES SETS, set search results, on `library#show`, `#in_progress`, more tiles/results): while its set is a goal, the tile gets the 6px goal edge in the goal's colour and the large bookmark before its name on both faces; its accessible name adds the goal after the kind: "Mes favoris, set perso, objectif 3, 9 cartes sur 14" / "Roguelike, thème, objectif 1, 12 cartes sur 62, …". The closest-tier gold frame combines with it. Never on the public profile's tiles.
- Catalog stays goal-free: `Catalog::CollectionGrid` takes an optional `card_ids:` restriction; `Catalog::CardView` gains `card_id` (default nil, never rendered) filled by `CardViews` and `CardDetail`.
- Reads only: no table, migration, operation or event. No `style` attribute; no markup built in script; every string in en.yml and fr.yml (U+202F before `: ; ? !` in French); new CSS in a new file (`collection-grid.css` is at 499 lines, `booster-canister.css` 492, `card-detail.css` 466, `collection-goals.css` 396); `booster_controller.ts` stays ≤ 400 lines.

**Never:** bookmarks on trade boards (the trade suggestions epic), on the set tiles' small recto cards, on feed/hub/showcase/public cards; goal edges on the hub's set rows; any change to draws, `Game::DrawPool`, `Game::Draw` or draw tests; a database id or goal position in HTML, URLs or JSON; storing marks.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Grid, one goal | goal 1 on studio/valve; grid shows Portal (owned) and an unowned Valve card | both carry bookmark 1 at the art's top-left; link names end ", objectif 1 : Valve" | No error expected |
| Two goals on one card | goals 2 and 4 both hold the card | bookmarks 2 then 4, side by side | No error expected |
| Own album | album of goal 1's set, card also in goal 3 | only bookmark 3 on its cards | No error expected |
| Other album | album of another set holding goal 1's cards | bookmark 1 shows | No error expected |
| Public profile | viewer with goals opens a friend's collection/album | no bookmarks, no OBJECTIFS group | No error expected |
| Visitor / no goals | signed out, or zero goals | no bookmarks, no OBJECTIFS group, no detail row | No error expected |
| Filter | `goals[]=studio:valve` | grid keeps that set's cards, owned and missing; count includes it | No error expected |
| Stale filter | `goals[]=theme:gone` or another player's token | ignored, grid unfiltered by goals | No error expected |
| Capsule | revealed card in goal 2 | face shows bookmark 2 after the flip, hidden while face down; restored capsule shows it | No error expected |
| Card detail | signed-in, card in goal 1 (game set) and goal 3 (custom set) | OBJECTIFS row with two linked lines; large bookmarks 1, 3 on the card | No error expected |
| Goal removed | goal removed | next render: no marks, no chip, no row | No error expected |

</intent-contract>

## Code Map

- `app/components/card_component.{rb,html.erb}` -- add `goals:`; render a `.card__goals` span (direct child of `.card`, after `.card__body`) holding `helpers.goal_bookmark(n, size: large? ? :large : nil)` per number. `test/components/card_component_test.rb`.
- `app/frontend/styles/card.css` (416 lines) -- `.card__lock` shows the bottom-offset formula to reuse for the art's top edge (`frame + padding + rarity-line + 2*gap + line + art-height`); left = `frame + padding + 4px`. Put the new rules in a new `app/frontend/styles/card-goals.css`, imported in `app/frontend/entrypoints/application.css`. `.card__art::before` (white top-left bracket) sits under the marks; `.collection-slot__new` (collection-grid.css ~235) is at the slot's top-left — check it does not cover the marks.
- `app/helpers/goals_helper.rb` -- `goal_bookmark(number, size:, hollow:)`, `goal_set_name`, `goal_album_path`, `goal_aim_params`. `app/frontend/styles/collection-goals.css` -- `.goal-tone--n` sets `--goal`; bookmark sizes; album header edge rule (~330-354) to mirror for tiles.
- `app/domains/game/app/queries/game/goal_needs.rb` -- `call(player)` (Needs with `card_ids`, `position`, target fields), `targets(player)` (no holdings, for tiles). Add a web-layer value object (e.g. `app/models/goal_marks.rb`) built from needs: `numbers_for(card_id, except: goal_id)`, `words_for(card_id, except:)`, the targets for chips; memoize per request in a controller concern (e.g. `app/controllers/concerns/goal_marks_loading.rb`, returning an empty object for nil player or `grid_another?`).
- `app/domains/catalog/app/queries/catalog/card_view.rb`, `card_views.rb`, `card_detail.rb` -- add `card_id` (Data with `card_id: nil` default via `initialize`), pluck `catalog_card_seasons.card_id`. `app/controllers/back_office/cards_controller.rb:20` and tests constructing `CardView` keep working by the default.
- Grid: `app/controllers/concerns/collection_grid_loading.rb` (`LIST_FILTERS`, `collection_grid`, `grid_context`, `grid_list_filters` — goals only when `grid_owner` is the signed-in player and not `grid_another?`), `app/domains/catalog/app/queries/catalog/collection_grid.rb` (`card_ids:`), `app/helpers/collection_helper.rb` `collection_filter_count`, `app/models/set_album_filters.rb` (album stays without goals), `app/views/library/{_collection,_filters,_slots,_grid}.html.erb`, `cards.turbo_stream.erb`, `app/frontend/controllers/collection_filters_controller.ts` (counts every `group` target fieldset automatically). `cards_controller.rb#grid_browse` re-runs `collection_grid` with `params[:grid]`.
- Album: `app/controllers/concerns/set_album_loading.rb` (`Slot`, `album_slots`), `app/views/library/_album.html.erb` (cards at ~29-44, `context`), `library_controller.rb#set`, `custom_sets_controller.rb#show` (`@goal` from `GoalControlLoading`), `public_profiles_controller.rb` and `public_profiles/set.html.erb` (no marks).
- Card detail: `app/views/cards/_detail.html.erb` (card ~30-40, SETS row ~97-108), `cards_controller.rb#show`, `app/helpers/card_details_helper.rb` (`card_detail_open_label`, `link_to_card_detail`), `app/frontend/styles/card-detail.css` (466 lines; new rules go to the new CSS file).
- Booster: `app/helpers/packs_helper.rb` (`pack_faces`, `pack_card_fields`, `pack_opening_json`), `app/controllers/packs_controller.rb` (`open_from_booster`, `show`), `app/controllers/concerns/pack_cards.rb` (`cards_of`), `app/controllers/boosters_controller.rb#show`, `app/views/boosters/_opened.html.erb`, `app/helpers/boosters_helper.rb` (`booster_opened_card_data`, `screen_strings("booster.strings")` passes every key), `app/views/packs/show.html.erb`; TS `app/frontend/lib/opening.ts` (`OpeningCard`, `isCard`), `booster_markup.ts` (`cardFrom`), `booster_render.ts` (~193-199 hit name, ~308 tray name), `booster_render_host.ts` / `booster_types.ts` (strings type), `booster_fixtures.ts`; CSS gate pattern `.booster-card:not([data-revealed]) .card__flake-group` in `booster-canister.css` ~389 (put the new gate in the new CSS file). `booster_controller.ts` is at 400 lines: do not add to it.
- Tiles: `app/views/library/_set_progress_tile.html.erb` (`set-tile` link classes, head with name/kind, visually hidden `label.sentence`), `_set_tile_page.html.erb`, `_custom_sets.html.erb`, `_set_results.html.erb`, `more_results.html.erb`, `in_progress.html.erb`, `more_tiles.html.erb`, `app/helpers/set_rows_helper.rb` (`set_tile_label`, `set_progress_sentence`), `app/helpers/custom_sets_helper.rb` (`own_set_tile_name`), `app/controllers/concerns/set_board_loading.rb`; `public_profiles/_sets.html.erb` renders the tile without a goal.
- Copy: `config/locales/{en,fr}.yml` -- `goals.*`, `library.filters.*`, `card_details.facts.*`, `booster.strings.*`, `library.entry.goals.*` (Copy deck "Goals" in EXPERIENCE.md line 113).
- Tests: `test/controllers/library_controller_test.rb` (exact query counts ~218, 405, 775, 781, 1678 will move), `library_goals_test.rb` (`add` helper: `Game::AddGoal.new.call(player:, **aim).value!`), `library_set_test.rb`, `cards_controller_test.rb`, `custom_sets_controller_test.rb`, `public_profiles_controller_test.rb` (query counts), `packs_controller_test.rb` (~409 answer keys; ~690 goal example on studio/valve with `portal_one`), `boosters_controller_test.rb` (restored templates); `test/support/{game_packs,game_sets,custom_sets,holdings,steam_sign_in}.rb`; system `test/system/{goals,library,collection_set,booster}_test.rb`; vitest `app/frontend/lib/opening.test.ts`, `booster_markup.test.ts`.

## Tasks & Acceptance

**Execution:**
- [x] `card_view.rb`, `card_views.rb`, `card_detail.rb` -- `card_id` on the view -- marks look cards up by catalog card id.
- [x] `app/models/goal_marks.rb` + `app/controllers/concerns/goal_marks_loading.rb` -- per-card marks and words from `GoalNeeds`, empty for a visitor or another player's page.
- [x] `card_component.{rb,html.erb}`, `app/frontend/styles/card-goals.css`, `application.css` -- the marks on the image's top-left corner, at full colour on a card not owned, sized per card size.
- [x] `collection_grid_loading.rb`, `collection_grid.rb`, `collection_helper.rb`, `library/_filters.html.erb`, `_collection`, `_slots`, `cards.html.erb`, `cards.turbo_stream.erb`, `library_controller.rb#cards` -- marks on grid cards and the OBJECTIFS filter group.
- [x] `set_album_loading.rb`, `_album.html.erb`, `library_controller.rb#set`, `custom_sets_controller.rb#show` -- album marks without the album's own goal; none on profile albums.
- [x] `cards_controller.rb`, `cards/_detail.html.erb`, `card_details_helper.rb` -- large bookmarks on the card and the OBJECTIFS row; goal words in link labels.
- [x] `packs_helper.rb`, `packs_controller.rb`, `boosters_controller.rb`, `boosters/_opened.html.erb`, `boosters_helper.rb`, `packs/show.html.erb`, `opening.ts`, `booster_markup.ts`, `booster_render.ts`, strings type, `booster_fixtures.ts` -- marks in the reveal faces, gated until revealed; `goals` words in the JSON and names.
- [x] `_set_progress_tile.html.erb`, `_set_tile_page.html.erb`, `_custom_sets.html.erb`, `set_rows_helper.rb`, `custom_sets_helper.rb`, `library_controller.rb#show/#in_progress` -- goal edge, bookmark and goal words on goal set tiles.
- [x] `config/locales/en.yml`, `fr.yml` -- card goal words, filter group and chip name, detail row label, booster names, tile goal word.
- [x] Tests: component (marks, sizes, outside the body), `GoalMarks` unit test, controller tests for grid/album/own album/profile/visitor/filter/stale filter/count/card detail row/pack JSON `goals`/restored templates/tiles, updated query counts; vitest for `goals` validation and markup (`opening.test.ts`, `booster_markup.test.ts`); a new `test/system/goal_bookmarks_test.rb` covering the Acceptance Criteria (grid and filter, shared and own album, capsule reveal, card detail, profile, removal, tile), asserting with retrying Capybara matchers and restoring any window size it changes.

**Acceptance Criteria:**
- Given a signed-in player with a goal on a game set, when they open Toutes les cartes, then every card of that set, owned and missing, shows the numbered bookmark at the top-left of its image, the OBJECTIFS group lists the goal, and checking its chip keeps only that set's cards with the filter count at 1.
- Given that player, when they open the album of another set sharing those cards, then the shared cards carry the bookmark; when they open the goal's own album, then its cards carry none.
- Given that player opens a capsule on the booster screen holding a card of the goal, when the card is revealed, then its face shows the bookmark, which was not visible while face down.
- Given that player opens that card's detail, then the card shows the large bookmark and the OBJECTIFS row links to the set's album.
- Given another player views the first player's public collection and album, then no bookmark shows.
- Given the player removes the goal, when they reopen the grid, then no bookmark and no OBJECTIFS group remain.
- Given a goal set's tile in EN COURS or MES SETS, then it carries the goal edge and bookmark, and its accessible name names the goal.

## Implementation Notes

**Decisions**
- `GoalMarks` (`app/models/goal_marks.rb`) wraps the `GoalNeeds::Need`s in number order and indexes them by catalog card id: `goals_for(card_id)` (the needs, for words), `numbers_for`, `without(target)` (a goal's own album), `chosen(values)` and `card_ids_of(chosen)` (the filter), `targets`, and `GoalMarks.filter_value` (`kind:key` or the custom set token). `GoalMarks::NONE` is the empty value every partial defaults to, so a page that passes nothing (public profile, hub, feeds, trades, editor) never draws a mark.
- `GoalMarksLoading#goal_marks` memoizes one `GoalNeeds.call` per request (empty for a visitor). `CollectionGridLoading` includes it and gates it with `grid_goals` (NONE when `grid_another?` or no owner), which serves the chips, the filter and the marks; the card detail uses `goal_marks` directly, so a signed-in viewer sees their own goals on a card even when browsing a friend's grid (the grid's goal filter is still ignored there).
- `GoalControlLoading#load_goal_control` takes `targets:` (default `GoalNeeds.targets`): the album pages pass `goal_marks.targets`, so the goals are read once; `GoalsController` keeps the default.
- Card words go through helpers (`goal_card_words`, `goal_name`, `set_tile_goal` in `GoalsHelper`); `card_detail_open_label`/`link_to_card_detail` take `goals:` (needs) and append the words only when there are any. Partials receive the needs, `CardComponent` the numbers.
- The marks are the last child of `.card` (after `.card__effects` or `.card__lock`), positioned by `top: 100% - (frame + padding + rarity line + 2 gaps + line + art height)` and `left: frame + padding + 4px`; gaps 4px, 3px on `card--s`, 5px on `l`/`xl`. All new CSS is in `app/frontend/styles/card-goals.css` (card marks, booster gate, detail row, chip gap, tile edge and title), imported after `card-rarity-effects.css`.
- Tiles get a `goal:` strict local; the `goals:` list (needs on `library#show`, targets from `GoalNeeds.targets` on `#in_progress` and the more-results frame) is threaded through `_entry`, `_set_results`, `_custom_sets`, `_set_tile_section`, `_set_tile_page`. `_steam_library` passes none (it cannot be a goal); `public_profiles/_sets` passes none.
- Booster: `pack_card_fields(card, goals:)` adds `goals` (the words, "" when none) to the JSON and to the restored `data-goals`; `pack_faces(card, goals:)` and `_opened` render the faces with the numbers. New strings `face_up_goals`, `face_up_store_goals`, `tray_slot_goals`; `BoosterRenderer#faceUpString` picks them when `card.goals` is non-empty. `booster_controller.ts` untouched (400 lines).
- Chip accessible name is the checkbox's `aria-label` ("Objectif 1 : Roguelike"); the OBJECTIFS detail links carry the same `aria-label`.

**Files touched**
- New: `app/models/goal_marks.rb`, `app/controllers/concerns/goal_marks_loading.rb`, `app/frontend/styles/card-goals.css`, `test/models/goal_marks_test.rb`, `test/controllers/goal_bookmarks_pages_test.rb`, `test/system/goal_bookmarks_test.rb`.
- Catalog: `card_view.rb` (`card_id`, default nil), `card_views.rb`, `card_detail.rb`, `collection_grid.rb` (`card_ids:`).
- Controllers: `collection_grid_loading.rb`, `goal_control_loading.rb`, `library_controller.rb`, `custom_sets_controller.rb`, `cards_controller.rb`, `packs_controller.rb`, `boosters_controller.rb`.
- Helpers: `card_details_helper.rb`, `collection_helper.rb`, `custom_sets_helper.rb`, `goals_helper.rb`, `packs_helper.rb`, `boosters_helper.rb`, `set_rows_helper.rb`.
- Views: `card_component.{rb,html.erb}`, `library/{_album,_collection,_custom_sets,_entry,_filters,_grid,_set_progress_tile,_set_results,_set_tile_page,_set_tile_section,_slots,cards,in_progress,more_results,more_tiles,set}`, `cards.turbo_stream.erb`, `cards/{_detail,show}`, `custom_sets/show`, `boosters/{_booster,_opened,show}`, `packs/show`.
- TS: `opening.ts`, `booster_markup.ts`, `booster_render.ts`, `booster_render_host.ts`, `booster_fixtures.ts`, tests `opening.test.ts`, `booster_markup.test.ts`.
- Locales: `goals.{name,card_words,tile_words}`, `library.filters.groups.goals`, `card_details.facts.goals`, `booster.strings.{face_up_goals,face_up_store_goals,tray_slot_goals}` in en and fr.
- Tests updated: query counts (+1, the goals read) in `library_controller_test.rb` and `cards_controller_test.rb`; JSON keys in `packs_controller_test.rb`; `card_id` in `card_views_test.rb`, `card_detail_test.rb`; `card_component_test.rb`; `card_share_image_test.rb`.
- `set_album_loading.rb` needed no change: its slots carry the `CardView`, which now carries `card_id`.

**Verified**: full suite (`PARALLEL_WORKERS=3 bin/rails test`, 4054 runs) green; system tests `goal_bookmarks`, `goals`, `library`, `collection_set`, `booster`, `custom_sets`, `card_detail`, `public_profile` green; `npm run test:js`, `format:check`, `lint:css`, `zeitwerk:check`, `packwerk check`, `check_planning_references`, `check_file_sizes`, `i18n-tasks missing/unused`, `rubocop`, French typography clean. Screenshots of the grid, card detail, entry tiles and capsule checked by eye.

**Surprises**
- `CardShareImage.fingerprint` hashed `view.to_h`: adding `card_id` would have changed every card's fingerprint and re-rendered every stored share image in production. It now hashes `view.to_h.except(:card_id)` (the image does not draw the id), with a test.
- A goal the opening completes is removed in the opening's transaction, so marks read afterwards would miss the completing card. The booster JSON path reads the marks before `Game::OpenPack` (`marks_before_opening`), so that card keeps its bookmark and words in the reveal; the restored capsule and the pack page read live goals. Asserted in `packs_controller_test.rb` (the Valve goal reached by an opening).
- Review fixes: the tile partial's next-tier line is now `goal_line`, so `goal` keeps meaning the goal; `packs#show` reads `goal_marks` through a helper method instead of an `@goals` holding a `GoalMarks`.
- Adding a goal on a set already complete is refused (`goal_set_complete`), and a custom set needs three games: the tests arrange around both.

## Plan Change Log

## Review Triage Log

### 2026-11-01 — Review pass
- verdicts: 3 findings — high 0, medium 1, low 2, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` Quick: the booster JSON read the goal marks after `Game::OpenPack`, whose goal-completion handler had already deleted a goal the opening completes, so the card that completed it showed no bookmark and no goal words at its reveal, although it belonged to the goal when the capsule was opened and the OBJECTIF ATTEINT toast only follows the reveal — verified in `packs_controller.rb#open_from_booster` and `Game::Handlers::GoalsReached`; fixed by reading `goal_marks` before the opening (`marks_before_opening`) and asserting in `packs_controller_test.rb` that the completing cards carry "goal 1: Valve" and bookmark 1. The restored capsule and the no-script pack page keep reading live goals (residual risk).
  - `[low]` `[patch]` Quick: `_set_progress_tile.html.erb` reassigned the new strict local `goal` with the next-tier text (`if (goal = set_goal_line(standing))`), one name for two meanings — verified harmless today (nothing reads `goal` afterwards) but a direct rename fixes it; renamed to `goal_line`.
  - `[low]` `[patch]` Quick: `packs#show` stored a `GoalMarks` in `@goals` while every other controller's `@goals` holds needs or targets — verified; `PacksController` now exposes `goal_marks` as a helper method and `packs/show.html.erb` reads it, the ivar is gone.

## Design Notes

- Marks live in `CardComponent` so every face the server renders (grid, album, detail, booster faces carried as HTML in the JSON and the restored templates, pack page) gets one placement rule. The `.card` root is the tilt layer (no filter/opacity on it); the marks sit beside `.card__body` like `.card__lock`, which already escapes the not-owned grey.
- `GoalNeeds.call` already returns every goal's card ids with one query set (sets by key, custom set standings, held games); one read per request serves the marks, the chips and the filter. Tiles that need only targets use `GoalNeeds.targets`.
- The trade boards' bookmarks (author, 2026-10-31) belong to the trade suggestions epic and are left out.

## Verification

**Commands:**
- `bin/rails test test/components test/controllers test/domains/catalog test/domains/game test/helpers test/models` -- expected: pass
- `bin/rails test test/system/goal_bookmarks_test.rb test/system/goals_test.rb test/system/library_test.rb test/system/collection_set_test.rb test/system/booster_test.rb test/system/custom_sets_test.rb` -- expected: pass
- `PARALLEL_WORKERS=3 bin/rails test` -- expected: pass
- `npm run test:js`, `npm run format:check`, `npm run lint:css`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `script/check_planning_references`, `script/check_file_sizes`, `bundle exec i18n-tasks missing`, `bundle exec i18n-tasks unused`, `bin/rubocop`, `bin/rails test test/config/french_typography_test.rb` -- expected: clean

## Auto Run Result

Status: built.

**Change.** Every card of a player's goal sets, owned or not, now carries the numbered Goal bookmark in the goal's colour. It hangs from the top edge of the card's image, 4px in from its left edge, side by side in number order, outside the faded body, so a card not owned keeps it at full colour. The marks show:
- in Toutes les cartes;
- in every album, without the album's own goal;
- at the capsule reveal, only once the card is face up, the restored capsule and the no-script pack page included;
- on the card detail, large, with an OBJECTIFS row after SETS linking each goal's album.

Each marked card's accessible name ends with its goals ("objectif 1 : Roguelike"). The grid's filter zone gains the OBJECTIFS group (`goals[]` by `kind:key` or custom set token), counted, paged, cleared and carried into the card detail's ◀ ▶. A goal set's tile in EN COURS, COMPLÉTÉS, MES SETS and the set search gets the 6px goal edge, the large bookmark before its name and "objectif n" in its accessible name. Nothing is stored; a removed goal's marks are gone on the next render. A public profile, a visitor, the hub, feeds, showcases, the editor and trade boards show none.

**Files.**
- `app/models/goal_marks.rb`, `app/controllers/concerns/goal_marks_loading.rb`: per-card marks from `Game::GoalNeeds`, read once per request.
- `app/domains/catalog/app/queries/catalog/{card_view,card_views,card_detail,collection_grid}.rb`: `card_id` on the card view (never rendered); the grid's `card_ids:` restriction.
- `app/components/card_component.{rb,html.erb}`, `app/frontend/styles/card-goals.css`, `application.css`: the bookmarks on the face, the face-down gate, the detail row, the chips and the tile edge.
- `app/controllers/{library,custom_sets,cards,packs,boosters}_controller.rb`, `concerns/{collection_grid_loading,goal_control_loading}.rb`: goals threaded to each own page.
- `app/helpers/{goals,card_details,collection,custom_sets,set_rows,packs,boosters}_helper.rb`: goal words, labels, count, tile sentence, booster JSON `goals`.
- `app/views/library/*`, `cards/{_detail,show}`, `custom_sets/show`, `boosters/{_booster,_opened,show}`, `packs/show`: the marks, the filter group, the detail row and the tiles.
- `app/frontend/lib/{opening,booster_markup,booster_render,booster_render_host,booster_fixtures}.ts`: `goals` validated and read back; revealed and tray names with goals.
- `app/models/card_share_image.rb`: the share image fingerprint leaves `card_id` out, so no stored image is re-rendered.
- `config/locales/{en,fr}.yml`: the new strings.
- Tests: new `test/models/goal_marks_test.rb`, `test/controllers/goal_bookmarks_pages_test.rb` and `test/system/goal_bookmarks_test.rb`; updated component, catalog, share image, library, cards and packs tests (query counts +1, JSON keys), and the vitest files `opening.test.ts` and `booster_markup.test.ts`.

**Review (quick lens, one pass).** 3 findings, all patched, none deferred or rejected:
- medium: the card that completes a goal at the opening lost its bookmark, since the marks were read after the goal was deleted; the booster JSON now reads them before the opening, with a test;
- low: the tile partial's `goal` local was reused for the next-tier line; renamed `goal_line`;
- low: `packs#show`'s `@goals` held a `GoalMarks`; it now reads `goal_marks` through a helper method.

Follow-up review recommended: false. This pass patched 1 medium and 2 low, no high.

**Verification** (after the patches):
- `PARALLEL_WORKERS=3 bin/rails test`: 4054 runs, 0 failures. This includes the French typography test.
- System tests `goal_bookmarks`, `goals`, `library`, `collection_set`, `booster`, `booster_screen`, `custom_sets`, `card_detail` and `public_profile`: 110 runs, 0 failures. Before the patches, `booster_reveal_mode` and `booster_reserves` also passed: 17 runs.
- `npm run test:js`: 795 tests passed.
- Clean: `format:check`, `lint:css`, `check_planning_references`, `check_file_sizes`, `packwerk check`, `zeitwerk:check`, `i18n-tasks missing` / `unused`, `rubocop`, `export.mjs --check`.

**Copy the UX did not specify.**
- All the English wording: "Goals" (filter group, detail row), "Goal n: <set>" (chip and detail link names), "goal n: <set>" (card name words) and "goal n" (tile name).
- The booster names with goals in both languages: "%{card}, %{rarity}, %{goals}. Voir la fiche." / "… Ranger la carte." / "… Agrandir." and their English versions.

**Residual risks.**
- Trade boards carry no bookmark yet (author, 2026-10-31). They are left to the trade suggestions epic.
- The card that completes a goal keeps its bookmark only on the live booster reveal. After a reload of the opened capsule, and on the no-script pack page, the goal is already gone, so that card shows none.
- A signed-in viewer sees their own goals on a card detail opened from a friend's grid or album. Those pages themselves show no marks.
- Each own page now reads the goals once more: the grid, the card detail, the albums, in progress and the booster opening, about four queries each.
- The marks' position relies on the card's size variables. It was checked by eye on the grid, the detail, the tiles and the capsule, not at every container width. The NOUVEAU tag at the slot's top-left sits above the image, so it was not seen to collide.
- The goal bookmarks on the set tiles' small recto cards are left out.
