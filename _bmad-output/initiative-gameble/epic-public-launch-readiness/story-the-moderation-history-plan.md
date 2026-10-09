---
title: 'The moderation history'
type: 'feature'
ticket: '19'
created: '2026-10-09'
status: 'built'
baseline_revision: '82e9a6025bc8cd9fdea4831ae3f66ca8dd08b343'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/AGENTS.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** A ban, an unban or a dismissal leaves no record a page reads: no reason, no "banned by", no history of classed reports; only the event store keeps `PlayerBanned`, `PlayerUnbanned` and `ReportsDismissed` with the staff member's id. The author decided (2026-10-09) that a ban requires a reason the staff member types and that every ban, unban and dismissal is kept and shown in the back-office (R4).

**Approach:** A table `accounts_moderation_actions` (kind, player, staff, reason, time) written by `BanPlayer`, `UnbanPlayer` and `DismissReports` inside their transaction; `BanPlayer` takes a required `reason:`. A data migration copies the three kinds of events already in the event store into the table, with no reason. A back-office page `/<locale>/back-office/history` lists the rows newest first, 50 a page, filtered by player (`?player=<token>`), linked from the dashboard, the queue, the banned list and each row of the players list. Every ban form (the shared `_ban_action` partial) gets a required reason field.

## Boundaries & Constraints

**Always:** the reason is cleaned like a persona name (invisible characters dropped, spaces made plain and squished, stripped; nothing visible left = no reason) and refused when blank (`Failure(:reason_required)`) or longer than 500 characters (`Failure(:reason_too_long)`), checked after the existing permission refusal (a non-staff caller still gets `staff_required`); the history row is written inside the operation's transaction, after the re-check under the lock, so a refused or rolled-back action leaves no row; events stay unchanged and carry ids only (the reason is free text: never in an event); `BanPlayer.refusal` keeps its signature (the views ask it without a reason); the history page is staff only (`BackOffice::BaseController`'s 404, a Pundit policy `index? = moderator?`); players addressed by token, no database id in URLs, HTML or DOM; the reason is user content, escaped; every string in `fr.yml` and `en.yml` (English translated from the French, "vous", "officier"), the dynamic `errors.accounts.reason_required` / `reason_too_long` added by hand to both; strong_migrations; no `style` attribute; no planning ids in code, tests or migrations.

**Never:** a reason for unban or dismissal; the reason in an event or in a toast; showing the Steam id; editing or deleting history rows from a page; changing the rank rule, the refusal codes or where each form redirects; storing the reason on `accounts_players`; replaying events at runtime (the page reads the table only); touching existing entries of `pending-approvals.md`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Ban with reason | moderator bans a player with "  Insultes​ dans le pseudo " | ban as today; one `ban` row: player, staff, reason "Insultes dans le pseudo", time | none |
| Ban without reason | reason missing, `""`, spaces only, or only invisible characters | nothing changes, no event, no row | `Failure(:reason_required)`, alert, redirect as today |
| Overlong reason | 501 characters after cleaning | nothing changes, no event, no row | `Failure(:reason_too_long)` |
| Refused ban | outranked / self / already banned / not staff, with a reason | no row | existing codes, checked before the reason |
| Unban | moderator lifts a ban | one `unban` row, no reason | none |
| Dismissal | moderator classes a player's reports | one `dismissal` row, no reason | `no_open_reports`: no row |
| History | staff opens the history | rows newest first (time, action, player, by, reason), 50 a page, page 2 works | none |
| Filter | `?player=<token>` of a player | only that player's rows; heading names them; a link back to the whole history | none |
| Unknown filter | `?player=` a token matching no one | an empty list saying the player is not found, link to the whole history | none |
| Old ban | a ban made before this story (backfilled) | row shows "Raison non consignée" | none |
| Deleted account | the player or the staff member of a row since deleted | the row stays, the name reads "Compte supprimé", no filter link | none |
| Backfill | event store holds `PlayerBanned`, `PlayerUnbanned`, `ReportsDismissed` | one row per event, kind from its type, `player_id`/`staff_id` from its data, its time, reason NULL; other events ignored | none |
| Not staff | visitor or player on the history | 404 of an unknown address | existing `BaseController` |

</intent-contract>

## Code Map

- `packs/accounts/app/operations/accounts/ban_player.rb` -- `call(staff:, player:)` locks, re-checks `refusal`, publishes `PlayerBanned`, handles open reports, sets `banned_at`. Add `reason:` (required keyword); `step` a reason check after the first `permitted`; inside the transaction create the `ban` row with the cleaned reason. Update the doc comment's failure list.
- `packs/accounts/app/operations/accounts/unban_player.rb`, `dismiss_reports.rb` -- create the `unban` / `dismissal` row in the transaction after `publish` (dismissal: only once `any_handled` passed).
- `packs/accounts/app/models/accounts/persona_name.rb` -- `INVISIBLE`, `SPACE`, `VISIBLE` regexes and the cleaning steps to reuse (not its cut to 64) in a new `packs/accounts/app/models/accounts/ban_reason.rb` (`LENGTH = 500`, `clean(value)` → String or nil).
- `packs/accounts/app/models/accounts/report.rb` -- model pattern (string enum with `validate: true`, `belongs_to ... class_name: "Accounts::Player"`) for the new `packs/accounts/app/models/accounts/moderation_action.rb`.
- `packs/accounts/app/queries/accounts/banned_players.rb` -- query pattern for `packs/accounts/app/queries/accounts/moderation_history.rb` (`call(player = nil)`: relation ordered `created_at: :desc, id: :desc`, `includes(:player, :staff)`, narrowed to the player when given).
- `packs/accounts/app/queries/accounts/player_by_token.rb` -- read the filter's player.
- Event store rows (checked): `event_store_events.event_type` = `'Accounts::PlayerBanned'` etc., `data` jsonb `{"staff_id": 2, "player_id": 1}`, `created_at` = publish time. The data migration reads these with SQL; precedent `db/migrate/20261003040000_move_import_runs_off_the_genres_step.rb` (`safety_assured { execute ... }`, empty `down`) and its test `test/packs/steam/genres_step_migration_test.rb` (requires the migration file, `suppress_messages { X.new.migrate(:up) }`).
- `app/controllers/back_office/bans_controller.rb` -- `create` passes `reason: params[:reason]`; nothing else changes. `reports_controller.rb`, `players_controller.rb` -- patterns (`include Pagy::Method`, `PAGE_SIZE = 50`, `MAX_PAGE`, `authorize [ :back_office, :x ], :index?`) for `app/controllers/back_office/history_controller.rb < BaseController`.
- `app/policies/back_office/players_policy.rb` -- pattern for `history_policy.rb`.
- `config/routes.rb:117-125` -- add `get "history" => "history#index", as: :history` in the back-office scope (→ `back_office_history_path`).
- `app/views/back_office/bans/_ban_action.html.erb` -- today a `ButtonComponent` form button (POST `back_office_bans_path`, `params: { token:, **back }`, `confirm:`). Replace by a `form_with url: back_office_bans_path, method: :post, class: "ban-form", data: { turbo_confirm: ... }` holding hidden `token` and `back` params, a visually hidden label, a text field `reason` (`required`, `maxlength: Accounts::BanReason::LENGTH`, `autocomplete: "off"`, placeholder, an `id` built from the token) and `ButtonComponent.new(variant: :danger, size: :small, type: :submit)` "BANNIR". Keep `data-ban-refusal` and the refusal branch; keep `form[action='/fr/back-office/bans'][method=post][data-turbo-confirm]` and `button.button--danger` "BANNIR" true (existing tests assert them).
- `app/views/back_office/{reports,bans,players}/index.html.erb`, `dashboard/show.html.erb` -- footer link "L'historique" on the three lists; a per-row link to the player's history in the players list (new last column, visually hidden head); a dashboard link by policy after "Les bannis".
- `app/views/back_office/import_runs/_time.html.erb` -- time cell. `app/helpers/public_profiles_helper.rb#public_profile_title` -- names; a deleted account shows `back_office.history.index.deleted_account` instead (a small helper, e.g. `app/helpers/back_office_helper.rb#moderation_name(player)`).
- `app/frontend/entrypoints/application.css:82-105` -- `.ledger-search` field styles; add `.ban-form` (field and button on one row, wrapping on a narrow screen, tokens only).
- `config/locales/{fr,en}.yml` -- `back_office.history.index.*`, `back_office.bans.actions.reason_label|reason_placeholder`, dashboard and list link keys, `errors.accounts.reason_required|reason_too_long`.
- `README.md:83-101` "Staff accounts and moderation" -- the reason and the history.
- Tests to update for `reason:`: `test/packs/accounts/{ban_player,unban_player,ban_player_concurrency,moderation_rank_concurrency}_test.rb`, `test/controllers/back_office/{bans,players,reports,hidden}_controller_test.rb`/`hidden_test.rb` (staff POSTs to bans need a `reason`), `test/system/moderation_test.rb` (fill the reason before BANNIR). Fixtures `accounts_players(:player, :moderator, :administrator, :banned)`; `test/support/hidden_back_office.rb` (`assert_unknown_address`); `hidden_test.rb` enumerates every back-office route, so the new one is covered.

## Tasks & Acceptance

**Execution:**
- [x] `db/migrate/20261009130000_create_accounts_moderation_actions.rb` -- `create_table :accounts_moderation_actions`: `kind` string not null, `player` and `staff` references (not null, FK to `accounts_players`), `reason` text nullable, `created_at` not null (no `updated_at`: rows are never changed); checks inside `create_table` (`kind IN ('ban','unban','dismissal')`, `reason IS NULL OR kind = 'ban'`, `reason IS NULL OR char_length(reason) <= 500`); indexes `created_at`, `[player_id, created_at]`, `staff_id` -- the history's table (new table: checks and indexes in place are safe)
- [x] `db/migrate/20261009130001_copy_moderation_events_to_accounts_moderation_actions.rb` -- `up`: one `INSERT ... SELECT` from `event_store_events` of the three types, kind by `CASE event_type`, ids cast from `data`, `created_at` from the event, reason NULL, only when both players exist; `down` empty -- old actions appear
- [x] `db/schema.rb` -- regenerated, never edited
- [x] `packs/accounts/app/models/accounts/{ban_reason,moderation_action}.rb`, `packs/accounts/app/queries/accounts/moderation_history.rb` -- the cleaning, the model, the query
- [x] `packs/accounts/app/operations/accounts/{ban_player,unban_player,dismiss_reports}.rb` -- the reason and the rows
- [x] `config/routes.rb`, `app/policies/back_office/history_policy.rb`, `app/controllers/back_office/history_controller.rb`, `app/views/back_office/history/index.html.erb`, a name helper -- the page (heading "L'historique de modération", or "L'historique de <name>" when filtered; intro; ledger: Date, Action, Joueur, Par, Raison; player name links to `?player=<token>` unless deleted; empty / filtered-empty / unknown-player panels; Pagy nav; links back to the whole history and to the dashboard lists); rows carry `data-moderation-kind` for tests, no ids
- [x] `app/controllers/back_office/bans_controller.rb`, `app/views/back_office/bans/_ban_action.html.erb`, `app/frontend/entrypoints/application.css` -- the reason field
- [x] `app/views/back_office/{reports,bans,players}/index.html.erb`, `app/views/back_office/dashboard/show.html.erb` -- the links
- [x] `config/locales/{fr,en}.yml`, `README.md` -- copy, runbook: a ban requires a reason, kept with who acted and when in the history at `/<locale>/back-office/history`, filtered by player from the players list; bans made before have no reason
- [x] Tests: `test/packs/accounts/ban_player_test.rb` (reason required: missing, blank, invisible-only; too long; cleaned reason stored; refusal codes before the reason; the row's player, staff, time; no row on refusal), `unban_player_test.rb` and `dismiss_reports_test.rb` (row written; none on refusal or `no_open_reports`), `test/packs/accounts/moderation_history_test.rb` (order, filter, includes deleted), `test/packs/accounts/moderation_history_migration_test.rb` (events of the three types and one unrelated become rows with the event's time and no reason), `test/policies/back_office/history_policy_test.rb`, `test/controllers/back_office/history_controller_test.rb` (rows and columns, reason escaped, old ban "Raison non consignée", deleted names, filter, unknown filter, page 2, English, no database id, visitor and player 404), `bans_controller_test.rb` (a ban without a reason is refused with the alert; the form has the required reason field on the queue, banned list and players list), dashboard test (link), existing tests given a reason; `test/system/moderation_test.rb` -- a moderator types a reason and bans, lifts the ban, classes another player's reports, opens the history from the dashboard and sees the three lines with the moderator's name, the times and the reason; filters by the player from the players list

**Acceptance Criteria:**
- Given a moderator in the queue, when they click BANNIR with an empty reason, then the browser does not send it, and a request sent without one is refused with "Indiquez la raison du bannissement, officier." and the player stays unbanned.
- Given a moderator who banned a player with a reason, lifted the ban and classed another player's reports, when they open "L'historique" from the dashboard, then three lines show newest first with the moderator's name, the times, and the ban's reason.
- Given the players list, when a moderator follows a row's history link, then only that player's lines show.
- Given a visitor or a non-staff player, when they request `/fr/back-office/history`, then the response is the 404 of an unknown address.
- Given the suite, when the verification commands run, then all pass.

## Implementation Notes

- `BanPlayer#call` checks the reason (`cleaned`) right after the first permission check and before the transaction; the `ban` row is written with the same `now` as `banned_at`. The `unban` row is written after `banned_at` is cleared; the `dismissal` row only once `any_handled` passed.
- `Accounts::BanReason.clean` reuses `PersonaName::INVISIBLE`, `SPACE` and `VISIBLE` without the 64-character cut; a non-String reason (an array from `reason[]=`) reads as no reason.
- The history treats a token of a deleted account like an unknown one (the "not found" panel): a deleted account's token is rotated, so no link leads there.
- The banned list offers only LEVER LE BAN, so it has no ban form; it links to the history at its foot, as the queue and the players list do.
- The two concurrency tests' teardowns delete history rows before the players they commit, as the new foreign keys require.
- The first schema dump wrote the `kind` check in another form; a clean `db:drop db:create db:migrate` gave the form now committed, stable across rebuilds.
- `bin/ci`'s setup rewrote `package-lock.json`'s name to the worktree's; reverted.

## Plan Change Log

## Review Triage Log

### 2026-10-09 — Review pass
- verdicts: 5 findings — high 0, medium 0, low 5, false 0, maybe-false 0
- findings:
  - `[low]` `[reject]` (quick) Actions made by the old code between the data migration and the new container taking over get no history row, as the copy runs once at boot — real, but needs a ban, unban or dismissal in the seconds of a deploy's switch-over, before the public launch and with a handful of staff; closing it means an `event_id` column, a unique index and a re-runnable copy. Recorded in `pending-approvals.md` for the author.
  - `[low]` `[patch]` (quick) The new files and the operations' grown doc comments explain the code in comments, against AGENTS.md — deleted; one line kept above the data migration's `up` (why `safety_assured` is safe) and one in `ban_player.rb` (the reason is free text, so no event carries it).
  - `[low]` `[patch]` (quick) French text outside `fr.yml`: the `BanReason` comment example, the CSS comment naming BANNIR and French reasons used as test data — comments deleted; the typed reasons in the tests are English ("Insults in the name"); assertions on the French copy unchanged.
  - `[low]` `[patch]` (quick) The history system test checked a time on the first row only — each of the three rows now asserts its `time`.
  - `[low]` `[reject]` (quick) The field's `maxlength` counts UTF-16 units before cleaning, the server characters after — the browser is stricter only for a reason near 500 characters made of emoji or padded with invisible characters; the server rule stays the one enforced, and dropping `maxlength` would lose the limit for every staff member.

## Design Notes

A table written by the operations, not the event store read at render: AD-10 keeps events to ids ("personal data frozen in a log"), and a typed reason is free text that may name people, so it cannot go in an event; the event store has no index on the player in `data` and grows with every pack opened; and state tables are the truth there. The table is the history's truth from now on; the data migration copies, once, what the events already hold so bans, unbans and dismissals made since the back-office actions existed appear, reason "Raison non consignée". Bans set by hand in the console before that published nothing and do not appear.

Rows outlive a deleted account (they name it, as reports do): the name reads "Compte supprimé". No `updated_at`: a history row is never changed.

## Verification

Environment for every command: `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w7_15`, `CHROME_BIN=/usr/bin/chromium`.

**Commands:**
- `RAILS_ENV=test bin/rails db:drop db:create db:migrate` -- expected: no strong_migrations error; `db/schema.rb` diff is the new table only
- `bin/ci` -- expected: green (stage `db/schema.rb` first)
- `npm run test:js`, `bin/rails zeitwerk:check`, `bundle exec packwerk check` -- expected: clean
- `bin/rails test test/system/moderation_test.rb test/system/public_profile_test.rb test/system/import_run_test.rb test/system/shell_test.rb` -- expected: green

## Auto Run Result

Status: built.

**Summary:** a ban now requires a reason, typed in a field beside BANNIR on every ban form (the shared `_ban_action` partial: the queue and the players list), cleaned like a persona name, required by the browser and refused by `Accounts::BanPlayer` when blank (`reason_required`) or over 500 characters (`reason_too_long`), after the existing refusals. `BanPlayer`, `UnbanPlayer` and `DismissReports` write each action to the new `accounts_moderation_actions` table (kind, player, staff, the ban's reason, time) inside their transaction, after the re-check under the lock; events are unchanged. A data migration copied the bans, unbans and dismissals the event store already held, without a reason ("Raison non consignée"). Staff read the history at `/<locale>/back-office/history`, newest first, 50 a page, filtered by player (`?player=<token>`, from each row of the players list or a name in the history), linked from the dashboard, the queue, the banned list and the players list; a deleted account reads "Compte supprimé"; anyone not staff gets the back-office's 404.

**Files changed:**
- `db/migrate/20261009130000_create_accounts_moderation_actions.rb`, `db/migrate/20261009130001_copy_moderation_events_to_accounts_moderation_actions.rb`, `db/schema.rb` -- the table with its checks and indexes; the one-time copy of the events.
- `packs/accounts/app/models/accounts/{ban_reason,moderation_action}.rb`, `packs/accounts/app/queries/accounts/moderation_history.rb` -- the reason's cleaning, the model, the query.
- `packs/accounts/app/operations/accounts/{ban_player,unban_player,dismiss_reports}.rb` -- the required reason and the history rows.
- `config/routes.rb`, `app/policies/back_office/history_policy.rb`, `app/controllers/back_office/history_controller.rb`, `app/views/back_office/history/index.html.erb`, `app/helpers/back_office_helper.rb` -- the history page.
- `app/controllers/back_office/bans_controller.rb`, `app/views/back_office/bans/_ban_action.html.erb`, `app/frontend/entrypoints/application.css` -- the reason field.
- `app/views/back_office/{reports,bans,players}/index.html.erb`, `app/views/back_office/dashboard/show.html.erb` -- the links.
- `config/locales/{fr,en}.yml`, `README.md` -- copy, error messages, runbook.
- Tests: operations (reason rules, rows, no row on refusal or rollback), `moderation_history_test.rb`, `moderation_history_migration_test.rb`, `history_policy_test.rb`, `history_controller_test.rb`, bans, players, reports, dashboard and hidden controller tests, the concurrency tests' teardown, `test/system/moderation_test.rb` (an empty reason is blocked, ban with a reason, dismissal, unban, the three lines in the history, the player filter from the players list).
- `_bmad-output/initiative-gameble/deferred-work.md`, `pending-approvals.md` -- story 7.5's "no record" entry resolved; the history's choices to confirm.

**Review findings:** quick review, 5 findings, all low. Patched 3 (comments against AGENTS.md, French text outside `fr.yml`, times checked on one history row only). Deferred: none. Rejected 2: the deploy switch-over window (recorded in `pending-approvals.md`) and the `maxlength` counting UTF-16 units, each with its reason in the triage log.

**Follow-up review recommended:** false -- patched high 0, medium 0, low 3.

**Verification:** `RAILS_ENV=test bin/rails db:drop db:create db:migrate` on Postgres 18: no strong_migrations error, schema diff the new table only; `bin/ci` (setup, rubocop, packwerk, i18n-tasks missing, typecheck, bundler-audit, brakeman, migration safety, 1881 Rails tests, seeds): green; `npm run test:js` (168): green; `bin/rails zeitwerk:check`: all good; `bundle exec packwerk check`: no offenses; system tests `moderation`, `public_profile`, `import_run`, `shell`: 25 runs, 0 failures.

**Residual risks:** an action made by the old code during a deploy's switch-over, after the copy ran, has no history row (its event remains); a ban set by hand in the console never appears; the history keeps the reason after the banned player deletes their account, and the data export does not include it.
