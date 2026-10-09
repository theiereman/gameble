---
title: 'A searchable list of players in the back-office'
type: 'feature'
ticket: '14'
created: '2026-10-09'
status: 'built'
baseline_revision: '398610cd8ae1d2b9c247ac193b441ddf160124a8'
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

**Problem:** Staff reach a player only through a report (the queue) or a past ban (the banned list); the author wants staff to find any player easily and ban without waiting for a report (decision of 2026-10-09, R4).

**Approach:** A back-office page `/<locale>/back-office/players`, paged, with a search by part of the username or by Steam id; each row shows the name (linking to the profile), role, visibility and ban state, and the ban or unban button or the refusal text the rank rule gives, rendered by the same partials as the queue and the banned list and posting to the existing `BansController` actions, which send the staff member back to the list they came from.

## Boundaries & Constraints

**Always:** reuse `Accounts::BanPlayer` / `Accounts::UnbanPlayer` and their class `refusal` (`outranked`, `cannot_ban_self`…) unchanged; one partial each for the ban cell and the unban cell, used by the queue, the banned list and the new list; deleted players never listed; players addressed by token only, no database id in HTML or URLs; the search is a plain GET form (works without JavaScript), the query escaped for `LIKE` (`sanitize_sql_like`) and capped in length; a Pundit policy for the new action (`moderator?`); the new route sits under the `back-office` scope, so `BackOffice::BaseController`'s 404 covers it; every string in `fr.yml` and `en.yml` (English translated from the French, "vous"); no `style` attribute; no planning ids in code or tests.

**Never:** a new ban or unban action or operation; changing the rank rule or the refusal codes; showing the Steam id or any other personal data beyond what the queue shows (name, plus role, visibility, ban state); a migration or a search index; JavaScript search-as-you-type; changing where the queue's and the banned list's buttons send the staff member back.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| List | moderator, no query | every non-deleted player (banned included), newest account first, 50 a page; role, visibility, state; action cell | none |
| Name search | `q` = part of a persona name, any case, surrounding spaces | players whose persona name contains it | none |
| Steam id search | `q` = a full 17-digit Steam id | that player (exact match), plus any name containing those digits | none |
| Wildcards | `q` = `%` or `_` | matched literally, not "everything" | none |
| No match | `q` matching no one | "no player matches" panel naming the query | none |
| Overlong query | `q` longer than the cap | searched on its first `MAX_QUERY` characters | none |
| Ban from list | moderator bans a player from a searched list | ban succeeds, redirect to the list with the same `q` and page; the row shows banned and LEVER LE BAN | none |
| Unban from list | moderator lifts a banned player's ban from the list | redirect back to the list with `q`; row shows in good standing and BANNIR | none |
| Refused | moderator on an administrator's or a moderator's row, or their own | refusal text instead of the button (`outranked`, `cannot_ban_self`) | operation refuses too (`Failure`), alert, redirect to the list |
| Administrator | administrator on a moderator's row | BANNIR offered | none |
| Deleted | deleted account | not listed, even searched by name or old steam id | none |
| Not staff | visitor or player on the list | 404 of an unknown address | existing `BaseController` |
| Queue / banned list | ban from the queue, unban from the banned list | redirect as today (queue, banned list) | none |

</intent-contract>

## Code Map

- `config/routes.rb:117-124` -- back-office moderation routes; add `resources :players, only: :index` in the same `scope "back-office"`.
- `app/controllers/back_office/reports_controller.rb`, `bans_controller.rb` -- pattern for the new `PlayersController < BaseController` (`include Pagy::Method`, `PAGE_SIZE = 50`, `MAX_PAGE`, `pagy(:offset, relation, limit:, page: params[:page].to_s.to_i.clamp(1, MAX_PAGE))`, `authorize [ :back_office, :players ], :index?`). In `BansController#create`/`#destroy`, replace the fixed `back_office_reports_path` / `back_office_bans_path` redirects (success and failure) by a private helper that returns `back_office_players_path(q:, page:)` when `params[:return_to] == "players"`, else the current path; nothing else changes there.
- `app/views/back_office/reports/index.html.erb` (ban cell: `Accounts::BanPlayer.refusal` → `<span data-ban-refusal>` or danger `ButtonComponent` POST `back_office_bans_path` with `params: { token: }` and `confirm: t(".ban_confirm", name:)`) and `app/views/back_office/bans/index.html.erb` (unban cell: `Accounts::UnbanPlayer.refusal` → `<span data-unban-refusal>` or secondary DELETE `back_office_ban_path(token:)`, `confirm: t(".unban_confirm", name:)`) -- move each cell's content into `app/views/back_office/bans/_ban_action.html.erb` and `_unban_action.html.erb` (locals `player`, `name`, `back:` extra params, default `{}`), the confirm copy moved to shared keys (`back_office.bans.actions.*`) so all three pages read one text; keep the data attributes and button labels identical (existing tests assert them).
- `packs/accounts/app/queries/accounts/banned_players.rb` -- query style; add `packs/accounts/app/queries/accounts/player_search.rb` (`Accounts::PlayerSearch.call(query)`: `Player.where(deleted_at: nil)`, when the stripped, capped query is present `persona_name ILIKE '%q%' OR steam_id = q` via `Player.sanitize_sql_like`, ordered `created_at: :desc, id: :desc`; `MAX_QUERY`). `packs/catalog/app/queries/catalog/collection_grid.rb:94` is the ILIKE precedent.
- `packs/accounts/app/models/accounts/player.rb` -- `role`, `visibility` (prefix `visibility_`), `banned?`, `banned_at`, `deleted_at`; read only.
- `app/helpers/public_profiles_helper.rb#public_profile_title` -- the row name; `brother_path(token:)` the profile link; `back_office/import_runs/_time` the time partial.
- `config/locales/{fr,en}.yml` -- `back_office.players.index.*` (heading, intro, search label/placeholder/submit, empty, no match, caption, column heads, role names, state words), `back_office.dashboard.show.players`; visibility names reuse `settings.show.visibility.{public,friends_only,private}`.
- `app/policies/back_office/bans_policy.rb` -- pattern for `players_policy.rb` (`index? = moderator?`).
- `app/views/back_office/dashboard/show.html.erb` -- add the "Les joueurs" link by policy, first among the moderation links.
- `app/frontend/entrypoints/application.css` -- back-office ledger styles; add a small `.ledger-search` (field and button on one row, tokens only).
- `README.md:94` -- mention the player list in "Staff accounts and moderation".
- Tests: `test/controllers/back_office/bans_controller_test.rb` and `reports_controller_test.rb` (assertions on the cells must still pass), `test/policies/back_office/bans_policy_test.rb` (pattern), `test/packs/accounts/report_queue_test.rb` (query test pattern), `test/system/moderation_test.rb` (system pattern: `steam_identity`, `click_steam_sign_in`, `accept_confirm`), `test/support/hidden_back_office.rb` (`assert_unknown_address`); `test/controllers/back_office/hidden_test.rb` enumerates every back-office route, so the new one is covered without edits.

## Tasks & Acceptance

**Execution:**
- [x] `packs/accounts/app/queries/accounts/player_search.rb` -- the search relation -- one place for the list's rule
- [x] `config/routes.rb`, `app/policies/back_office/players_policy.rb`, `app/controllers/back_office/players_controller.rb` -- the page, staff only
- [x] `app/views/back_office/bans/_ban_action.html.erb`, `_unban_action.html.erb`, `app/views/back_office/reports/index.html.erb`, `app/views/back_office/bans/index.html.erb` -- shared action cells
- [x] `app/controllers/back_office/bans_controller.rb` -- return to the players list when the button came from it
- [x] `app/views/back_office/players/index.html.erb`, `app/views/back_office/dashboard/show.html.erb`, `app/frontend/entrypoints/application.css`, `config/locales/{fr,en}.yml`, `README.md` -- the page, the dashboard link, copy, runbook
- [x] Tests: `test/packs/accounts/player_search_test.rb` (name part any case and trimmed, exact steam id, partial steam id not matched unless in a name, `%`/`_` literal, deleted excluded, banned included, order, cap); `test/policies/back_office/players_policy_test.rb`; `test/controllers/back_office/players_controller_test.rb` (list and columns, search by name and steam id, no match, deleted absent, moderator's row refusals for administrator/moderator/self, administrator sees BANNIR on a moderator, banned row shows LEVER LE BAN, ban and unban from the list redirect to it with `q`, refusal from the list returns to it with the alert, page 2, English, no database id, player and visitor 404); `bans_controller_test.rb` keeps its redirects; `test/system/moderation_test.rb` -- a moderator searches part of a name, bans from the list, sees the row banned with LEVER LE BAN; finds a player by Steam id; an administrator's row offers no ban

**Acceptance Criteria:**
- Given a moderator on "Les joueurs", when they search part of a player's name and click BANNIR (confirming), then they are back on the list with the same search, the row reads banned and offers LEVER LE BAN.
- Given a moderator, when they search a player's Steam id, then that player's row is listed.
- Given a moderator, when the list shows an administrator, then the row offers no BANNIR and shows the rank refusal.
- Given a deleted account, when anyone searches its old name, then it is not listed.
- Given the suite, when the verification commands run, then all pass.

## Implementation Notes

- `Accounts::PlayerSearch.normalize` is the one cleaning of the query, used by the list and by `BansController#return_path`; after review it is `Accounts::PersonaName.clean(query) || ""`, the cleaning stored names get at sign-in, so `MAX_QUERY` is `PersonaName::LENGTH` (64).
- The ban and unban labels and confirm texts moved to `back_office.bans.actions.*`, read by the two shared partials; the old `reports.index.ban_confirm` and `bans.index.unban_confirm` keys are gone, the visually hidden column heads keep their own keys.
- Not in the plan: a "Les signalements" link at the foot of the list, as the banned list has, and `data-player-search-empty` on the no-match panel for tests.
- `bin/setup` rewrote `package-lock.json`'s name to the worktree's; reverted.

## Plan Change Log

## Review Triage Log

### 2026-10-09 — Review pass
- verdicts: 3 findings — high 0, medium 0, low 3, false 0, maybe-false 0
- findings:
  - `[low]` `[patch]` (quick) A query holding a NUL byte (`?q=%00`) reached Postgres and raised `ArgumentError: string contains null byte`, a 500 on the list (staff only) — `normalize` now cleans the query with `Accounts::PersonaName.clean`, which drops control characters; query and controller tests send a NUL.
  - `[low]` `[patch]` (quick) The query was only stripped while stored names are cleaned at sign-in, so a no-break space or a double space missed an exact name — same fix as above (spaces made plain and squished); a test finds "Gabe the Rude" from both.
  - `[low]` `[patch]` (quick) The three-line comment above `BansController#return_path` restated the code, against AGENTS.md's comment rule — deleted.

## Design Notes

Returning from a ban to the page it was made on: the list's buttons carry `return_to=players` plus `q` and `page`; `BansController` maps only that one value to `back_office_players_path`, so no arbitrary URL is ever redirected to and the queue and banned list keep their redirects. The Referer header was rejected: a browser or extension may drop it, and the redirect would then silently land on the queue.

Order: newest account first (`created_at desc`), a stable order needing no extra column; the search narrows it. The Steam id matches exactly, the name by substring: a Steam id is a key, a name is a label.

## Verification

Environment for every command: `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w7_14`, `CHROME_BIN=/usr/bin/chromium`.

**Commands:**
- `bin/ci` -- expected: green
- `npm run test:js`, `bin/rails zeitwerk:check`, `bundle exec packwerk check` -- expected: clean
- `bin/rails test test/system/moderation_test.rb test/system/public_profile_test.rb test/system/import_run_test.rb test/system/shell_test.rb` -- expected: green

## Auto Run Result

Status: built.

**Summary:** staff open "Les joueurs" (`/<locale>/back-office/players`), every player whose account is not deleted, banned ones included, the newest account first, 50 a page, searched by part of the name (any case, the query cleaned as stored names are, LIKE wildcards literal) or by the full Steam id. Each row shows the name linking to the profile, the role, the visibility and the standing, and the ban or unban button or the rank refusal, from two partials now shared with the queue and the banned list. The buttons post to the existing `BansController` actions and operations; `return_to=players` (the only value followed) sends the staff member back to the list with its search and page, while the queue and banned list keep their redirects. The dashboard links the list first.

**Files changed:**
- `packs/accounts/app/queries/accounts/player_search.rb` (new) -- the list's relation and the query cleaning.
- `config/routes.rb`, `app/policies/back_office/players_policy.rb`, `app/controllers/back_office/players_controller.rb` (new) -- the page, moderators and administrators, behind the back-office's 404.
- `app/views/back_office/bans/_ban_action.html.erb`, `_unban_action.html.erb` (new), `app/views/back_office/{reports,bans}/index.html.erb` -- the shared action cells.
- `app/controllers/back_office/bans_controller.rb` -- `return_path`.
- `app/views/back_office/players/index.html.erb` (new), `app/views/back_office/dashboard/show.html.erb`, `app/frontend/entrypoints/application.css`, `config/locales/{fr,en}.yml`, `README.md` -- the page, the link, the search field style, copy, runbook.
- Tests: `test/packs/accounts/player_search_test.rb`, `test/policies/back_office/players_policy_test.rb`, `test/controllers/back_office/players_controller_test.rb` (new), `test/system/moderation_test.rb` (a moderator finds a player by part of the name, bans from the list and sees the row banned with LEVER LE BAN, finds a player by Steam id, an administrator's row offers no ban).
- `_bmad-output/initiative-gameble/pending-approvals.md`, `deferred-work.md` -- the list's choices to confirm; the search index for later.

**Review findings:** quick review, 3 findings, all low, all patched (NUL byte 500, query not cleaned like stored names, a comment restating the code). Deferred: none in this plan (a `deferred-work.md` entry records the search's missing trigram index, by the plan's no-migration rule). Rejected: none.

**Follow-up review recommended:** false -- patched high 0, medium 0, low 3.

**Verification:** `bin/ci` (rubocop, packwerk, i18n-tasks, typecheck, bundler-audit, brakeman, migrations, 1829 Rails tests, seeds): green; `npm run test:js` (168): green; `bin/rails zeitwerk:check`: all good; `bundle exec packwerk check`: no offenses; system tests `moderation`, `public_profile`, `import_run`, `shell`: 24 runs, 0 failures. No migration.

**Residual risks:** the name search scans the players table (no index); a player with no Steam name shows as "Joueur <code>" and is found only by Steam id; the query is cut at 64 characters.
