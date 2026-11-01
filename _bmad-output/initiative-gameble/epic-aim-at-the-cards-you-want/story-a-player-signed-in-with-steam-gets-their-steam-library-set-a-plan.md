---
title: 'A player signed in with Steam gets their Steam library set automatically, synced once a day'
type: 'feature'
ticket: '7'
created: '2026-11-01'
status: 'built'
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
deferred:
  - summary: >-
      Players already signed in, or who linked Steam before this release and now sign in through Clerk, get no library set until their next Steam sign-in or link.
    evidence: |-
      The set is created only from SessionsController#create (Steam sign-in) and #link_steam, as the ticket says ("After a Steam sign-in"). The session cookie lives 30 days and each request renews it (config/initializers/session_store.rb), so an active production player may not sign in with Steam again for a long time, and Accounts::SignInThroughClerk never enqueues the job. A one-off backfill (CreateSteamLibrarySetJob for every player in good standing with a Steam identity) or an enqueue on Clerk sign-in for a player with a Steam identity would close it; the ticket does not ask for either, so the author decides.
    location: >-
      app/controllers/sessions_controller.rb create, link_steam
    severity: medium
---

<intent-contract>

## Intent

**Problem:** A player who signs in with Steam has no way to follow the catalog games they already own on Steam; the tables (`game_custom_sets` kind `steam_library`, `synced_at`, `library_private_since`) and `Steam::OwnedGames` exist, but nothing creates or syncs a library set, and the collection never shows one.

**Approach:** After a Steam sign-in (or a Steam link from the settings) commits, the web layer enqueues `CreateSteamLibrarySetJob`, which creates the player's one library set through `Game::CreateLibrarySet`. A daily `SyncSteamLibrariesJob` enqueues at most `STEAM_LIBRARY_DAILY_SYNCS` `SyncSteamLibraryJob`s (never-synced first, then least recently synced) on the `steam_library` queue, served by the import worker's single thread; each reads the Steam id through `Accounts`, calls `Steam::OwnedGames`, then `Game::SyncLibrarySet` or `Game::MarkLibraryPrivate`. The collection shows the set in a MA LUDOTHÈQUE STEAM section after MES SETS, with its sync line, once a first sync has run.

## Boundaries & Constraints

**Always:**
- Only the AD-2 arrows: jobs in `app/jobs` (web layer) combine `Accounts`, `Steam` and `Game`; no domain calls another to do this. Job arguments are the player id (create) or the player id and the set's token (sync), never a Steam id or a games list.
- `Game::CreateLibrarySet(player:)`: requires a player in good standing with a Steam identity (`Accounts::SteamIdOf`), takes the bank lock, creates a `steam_library` set (name null) only when the player has none, publishes `Game::LibrarySetCreated`; otherwise `Success` without writing or publishing. It never calls Steam and never enqueues a sync.
- `Game::SyncLibrarySet(player:, token:, card_ids:)`: require player, bank lock first (refusing a deleted player), re-finds the set by token among the player's `steam_library` sets with a row lock, `Success` without writing when gone, never creates one; keeps only ids `Catalog::PublishedCardIds.within` accepts; deletes the set's games no longer listed and inserts the new ones in one transaction; sets `synced_at` to now and clears `library_private_since`; publishes `Game::LibrarySetSynced` (player and set ids only) only when the games changed.
- `Game::MarkLibraryPrivate(player:, token:)`: same lock and lookup; keeps the games and `synced_at`; sets `library_private_since` to now when it is null and publishes `Game::LibrarySetMarkedPrivate`; when already set, `Success` without writing.
- `:steam_unavailable` leaves the set and its state untouched (it stays least recently synced, first the next day). `Steam::WebApi::Error`/`BrokenKey` raise out of the job (reported by the queue).
- The daily selection skips sets of banned or deleted players; order `synced_at NULLS FIRST, id`; limit from `config.x.steam.library_daily_syncs` (`STEAM_LIBRARY_DAILY_SYNCS`, default 5000).
- `config/queue_import.yml` lists `[ import, steam_library ]`, one process, one thread; `config/recurring.yml` runs `SyncSteamLibrariesJob` once a day in development and production.
- The section shows on the player's own collection only, after MES SETS, hidden under a typed set search like MES SETS, and only when the set exists and has `synced_at` or `library_private_since`. Its tile names "Ma ludothèque Steam" / "My Steam library", kind line "Steam · n jeux du catalogue", owned/total and a gauge to complete, no tiers; accessible name "Ma ludothèque Steam, 38 cartes sur 214". The sync line is muted, never orange: "Synchronisée avec Steam le 29 octobre 2026." or, when private, "Steam ne partage pas votre bibliothèque. Rendez publics les détails de jeux de votre profil Steam." then "Dernière synchronisation : 12 octobre 2026." (only when `synced_at` is set). MES SETS lists `custom` sets only, filtered in `Game::CustomSetStandings` by kind.
- The library set's album and page title read the display name; no MODIFIER, SUPPRIMER or goal button.
- New French strings take U+202F before `: ; ? !` and inside « »; every string in en.yml and fr.yml.

**Never:** the settings switch or its erase (entry 15), the privacy/retention pages or export naming of the list (entry 8), the set search finding the library set or custom set tiles (entry 5), goals, a Steam call in a request or in the create job, a stored raw Steam answer, a list in an event or job argument, a real Steam call in tests, a Solid Queue API call in code.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| First Steam sign-in | new or existing Steam player, no library set | `CreateSteamLibrarySetJob` enqueued after the sign-in; running it creates one set, one `LibrarySetCreated` | No error expected |
| Second sign-in | set exists | job runs, nothing written, no event | No error expected |
| Steam link from settings | Clerk player links Steam | same job enqueued; set created | No error expected |
| No Steam identity / banned / deleted | create job or operation | nothing written | `Failure(:steam_identity_required)` / `Failure(:player_required)` |
| Daily run | 3 sets, cap 2, one never synced | 2 sync jobs: never-synced, then oldest `synced_at`; banned/deleted players' sets never | No error expected |
| Sync, public | Steam lists games A, B; set holds B, C | set holds A, B; `synced_at` now, `library_private_since` null; one `LibrarySetSynced` | No error expected |
| Sync, unchanged | same list | `synced_at` updated, no event | No error expected |
| Sync, private | `Failure(:library_private)` | games and `synced_at` kept, `library_private_since` set once; one `LibrarySetMarkedPrivate` the first time | No error expected |
| Sync, unavailable | `Failure(:steam_unavailable)` | nothing written | No error expected |
| Set gone / player gone | token unknown, player deleted or without Steam id | nothing written, no Steam call when the player or id is missing | `Success` / job returns |
| Collection, never synced | set with neither date | no MA LUDOTHÈQUE STEAM section | No error expected |
| Collection, private | `library_private_since` set | section with its tile and the not-shared lines | No error expected |

</intent-contract>

## Code Map

- `app/controllers/sessions_controller.rb` -- `create` (Steam sign-in success after `session[:player_id] = player.id`) and `link_steam` (on `result&.success?`): enqueue `CreateSteamLibrarySetJob.perform_later(player.id)`; 140 lines, stay under 400.
- `app/domains/game/app/operations/game/operation.rb` -- `require_player`, `lock_bank`, `stream_name`; `custom_set_steps.rb#published(event, player, custom_set)` publishes with player and set ids. `create_custom_set.rb` is the shape to follow. `CustomSet` model: `CUSTOM`, `STEAM_LIBRARY`, enum `kind` (scope `steam_library`).
- `app/domains/accounts/app/queries/accounts/identities_of.rb`, `player_by_id.rb` -- pattern for the new `Accounts::SteamIdOf.call(player)` (the `uid` of the player's `provider: "steam"` identity, or nil); identities are authoritative (backfilled 2026-10-29).
- `app/domains/steam/app/models/steam/owned_games.rb` -- `Steam::OwnedGames.call(steam_id:)` → `Success(card_ids)`, `Failure(:library_private)`, `Failure(:steam_unavailable)`; read only.
- `app/domains/catalog/app/queries/catalog/published_card_ids.rb` -- `within(card_ids)`; read only.
- `app/domains/game/app/queries/game/custom_set_standings.rb` -- add a `kind:` filter and `synced_at`/`library_private_since` to `Standing` (nil for custom sets); `app/controllers/library_controller.rb#show` replaces `.select(&:custom?)` by the kind filter and loads the library standing.
- `app/views/library/_entry.html.erb` (rendered only by `library/show.html.erb`), `_custom_sets.html.erb` -- add `library/_steam_library` after MES SETS; reuse `.custom-sets__link`/`__count` look, `set-row__bar` progress, `set_album_value_text`/`library.set_progress.count`. `app/frontend/styles/collection-custom-sets.css` (201 lines) -- hide the section under `.set-results` like `.custom-sets`; muted sync line on `--color-panel-sunken` with the soft-line inner edge (check the token names in `app/frontend/styles/tokens*`).
- `app/views/custom_sets/show.html.erb`, `app/controllers/custom_sets_controller.rb#show` -- heading and title use a display-name helper (library → `custom_sets.library.name`).
- `app/helpers/card_details_helper.rb#card_detail_pioneer_date` -- the `long_day` / `long_day_first` date pattern to reuse for the sync dates.
- `app/jobs/card_share_image_job.rb`, `app/domains/game/app/jobs/game/grant_achievements_job.rb` -- job style; jobs here inherit `ApplicationJob`.
- `config/initializers/steam.rb` -- add `config.x.steam.library_daily_syncs`.
- `config/queue_import.yml`, `config/queue.yml` (comment names the queues it leaves out), `config/recurring.yml`; tests `test/config/queue_config_test.rb`, `test/lib/connection_budget_test.rb` (worker name becomes `Solid Queue worker (import, steam_library)`).
- Tests support: `test/support/steam_api_stubs.rb` (`stub_steam_api`, `stub_owned_games(appids)`, `stub_private_owned_games`, `stub_owned_games_failure`), `test/support/custom_sets.rb`, `test/support/steam_sign_in.rb`, `test/support/game_sets.rb` (`published_cards`), fixtures `accounts/identities.yml`, `test/system/custom_sets_test.rb` (system sign-in), `test/system/live_updates_test.rb` (`ActiveJob::TestHelper` in a system test), `test/controllers/sessions_controller_test.rb`, `test/controllers/library_controller_test.rb`, `test/controllers/custom_sets_controller_test.rb`.

## Tasks & Acceptance

**Execution:**
- [x] `app/domains/accounts/app/queries/accounts/steam_id_of.rb` -- new query -- the one Steam id read.
- [x] `app/domains/game/app/events/game/library_set_{created,synced,marked_private}.rb` -- events.
- [x] `app/domains/game/app/operations/game/{create_library_set,sync_library_set,mark_library_private}.rb` (+ shared lookup step in `custom_set_steps.rb` or a `library_set_steps.rb`) -- per the matrix.
- [x] `app/domains/game/app/queries/game/library_sets_due.rb` -- `call(limit:)` → `[player_id, token]` pairs, good-standing players only, `synced_at NULLS FIRST, id`.
- [x] `app/domains/game/app/queries/game/custom_set_standings.rb` -- `kind:` filter, sync dates on `Standing`.
- [x] `app/jobs/{create_steam_library_set,sync_steam_libraries,sync_steam_library}_job.rb` -- the three jobs; sync on queue `steam_library`, the others `default`.
- [x] `config/initializers/steam.rb`, `config/queue_import.yml`, `config/queue.yml`, `config/recurring.yml` -- cap, queue, daily schedule.
- [x] `app/controllers/sessions_controller.rb` -- enqueue after sign-in and after a successful Steam link.
- [x] `app/controllers/library_controller.rb`, `app/views/library/{_entry,_steam_library}.html.erb`, `show.html.erb`, a helper for the display name and sync lines, `app/views/custom_sets/show.html.erb`, `app/frontend/styles/collection-custom-sets.css` -- the section and the album name.
- [x] `config/locales/en.yml`, `fr.yml` -- `library.entry.steam_library.*` (kicker, kind line with zero/one/other, synced, not shared, last sync), `custom_sets.library.name`.
- [x] Tests: `test/domains/accounts/steam_id_of_test.rb`; `test/domains/game/library_set_operations_test.rb` (every operation row, events, nothing written on refusal); `test/domains/game/library_sets_due_test.rb`; `test/jobs/{create_steam_library_set,sync_steam_libraries,sync_steam_library}_job_test.rb` (stubbed Steam, one call per job, no call without a Steam id, queue name); `test/controllers/sessions_controller_test.rb` (job enqueued on sign-in and link, not on a refused sign-in); `test/controllers/library_controller_test.rb` (section absent / synced / private / never for a player without a set; MES SETS keeps custom sets only); `test/controllers/custom_sets_controller_test.rb` (library album named, no edit/delete); config tests; `test/system/steam_library_test.rb` (Steam sign-in in the browser, jobs performed with Steam stubbed, the section shows the games; a private run shows the message).

**Acceptance Criteria:**
- Given a player with public game details, when they sign in with Steam and the create job and a sync job run, then the collection shows MA LUDOTHÈQUE STEAM with "Ma ludothèque Steam", their owned published catalog games counted owned/total and the sync date; signing in again creates no second set.
- Given a synced set, when Steam later lists one more catalog game and the next sync runs, then the album lists it.
- Given a synced set, when Steam answers without a games list, then the set keeps its games and the section reads the not-shared line with the last sync date.
- Given a player without a Steam identity, then no set is created and no section shows.
- Given the suite, then no test reaches Steam and the draw and custom set tests pass unchanged.

## Implementation Notes

- Operations: `Game::CreateLibrarySet`, `Game::SyncLibrarySet`, `Game::MarkLibraryPrivate`, the shared `locked_library_set` added to `custom_set_steps.rb` (returns the set or nil, so a gone set is `Success(nil)` without writing). `CreateLibrarySet` returns the player's library set, created or already there; the Steam identity check runs before the bank lock. `SyncLibrarySet` filters the ids through `Catalog::PublishedCardIds.within` before the transaction, then deletes the games no longer listed and inserts the new ones; an empty public list empties the set (only a private answer keeps it).
- `Game::LibrarySetsDue` uses `Accounts::Player.in_good_standing` and orders `synced_at ASC NULLS FIRST, id`.
- `SyncSteamLibrariesJob` enqueues through `ActiveJob.perform_all_later` (one bulk insert for up to 5000 jobs; Active Job API, not Solid Queue's). `SyncSteamLibraryJob` makes no Steam call for a missing/banned/deleted player or a player without a Steam id; it still calls Steam for an unknown token (allowed by the matrix), and ignores `:steam_unavailable` without a retry, so the set stays first the next day. Operation failures in the job (a player deleted meanwhile) are ignored.
- `CustomSetStandings::Standing` gains `synced_at`, `library_private_since`, `steam_library?`, `library_private?` and `ever_synced?` (the section's condition). The library controller calls the query twice, once per kind, as the plan asks: the entry's query budget in `library_controller_test` moves from 13 to 14 with a search and from 7 to 8 without (test and its comment updated).
- `CustomSetsHelper` (new): `custom_set_display_name` (album heading and page title), the kind line, the tile's accessible name (name + `set_album_value_text`) and the sync lines with the `long_day`/`long_day_first` date pattern on the server's zone. The section partial is `library/_steam_library.html.erb`; the private case renders the not-shared line, then `<br>` and the bold last-sync line when `synced_at` is set. The visible name, kind and count are `aria-hidden`; a visually hidden span carries "Ma ludothèque Steam, 38 cartes sur 214".
- CSS in `collection-custom-sets.css`: the section hides under a typed search with `.custom-sets`; the sync line is `--color-panel-sunken` with a 2px `--color-line-soft` inner edge, a muted 8px light, muted bold body-small; the tile reuses `.custom-sets__link` and wraps to put the `set-row__bar` gauge on its own row.
- `recurring.yml` runs `sync_steam_libraries` every day at 5am (after the 4am retention); `STEAM_LIBRARY_DAILY_SYNCS` reads blank as the default. Surprise: `test/script/env_example_test.rb` requires every variable the code reads to be listed in `.env.example`, so it is listed there under Steam.
- The Steam link enqueue test lives in `test/controllers/steam_links_controller_test.rb`, where the link flow helpers are; the sign-in ones in `sessions_controller_test.rb`. The import worker's budget name changed in `connection_budget_test.rb` and `connection_budget_task_test.rb`.
- No locale key for `errors.game.steam_identity_required`: the failure is never shown to a player.
- Risk: if a day's sync jobs are still queued when the next daily run fires (an import keeping the single thread busy), the same sets are enqueued again; each sync is idempotent, but the Steam calls count twice against the cap.

- After review: the `config/deploy.yml` roles comment and `docs/operations.md` (Steam import paragraph, a new Steam library sync paragraph before Retention) name the `steam_library` queue and the daily sync; the job test no longer asserts the booted cap, which depends on the environment.

Files touched: `.env.example`, `config/deploy.yml`, `docs/operations.md`, `app/domains/accounts/app/queries/accounts/steam_id_of.rb`, `app/domains/game/app/events/game/library_set_{created,synced,marked_private}.rb`, `app/domains/game/app/operations/game/{create_library_set,sync_library_set,mark_library_private,custom_set_steps}.rb`, `app/domains/game/app/queries/game/{library_sets_due,custom_set_standings}.rb`, `app/jobs/{create_steam_library_set,sync_steam_libraries,sync_steam_library}_job.rb`, `app/controllers/{sessions,library}_controller.rb`, `app/helpers/custom_sets_helper.rb`, `app/views/library/{show,_entry,_steam_library}.html.erb`, `app/views/custom_sets/show.html.erb`, `app/frontend/styles/collection-custom-sets.css`, `config/initializers/steam.rb`, `config/queue.yml`, `config/queue_import.yml`, `config/recurring.yml`, `config/locales/{en,fr}.yml`; tests `test/support/custom_sets.rb`, `test/domains/accounts/steam_id_of_test.rb`, `test/domains/game/{library_set_operations,library_sets_due,custom_set_standings}_test.rb`, `test/jobs/{create_steam_library_set,sync_steam_libraries,sync_steam_library}_job_test.rb`, `test/controllers/{sessions,steam_links,library,custom_sets}_controller_test.rb`, `test/config/queue_config_test.rb`, `test/lib/connection_budget{,_task}_test.rb`, `test/system/steam_library_test.rb`.

## Plan Change Log

## Review Triage Log

### 2026-11-01 — Review pass
- verdicts: 4 findings — high 0, medium 1, low 3, false 0, maybe-false 0
- findings:
  - `[medium]` `[defer]` Players already signed in, or who linked Steam before the release and sign in through Clerk, never get a library set — real: only the Steam sign-in and the Steam link enqueue the creation, and sessions last 30 days, renewed by each request. The ticket defines the trigger as "after a Steam sign-in" and asks for no backfill, so it is out of this change's intent; deferred to the frontmatter `deferred` list for the author to decide on a backfill.
  - `[low]` `[reject]` Private and never-synced sets keep their sort key under `synced_at NULLS FIRST`, so once they number `STEAM_LIBRARY_DAILY_SYNCS` (5000) no public set is synced again — real, but only past 5000 private or never-synced libraries, far beyond the current player base, and the cap is configuration meant to be tuned. A fix needs an attempt date (a column) or a change to the contract's no-write rule for an already-private set, which is more than a direct correction. Named under residual risks.
  - `[low]` `[patch]` `config/deploy.yml` and `docs/operations.md` still describe the import worker as serving the `import` queue only, and the docs omit the daily sync — the implementer corrected the deploy comment and the Steam import paragraph, and added a "Steam library sync" paragraph before Retention.
  - `[low]` `[patch]` `sync_steam_libraries_job_test` asserted the booted cap equals 5000, which fails when `STEAM_LIBRARY_DAILY_SYNCS` is set and never tests the fallback — the implementer removed the assertion and the wording from the test name.

## Design Notes

A set whose first sync found the library private shows the section with the not-shared line and no last-sync line: the first sync has run, and the player learns why the set is empty. Private sets keep their old `synced_at`, so they stay early in the daily order and are retried each day; that is how a library made public again comes back, at one call per private set.

The tile is the MES SETS link look plus a kind line and a gauge; the full set progress tile for custom sets and the library is the custom sets section entry's work.

## Verification

**Commands:**
- `bin/rails test test/domains/game test/domains/accounts test/domains/steam test/jobs test/controllers/sessions_controller_test.rb test/controllers/library_controller_test.rb test/controllers/custom_sets_controller_test.rb test/config test/lib` -- expected: pass
- `bin/rails test test/system/steam_library_test.rb test/system/custom_sets_test.rb test/system/library_test.rb` -- expected: pass
- `bin/rails test` -- expected: pass
- `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `bin/rubocop`, `script/check_planning_references`, `script/check_file_sizes`, `npm run format:check`, `npm run lint:css`, `bundle exec i18n-tasks missing`, `bundle exec i18n-tasks unused` -- expected: clean

## Auto Run Result

Status: built.

**Change.**
- **Creating the set:** after a Steam sign-in, or a Steam account linked from the settings, the web layer enqueues `CreateSteamLibrarySetJob`. It creates the player's one `steam_library` set through `Game::CreateLibrarySet`, which takes the bank lock and requires a Steam identity (`Accounts::SteamIdOf`). It does nothing when the set exists and never calls Steam.
- **Daily selection:** `SyncSteamLibrariesJob`, every day at 5am, enqueues at most `STEAM_LIBRARY_DAILY_SYNCS` (default 5000) `SyncSteamLibraryJob`s, from sets of players in good standing, never-synced first, then by oldest sync.
- **Each sync:** each job takes only a player id and a token and runs on the `steam_library` queue, which the import worker's single thread serves. It calls `Steam::OwnedGames` once, then:
  - games listed: `Game::SyncLibrarySet` applies the difference of published games, dates the sync, clears the private mark, and publishes `LibrarySetSynced` only on a change;
  - library private: `Game::MarkLibraryPrivate` keeps the list and its date and records since when, once;
  - Steam unavailable: nothing is written.
- **Collection:** once a first sync has run, a MA LUDOTHÈQUE STEAM section after MES SETS holds:
  - the muted sync line, or the not-shared line with the last sync date;
  - a link tile with "Ma ludothèque Steam", "Steam · n jeux du catalogue", owned/total and a gauge.

  A typed set search hides it. MES SETS now lists custom sets only (a kind filter in `Game::CustomSetStandings`). The library's album reads "Ma ludothèque Steam" / "My Steam library", with no edit, delete or goal button. There is no migration.

**Files.**
- `app/domains/accounts/app/queries/accounts/steam_id_of.rb`: the Steam id read.
- `app/domains/game/app/events/game/library_set_{created,synced,marked_private}.rb`: the events (player and set ids only).
- `app/domains/game/app/operations/game/{create_library_set,sync_library_set,mark_library_private}.rb`, `custom_set_steps.rb`: the operations and the locked lookup by token.
- `app/domains/game/app/queries/game/library_sets_due.rb`, `custom_set_standings.rb`: the daily selection; the kind filter and sync dates.
- `app/jobs/{create_steam_library_set,sync_steam_libraries,sync_steam_library}_job.rb`: the three jobs.
- `app/controllers/sessions_controller.rb`: the enqueue after a Steam sign-in or link. `app/controllers/library_controller.rb`: the library standing.
- `app/helpers/custom_sets_helper.rb`, `app/views/library/{show,_entry,_steam_library}.html.erb`, `app/views/custom_sets/show.html.erb`, `app/frontend/styles/collection-custom-sets.css`: the section and the album name.
- `config/initializers/steam.rb`, `config/queue.yml`, `config/queue_import.yml`, `config/recurring.yml`, `config/deploy.yml`, `docs/operations.md`, `.env.example`: the cap, the queue, the schedule and their documentation.
- `config/locales/en.yml`, `fr.yml`: the section's and the album's strings.
- Tests: `test/domains/accounts/steam_id_of_test.rb`, `test/domains/game/{library_set_operations,library_sets_due,custom_set_standings}_test.rb`, `test/jobs/{create_steam_library_set,sync_steam_libraries,sync_steam_library}_job_test.rb`, `test/controllers/{sessions,steam_links,library,custom_sets}_controller_test.rb`, `test/config/queue_config_test.rb`, `test/lib/connection_budget{,_task}_test.rb`, `test/support/custom_sets.rb`, `test/system/steam_library_test.rb`.

**Review.** One quick pass, 4 findings:
- Patched (2, both low): the deploy comment and the operations docs; the environment-dependent cap assertion.
- Deferred (1, medium): no backfill for players who do not sign in with Steam again.
- Rejected (1, low): private and never-synced sets crowding out public ones past the daily cap, which needs more than a direct correction (reason in the Review Triage Log).

Follow-up review recommended: false. This pass patched 2 entries: high 0, medium 0, low 2.

**Verification** (all pass, after the patches):
- `bin/rails test` with `PARALLEL_WORKERS=4`: 3851 runs, 0 failures.
- `bin/rails test test/system/steam_library_test.rb test/system/custom_sets_test.rb test/system/library_test.rb`: 21 runs, 0 failures.
- `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `bin/rubocop`, `script/check_planning_references`, `script/check_file_sizes`, `npm run format:check`, `npm run lint:css`, `bundle exec i18n-tasks missing` and `unused`, and `npm run test:js` (756): all clean.
- `db/schema.rb` is unchanged, and the new French strings carry U+202F before `:`.
- Matrix audit: every row has a passing test, in the operations, query, job, controller and system tests.

**Copy the UX did not specify.**
- Every English string: "My Steam library", "Steam · n catalog game(s)", "Synced with Steam on October 29, 2026.", "Steam does not share your library. Make the game details of your Steam profile public.", "Last sync: October 1, 2026.".
- The French singular kind line ("Steam · 1 jeu du catalogue", also used for 0).

**Residual risks.**
- The staging walkthrough of the verify clause is the author's.
- Players who stay signed in, or use Clerk after linking Steam before the release, get no set until they sign in with Steam again (deferred).
- Past 5000 private or never-synced libraries, public sets stop syncing until the cap is raised (rejected finding).
- A day's syncs still queued when the next run fires are queued again; each sync gives the same result, but its Steam calls count twice.
- Sync dates are in UTC.
- The library tile is the MES SETS link look, not the design's full set progress tile, which is left to the custom sets section entry.
- The section was checked by tests only, never by eye in a browser.
