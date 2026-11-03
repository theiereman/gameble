---
title: 'A player picks up to five active goals and follows them in the collection'
type: 'feature'
ticket: 9
created: '2026-11-01'
status: done
baseline_revision: 'ded021fb11ba64766b8b94ed5924bd3ab41808de'
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

**Problem:** A player cannot tell the game which sets they are working towards; nothing keeps a chosen set's progress in front of them.

**Approach:** A `game_goals` table (up to five numbered goals per player, each on a game set by kind and key or on a `custom` set), `Game::AddGoal` / `Game::RemoveGoal` behind a goal button in the player's own album header, one `Game::GoalNeeds` query feeding an OBJECTIFS panel of goal rows on the collection entry, goals removed by handlers when a pack or trade completes their set (with an OBJECTIF ATTEINT toast for the acting player) or when a newly published season drops their game set (silently).

## Boundaries & Constraints

**Always:**
- Table `game_goals` (the architecture's name; the weekly goal keeps `game_weekly_goals`, `WeeklyGoal`, `GoalReward`, `CurrentGoal`): `player_id` (FK accounts_players), `position` integer checked `BETWEEN 1 AND 5`, `set_kind` / `set_key` strings, `custom_set_id` (FK game_custom_sets `on_delete: :cascade`), timestamps. Checks: exactly one target (`(custom_set_id IS NULL) = (set_kind IS NOT NULL)`, `(set_kind IS NULL) = (set_key IS NULL)`), `set_kind` one of `Catalog::SetKind::ALL` written as `OR`-ed equalities (an `IN` list breaks the schema round trip). Unique `(player_id, position)`; unique `(player_id, set_kind, set_key) WHERE set_kind IS NOT NULL`; unique `custom_set_id WHERE custom_set_id IS NOT NULL`. Migration version `20261101130000`.
- A goal is addressed by its target, never by position, in URLs, forms and HTML; a custom set by token. No database id leaves the server.
- `Game::AddGoal.call(player:, kind: nil, key: nil, custom_set: nil)` and `Game::RemoveGoal` (same target arguments) run under `lock_bank`; Add takes the lowest free position 1–5, publishes `Game::GoalAdded`; Remove deletes and publishes `Game::GoalRemoved` (data `player_id`, `goal_id` only, player stream). Goals are never reordered or renumbered.
- A goal targets a game set present in the published season (`Catalog::PublishedSeason`) or one of the player's `custom`-kind sets; never a `steam_library` set. A complete set cannot become a goal (it would leave at once by the completion rule).
- `Game::GoalNeeds.call(player)` is the one query returning, in position order, each goal's target, label data, all its card ids, held card ids and tiers (`missing_card_ids`, `held`, `total`, `complete?`, `custom?`, `to_set_standing`); custom set goals read `Game::CustomSetStandings`; game set goals read a new batch `Catalog::SetsByKey`; one `HeldGames` call for the game sets. `Game::GoalNeeds.targets(player)` returns the rows only (position, kind, key, custom set token and name, the catalog set for its label) for the album button and the reached-goal snapshot.
- Completion: a handler subscribed to `Game::PackOpened` (player) and `Game::TradeAccepted` (proposer and recipient) deletes, in that transaction, every goal of those players whose set is now complete (read through `GoalNeeds`); it publishes nothing.
- Publication: `Game::Handlers::SeasonPublished` also deletes every game set goal whose kind and key has no `catalog_sets` row in the published season, in the publication transaction, with no notice.
- Toast "OBJECTIF ATTEINT" (title) with the set's name (message), one per reached goal, for the player whose action completed it: the web layer reads `GoalNeeds.targets` before and after `OpenPack` / `AcceptTrade` and names the goals that left. Booster JSON carries `goalsReached: [names]`, and the booster dispatches the toasts when the opening completes (where the set celebration starts), never while cards are face down; the form path and trade accept carry them in `flash[:goals_reached]`, rendered by `shell/_toasts.html.erb`.
- Goal button only on `library#set` (own game set album) and `custom_sets#show` for a `custom` set: "MARQUER COMME OBJECTIF" → "OBJECTIF n · RETIRER" (accessible name "Objectif n, <set>. Retirer des objectifs"), removal without confirmation. With five goals the button stays enabled; a press writes the refusal "5 OBJECTIFS AU PLUS · Retirez un objectif pour en ajouter un autre." with "VOIR MES OBJECTIFS ▸" (`library_path(anchor: "goals")`) under it, `role="status"`. Turbo Stream responses replace only the goal control so focus stays on the button; HTML falls back to a redirect to the album. Album header gets the 6px goal edge in the goal's colour while its set is a goal.
- OBJECTIFS panel (`id="goals"`, corner brackets) on the player's own collection entry, a direct child of `.set-entry` between the set results and MES SETS, hidden under typed search results: kicker "OBJECTIFS" with "n / 5"; one goal row per goal in number order (whole row one link to the album named by the row sentence, bookmark/gauge/ticks hidden from assistive technology); free slot line under five goals; empty line with the hollow bookmark at zero. Copy deck "Goals" in EXPERIENCE.md; English translated from the French.
- Goal colours `--color-goal-1..5` and `--color-on-goal` in `tokens.css` (DESIGN.md hex); bookmark drawn in CSS per `components.goal-bookmark` (clip-path, drop-shadow outline); server HTML carries no `style` attribute; gauges are `<progress>`.
- Account deletion erases goals; the data export lists them (position, game set kind and key or custom set token, creation time); the delete dialog note and the legal page's stored-data line and deletion paragraph name the goals.
- Every string in en.yml and fr.yml; French U+202F before `: ; ? !` and inside « »; French plurals with a `zero` form.

**Never:** goal bookmarks on cards, the grid's OBJECTIFS filter, the card detail's OBJECTIFS row, goal edges on set progress tiles (the bookmark entry); goals on the profile or the bridge; a goal on a Steam library set; anything in `Game::DrawPool`, `Game::Draw` or the odds reading goals; draw tests changed; a goal toast for the trade's proposer; React or markup built in script.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Add first | no goals, game set theme/roguelike in the published season | goal at position 1, one `GoalAdded` | No error expected |
| Lowest free | goals at 1, 2, 3; 2 removed; add | new goal at 2; 1 and 3 unchanged | No error expected |
| Sixth | five goals | nothing written | `Failure(:too_many_goals)` |
| Already a goal | add the same target | nothing written, returns the goal | Success |
| Remove absent | target not a goal | nothing written | Success(nil) |
| Unknown game set | kind not in `SetKind::ALL`, key absent from the published season, or no published season | nothing written | `Failure(:goal_set_not_found)` |
| Other's / library set | custom set token of another player or a `steam_library` set | nothing written | `Failure(:custom_set_not_found)` |
| Complete set | every game held | nothing written | `Failure(:goal_set_complete)` |
| Banned / deleted / nil | any | nothing written | `Failure(:player_required)` |
| Pack completes | the pack credits the last missing game of goal 2 | goal 2 deleted in the opening's transaction; JSON `goalsReached: ["Roguelike"]`; toast after the reveal | No error expected |
| Trade completes | accepted trade completes a goal of both players | both goals deleted; accepter gets the toast | No error expected |
| Season drops set | new season has no theme/roguelike | that goal deleted silently; custom set goals kept | No error expected |
| Custom set deleted | goal on it | goal gone by cascade | No error expected |

</intent-contract>

## Code Map

- `db/migrate/20261031100000_create_game_custom_sets.rb` -- table, FK, partial index and check style to mirror.
- `app/domains/game/app/operations/game/operation.rb` -- `require_player`, `lock_bank`, `stream_name`, `publish`; `#call` must take `player:`. `create_custom_set.rb`, `delete_custom_set.rb`, `custom_set_steps.rb` (`locked_custom_set`, `published`) -- shape of locked, refusing, publishing operations.
- `app/domains/game/app/queries/game/custom_set_standings.rb` -- `call(player, tokens:)`, `Standing#to_set_standing`; reuse unchanged. `held_games.rb` -- `HeldGames.call(player_id, card_ids:)`.
- `app/domains/game/app/models/game/set_standing.rb` -- `measured(set_id:, held:, total:, tiers:)`, `next_tier`, `missing`, `complete?`.
- `app/domains/catalog/app/queries/catalog/set_album.rb` -- one set's members and tiers by season/kind/key; `Catalog::SetsByKey` is its batch sibling (`sets(season:, keys:)` one query; `call(season:, keys:)` with card ids in set order and `{tier => required}`).
- `app/domains/game/app/operations/game/open_pack.rb`, `accept_trade.rb` -- holdings credited before `PackOpened` / `TradeAccepted` are published; handlers see them. Do not change these operations.
- `config/initializers/event_store.rb` -- subscriptions; add the completion handler. `app/domains/game/app/handlers/game/handlers/pack_opened.rb` -- handler writing derived rows through a model class method (`WeeklyContribution.record_opening`), the precedent for `Goal` class methods called from handlers; `season_published.rb` -- add the unpublished-goal drop.
- `app/controllers/packs_controller.rb` (`open_from_form`, `open_from_booster`), `app/helpers/packs_helper.rb` (`pack_opening_json`), `app/controllers/trades_controller.rb#accept` (`toast`, `redirect_after`) -- where the reached-goal snapshot wraps the operation; extract the snapshot into a controller concern.
- Booster front-end: `app/frontend/lib/opening.ts` (answer type and validator), `booster_opening.ts` (`openingAnswered`, `completed()`), `booster_state.ts` (`celebrate`), `booster_reflect.ts` (side effects), `booster_fixtures.ts`; `controllers/booster_controller.ts` is at exactly 400 lines -- add nothing there or extract first. Toast: `lib/events.ts` `gameble:toast`, `controllers/toast_controller.ts`, `app/components/toast_component.rb`, `app/views/shell/_toasts.html.erb`.
- `app/controllers/library_controller.rb#show`, `#set`; `app/views/library/_entry.html.erb` (order: search, results, MES SETS, lazy EN COURS), `_custom_sets.html.erb`, `set.html.erb`, `_album.html.erb` (`actions` local in `.set-album__title`), `app/views/custom_sets/show.html.erb` (actions only when `custom?`).
- `app/helpers/set_rows_helper.rb` -- `set_kind_name`, `set_tier_ticks?`, `set_tier_ticks`, `set_goal_line` ("Plus que X pour Y" with tier chip), `set_tier_chip`; `app/components/set_label.rb` -- `SetLabel.for(set)`. `library/_set_progress_row.html.erb` -- closest row markup; `tier-ticks` Stimulus controller positions ticks.
- CSS: `app/frontend/styles/tokens.css`, `collection-custom-sets.css` (`.set-entry:has(.set-results) > .custom-sets` hide rule, `.set-album__actions`); `collection-grid.css` is at 499 lines -- add nothing there; new `collection-goals.css` imported in `app/frontend/entrypoints/application.css`.
- `app/controllers/custom_sets_controller.rb` -- `throttle_player`, `authorize`, `redirect_refused`; `app/policies/custom_set_policy.rb` -- policy shape.
- `config/routes.rb` -- library routes under `:locale`; add goal routes beside `library/custom-sets`.
- Deletion/export: `app/domains/game/app/operations/game/release_player.rb`, `queries/game/export_of.rb` (`Result`, `custom_sets`, `private_class_method`), `app/models/player_export.rb` (`to_h` sections); copy in `accounts.dialog.note`, legal stored-data line and deletion paragraph (en.yml ~17/1875/1973, fr.yml ~276/311/1752).
- Tests: `test/support/{game_sets,custom_sets,holdings,game_packs,game_trades,catalog_seeds}.rb` (`insert_set`, `published_cards`, `create_custom_set`, `hold`, `create_pack`, `conclude_trade`, `publish_sets_draft`, `game_events`); `test/domains/game/custom_set_operations_test.rb` (`assert_refused`, write counting); `test/controllers/accounts_controller_test.rb` (`ERASED_OR_CANCELLED` must map `game_goals`), `pages_controller_test.rb` (legal lists), `test/models/player_export_test.rb` (`SECTIONS`), `data_exports_controller_test.rb`, `library_controller_test.rb:1400` (entry query count), `packs_controller_test.rb:409` (`setTiers` JSON), `test/system/custom_sets_test.rb` (system sign-in), booster system tests; front-end `app/frontend/lib/*.test.ts`. `test/domains/game/draw_test.rb` stays untouched.

## Tasks & Acceptance

**Execution:**
- [x] `db/migrate/20261101130000_create_game_goals.rb`, `db/schema.rb` -- table, indexes, checks per Always; regenerate the schema as AGENTS.md says (with `db:schema:dump`); diff holds only `game_goals`.
- [x] `app/domains/game/app/models/game/goal.rb` -- model, `POSITIONS = (1..5)`, class methods `drop_reached(player_ids)` (deletes goals whose `GoalNeeds` reads complete) and `drop_unpublished(season_id)` (one DELETE with `NOT EXISTS` on `catalog_sets`).
- [x] `app/domains/game/app/events/game/goal_{added,removed}.rb` -- events.
- [x] `app/domains/game/app/operations/game/{add_goal,remove_goal}.rb` (+ `goal_steps.rb` for target resolution) -- per the matrix.
- [x] `app/domains/catalog/app/queries/catalog/sets_by_key.rb` -- batch read of published sets by `[kind, key]`.
- [x] `app/domains/game/app/queries/game/goal_needs.rb` -- `call` and `targets` per Always.
- [x] `app/domains/game/app/handlers/game/handlers/goals_reached.rb`, `season_published.rb`, `config/initializers/event_store.rb` -- completion handler on `PackOpened` and `TradeAccepted`; publication drop.
- [x] `release_player.rb`, `export_of.rb`, `player_export.rb` -- erase and export goals.
- [x] `app/policies/goal_policy.rb`, `config/routes.rb` (`post`/`delete "library/goals"`), `app/controllers/goals_controller.rb` -- create/destroy by target params (`kind`+`key` or `custom_set`), throttled, turbo_stream replacing `#set-album-goal` (refusal inline, other failures as an alert toast) and HTML redirect fallback.
- [x] `app/controllers/concerns/goals_reached_tracking.rb`, `packs_controller.rb`, `packs_helper.rb`, `trades_controller.rb`, `app/views/shell/_toasts.html.erb` -- reached-goal snapshot, `goalsReached` in the booster JSON, `flash[:goals_reached]` toasts.
- [x] `app/frontend/lib/{opening,booster_opening,booster_state,booster_reflect,booster_fixtures}.ts` (+ the booster's strings source) -- validate `goalsReached`, dispatch one `gameble:toast` per name with the localized title when the opening completes; vitest coverage.
- [x] `app/views/goals/_control.html.erb`, `library/set.html.erb`, `custom_sets/show.html.erb`, `library_controller.rb`, `custom_sets_controller.rb` -- the goal button in the album actions, from `GoalNeeds.targets`.
- [x] `app/views/library/_goals.html.erb`, `_entry.html.erb`, `library_controller.rb#show`, a goals helper -- OBJECTIFS panel and goal rows.
- [x] `app/frontend/styles/tokens.css`, `collection-goals.css`, `entrypoints/application.css` -- tokens, bookmark, panel, rows (phone stacking), button tone, header edge, hide under search.
- [x] `config/locales/en.yml`, `fr.yml` -- goal copy, toast, refusal, `errors.game.{too_many_goals,goal_set_not_found,goal_set_complete}`, dialog note and legal lines naming goals.
- [x] Tests: `test/domains/game/goal_operations_test.rb` (matrix rows, events, nothing written on refusal), `goal_needs_test.rb`, `goals_reached_test.rb` (pack, trade both players, unaffected goal kept, publication drop, custom set cascade), `test/domains/catalog/sets_by_key_test.rb`, `test/policies/goal_policy_test.rb`, `test/controllers/goals_controller_test.rb` (create/destroy, refusal stream and HTML, visitor, throttle, no database id), `packs_controller_test.rb` (`goalsReached`), trades controller test (accept toast), library/custom sets controller tests (panel, button presence/absence incl. library set and public profile album, query count), accounts/pages/export tests, `test/system/goals_test.rb`.

**Acceptance Criteria:**
- Given a signed-in player on a game set's album and a custom set's album, when they press MARQUER COMME OBJECTIF on each, then the buttons read OBJECTIF 1 · RETIRER and OBJECTIF 2 · RETIRER, focus stays on the button, and the collection's OBJECTIFS shows "2 / 5", both rows in number order with owned/total, gauge and "Plus que" line, and the free slot line.
- Given goals 1 and 2, when the player removes goal 1 and marks a third set, then it reads OBJECTIF 1 and goal 2 keeps its number.
- Given five goals, when the player presses MARQUER COMME OBJECTIF on a sixth set, then nothing is added and the refusal with VOIR MES OBJECTIFS ▸ appears under the button.
- Given a goal set missing one game, when the player opens a capsule holding it on the booster screen, then after the cards are revealed the toast OBJECTIF ATTEINT names the set and the collection no longer lists the goal.
- Given a player with goals on the collection, when they type a set search, then OBJECTIFS is hidden like MES SETS; when they open the hub or a public profile, then no goal appears.
- Given players with and without goals, when the draw tests run, then they pass unchanged.

## Implementation Notes

**Decisions**
- Migration hard-codes the five set kinds in the check (no app constant in a migration); schema diff holds only `game_goals` and its two foreign keys. `player_id` has no index of its own: the unique `(player_id, position)` covers it.
- `Game::GoalNeeds` returns `Target` rows (goal id, position, kind, key, custom set token and name, catalog set) and `Need` (target + `card_ids`, `held_card_ids`, `tiers`, `missing_card_ids`, `complete?`, `to_set_standing`). A game set goal whose kind/key has no set in the published season is skipped by both readers (only possible with no published season, since publication drops them). Goal ids stay server-side (handler and the reached-goal diff); no id reaches HTML.
- `Game::AddGoal` check order: target (unknown set / not own custom set) → already a goal (Success, even at five) → free number (`too_many_goals`) → complete set (`goal_set_complete`). `Game::RemoveGoal` resolves the target without validating the set (a stale goal can always be removed) and answers `Success(nil)` when nothing matches.
- Completion: `Game::Handlers::GoalsReached` (subscribed to `PackOpened` and `TradeAccepted`) calls `Goal.drop_reached`, which only loads players that have goals, then reads `GoalNeeds` per player. Publication: `SeasonPublished` handler calls `Goal.drop_unpublished` (one `DELETE … WHERE NOT EXISTS` on `catalog_sets`) before enqueuing the bank healing.
- Web: `GoalsReachedTracking` concern (`tracking_goals_reached`, `toast_goals_reached`) wraps `OpenPack` in both pack paths and `AcceptTrade`; names come from `GoalsHelper#goal_set_name` (SetLabel or the custom set name). `pack_opening_json` takes `goals_reached:`; `shell/_toasts.html.erb` renders one toast per `flash[:goals_reached]` name.
- Booster: `goalsPending` (set by `openingAnswered`) moves to `goalsReached` inside `celebrate()` (so on the hand's completion and on a layout rebuild of a revealed hand) and inside `openingStarted` (a phone player who opens the next capsule before storing every card still gets the toast; every card is face up by then). `reflectChange` dispatches one `gameble:toast` per name with `booster.strings.goal_reached` when `goalsReached` changes; `booster_controller.ts` passes the title on its existing line (still 400 lines). A restored opened capsule carries `goalsReached: []`.
- Goal button: `goals/_control.html.erb`, rendered in the album `actions` (game set album; custom set album before MODIFIER/SUPPRIMER, `custom` kind only). It is hidden on an album whose set is complete and not a goal. Turbo Stream answer is `replace` with `method: :morph` on `#set-album-goal`; the refusal lives in an always-present empty `<p role="status">`. Other failures append an alert `ToastComponent` to `#toasts` (422). HTML fallback redirects to the album (flash `goal_refused` or alert), or to the collection when the target cannot name an album.
- Turbo disables the pressed submitter during submission, which drops focus; a small `goal-control` Stimulus controller remembers focus on `submit` and refocuses the control's button after the stream renders (wrapping `turbo:before-stream-render`'s `render`).
- The album header's goal edge comes from CSS `:has(.goal-control--set.goal-tone--n)`, so the stream only redraws the control. Ticks in goal rows reuse `set_tier_ticks` with their rank marks hidden (rows are 58px).
- Copy: `library.entry.goals.*` (panel, rows, sentence), `goals.*` (button, refusal, toast, throttle), `booster.strings.goal_reached`, `errors.game.{too_many_goals,goal_set_not_found,goal_set_complete}`; `goals.throttled` added to i18n-tasks `ignore_unused` (read through `throttle_player`). Legal stored-data line, deletion paragraph and delete-dialog note name the goals.

**Files touched**
- New: `db/migrate/20261101130000_create_game_goals.rb`, `app/domains/game/app/models/game/goal.rb`, `app/domains/game/app/events/game/goal_{added,removed}.rb`, `app/domains/game/app/operations/game/{add_goal,remove_goal,goal_steps}.rb`, `app/domains/game/app/queries/game/goal_needs.rb`, `app/domains/game/app/handlers/game/handlers/goals_reached.rb`, `app/domains/catalog/app/queries/catalog/sets_by_key.rb`, `app/controllers/goals_controller.rb`, `app/controllers/concerns/{goal_control_loading,goals_reached_tracking}.rb`, `app/policies/goal_policy.rb`, `app/helpers/goals_helper.rb`, `app/views/goals/_control.html.erb`, `app/views/library/_goals.html.erb`, `app/frontend/controllers/goal_control_controller.ts`, `app/frontend/styles/collection-goals.css`, tests `test/domains/game/{goal_operations,goal_needs,goals_reached}_test.rb`, `test/domains/catalog/sets_by_key_test.rb`, `test/policies/goal_policy_test.rb`, `test/controllers/{goals_controller,library_goals}_test.rb`, `test/system/goals_test.rb`, `app/frontend/lib/booster_goals.test.ts`.
- Changed: `db/schema.rb`, `config/routes.rb`, `config/initializers/event_store.rb`, `config/i18n-tasks.yml`, `config/locales/{en,fr}.yml`, `season_published.rb`, `release_player.rb`, `export_of.rb`, `app/models/player_export.rb`, `library_controller.rb`, `custom_sets_controller.rb`, `packs_controller.rb`, `trades_controller.rb`, `packs_helper.rb`, `library/{show,_entry,set}.html.erb`, `custom_sets/show.html.erb`, `shell/_toasts.html.erb`, `tokens.css`, `application.css`, `lib/{opening,booster_markup,booster_types,booster_state,booster_opening,booster_reflect,booster_render_host,booster_fixtures,opening.test}.ts`, `controllers/booster_controller.ts` (one argument), and the existing tests that list entry headings and the entry order, entry and album query counts (+1 query each: the goal rows), the album title line, pack JSON keys, export sections, erased tables and legal lists.

**Surprises**
- `.goal-row__next` as a flex container split "Only / 3 / more for" into separate items; it is plain inline text now.
- Capybara's `assert_link` matches the DOM text, not the CSS-uppercased rendering.

## Plan Change Log

## Review Triage Log

### 2026-11-01 — Review pass
- verdicts: 5 findings — high 0, medium 0, low 5, false 0, maybe-false 0
- findings:
  - `[low]` `[patch]` Quick: `package-lock.json` renamed the package to the worktree's folder name, an npm side effect outside the story — restored to the baseline content (bin/ci's setup step renames it again on each run, so it was restored once more before the commit).
  - `[low]` `[reject]` Quick: a goal whose game set is still in a newly published season but already complete for the player stays a goal until the next pack or trade, which then drops it with an OBJECTIF ATTEINT toast — real but rare (the new season's set must be wholly held through earlier editions); the architecture names only the crediting events and the missing-set drop at publication, and reading every goal player's holdings in the publication transaction is more than a direct correction.
  - `[low]` `[reject]` Quick: the Turbo Stream redraw of the goal control never passes `complete:`, so removing a goal on a complete set shows MARQUER COMME OBJECTIF where a page load shows nothing, and pressing it toasts `goal_set_complete` — reachable only through the publication case above or a stale second tab; the fix adds a read of the set's standing to the stream answer.
  - `[low]` `[reject]` Quick: without JavaScript, a `goal_set_not_found` or `custom_set_not_found` refusal redirects to the named album, which 404s and drops the alert — only on the no-script fallback with a stale or forged album; the fix adds a branch on the failure code.
  - `[low]` `[patch]` Quick: the three existing French lines this diff extends (legal stored-data line, deletion paragraph, delete-dialog note) kept plain spaces before ":" and ";", which develop's French typography rule now refuses — the edited lines now carry U+202F before ":" and ";" (the deletion paragraph had none), and `accounts_controller_test` quotes the note with U+202F. The rebase onto newer develop the finding also asks for is rejected: this build was cut from `ded021fb` on purpose and is cherry-picked by its caller.

## Design Notes

- The reached-goal toast needs to know which goals left, and the handler that deletes them may not publish; the web layer's before/after read of `GoalNeeds.targets` around the operation is the only stateless way. A replayed opening (same idempotency key) or a reload of the opened pack shows no goal toast; the trade's proposer, absent at the moment of completion, reads the goal gone: a toast confirms an action (EXPERIENCE.md, Toast), and the proposer's action was the proposal.
- `Goal.drop_reached` / `drop_unpublished` follow the existing handler precedent (`WeeklyContribution.record_opening`): derived deletions inside the event's transaction, no operation, no event.
- A goal on a set already complete is refused rather than left to the next credit, since the rule "a goal whose set becomes complete leaves by itself" would otherwise hold a complete goal with no event to remove it until the next pack or trade.
- The architecture's tribute set has no kind in code yet (`Catalog::SetKind::ALL`); the kind check excludes it by construction.

## Verification

**Commands:**
- `RAILS_ENV=test SCHEMA=tmp/migrated_schema.rb bin/rails db:drop db:create db:migrate db:schema:dump && cp tmp/migrated_schema.rb db/schema.rb` -- expected: diff limited to `game_goals`
- `bin/rails test test/domains/game test/domains/catalog test/domains/accounts test/policies test/controllers test/models` -- expected: pass, `draw_test.rb` unchanged
- `bin/rails test test/system/goals_test.rb test/system/custom_sets_test.rb test/system/library_test.rb` plus the booster system tests touched -- expected: pass
- `bin/rails test` -- expected: pass
- `bin/ci`, `npm run test:js`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `script/check_planning_references`, `script/check_file_sizes`, `npm run format:check`, `npm run lint:css`, `bundle exec i18n-tasks missing`, `bundle exec i18n-tasks unused` -- expected: clean

## Auto Run Result

Status: built.

**Change.** A player marks up to five sets as goals from the album header of a game set of the published season or of their own custom set ("MARQUER COMME OBJECTIF", then "OBJECTIF n · RETIRER"). Each goal keeps its number until removed, and a new goal takes the lowest free number. A sixth is refused under the button, with "VOIR MES OBJECTIFS ▸". The collection entry's OBJECTIFS panel lists the goals in number order, each with its gauge, ticks, owned / total and "Plus que" line, plus the free slot or empty line, and hides under a typed search. A goal whose set a capsule or an accepted trade completes leaves in that transaction. The acting player then reads "OBJECTIF ATTEINT · <set>": on the booster after the hand is revealed, and as a flash toast on the form path and on trade accept. A newly published season that no longer holds a goal's game set drops the goal silently. Deleting a custom set or the account erases its goals, and the data export lists them. Draws read nothing of goals; `draw_test.rb` is unchanged.

**Files.**
- `db/migrate/20261101130000_create_game_goals.rb`, `db/schema.rb`: the `game_goals` table, its checks and indexes.
- `app/domains/game/app/{models/game/goal.rb,events/game/goal_{added,removed}.rb,operations/game/{add_goal,remove_goal,goal_steps}.rb,queries/game/goal_needs.rb,handlers/game/handlers/goals_reached.rb}`, `season_published.rb`, `release_player.rb`, `export_of.rb`, `config/initializers/event_store.rb`: the domain side.
- `app/domains/catalog/app/queries/catalog/sets_by_key.rb`: published sets by kind and key, in batch.
- `app/controllers/goals_controller.rb`, `concerns/{goal_control_loading,goals_reached_tracking}.rb`, `library_controller.rb`, `custom_sets_controller.rb`, `packs_controller.rb`, `trades_controller.rb`, `app/policies/goal_policy.rb`, `config/routes.rb`, `app/helpers/{goals_helper,packs_helper}.rb`, `app/models/player_export.rb`: the web layer.
- `app/views/goals/_control.html.erb`, `app/views/library/{_goals,_entry,show,set}.html.erb`, `app/views/custom_sets/show.html.erb`, `app/views/shell/_toasts.html.erb`: the button, the panel and the toasts.
- `app/frontend/controllers/goal_control_controller.ts`, `app/frontend/lib/{opening,booster_opening,booster_state,booster_reflect,booster_types,booster_markup,booster_render_host,booster_fixtures}.ts`, `booster_controller.ts` (one line): the booster toasts and focus kept on the goal button.
- `app/frontend/styles/{tokens,collection-goals}.css`, `entrypoints/application.css`: the goal colours, bookmark, panel, rows, button and header edge.
- `config/locales/{en,fr}.yml`, `config/i18n-tasks.yml`: copy.
- Tests: new `goal_operations`, `goal_needs`, `goals_reached`, `sets_by_key`, `goal_policy`, `goals_controller`, `library_goals` and `system/goals` tests. Updated: `accounts_controller`, `library_controller`, `library_set`, `packs_controller`, `pages_controller`, `trades_controller` and `player_export` tests, and `opening.test.ts` with the new `booster_goals.test.ts`.

**Review (quick lens, one pass).** 5 findings, all low: 2 patched (the lockfile rename was reverted; the three French lines this diff extends now use U+202F), none deferred, 3 rejected:
- a goal whose set a new season already completes stays until the next credit;
- the stream redraw's `complete:` on a stale goal;
- the no-script redirect to an album that no longer exists.

Each rejection's reason is in the Review Triage Log.

Follow-up review recommended: false. This pass patched no high and no medium entry.

**Verification.**
- `bin/ci`: every step passed except the schema round trip. The full Rails suite ran 3858 runs with 0 failures. The round-trip step compares the working tree with the index, so it flags any unstaged `db/schema.rb`. Loading the schema and dumping it again gives a file identical to the working copy, and the migrated schema's diff holds only `game_goals`.
- System tests: `goals`, `custom_sets`, `library`, `collection_set`, `booster`, `booster_screen`, `booster_reserves` and `trades` gave 98 runs, 0 failures. `settings` gave 14 runs, 0 failures.
- `npm run test:js`: 760 tests passed.
- `bin/rails zeitwerk:check`: clean. Packwerk, i18n-tasks, the planning-id check, the size check, prettier and stylelint are clean inside `bin/ci`.

**Copy the design did not specify.**
- All the English wording, translated from the French.
- The refusals `errors.game.goal_set_not_found` ("Ce set ne fait pas partie de la saison publiée." / "This set is not in the published season.") and `goal_set_complete` ("Ce set est déjà complet." / "This set is already complete.").
- The throttle line `goals.throttled`.
- The French zero form "Aucun objectif libre · …", which the five-goal case never shows.
- "objectifs" / "goals" added to the legal stored-data line, the deletion paragraph and the account deletion note.

**Residual risks.**
- The branch was cut from `ded021fb`; develop has moved past it with the French typography rule, the Steam library set and two more stories.
  - Cherry-picking will conflict in `fr.yml` on the three extended legal and dialog lines. Keep develop's typography and add "objectifs" / "vos objectifs".
  - `db/schema.rb` must be regenerated from the migrations after the pick.
  - `library_controller#show` and the MES SETS list may also conflict with the library set entry, which filters `CustomSetStandings` by kind.
  - `booster_controller.ts` sits at exactly 400 lines.
- A replayed opening (same idempotency key), a reload of an opened pack and the trade's proposer get no OBJECTIF ATTEINT toast.
- A goal whose game set a new season already completes stays until the next pack or trade.
- The custom set editor entry, which lets a player remove a set's games, can complete a goal's custom set without a credit. It must drop the goal then.
- The goal edge and bookmark on set progress tiles, and the bookmarks on cards, are left to the bookmark entry.
- The staging walkthrough of this high-risk entry is the author's.
