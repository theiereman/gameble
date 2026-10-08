---
title: 'Invitations by code and by link'
type: 'feature'
ticket: '2'
created: '2026-10-07'
status: done
baseline_revision: '47cea18b653361d83cd2a5ab133491a1eade4cca'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick-review-subagent]
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Players cannot become friends: the Friends screen has a code and an empty list but no way to invite, answer or share a link.

**Approach:** In `Game`, an `invitations` table and operations SendInvitation, AcceptInvitation (creates the friendship in the same transaction) and IgnoreInvitation; on the Friends screen the invite link with COPIER, a code field, received and sent invitation rows; a public invite page per player (the player's token) where a visitor signs in and returns to it.

**Decisions (autonomous run, author away):** the permanent link is `/:locale/invite/:token` with the player's own token (AD-15); opening it is a read, a button on it (POST) sends the invitation; a successful sign-in started from an invite page returns to that page, every other sign-in still lands on the hub; an invitation has a random token (AD-15) and a status pending/accepted/ignored, one pending per sender and recipient; sending to someone who already invited you accepts their invitation (both want it); an ignored invitation may be sent again (the rate limit bounds it); a banned or unknown recipient answers "unknown code"; added copy lines (not in the deck): unknown code, already friends, own link, invalid link; mutating endpoints are limited to 20 a minute per player; the invitation events InvitationSent and InvitationAccepted are published, live delivery on the private stream waits for its own story; English copy is written here.

## Boundaries & Constraints

**Always:** invitations and friendships are written only by Game operations (AD-3, AD-14, one player as input); GETs never write (AD-11); no database id in a URL or the DOM (AD-15); a friendship stays one row per pair, lower id first.

**Never:** trades, presence, friend profile, live streaming of invitations, deleting friendships on account deletion.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Valid code | other player's code | pending invitation, "Invitation envoyée à CODE." | n/a |
| Format wrong | "abc" | "Format attendu : ABCD-1234." | no row |
| Own code / link | own | "C'est votre propre code." | no row |
| Repeated | pending already | "Invitation déjà envoyée." | no row |
| Already friends | friendship exists | "Vous êtes déjà amis." | no row |
| Accept | recipient presses ACCEPTER | friendship + accepted, toast NOUVEL AMI | other's row: not found |
| Ignore | IGNORER | row disappears, no friendship | n/a |
| Link, visitor | GET invite page | page with sign-in button; sign-in returns to the page | unknown token: 404 page |
| Link, player | POST | invitation sent, back to Friends | same refusals |

</frozen-after-approval>

## Code Map

- `db/migrate`, `db/schema.rb` -- game_invitations (token, sender, recipient, status).
- `packs/game/app/models/game/invitation.rb`; `operations/game/{send,accept,ignore}_invitation.rb`; `queries/game/invitations_of.rb`; `events/game/invitation_{sent,accepted}.rb`.
- `app/controllers/{invitations,invite_links}_controller.rb`, `app/policies/`, `config/routes.rb`, `sessions_controller.rb` (return to the invite page).
- `app/views/friends/show.html.erb`, `app/views/invite_links/show.html.erb`, `app/frontend/styles/friends.css`, `config/locales/{en,fr}.yml`.
- Reuse: `share_controller.ts` for COPIER; `Accounts::PlayerByToken`; `Game::FriendCode::FORMAT`; `rate_limit` as in DailyBonusesController.

## Tasks & Acceptance

**Execution:**
- [ ] migration, model, events, three operations, query
- [ ] controllers, policies, routes, sign-in return, views, css, locales
- [ ] tests: operations, query, controllers, policies, rate limit

**Acceptance Criteria:**
- Given a valid code, when entered, then the friend sees the invitation and ACCEPTER makes both see each other.
- Given IGNORER, then no friendship exists and the row is gone.
- Given a signed-out visitor on an invite link, when signing in, then they land back on it.

## Implementation Notes

Built directly in this session. Quick review (subagent): no real bug; one accepted low risk, two players inviting each other at the same instant can leave two pending invitations (no lock); the first accept makes the friendship and the second is idempotent.

## Plan Change Log

## Review Triage Log

## Verification

**Commands:**
- `bin/rails test` (minus card_face_visual_test), `bin/rubocop`, `bin/packwerk check`, `bundle exec i18n-tasks missing`, `npm run typecheck`, `npm run test:js` -- all green
