---
title: 'Friend code and a first Friends screen'
type: 'feature'
ticket: '1'
created: '2026-10-07'
status: 'built'
baseline_revision: 'fa1676d08778595dc0c244091066abb7b0b49786'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: []
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Epic 5 has no friendship data, no friend code and no Friends screen; menu 04 and the PLUS row for AMIS are still "coming soon".

**Approach:** In `Game`, add friendship and friend-code tables, a purely random unique code per player (XXXX-XXXX) created at sign-up and backfilled for existing players, and a minimal AMIS screen (friends list, empty for now, plus "VOTRE CODE AMI") reached from menu 04 and the PLUS row; a visitor gets the sign-in panel.

**Decisions (autonomous run, author away):** code alphabet is 31 unambiguous characters (no 0 O 1 I L); the code is created by the PlayerRegistered handler (a GET never writes, AD-11) and backfilled by a job and rake task like player states; a missing code row renders no code block; a visitor at /friends is refused and sent home (existing policy behaviour), and menu 04 / the PLUS row open the sign-in panel for a visitor; the invite link, code entry and invitations are story 5.2 and are not on the screen; the Friends route is `/:locale/friends`; the coding is done directly in this session (no coding subagent).

## Boundaries & Constraints

**Always:** friendships and codes live in Game and are written only through Game operations (AD-3); a friendship is one row per pair, lower player id first, unique; code is never derived from a name or id.

**Never:** invitations, link, code entry, presence, friend profile, trades.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Signed-in player | GET /fr/friends | page with the player's code and an empty friends list | n/a |
| Visitor | GET /fr/friends | redirect home with the sign-in message; menu 04 opens the sign-in panel | n/a |
| Two players | codes created | distinct codes of the form XXXX-XXXX | collision retried |

</frozen-after-approval>

## Code Map

- `packs/game/app/models/game/friend_code.rb`, `friendship.rb` -- new models.
- `packs/game/app/operations/game/create_friend_code.rb` -- idempotent, retries on collision.
- `packs/game/app/queries/game/friend_code_of.rb`, `friends_of.rb` -- reads for the web layer.
- `packs/game/app/handlers/game/handlers/player_registered.rb` -- also creates the code.
- `packs/game/app/jobs/game/backfill_friend_codes_job.rb`, `packs/game/lib/tasks/game.rake` -- backfill.
- `app/controllers/friends_controller.rb`, `app/policies/friend_policy.rb`, `app/views/friends/show.html.erb`, `config/routes.rb`.
- `app/views/pages/_menu.html.erb`, `_menu_friends.html.erb`, `more.html.erb`, `config/locales/{en,fr}.yml`.

## Tasks & Acceptance

**Execution:**
- [ ] migration + `db/schema.rb` -- game_friend_codes, game_friendships
- [ ] Game models, operation, queries, handler, backfill job and task
- [ ] controller, policy, route, view, menu 04 and PLUS row, locales
- [ ] tests: operation, queries, job, controller, policy, hub menu update, fixtures

**Acceptance Criteria:**
- Given a signed-in player, when they open AMIS from menu 04 or PLUS, then they see their code and an empty list.
- Given two accounts, then their codes differ.
- Given a visitor, then menu 04 opens the sign-in panel and /friends leads home.

## Implementation Notes

## Plan Change Log

## Review Triage Log

## Verification

**Commands:**
- `bin/rails test` (minus card_face_visual_test), `bin/rubocop`, `bin/packwerk check`, `bundle exec i18n-tasks health`, typecheck, js tests -- all green
