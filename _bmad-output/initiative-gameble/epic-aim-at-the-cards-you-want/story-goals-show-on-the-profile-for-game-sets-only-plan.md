---
title: 'Goals show on the profile, for game sets only'
type: 'feature'
ticket: 11
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
deferred: []
---

<intent-contract>

## Intent

**Problem:** A player's goals show only on their own collection entry; whoever can read their public profile cannot see which game sets they are aiming at.

**Approach:** The public profile gains an OBJECTIFS section listing the owner's goals on game sets as goal rows without their bookmark, each opening the owner's public album of that set. A goal on a custom set never shows there, and the section exists only where the profile itself is visible. The bridge stays without goals.

## Boundaries & Constraints

**Always:**
- Visibility is the profile's: the section renders only inside `public_profiles#show`, which already answers the unavailable page (404) when `Game::Visibility.visible?` refuses the viewer (private, friends only to a non-friend, banned). No new visibility rule.
- Read through one new query entry point, `Game::GoalNeeds.on_game_sets(player)`: the `Need`s of the player's game set goals, in position order, the same shape as `GoalNeeds.call`. It filters the goal rows to `custom_set_id: nil` at the SQL level, so it never reads a custom set (no `CustomSetStandings` query) and a custom set goal's name never reaches the view.
- Section placement and markup: an h2 section `public_profiles/_goals.html.erb` using the existing `profile-section` classes (`aria-labelledby`, id `profile-goals-heading`), rendered after SUCCÈS and before SETS, only when there is a published season and at least one game set goal; absent otherwise (no empty line, no count, no "n / 5": the count would reveal hidden custom goals).
- Each row is the Goal row of the collection (one link, `goal-tone--n` edge and gauge colour, name over kind, gauge with ticks of a tiered set, owned/total, "Plus que X pour Y", "ALBUM ▸"; bookmark, gauge, ticks hidden from assistive technology) without the bookmark, linking to `brother_set_path(owner.token, kind:, key:)`. Its accessible name is the row sentence without the goal number: "Roguelike, thème, 12 cartes sur 62, plus que 4 pour Adepte".
- Extract the goal row markup from `library/_goals.html.erb` into one shared partial taking `need:`, `href:`, `sentence:` and `bookmark:`; the collection entry's OBJECTIFS output stays byte-for-byte equivalent (its tests pass unchanged).
- A bookmarkless row gets a modifier class whose grid drops the `mark` column on desktop and on the phone (`max-width: 719px`), in `collection-goals.css`; server HTML carries no `style` attribute.
- Every new string in en.yml and fr.yml (French typography U+202F before `: ; ? !`).

**Never:** goals on the hub/bridge, the friend profile dialog, the owner's full collection (`brothers/:token/library`) or a public album; a custom set goal on the profile, by name, count or number; a goal bookmark anywhere on the profile; changes to `GoalNeeds.call`/`targets` behaviour; database ids in HTML; planning ids in code.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Public, mixed goals | owner public; goal 1 custom "Mes favoris", goal 2 theme/roguelike, goal 3 studio/valve | OBJECTIFS lists Roguelike then Valve, no "Mes favoris", no bookmark; rows link to the owner's public albums | No error expected |
| Custom goals only | owner's goals all on custom sets | no OBJECTIFS section | No error expected |
| No goals | owner without goals | no OBJECTIFS section; one more SQL query than before (the goal rows) | No error expected |
| Private | owner private, visitor or friend | unavailable page, 404, no goals | Existing visibility |
| Friends only | non-friend / friend | non-friend: unavailable; friend: OBJECTIFS shown | Existing visibility |
| Signed out | owner public | OBJECTIFS shown | No error expected |
| No published season | owner public with goals | no-season line, no OBJECTIFS | No error expected |
| Bridge | owner signed in with goals opens the hub | no goal row, no bookmark | No error expected |

</intent-contract>

## Code Map

- `app/domains/game/app/queries/game/goal_needs.rb` -- `call(player)` builds `Need`s from `goal_rows`, `Catalog::SetsByKey.call`, `CustomSetStandings` (returns `[]` with no query for empty tokens) and `HeldGames`; add `on_game_sets(player)` sharing that path with the rows restricted to `custom_set_id: nil` (e.g. a private `needs(player, rows)` both call). Keep `private_class_method` list tidy; file stays well under 400 lines.
- `app/controllers/public_profiles_controller.rb` -- `load_stats_and_sets` runs only with a season; set `@goals = Game::GoalNeeds.on_game_sets(@owner)` there. `app/views/public_profiles/show.html.erb` passes locals to `_profile.html.erb` (strict `locals:` magic comment: add `goals:` with a default `[]`), which renders stats, achievements, sets in order.
- `app/views/public_profiles/_sets.html.erb`, `_achievements.html.erb` -- section markup to mirror (`profile-section`, `profile-section__head`, `profile-section__title`).
- `app/views/library/_goals.html.erb` -- current goal row markup inside `goals.each`; move it to the shared partial (e.g. `app/views/goals/_row.html.erb`) and render it from here with `href: goal_album_path(need)`, `sentence: goal_row_sentence(need)`, `bookmark: true`.
- `app/helpers/goals_helper.rb` -- `goal_set_name`, `goal_kind_name`, `goal_row_sentence` (uses `library.entry.goals.row` with `number:`); add a numberless sentence helper for the profile (new key, e.g. `public_profiles.show.goals.row: "%{set}, %{kind}, %{count}, %{next}"`) reusing `goal_next_words`; `set_tier_ticks?`, `set_tier_ticks`, `set_goal_line` come from `app/helpers/set_rows_helper.rb`.
- `app/frontend/styles/collection-goals.css` (383 lines, limit 500) -- `.goal-row` grid `"mark name track count next album"` and the phone grid `"mark name count" / "track track track" / "next next next"` under `@media (max-width: 719px)`; add the bookmarkless modifier. `goal-tone--n` defines `--goal`. Already imported globally.
- `config/locales/en.yml` / `fr.yml` -- `public_profiles.show.*` (sets block around en.yml:2235) for the new title and row keys; French copy "Objectifs", sentence like `library.entry.goals.row` minus "Objectif %{number} : ".
- Tests: `test/controllers/library_goals_test.rb:146` asserts a public profile shows no goal -- change its profile part to assert no bookmark and no custom set goal instead (keep the hub and other's album assertions). `test/controllers/public_profiles_controller_test.rb:751-777` `assert_request_queries(15/23/24/22)` on `brother_path` gain exactly one query (goal rows) when the owner has no goals. Helpers: `test/support/{custom_sets,game_sets,library_requests,catalog_seeds}.rb` (`create_custom_set`, `insert_set`, `assert_request_queries`, `publish_sets_draft`); `Game::AddGoal.new.call(player:, kind:, key:)` / `(player:, custom_set:)` as in `library_goals_test.rb#add`; visibility set as other profile tests do (grep `visibility` in `public_profiles_controller_test.rb`). System: `test/system/public_profile_test.rb` (sign-in, `publish_sets_draft`, `brother_path`).

## Tasks & Acceptance

**Execution:**
- [x] `app/domains/game/app/queries/game/goal_needs.rb` -- add `on_game_sets(player)` -- profile reads game set goals without touching custom sets.
- [x] `app/views/goals/_row.html.erb`, `app/views/library/_goals.html.erb` -- extract the goal row (locals `need:, href:, sentence:, bookmark:`) and render it from OBJECTIFS unchanged.
- [x] `app/helpers/goals_helper.rb` -- numberless row sentence for the profile.
- [x] `app/controllers/public_profiles_controller.rb`, `app/views/public_profiles/{show,_profile,_goals}.html.erb` -- load `@goals`, render the OBJECTIFS section between SUCCÈS and SETS when any.
- [x] `app/frontend/styles/collection-goals.css` -- bookmarkless row grid, desktop and phone.
- [x] `config/locales/en.yml`, `config/locales/fr.yml` -- section title and row sentence.
- [x] `test/domains/game/goal_needs_test.rb` -- `on_game_sets` returns game set goals in order, skips custom ones, issues no custom set query.
- [x] `test/controllers/public_profile_goals_test.rb` (new) -- matrix rows: mixed goals (order, links to `brother_set_path`, no custom name, no `.goal-bookmark`, numberless accessible sentence), custom-only and none (no section), private and friends-only non-friend (404, no rows), friend and signed-out visitor (shown), no published season; `library_goals_test.rb` and `public_profiles_controller_test.rb` query counts updated.
- [x] `test/system/public_profile_test.rb` -- a visitor reads the owner's game set goals as rows without bookmark, never the custom one, opens a row's album; after the owner goes private, the profile is unavailable.

**Acceptance Criteria:**
- Given an owner with goals on a custom set and on two game sets and a public profile, when a signed-out visitor opens the profile, then OBJECTIFS lists the two game sets in goal number order as goal rows without bookmark, and the custom set's name appears nowhere on the page.
- Given that profile, when the visitor activates a goal row, then the owner's public album of that set opens.
- Given the owner sets their profile private, when the visitor opens the profile, then the unavailable page shows and no goal appears.
- Given the owner signed in with goals, when they open the hub, then no goal row or bookmark appears.
- Given the collection entry's OBJECTIFS, when the existing collection goal tests run, then they pass unchanged.

## Implementation Notes

- `Game::GoalNeeds.on_game_sets(player)` and `.call(player)` both go through a private `needs(player, rows)`; `goal_rows` takes an optional goal scope, and `on_game_sets` passes `Goal.where(custom_set_id: nil)`. With no custom target, `CustomSetStandings` returns `[]` without a query, so no `FROM "game_custom_sets"` statement is issued (the goal row query keeps its harmless LEFT JOIN, all its custom columns NULL).
- Shared row partial `app/views/goals/_row.html.erb` (`need:, href:, sentence:, bookmark:`) renders the link only; the caller wraps it in its `<li>`. The bookmarkless modifier is `goal-row--no-bookmark`; with `bookmark: true` the class list is unchanged, so OBJECTIFS on the collection renders the same markup (its tests pass unchanged).
- `GoalsHelper#profile_goal_row_sentence` reuses a private `goal_row_words(need)` shared with `goal_row_sentence`; new keys `public_profiles.show.goals.{title,row}` in en.yml and fr.yml.
- `PublicProfilesController#load_stats_and_sets` sets `@goals` (so only with a published season); `_profile.html.erb` takes `goals: []` and renders `public_profiles/_goals` between achievements and sets only when `goals.any?`. The list is `ol.goals__list.profile-goals` (the `profile-goals` class is a hook only, no CSS).
- CSS: `.goal-row--no-bookmark` drops the `mark` column on desktop (after `.goal-row`) and on the phone (inside the 719px media query after the phone `.goal-row`). File now 396 lines.
- Tests: new `test/controllers/public_profile_goals_test.rb` (mixed, custom-only and none, private/friends-only/friend/stranger, no season); `goal_needs_test.rb` gains the `on_game_sets` test; `library_goals_test.rb`'s last test now asserts the profile shows one game set row, no bookmark, no custom set name (hub and other's album assertions kept); `public_profiles_controller_test.rb` query counts +1 (16/16/24/25/23) with the comment naming the goal rows; system test in `public_profile_test.rb` (desktop and 390px screenshots checked by eye: rows without bookmark, phone grid name/count, track, next).
- Surprise: `goals: if goals.any?` (shorthand hash value before a modifier `if`) is a syntax error in ERB/Prism; written `goals: goals if goals.any?`.
- After review: the row partial takes `tone:` (default `need.position`), and the profile passes the display order, so a hidden custom set goal's slot never shows through the tones; `load_stats_and_sets` renamed `load_season_sections`; `profile.css` header lists the goals; the hub assertion also refuses `.goal-row`.
- Verification run: the four request/domain files, both system files, `PARALLEL_WORKERS=3 bin/rails test` (3967 runs, 0 failures), `npm run format:check`, `npm run lint:css`, `npm run test:js` (795 passed), `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `script/check_planning_references`, `script/check_file_sizes`, `i18n-tasks missing/unused`, `test/config/french_typography_test.rb`, rubocop on touched Ruby, brakeman: all clean.

## Plan Change Log

## Review Triage Log

### 2026-11-01 — Review pass
- verdicts: 4 findings — high 0, medium 0, low 4, false 0, maybe-false 0
- findings:
  - `[low]` `[patch]` Quick: the profile rows carried the goal's real slot in `goal-tone--n` and its colour, so a hidden custom set goal at slot 1 showed as profile tones starting at 2, against the Never rule (no custom set goal on the profile by number) — the row partial takes `tone:` (default `need.position`, the collection unchanged) and the profile passes the display order; the test expects `goal-tone--1 goal-tone--2`.
  - `[low]` `[patch]` Quick: `load_stats_and_sets` also loaded the goals, so its name no longer said what it does — renamed `load_season_sections`.
  - `[low]` `[patch]` Quick: the `profile.css` header comment listed the profile's sections without the goals — the comment now names the game set goals between the latest achievements and the started sets.
  - `[low]` `[patch]` Quick: the hub assertion in `library_goals_test.rb` refused `#goals, .goal-bookmark` but not `.goal-row` — `.goal-row` added.

## Design Notes

- No "n / 5" and no free slot on the profile: both count every goal, so they would reveal custom set goals the profile must never show. The goal colour edge stays (it is part of the Goal row); without the bookmark the number is not shown nor spoken, which keeps the row honest about what it shows.
- OBJECTIFS sits after SUCCÈS and before SETS: it is closest to SETS in meaning, and leads it because a goal is the owner's chosen focus while SETS is a ranking.

## Verification

**Commands:**
- `bin/rails test test/controllers/public_profile_goals_test.rb test/controllers/public_profiles_controller_test.rb test/controllers/library_goals_test.rb test/domains/game/goal_needs_test.rb` -- expected: pass
- `bin/rails test test/system/public_profile_test.rb test/system/goals_test.rb` -- expected: pass
- `PARALLEL_WORKERS=3 bin/rails test` -- expected: pass
- `npm run format:check`, `npm run lint:css`, `npm run test:js`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `script/check_planning_references`, `script/check_file_sizes`, `bundle exec i18n-tasks missing`, `bundle exec i18n-tasks unused`, `bin/rails test test/config/french_typography_test.rb` -- expected: clean

## Auto Run Result

Status: built.

**Change.** The public profile gains an OBJECTIFS section between SUCCÈS and SETS. It lists the owner's goals on game sets, in goal number order, as goal rows without their bookmark: name over kind, gauge with tier ticks, owned / total, "Plus que X pour Y" and "ALBUM ▸". Each row opens the owner's public album of that set. A goal on a custom set never shows, by name, count, number or colour. The section has no "n / 5" and no free slot, and it is absent when the owner has no game set goal or no season is published. It shows wherever the profile shows: signed out and to friends on a friends-only profile; a private profile, and a friends-only one to a stranger, stay the unavailable page. The bridge still shows no goals.

**Files.**
- `app/domains/game/app/queries/game/goal_needs.rb`: `on_game_sets(player)`, the game set goals only, filtered in SQL; `call` unchanged through a shared private `needs`.
- `app/views/goals/_row.html.erb` (new), `app/views/library/_goals.html.erb`: the goal row, shared by the collection and the profile (`bookmark:`, `tone:`).
- `app/views/public_profiles/_goals.html.erb` (new), `_profile.html.erb`, `show.html.erb`, `app/controllers/public_profiles_controller.rb` (`load_season_sections`): the profile section.
- `app/helpers/goals_helper.rb`: the row sentence without the goal number.
- `app/frontend/styles/collection-goals.css`: `.goal-row--no-bookmark`, desktop and phone; `profile.css`: header comment.
- `config/locales/{en,fr}.yml`: `public_profiles.show.goals.{title,row}`.
- Tests: new `test/controllers/public_profile_goals_test.rb`; `goal_needs_test.rb`, `library_goals_test.rb`, `public_profiles_controller_test.rb` (profile query counts +1: the goal rows), `test/system/public_profile_test.rb`.

**Review (quick lens, one pass).** 4 findings, all low, all patched (tones by display order on the profile, the controller method renamed, the CSS header comment, the hub assertion); none deferred, none rejected.

Follow-up review recommended: false. This pass patched 4 low entries, no high and no medium.

**Verification.**
- `PARALLEL_WORKERS=3 bin/rails test`: 3967 runs, 0 failures, after the review patches.
- System tests `public_profile` and `goals`: 8 runs, 0 failures.
- `npm run test:js`: 795 passed.
- Clean: `npm run format:check`, `npm run lint:css`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `script/check_planning_references`, `script/check_file_sizes`, `i18n-tasks missing` and `unused`, the French typography test, and rubocop on the touched Ruby.
- Desktop and 390px screenshots checked: rows without bookmark; on the phone name and count, then the gauge, then the "Plus que" line.

**Copy the design did not specify.**
- The section title "Objectifs" / "Goals".
- The row's accessible sentence without the goal number: "Roguelike, thème, 1 carte sur 5, plus que 2 pour Novice" / "Horror, theme, 8 cards out of 16, …".

**Residual risks.**
- Placement between SUCCÈS and SETS, no count, and the tones renumbered by display order are build choices; the UX names only "Goal rows without their bookmark, under the profile's visibility".
  - On their own profile, the owner sees a goal in a colour that can differ from its colour on their collection.
- With game set goals present, the profile costs a few more queries (published season, sets by key, held games). Only the no-goal case (+1 query) is pinned by a test.

