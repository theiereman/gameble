---
title: 'Roles, policies and ban check'
type: 'feature'
ticket: '7'
created: '2026-10-02'
status: 'built'
baseline_revision: '92feaecc2c6496dabbcd0e2a13ef837f62aafe41'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md'
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** Any request can reach any action, a player has no role, and nothing can take access away. AD-14 and CAP-18 require a Pundit policy on every controller action, four roles (visitor, player, moderator, administrator), a ban check on every request, and that a signed-out visitor can look but not act; AD-14 also requires every `Game` operation to take a player.

**Approach:** Add Pundit with an `ApplicationPolicy` that denies by default and a check that fails any action that skipped authorization. Give players a role and a ban timestamp. On each request, a banned player's session is reset and the request continues as a visitor. A refused action sends a visitor to sign in and answers a signed-in player with 403. Add a `Game` base operation that refuses to define an operation without a `player:` input and fails without a valid player.

## Boundaries & Constraints

**Always:**
- Gem from the Stack table: `pundit ~> 2.5.2`.
- Roles live on `accounts_players.role` (not null, default `player`; values `player`, `moderator`, `administrator`); a visitor is the absence of a player. The ban is `accounts_players.banned_at` (nullable). Migrations pass strong_migrations and the schema drift check.
- `ApplicationController` runs `verify_authorized` after every action (no `verify_policy_scoped` until scopes exist). Every existing action (`PagesController#home`, `LocalesController#redirect`, `SessionsController#create`, `#failure`, `#destroy`) gets an explicit policy decision; reading pages and starting or finishing a sign-in are allowed to everyone, signing out requires a player.
- `ApplicationPolicy` exposes `visitor?`, `player?`, `moderator?` (moderator or administrator) and `administrator?`, and every predicate defaults to false.
- `Pundit::NotAuthorizedError`: a visitor is redirected to the current locale's home with a translated "sign in to act" alert (HTML) or gets 401; a signed-in player gets 403 with a translated message. JSON requests use the convention `{ "error": { "code": "…", "message": "…" } }`.
- Ban check: `current_player` is reloaded each request (already); when the player is banned, the session is reset and `current_player` is nil for the rest of the request. `Accounts::SignIn` fails with `:banned` for a banned player (key `errors.accounts.banned` in both locales).
- `Game::Operation` (in `packs/game`) inherits `ApplicationOperation`; a subclass whose `call` has no required `player:` keyword raises at class definition; a step helper fails with `Failure(:player_required)` for a nil, unsaved or banned player. Keys under `errors.game.*`.
- Policy tests cover the signed-out visitor for every policy (AD-22).

**Never:**
- No moderation screens, ban operation or report flow (epic 7); tests set `banned_at` directly.
- No back-office pages (story 1.8). No role assignment UI.
- No real `Game` operation.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Visitor reads | signed out, `GET /fr` | 200 | No error expected |
| Visitor acts | signed out, `DELETE /session` | not performed; redirect to `/<locale>` home with the sign-in alert | Pundit refusal |
| Visitor acts, JSON | signed out, `DELETE /session` with `Accept: application/json` | 401 with the JSON error shape | Pundit refusal |
| Player acts | signed in, `DELETE /session` | signed out | No error expected |
| Banned at next request | signed in, then `banned_at` set, then `GET /fr` | session reset; page renders signed out | No error expected |
| Banned sign-in | callback for a banned player's Steam id | no session; failure alert `errors.accounts.banned` | Operation Failure |
| Unauthorized action shipped | a controller action that never calls `authorize` | raises `Pundit::AuthorizationNotPerformedError` in tests | Fails the test suite |
| Game operation without player | subclass of `Game::Operation` whose `call` lacks `player:` | `ArgumentError` when the class is defined | Load-time error |
| Game operation, no valid player | `require_player` with nil, unsaved or banned player | `Failure(:player_required)` | Operation Failure |

</intent-contract>

## Code Map

- `app/controllers/application_controller.rb` -- `allow_browser`, `switch_locale` (validated `params[:locale]`, overridable `requested_locale`), `current_player` memoized from `Accounts::PlayerById.call(session[:player_id])`, `helper_method :current_player`, `default_url_options` with locale.
- `app/controllers/sessions_controller.rb` -- `create` (marker check, `Steam::SignInIdentity`, `Accounts::SignIn`, `reset_session`, `session[:player_id]`), `failure`, `destroy`; private `fail_sign_in(key)`, `return_path`, `origin_path`. Failures keep the session.
- `app/controllers/pages_controller.rb`, `app/controllers/locales_controller.rb` -- `home`, `redirect`.
- `packs/accounts/app/models/accounts/player.rb` -- `has_secure_token :token`, Steam id format validation.
- `packs/accounts/app/operations/accounts/sign_in.rb` -- validates the id, finds or creates in `transaction`, publishes `PlayerRegistered` on creation.
- `packs/accounts/app/queries/accounts/player_by_id.rb` -- nil for a blank id or no match.
- `lib/application_operation.rb` -- `transaction`, `publish`, `failure_key` (`errors.<first namespace segment>.<code>`); nested operations through `step`.
- `packs/game/package.yml` -- depends on `packs/accounts`, `packs/catalog`, `lib`; `packs/game/app/models/.keep` only.
- `db/migrate/20261002154023_create_accounts_players.rb`, `db/schema.rb` -- current players table.
- `test/test_helper.rb` -- `fixtures :all` from `test/fixtures`; there are no player fixtures yet. `test/controllers/sessions_controller_test.rb` drives sign-in with OmniAuth test mode (look at its helpers for signing in).
- `config/locales/{en,fr}.yml` -- `errors.accounts.*`, `errors.steam.*`, `sessions.*`; i18n-tasks checks both; missing keys raise in tests.

## Tasks & Acceptance

**Execution:**
- [x] `Gemfile`, `Gemfile.lock` -- add `pundit` -- AD-14
- [x] `db/migrate/*_add_role_and_banned_at_to_accounts_players.rb`, `db/schema.rb` -- `role` string not null default `player` with a check constraint on the three values; `banned_at` datetime -- roles and bans
- [x] `packs/accounts/app/models/accounts/player.rb` -- role enum (string-backed), `banned?`, `staff?` -- role reads
- [x] `packs/accounts/app/operations/accounts/sign_in.rb` -- `Failure(:banned)` for a banned player -- no session for a ban
- [x] `app/policies/application_policy.rb` -- deny by default; role predicates -- one base
- [x] `app/policies/page_policy.rb`, `app/policies/session_policy.rb` -- headless policies for the existing actions -- every action decided
- [x] `app/controllers/application_controller.rb` -- `include Pundit::Authorization`, `pundit_user` = `current_player`, `after_action :verify_authorized`, ban check in `current_player`, `rescue_from Pundit::NotAuthorizedError` as in Always -- AD-14
- [x] `app/controllers/{pages,locales,sessions}_controller.rb` -- `authorize` each action -- every action has a policy
- [x] `packs/game/app/operations/game/operation.rb` -- base class with the definition-time `player:` check and `require_player` step -- every Game operation takes a player
- [x] `config/locales/{en,fr}.yml` -- refusal messages, `errors.accounts.banned`, `errors.game.player_required` -- AD-18
- [x] `test/fixtures/accounts/players.yml` (table name set for the fixture) -- a player, a moderator, an administrator, a banned player -- shared test data
- [x] `test/policies/*_test.rb` -- each policy for visitor, player, moderator, administrator -- AD-22
- [x] `test/controllers/authorization_test.rb` -- the request rows of the matrix, including an action that skips `authorize` (a test-only controller and route drawn in the test) -- proof
- [x] `test/packs/accounts/sign_in_test.rb`, `test/packs/game/operation_test.rb` -- banned sign-in; Game operation rows -- proof

**Acceptance Criteria:**
- Given a signed-out visitor, when they send a mutating request, then it is refused and nothing changes.
- Given a signed-in player who is banned meanwhile, when they make their next request, then they are signed out.
- Given the suite, when tests, Packwerk, i18n-tasks, RuboCop, zeitwerk, Brakeman and the migration drift check run, then all pass.

## Implementation Notes

- The role check constraint is added `validate: false` and validated in a second migration (strong_migrations). It is written as `role = … OR …` rather than `IN (…)`: PostgreSQL 18 deparsed the `IN` form differently between two databases on the same server, which broke the schema drift check.
- `LocalesController#redirect` and `PagesController#home` both use `authorize :page, :show?`; `SessionPolicy` answers `create?`, `failure?`, `destroy?`.
- `rescue_from` runs outside the `around_action`, so the refusal re-enters the request's locale (`current_locale`) before translating and redirecting.
- A refused visitor gets 401 (JSON shape) or a plain 401 for formats other than HTML and JSON; a refused player gets 403, an HTML page in the layout or the JSON shape.
- Fixture players are loaded in every test, so the existing sign-in tests now count only players they created (`new_players`).
- The authorization test draws its own routes with `with_routing` (which resets the integration session), so it signs in inside that block with the callback route drawn.

## Plan Change Log

## Review Triage Log

### 2026-10-02 — Review pass
- verdicts: 3 findings — high 0, medium 1, low 2, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` The ban check's `reset_session` wiped the sign-in marker, so any sign-in from a browser holding a banned player's session failed with the generic message (another player could not sign in; the banned one never saw `errors.accounts.banned`) — on a ban only `session[:player_id]` is removed; tests cover both sign-ins from a banned session and the session is asserted unchanged on a banned sign-in.
  - `[low]` `[patch]` Redefining a valid `call(player:)` raised a false ArgumentError because the check read dry-operation's prepended wrapper — `method_added` walks `super_method` to the class's own `call`; a test reopens a valid subclass.
  - `[low]` `[reject]` A subclass using `operate_on :perform` bypasses the `player:` check — operations are written with `call` (README, base class); covering other entry points adds a guard for a case nobody writes.

## Verification

**Commands:**
- `bin/rails test` -- expected: all green
- `CHROME_BIN=/usr/bin/chromium bin/rails test:system` -- expected: all green
- `RAILS_ENV=test bin/rails db:drop db:create db:migrate` -- expected: no strong_migrations error; regenerated schema equals the development one
- `bundle exec packwerk validate && bundle exec packwerk check` -- expected: clean
- `bundle exec i18n-tasks missing` -- expected: none
- `bin/rubocop && bin/rails zeitwerk:check && bin/brakeman -q --no-pager` -- expected: clean

## Auto Run Result

**Summary:** Pundit guards every action (`verify_authorized` after each), with a deny-by-default `ApplicationPolicy` and role predicates for visitor, player, moderator and administrator. Players carry a `role` (checked by a database constraint) and `banned_at`. A banned player loses the session's player id at the next request, and cannot sign in. Refusals send a visitor to sign in (401 for JSON) and answer a player with 403. `Game::Operation` refuses at load time an operation without a `player:` input and fails without a valid player.

**Files changed:**
- `Gemfile`, `Gemfile.lock` -- pundit
- `db/migrate/20261002154024_*`, `db/migrate/20261002154025_*`, `db/schema.rb` -- role and ban columns, role check constraint (added unvalidated, then validated)
- `packs/accounts/app/models/accounts/player.rb`, `packs/accounts/app/operations/accounts/sign_in.rb` -- roles, `banned?`, banned sign-in failure
- `app/policies/{application,page,session}_policy.rb` -- policies
- `app/controllers/{application,pages,locales,sessions}_controller.rb` -- Pundit, ban check, refusal handling, `authorize` everywhere
- `packs/game/app/operations/game/operation.rb` -- Game base operation
- `config/locales/{en,fr}.yml` -- refusal and error messages
- `test/fixtures/accounts/players.yml`, `test/policies/*`, `test/controllers/authorization_test.rb`, `test/packs/**` -- matrix rows and review fixes

**Review findings:** 2 patches applied (1 medium, 1 low); 0 deferred; 1 rejected (`operate_on` bypass, low).

**Follow-up review recommended:** false — one medium patch.

**Verification:** `bin/rails test` (125 runs, 0 failures), system tests (3 runs), migrations from scratch (no strong_migrations error, schema equal to development), Packwerk, i18n-tasks, RuboCop, zeitwerk, Brakeman clean.

**Residual risks:** The role constraint is written with `OR` rather than `IN` because PostgreSQL 18 dumped the `IN` form differently between databases and tripped the drift check. A refused player's 403 is a bare translated message in the layout. Redefining `call` in an operation makes dry-operation wrap the result twice; nobody should reopen operations.
