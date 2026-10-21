---
title: 'The friendship action on a profile'
type: 'feature'
ticket: 6
created: '2026-10-21'
status: 'built'
baseline_revision: 'ba180afc3bff9c8df6cd7972c18d3697e1868a09'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
context: ['{project-root}/AGENTS.md']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A player viewing another player's public profile cannot act on the relation: the identity band shows only a greyed trade button to signed-out visitors and nothing to signed-in viewers, so befriending or trading with someone met on a profile means leaving for Amis and typing a code.

**Approach:** The identity band shows the viewer's one action under the name, set by the relation (table below). A new `POST` on the profile sends the invitation through `Game::SendInvitation` (which already accepts a reverse pending invitation) and returns to the profile with a flash; a query names the relation.

## Boundaries & Constraints

**Always:** Write only through `Game::SendInvitation`; controller reads through Game queries. Pundit on the new action (`InvitationPolicy#create?`). Token in URL, never an id. Every string in en.yml and fr.yml (« AJOUTER EN AMI » / "ADD FRIEND", « EN ATTENTE » / "PENDING", « ACCEPTER » / "ACCEPT", « ÉCHANGE » / "TRADE", accessible names « Ajouter %{name} en ami », « Accepter l'invitation de %{name} », « Échange avec %{name} »); failure keys by hand. No `style` attribute. GET writes nothing. Same rate limit as the other invitation actions.

**Never:** Change SIGNALER, the showcase, the key numbers, `SendInvitation`/`AcceptInvitation`, or the Amis screen. No action on a private or hidden profile (it renders the unavailable page already). No id in DOM or flash.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| No relation | signed in, no friendship, no invitation | « AJOUTER EN AMI » (a button posting the invitation) | — |
| Add | POST by that viewer | invitation in the owner's Amis; back on the profile showing « EN ATTENTE » | — |
| Sent | invitation unanswered, viewer → owner | « EN ATTENTE », disabled | — |
| Received | pending invitation owner → viewer | « ACCEPTER » posting to the same route; friendship created, band shows « ÉCHANGE » | — |
| Friends | friendship | « ÉCHANGE » linking to the open trade, else a new draft | — |
| Friends, viewer private | friendship, viewer's profile private | the trades-closed line in place of « ÉCHANGE » | — |
| Own profile | viewer is owner | no action | POST refused (`:own_link`) |
| Signed out | no viewer | « ÉCHANGE » greyed, disabled (as today) | POST refused like other invitation actions |
| Repeated | second POST while sent | nothing new written | alert flash, `:already_sent` |

</frozen-after-approval>

## Code Map

- `app/views/public_profiles/_summary.html.erb` -- identity band; the signed-out disabled ÉCHANGE sits here and moves into the new action partial
- `app/controllers/public_profiles_controller.rb` -- `show`; loads the relation (and the open trade token for friends) only for a signed-in viewer
- `app/controllers/invite_links_controller.rb` -- model for the token-based `SendInvitation` call, its rate limit and `relation_to`
- `app/controllers/concerns/invitation_feedback.rb` -- `new_friend` flash to reuse; `report_sent` redirects to Amis, so the new controller does its own redirect
- `packs/game/app/operations/game/send_invitation.rb` -- recipient by token, reverse pending accepted; do not change
- `packs/game/app/queries/game/{friendship_between,invitation_awaiting,open_trades_by_friend}.rb` -- reuse; add `profile_relation.rb` beside them
- `app/helpers/trades_helper.rb` -- `trades_refusal` / `trades_closed_line`, as on `friends/show`
- `app/views/friends/show.html.erb:79-86` -- the ÉCHANGE button to mirror
- `config/routes.rb` -- `brothers/:token/report` is the model for the new route; `config/locales/{en,fr}.yml` -- `public_profiles.show`, `invitations`
- `test/controllers/public_profiles_controller_test.rb`, `test/controllers/invitations_controller_test.rb`, `test/packs/game/invitation_test.rb` -- test style

## Tasks & Acceptance

**Execution:**
- [ ] `packs/game/app/queries/game/profile_relation.rb` -- `call(viewer, owner)` returns `:visitor`, `:self`, `:friends`, `:invited`, `:invited_by` or `:none` -- one place names the relation
- [ ] `app/controllers/brother_invitations_controller.rb`, `config/routes.rb`, `app/policies` -- `POST brothers/:token/invitation` through `SendInvitation(recipient_token:)`, redirect to the profile with flash -- the one write
- [ ] `app/views/public_profiles/_action.html.erb`, `_summary.html.erb`, `PublicProfilesController#show` -- render the action per the matrix -- the visible change
- [ ] `config/locales/{en,fr}.yml` -- the labels, accessible names, flashes and failures -- both languages
- [ ] tests -- query per relation; request tests for each matrix row incl. refusals and the repeated invitation; `i18n-tasks`, packwerk

**Acceptance Criteria:**
- Given a viewer who received an invitation from the owner, when they press « ACCEPTER », then they are friends and the profile shows « ÉCHANGE ».
- Given any GET of a profile, then nothing is written.

## Implementation Notes

- Self-review before the quick review: `ProfileRelation` read « received » from unanswered invitations, so an ignored one offered ACCEPTER while `SendInvitation` only accepts pending ones; fixed with one query reading status, and tested.

## Plan Change Log

## Review Triage Log

| Verdict | Route | Finding and evidence |
|---|---|---|
| medium | patch | Staff saw ADD FRIEND on a private or friends-only profile and could invite its owner: `Visibility.visible?` defaults to `staff_sees_all: true`. Fixed: the relation and the POST use `staff_sees_all: false`; tested. |
| medium | patch | The open-trade row was not tested (no trade created). Fixed: a test with a proposed trade asserts its `trade_path`, another the new-draft link. |
| low | patch | Throttle sent the player to Amis, against the controller's own "always the profile". Fixed: it redirects to the profile. |
| low | patch | Four-line intent comment against the no-comment policy. Removed. |
| low | patch | The reports test selector was loosened. Kept `.profile-band__meta button, 1` and added the band total of 2. |
| medium | patch | No test for a banned owner's POST or for staff cases. Added (404, nothing written). |
| low | false | Signed-out POST asserts only a redirect: the refusal is `ApplicationController`'s shared handling, tested elsewhere for every action; the nothing-written assertion is the matrix's point. |
| low | false | No throttle-redirect test, no friends-only test: the first is now the profile and covered by the shared limiter tests; friends-only is covered by the staff case. |

## Design Notes

The relation order matters: friends first, then received, then sent. A received invitation outranks a sent one only if both exist; `SendInvitation` already merges that case by accepting the reverse.

## Verification

**Commands:**
- `bin/rails test test/controllers test/packs/game` -- expected: pass
- `bundle exec packwerk check` and `bundle exec i18n-tasks health` -- expected: clean
- `bin/rails zeitwerk:check` -- expected: pass
