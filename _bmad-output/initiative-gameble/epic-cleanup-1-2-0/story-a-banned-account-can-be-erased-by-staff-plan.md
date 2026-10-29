---
title: 'A banned account can be erased by staff'
type: 'feature'
ticket: '3'
created: '2026-10-28'
status: done
baseline_revision: 'f9b5aed9490f58b87046faa76d461c9bcacaffd5'
route: 'full'
route_source: 'auto'
review: 'none'
review_source: 'auto'
lenses_ran: []
review_loop_iteration: 0
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** the legal page promises erasure on request, but `Accounts::DeletePlayer` refuses a banned player, so a banned account cannot be erased by anyone.

**Approach:** a new operation lets an administrator erase a banned player from a row of the back-office players index, confirmed by `turbo_confirm` naming the player, and records the erasure in the moderation history as a new kind. The ban stays in place.

## Boundaries & Constraints

**Always:** administrator only; a banned player acting alone is still refused by `DeletePlayer`; one event (`PlayerDeleted`) inside the transaction; the ban (`banned_at`) and its history rows stay; the new kind is added to the check constraint in two strong_migrations steps.

**Never:** a player page, a new event, changing `AccountsController`, a moderator able to erase, editing `legal` copy beyond what a new history label needs.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Erase | administrator, banned lower-rank player | player deleted (anonymised), `banned_at` kept, history row `erasure` by that administrator | none |
| Not banned | administrator, player in good standing | refused | `:not_banned` |
| Moderator | moderator, banned player | refused, no button shown | `:administrator_required` |
| Banned alone | `DeletePlayer` with the banned player | refused | `:player_required` |
| Outranked | administrator, banned administrator | refused | `:outranked` |
| Already erased | administrator, deleted player | refused | `:player_not_found` |

</frozen-after-approval>

## Code Map

- `app/domains/accounts/app/operations/accounts/delete_player.rb` -- refuses banned players; gains `allow_banned:` (default false), unchanged for `AccountsController` and `DeleteInactivePlayer`.
- `app/domains/accounts/app/operations/accounts/unban_player.rb` -- model for `refusal(staff:, player:)`, the staff lock and the history row.
- `app/domains/accounts/app/models/accounts/moderation_action.rb` -- enum gains `erasure`.
- `db/migrate/…` -- remove `accounts_moderation_actions_kind_check`, add `accounts_moderation_actions_kind_values_check` not validated; second migration validates it. Pattern: `20261028110002`/`110003`.
- `app/controllers/back_office/players_controller.rb`, `app/policies/back_office/players_policy.rb`, `config/routes.rb` (`resources :players` with `destroy` by token like `bans`).
- `app/views/back_office/players/index.html.erb` + new `_erase_action.html.erb` (model: `back_office/bans/_unban_action.html.erb`).
- `app/views/back_office/history/index.html.erb` -- `kinds.erasure` label; `config/locales/en.yml`, `fr.yml` (history intro, kinds, actions, flash, `errors.accounts.administrator_required`).
- Reuse: `Accounts::PlayerByToken`, `public_profile_title`, `redirect_refused`, `CountingRateLimit` in tests. Do not change `PurgeModerationHistory`: a deleted player's rows already expire one year after `deleted_at`.

## Tasks & Acceptance

**Execution:**
- [ ] `DeletePlayer` -- `allow_banned:` keyword -- the erasure reuses the one deletion
- [ ] `Accounts::EraseBannedPlayer` -- operation with `refusal`, staff lock, delegates to `DeletePlayer`, records `erasure` -- single event, one transaction
- [ ] `ModerationAction` + two migrations + `db/schema.rb` -- new kind -- expand then validate
- [ ] policy, route, controller `destroy`, players index, erase partial, history label, locales en/fr -- the staff action
- [ ] tests: operation, `DeletePlayer` still refuses banned, back-office controller (administrator erases, moderator cannot, not banned, rate limit), history shows the row, system test of the confirm button

**Acceptance Criteria:**
- Given an administrator and a banned player, when they erase the player from the players index, then the player is anonymised, still banned, and the history lists the erasure.
- Given a moderator or the banned player, when either tries it, then it is refused.

## Implementation Notes

- `Accounts::EraseBannedPlayer` follows `UnbanPlayer` (a `refusal` class method the view reuses, the staff row locked `FOR SHARE`) and delegates the deletion to `DeletePlayer`, whose new `allow_banned:` keyword defaults to false: `AccountsController` and `DeleteInactivePlayer` are untouched, and the only event is `PlayerDeleted`.
- Refusal codes: `:administrator_required` (new, both locales), `:player_not_found`, `:outranked`, `:not_banned`. A moderator never sees the button (it renders nothing when refused) and the policy answers 403 to a moderator, 404 to a player or visitor.
- Migrations: the old `accounts_moderation_actions_kind_check` is replaced by `accounts_moderation_actions_kind_values_check` (adds `erasure`), added not validated, validated in the second migration; `db/schema.rb` regenerated as AGENTS.md says.
- The erase button sits in the actions cell of a banned row of the players index, beside LIFT THE BAN; it posts back with the search and page, like the other row actions; rate limit 30 per minute like bans.
- Tests: operation (erase, event, refusals, rollback of the history row, banned alone still refused, constraint), back-office controller (button for administrator only, redirect with search, history row, 403, 404, not banned, rate limit), policy, and a system test with the confirm naming the player.

## Plan Change Log

## Review Triage Log

No independent review: a fork cannot spawn reviewers. Self-review of the diff: `DeletePlayer` keeps refusing a banned player unless asked; the history row and the deletion share the transaction (a stubbed failing deletion leaves no row); the erased player disappears from the players index and the banned list (both read `deleted_at IS NULL`) and stays in the history, named as a deleted account, until `PurgeModerationHistory` removes it a year after the deletion, as the privacy notice says. One consequence for the pull request: the deletion releases the Steam id, so the ban stays on the record but no longer blocks a new account created with the same Steam id. No finding to defer.

Independent review (read-only), triaged by the author on 2026-10-28:
- A banned person can register again with the same Steam id after the erasure: decided to leave as is (the erasure really erases, no hash of the Steam id is kept). The confirmation text and the players index intro now say that the Steam id is freed and the person can register again without the ban, and a test pins the behaviour (`SignIn` opens a new unbanned account).
- The free-text ban reason stays readable in the history until the yearly purge: decided to keep it as is.
- The first migration had no usable rollback once an `erasure` row exists: it now has an explicit `up` and a `down` that raises `ActiveRecord::IrreversibleMigration`, because going back would mean deleting moderation history rows.
- Two refusal tests added: `DeleteInactivePlayer` called directly on a long-idle banned player, and a player banned while signed in who tries to delete their own account.
- `packwerk` failed to parse the shorthand hash arguments of the two row actions in the players index; they are parenthesised (07e042d3).

## Design Notes

- Once erased, the player has no Steam id (released by the deletion), so the ban no longer blocks a new account with the same Steam id: the ban stays on the record only. This follows the author's decision (confirmed after the review, 2026-10-28): the texts shown to the administrator say so; noted for the pull request. The ban reason text is kept as is, and the first migration is irreversible by design.

## Verification

**Commands:**
- `bin/rails test` -- result: 3261 runs; the Accounts, back-office, policy and schema tests pass; one unrelated failure in the full parallel run (`PlayerExportTest` weekly contributions, passes alone 3 of 3, logged in the deferred work); `bin/rails test test/system/moderation_test.rb` -- 5 runs green three times
- `npm run test:js`, `npm run format:check`, `npm run lint:css`, `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `bundle exec rubocop`, `bundle exec i18n-tasks missing`, `script/check_file_sizes`, `script/check_planning_references` -- expected: clean
