---
title: 'A player turns the Steam library sync off in the settings, which erases the set and its list'
type: 'feature'
ticket: '15'
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

**Problem:** A player signed in with Steam gets a Steam library set automatically, with no way to object: the set has no delete action, and nothing stops the daily read of their Steam library or erases the stored list.

**Approach:** A new `Accounts` player setting `steam_library_sync` (on by default) set by `Accounts::SetSteamLibrarySync`, which publishes `Accounts::SteamLibrarySyncChanged`; its `Game` handler erases the library set and its games in that transaction when turned off. `Game::CreateLibrarySet` skips a player with the setting off. The settings screen shows SYNCHRONISER MES JEUX STEAM (OUI / NON) to a player with a Steam identity; NON asks to confirm in a dialog; OUI enqueues, after commit, the creation job with its first sync.

## Boundaries & Constraints

**Always:**
- Migration `20261102120000_add_steam_library_sync_to_accounts_players.rb`: `add_column :accounts_players, :steam_library_sync, :boolean, default: true, null: false`. Regenerate `db/schema.rb` from the migrations (AGENTS.md) and check a `db:schema:load` then `db:schema:dump` leaves it unchanged.
- `Accounts::SetSteamLibrarySync#call(player:, enabled:)`: `Failure(:player_required)` for a non-persisted or banned player (same `require_player` as `SetVisibility`); `Failure(:invalid_setting)` unless `enabled` is exactly `true` or `false`; `Failure(:steam_identity_required)` when the player has no `provider: "steam"` identity. In a transaction: lock the player row `FOR NO KEY UPDATE`, re-check, return the player without writing or publishing when the value is unchanged; otherwise publish `SteamLibrarySyncChanged` (data `{ player_id:, enabled: }`, stream `"Accounts::Player$#{id}"`) and update the column. Returns `Success(player)`.
- `Game::Handlers::SteamLibrarySyncChanged`: does nothing when `enabled` is true; otherwise calls `Game::EraseLibrarySet` with `value!`. Subscribed in `config/initializers/event_store.rb`.
- `Game::EraseLibrarySet#call(player:)`: `require_account` (a banned player's set is erased too, a deleted one is gone anyway), inside a `transaction`: `lock_bank`-style `BankLock.acquire(player.id)`, then deletes the player's `steam_library` set(s) by `delete_all` (games go by the `ON DELETE CASCADE`). It publishes nothing (it runs inside a handler). `Success()` whether or not a set existed.
- `Game::CreateLibrarySet`: after `lock_bank`, reads the setting fresh from the database (`Accounts::Player.where(id:).pick(:steam_library_sync)`, or a new `Accounts` query `Accounts::SteamLibrarySyncOn`) and returns `Failure(:library_sync_off)` without writing or publishing when it is off. Reading it after the bank lock is what keeps an erase and a creation that race from leaving a set behind.
- `CreateSteamLibrarySetJob#perform(player_id, first_sync: false)`: when `first_sync` and the creation succeeds, enqueues `SyncSteamLibraryJob.perform_later(player_id, set.token)`. Sign-in and link callers keep `perform_later(player.id)` unchanged.
- `SettingsController#steam_library` (`PATCH /:locale/settings/steam-library`, `as: :settings_steam_library`, `SettingsPolicy#steam_library? = player?`): `steam_library_sync` param `"on"`/`"off"`, anything else `:invalid` → the operation's `invalid_setting` refusal through `redirect_refused`. `"off"` from a player whose setting is on, without `confirmed=1`, writes nothing and redirects to the settings with `flash[:confirm_library_off]`, which renders the dialog open (the no-JavaScript path, as `confirm_private`). On success, when it went from off to on, `CreateSteamLibrarySetJob.perform_later(current_player.id, first_sync: true)`. Always `redirect_to settings_path, status: :see_other`.
- Settings row, after ANIMATIONS RÉDUITES, only when the player has a Steam identity: label "Synchroniser mes jeux Steam" (uppercased by CSS) with the line under it "Gameble lit les jeux de votre compte Steam une fois par jour pour votre set MA LUDOTHÈQUE STEAM."; a `segmented` group (`aria-labelledby`) with "Oui" / "Non", `aria-pressed` on the current one. "Non", when the setting is on, opens `library-sync-dialog` through `dialog-opener` with `aria-haspopup=dialog`, like PRIVÉ.
- Dialog `settings/_library_sync_dialog.html.erb`, built like `_private_dialog.html.erb` (`modal`, `PanelComponent`, close button, `dialog` controller): title "Désactiver la synchronisation ?", text "Le set MA LUDOTHÈQUE STEAM et la liste de vos jeux Steam seront effacés.", buttons "Désactiver" (submits `steam_library_sync=off`, `confirmed=1`) and "Annuler" (`formmethod=dialog`). Rendered only when the row shows and the setting is on.
- Copy in `en.yml` and `fr.yml` (`settings.show.steam_library.*`, `settings.library_sync_dialog.*`); French with U+202F before `?` and `:`; English: "Sync my Steam games", "Gameble reads the games of your Steam account once a day for your MY STEAM LIBRARY set.", "Yes" / "No", "Turn off the sync?", "The MY STEAM LIBRARY set and the list of your Steam games will be erased.", "Turn off", "Cancel", "Close". Add `errors.accounts.steam_identity_required` in both locales by hand (French "Liez d'abord un compte Steam." / English "Link a Steam account first.").
- No `style` attribute; CSS in `app/frontend/styles/settings.css` (309 lines, stay under 500): the label and its line stack on the left; group the new dialog classes with the `.private-dialog__*` rules.

**Never:** a Steam call in a request; a list or Steam id in an event or job argument; a toast or flash notice for the change; the setting for a player without Steam; touching the export, privacy or retention pages (entry 8); a SUPPRIMER on the library album; changing the daily selection `Game::LibrarySetsDue`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Turn off, confirmed | on, set with games | setting false, set and its games deleted in the same transaction, one `SteamLibrarySyncChanged` | No error expected |
| Turn off, no set yet | on, no set | setting false, nothing else | No error expected |
| NON unconfirmed | `steam_library_sync=off`, no `confirmed` | nothing written; settings page with the dialog open | No error expected |
| Turn on | off, no set | setting true, one event, nothing erased; after commit `CreateSteamLibrarySetJob(id, first_sync: true)`; running it creates the set and enqueues one `SyncSteamLibraryJob` | No error expected |
| Same value again | on → on / off → off | nothing written, no event, no job | No error expected |
| Sign-in with sync off | `CreateSteamLibrarySetJob(id)` | no set, no event | `Failure(:library_sync_off)` |
| Erase meets a running sync | sync job after erase | `SyncLibrarySet` finds no set, writes nothing | `Success` |
| No Steam identity | operation / PATCH | nothing written; row and dialog absent on GET | `Failure(:steam_identity_required)`, flash alert |
| Invalid value | `"maybe"`, `nil`, `[ "on" ]` | nothing written | `Failure(:invalid_setting)`, flash alert |
| Visitor / banned | PATCH | refused by policy / `player_required` | as the other settings |

</intent-contract>

## Code Map

- `app/domains/accounts/app/operations/accounts/set_visibility.rb` -- the shape to copy (lock, unchanged short-circuit, publish then update). `update_settings.rb` -- leave as is.
- `app/domains/accounts/app/events/accounts/visibility_changed.rb` -- event file style.
- `app/domains/accounts/app/models/accounts/player.rb`, `identity.rb` -- the player; `Accounts::SteamIdOf` (`queries/accounts/steam_id_of.rb`) tells whether a Steam identity exists.
- `app/domains/game/app/handlers/game/handlers/visibility_changed.rb` -- handler style (reads the player through `Accounts::PlayerById`, calls a non-publishing operation with `value!`). `config/initializers/event_store.rb` -- subscriptions.
- `app/domains/game/app/operations/game/operation.rb` -- `require_player`, `require_account`, `lock_bank` (`BankLock.acquire` then deleted check); `create_library_set.rb` -- add the setting check after `lock_bank`; `delete_custom_set.rb` -- `delete_all` style; `custom_set_steps.rb` -- read only. `Game::CustomSet.steam_library` scope.
- `app/jobs/create_steam_library_set_job.rb`, `sync_steam_library_job.rb` -- jobs; `app/controllers/sessions_controller.rb` lines 35 and 62 -- unchanged callers.
- `app/controllers/settings_controller.rb` (`visibility`, `cancels_unconfirmed_trades?`, `show` sets `@identities`, `@name_editable`); `app/policies/settings_policy.rb`; `config/routes.rb` around line 117 (`settings/visibility`).
- `app/views/settings/show.html.erb` (visibility row with `dialog-opener`, motion row, end of file renders `private_dialog`), `_private_dialog.html.erb` -- the dialog to mirror. `app/frontend/styles/settings.css` (`.settings-row*`, `.private-dialog__*` at ~204).
- Locales: `settings:` at `config/locales/fr.yml:1367`, `en.yml:2346`; `errors.accounts.*` near the other Accounts errors.
- Tests: `test/domains/accounts/set_visibility_test.rb` (operation test style), `test/domains/game/library_set_operations_test.rb`, `test/jobs/create_steam_library_set_job_test.rb`, `test/controllers/settings_controller_test.rb` (private dialog tests ~187-310: redirect with flash, `assert_select "dialog#private-dialog[open]"`), `test/system/settings_test.rb` (sign-in helpers, the going-private dialog test at line 60), `test/system/steam_library_test.rb` (Steam stubs, `perform_enqueued_jobs`, `run_daily_sync`), `test/support/steam_api_stubs.rb`. Fixtures: `accounts_players(:player)` has a Steam identity; create a Clerk-only player (no `steam` identity) for the absent-row cases.

## Tasks & Acceptance

**Execution:**
- [x] `db/migrate/20261102120000_add_steam_library_sync_to_accounts_players.rb`, `db/schema.rb` -- the column, schema regenerated.
- [x] `app/domains/accounts/app/events/accounts/steam_library_sync_changed.rb`, `app/domains/accounts/app/operations/accounts/set_steam_library_sync.rb` -- the setting operation and its event.
- [x] `app/domains/game/app/operations/game/erase_library_set.rb`, `app/domains/game/app/handlers/game/handlers/steam_library_sync_changed.rb`, `config/initializers/event_store.rb` -- erase in the publishing transaction.
- [x] `app/domains/game/app/operations/game/create_library_set.rb` -- skip when the setting is off.
- [x] `app/jobs/create_steam_library_set_job.rb` -- `first_sync:` keyword.
- [x] `app/controllers/settings_controller.rb`, `app/policies/settings_policy.rb`, `config/routes.rb` -- the action.
- [x] `app/views/settings/show.html.erb`, `app/views/settings/_library_sync_dialog.html.erb`, `app/frontend/styles/settings.css` -- the row and the dialog.
- [x] `config/locales/en.yml`, `config/locales/fr.yml` -- the copy and the error.
- [x] Tests: `test/domains/accounts/set_steam_library_sync_test.rb` (every operation row, event data, nothing written on refusal, banned, no Steam identity); `test/domains/game/erase_library_set_test.rb` or additions to `library_set_operations_test.rb` (turning off erases the set and its `CustomSetGame` rows, leaves custom sets and other players' library sets, no Game event published; `CreateLibrarySet` refuses with the setting off); `test/jobs/create_steam_library_set_job_test.rb` (`first_sync: true` enqueues one sync with the set's token, default does not, sync off creates nothing); `test/controllers/settings_controller_test.rb` (row and dialog for a Steam player in French; absent for a Clerk-only player; unconfirmed NON redirects with the dialog open and writes nothing; confirmed NON erases; OUI enqueues the job with `first_sync: true`; OUI when already on enqueues nothing; invalid values; visitor refused; GET writes nothing); `test/system/settings_test.rb` or `test/system/steam_library_test.rb` (in the browser: NON opens the dialog, ANNULER keeps everything, DÉSACTIVER erases the set and the collection no longer shows MA LUDOTHÈQUE STEAM; signing in with Steam again creates nothing; OUI then performed jobs with Steam stubbed bring the section back).

**Acceptance Criteria:**
- Given a Steam player with a synced library set, when they choose NON in the settings and confirm DÉSACTIVER, then the collection shows no MA LUDOTHÈQUE STEAM section and no `game_custom_sets` or `game_custom_set_games` row of theirs remains for that set.
- Given that player, when they sign in with Steam again and the enqueued jobs run, then no library set is created.
- Given that player, when they choose OUI and the enqueued jobs run with Steam listing their games, then the section shows again with those games.
- Given a player without a Steam identity, when they open the settings, then no SYNCHRONISER MES JEUX STEAM row and no dialog are rendered.

## Implementation Notes

- Setting read in `Game::CreateLibrarySet` goes through a new query `Accounts::SteamLibrarySyncOn` (fresh `pick` from the database), called as a `step` right after `lock_bank`; `Failure(:library_sync_off)` writes and publishes nothing.
- `Game::EraseLibrarySet` returns `Success(<rows deleted>)` (0 or 1) rather than a bare `Success()`: dry-operation wraps the transaction block's value, so returning `Success()` from it would nest monads. Callers only use `value!`/`success?`.
- `SettingsController#steam_library` asks for confirmation only when the player has a Steam identity, the setting is on, the choice is `off` and `confirmed` is not `"1"`; a player without Steam goes straight to the operation and gets `steam_identity_required` as a flash alert. The off-to-on job is enqueued when the operation succeeds and the player's value read before the call was off.
- `show` computes `steam_linked` once; `@name_editable = !steam_linked`, `@library_sync` is nil without Steam (row and dialog hidden), and the dialog renders only when `@library_sync` is true. The view iterates `SettingsController::LIBRARY_SYNC_CHOICES`.
- CSS: new `.settings-row__heading` (label and line stacked, left) and `.settings-row__hint`; the dialog classes `.library-sync-dialog__{form,text,actions}` share the `.private-dialog__*` rules. settings.css is 328 lines.
- Error copy added by hand: `errors.accounts.steam_identity_required` in both locales. `errors.game.library_sync_off` is not added: like `errors.game.steam_identity_required` it is only seen by the job, never shown.
- Existing assertions updated for the new row: the settings screen now has 10 rows for a Steam player (`settings_controller_test.rb` label lists in both locales, `system/settings_test.rb` `assert_every_setting_shown`).
- Surprise: in controller tests, the Steam sign-in leaves its welcome notice in the session until a request reads the flash; a PATCH that redirects without a flash does not, so the "no notice" tests GET the settings once before the PATCH.
- Tests added: `test/domains/accounts/set_steam_library_sync_test.rb`, `test/domains/game/erase_library_set_test.rb`; additions to `library_set_operations_test.rb`, `create_steam_library_set_job_test.rb`, `settings_controller_test.rb` and `system/steam_library_test.rb` (the full off / sign-in again / on round trip in the browser).
- Review fix: the controller no longer decides the first-sync enqueue from the value read before the operation; `turned_on?` asks the returned player `saved_change_to_steam_library_sync?` and the new value (`lock!` reloads and clears earlier changes, so only an update under the lock counts). Two operation tests cover a stale player loaded off then turned on elsewhere (no change reported, no event) and one loaded on then turned off elsewhere (change to on reported).
- Verification: migration + schema regenerated, `db:schema:load` then `db:schema:dump` leaves db/schema.rb identical; `PARALLEL_WORKERS=3 bin/rails test` 4001 runs, 0 failures; `test/system/settings_test.rb` and `test/system/steam_library_test.rb` 17 runs, 0 failures; packwerk, zeitwerk, rubocop, planning references, file sizes, prettier, stylelint, i18n-tasks missing/unused, french typography and vitest all clean.

## Plan Change Log

## Review Triage Log

### 2026-11-01 — Review pass
- verdicts: 1 findings — high 0, medium 1, low 0, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` `SettingsController#steam_library` decided the first-sync enqueue from `was_on`, read from `current_player` before the operation took its row lock, so overlapping requests got it wrong: two OUI from off both enqueued a creation with its sync (two Steam calls), and an OUI loaded before a concurrent confirmed NON committed turned the sync back on and enqueued nothing, leaving the player with the sync on and no set until their next Steam sign-in — real: `lock!` reloads the record, the operation returns `Success(player)` on both its write and its no-change path, and `Game::LibrarySetsDue` never creates a set. Fixed: the controller now asks the returned player `saved_change_to_steam_library_sync?` and the new value (`turned_on?`), so only a change made under the lock enqueues; `was_on` removed; two operation tests cover the stale-object cases.

## Design Notes

The re-creation goes through the existing `CreateSteamLibrarySetJob` rather than the handler, because `Game::CreateLibrarySet` publishes `LibrarySetCreated` and a handler never publishes; the set shows only after its first sync anyway, so a creation a moment after the request is invisible to the player. The erase, which the player must be able to trust at once, stays in the setting's transaction.

The confirmation is asked every time NON is chosen from OUI, even when the set does not exist yet (created but never synced is invisible to the player, yet the list may be about to be read).

## Verification

**Commands:**
- `bin/rails test test/domains/accounts test/domains/game test/jobs test/controllers/settings_controller_test.rb test/controllers/sessions_controller_test.rb test/controllers/steam_links_controller_test.rb` -- expected: pass
- `bin/rails test test/system/settings_test.rb test/system/steam_library_test.rb` -- expected: pass
- `PARALLEL_WORKERS=3 bin/rails test` -- expected: pass
- `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `bin/rubocop`, `script/check_planning_references`, `script/check_file_sizes`, `npm run format:check`, `npm run lint:css`, `bundle exec i18n-tasks missing`, `bundle exec i18n-tasks unused`, `bin/rails test test/config/french_typography_test.rb` -- expected: clean
- `RAILS_ENV=test SCHEMA=tmp/migrated_schema.rb bin/rails db:drop db:create db:migrate db:schema:dump && cp tmp/migrated_schema.rb db/schema.rb`, then `db:schema:load` and `db:schema:dump` round trip -- expected: no diff beyond the new column

## Auto Run Result

Status: built.

**Change.**
- **The setting:** a new column `accounts_players.steam_library_sync`, true by default, is set by `Accounts::SetSteamLibrarySync`.
  - The operation refuses a banned or unsaved player, a value other than true or false, and a player without a Steam identity.
  - It locks the player row and writes nothing when the value is unchanged. Otherwise it publishes `Accounts::SteamLibrarySyncChanged` (player id and the new value) and saves the value.
- **Turning it off:** the `Game` handler of that event runs `Game::EraseLibrarySet` inside the same transaction. It takes the bank lock and deletes the player's library set; its games go through the cascade. It publishes nothing.
- **Creation skips a player who opted out:** `Game::CreateLibrarySet` re-reads the setting after the bank lock and returns `Failure(:library_sync_off)`. A sign-in creates no set for a player who turned the sync off, and an erase and a creation that race cannot leave a set behind.
- **Turning it back on:** after commit, the controller enqueues `CreateSteamLibrarySetJob(first_sync: true)`, which creates the set and enqueues its first `SyncSteamLibraryJob`. It does so only when the operation itself turned the setting on, under its lock.
- **Settings screen:** a player with a Steam identity sees SYNCHRONISER MES JEUX STEAM, after ANIMATIONS RÉDUITES.
  - The row carries the line "Gameble lit les jeux de votre compte Steam une fois par jour pour votre set MA LUDOTHÈQUE STEAM." and the choices OUI / NON.
  - When the sync is on, NON opens the confirmation dialog: "Désactiver la synchronisation ?", "Le set MA LUDOTHÈQUE STEAM et la liste de vos jeux Steam seront effacés.", DÉSACTIVER / ANNULER.
  - Without JavaScript, an unconfirmed NON writes nothing and comes back with the dialog open.

**Files.**
- `db/migrate/20261102120000_add_steam_library_sync_to_accounts_players.rb`, `db/schema.rb`: the column, with the schema regenerated from the migrations.
- `app/domains/accounts/app/{events/accounts/steam_library_sync_changed,operations/accounts/set_steam_library_sync,queries/accounts/steam_library_sync_on}.rb`: the event, the operation and the fresh read of the setting.
- `app/domains/game/app/operations/game/erase_library_set.rb`, `app/domains/game/app/handlers/game/handlers/steam_library_sync_changed.rb`, `config/initializers/event_store.rb`: the erase and its subscription.
- `app/domains/game/app/operations/game/create_library_set.rb`: the opt-out check. `app/jobs/create_steam_library_set_job.rb`: the `first_sync:` keyword.
- `app/controllers/settings_controller.rb`, `app/policies/settings_policy.rb`, `config/routes.rb`: `PATCH /:locale/settings/steam-library`.
- `app/views/settings/show.html.erb`, `app/views/settings/_library_sync_dialog.html.erb`, `app/frontend/styles/settings.css`: the row and the dialog.
- `config/locales/{en,fr}.yml`: the copy and `errors.accounts.steam_identity_required`.
- Tests:
  - new: `test/domains/accounts/set_steam_library_sync_test.rb`, `test/domains/game/erase_library_set_test.rb`;
  - extended: `test/domains/game/library_set_operations_test.rb`, `test/jobs/create_steam_library_set_job_test.rb`, `test/controllers/settings_controller_test.rb`, `test/system/steam_library_test.rb`;
  - row counts updated: `test/system/settings_test.rb`.

**Review.** One quick pass found 1 entry, which was patched (medium): the first-sync enqueue was decided from the setting as read before the operation's lock (see the Review Triage Log). Nothing was deferred or rejected.

Follow-up review recommended: false. This pass patched 1 entry: high 0, medium 1, low 0. No high was patched, and fewer than two mediums.

**Verification** (after the patch):
- `PARALLEL_WORKERS=3 bin/rails test`: 4003 runs, 0 failures.
- `bin/rails test test/system/settings_test.rb test/system/steam_library_test.rb`: 17 runs, 0 failures.
- `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `bin/rubocop`, `script/check_planning_references`, `script/check_file_sizes`, `npm run format:check`, `npm run lint:css`, `npm run test:js` (795) and `bundle exec i18n-tasks missing` / `unused`: all clean.
- `db/schema.rb` matches a dump of the migrated test database, and the `db:schema:load` then `db:schema:dump` round trip leaves it unchanged.
- Matrix audit: every row has a passing test:
  - the operation, erase and creation tests cover the off, on, unchanged, sync-off sign-in, no-Steam and invalid rows;
  - the job test covers `first_sync`;
  - the controller test covers the unconfirmed NON, confirmed NON, OUI, unchanged value, visitor and banned rows;
  - the system test covers the browser round trip;
  - an erase meeting a running sync is the existing gone-set case of `SyncLibrarySet` (`library_set_operations_test.rb`).

**Copy the UX did not specify.**
- Every English string: "Sync my Steam games", "Gameble reads the games of your Steam account once a day for your MY STEAM LIBRARY set.", "Yes" / "No", "Turn off the sync?", "The MY STEAM LIBRARY set and the list of your Steam games will be erased.", "Turn off", "Cancel", "Close".
- The French dialog close label "Fermer".
- The refusal "Liez d'abord un compte Steam." / "Link a Steam account first.", which shows only to a player without Steam who posts the form by hand.

**Residual risks.**
- The staging walkthrough of the verify clause is the author's.
- The data export does not carry the setting. The export's naming of the library list is entry 8's.
- Each OUI after a NON costs one Steam call outside `STEAM_LIBRARY_DAILY_SYNCS`. A player toggling repeatedly spends one call per toggle, each behind a confirmed erase.
- The row's layout (the label and its line on the left) has no mockup. It was checked on desktop and phone screenshots by the implementer only.
- `i18n-tasks check-normalized` reports the locale files, the pagy ones included, as not normalized. No CI step runs it.
