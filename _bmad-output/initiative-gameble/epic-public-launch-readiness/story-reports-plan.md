---
title: 'Reports'
type: 'feature'
ticket: '4'
created: '2026-10-07'
status: 'built'
baseline_revision: '47cea18'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A visitor cannot tell moderators about a username or profile (R4, CAP-15).

**Approach:** An `accounts_reports` table, `Accounts::ReportPlayer` (reusable: the friend profile of epic 5 calls it), and on the public profile a SIGNALER link opening a report dialog with four reasons; anonymous to the reported player; a visitor's SIGNALER opens the sign-in panel; rate limits at the controller and the operation.

## Boundaries & Constraints

**Always:** the reported player is never told (nothing published, no event, same thank-you on a repeat); a profile the reporter may not see is the unavailable 404 (`Game::Visibility`); strong_migrations rules; English copy translated from the French.

**Never:** the staff queue, ban and unban (story 7.5); a second visibility check; the reporter's identity on any page of the reported player.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected | Error Handling |
|----------|--------------|----------|----------------|
| Report | player, other visible profile, a reason | row stored, thank-you toast | none |
| Repeat | same reporter and reported | Success, nothing added | none |
| Bad reason | none or unknown | nothing stored | `Failure(:invalid_reason)`, alert |
| Self | reporter = reported | refused | `Failure(:cannot_report_self)` |
| Visitor | signed out | refused, sign_in_required | SIGNALER opens the sign-in panel |
| Limit | 6th distinct player in 24 h | refused | `Failure(:rate_limited)`; controller 10 per minute |
| Hidden | private owner or unknown token | unavailable page, 404 | nothing stored |

</frozen-after-approval>

## Code Map

- `db/migrate/20261007130000_create_accounts_reports.rb` -- table, unique (reporter, reported), reason check constraint.
- `packs/accounts/app/models/accounts/report.rb`, `.../operations/accounts/report_player.rb` -- model and operation (LIMIT 5 per day).
- `app/controllers/reports_controller.rb`, `app/policies/report_policy.rb`, `config/routes.rb` (`POST brothers/:token/report`).
- `app/views/reports/_dialog.html.erb`, `app/views/public_profiles/_summary.html.erb` and `_profile.html.erb`, `app/frontend/styles/profile.css`, `config/locales/{fr,en}.yml`.
- `test/packs/accounts/report_player_test.rb`, `test/controllers/reports_controller_test.rb`.

## Tasks & Acceptance

**Execution:**
- [x] migration, `Accounts::Report`, `Accounts::ReportPlayer`
- [x] controller, policy, route, dialog, SIGNALER link, CSS, locales
- [x] tests: operation, controller (player, owner, visitor, repeat, hidden, limit)

**Acceptance Criteria:**
- Given a signed-in visitor of a public profile, when they choose a reason and send, then a report is stored and a thank-you shows; the reported player sees nothing.
- Given a signed-out visitor, when they choose SIGNALER, then the sign-in panel opens.
- Given a player who reported five players today, when they report a sixth, then it is refused.

## Implementation Notes

Decisions (author away, simplest option): (1) one report per reporter and reported player; a repeat is a silent Success, keeping the first reason; (2) operation limit 5 distinct players per 24 h, plus 10 per minute in the controller (`rate_limit`); (3) the dialog is the partial `reports/_dialog` taking `owner:`, rendered by the public profile only for a signed-in non-owner; the set page of a profile has no summary, hence no SIGNALER there; (4) HTML5 `required` radios enforce "a reason must be chosen", the server re-checks; (5) the submit is a normal form (Turbo) answered by a 303 to the profile with a toast; (6) the toast copy names no one ("Le joueur") since the profile's name can be a fallback code; (7) no event is published.

## Plan Change Log

## Review Triage Log

## Verification

**Commands:**
- `bin/rails test` (minus card_face_visual_test), `bin/rubocop`, `bundle exec packwerk check`, `bundle exec i18n-tasks missing`, `npm run typecheck`, `npm run test:js` -- all green.
