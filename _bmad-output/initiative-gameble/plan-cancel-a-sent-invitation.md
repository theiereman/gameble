---
title: 'Cancel a sent invitation'
type: 'feature'
ticket: ''
created: '2026-10-09'
status: 'done'
baseline_revision: 'c64a6e8f45824ff2a66b0330979c6f83475fab92'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A player who sent a friend invitation, by code or by link, cannot take it back. The row "Envoyée à Sam · En attente" stays on the Friends screen until the other player answers.

**Approach:** Every sent row gets an "Annuler" button. Cancelling removes the invitation for both players, live on the other player's open Friends screen, and the sender may invite the same player again. Sending directly from an invite link is a separate build.

## Boundaries & Constraints

**Always:** written through a new operation `Game::CancelInvitation` (`Success` / `Failure(:code)`) that publishes one `Game::InvitationCancelled` event inside its transaction; a POST route by invitation token; a Pundit policy; strings in `en.yml` and `fr.yml`, with the `errors.game.<code>` keys added by hand; the pair locked with `TradeLocks.players` as the other invitation operations do.

**Decision (author, 2026-10-09):** Annuler always deletes the invitation, whether it was pending or ignored. A sender may therefore cancel and re-invite someone who ignored them; ignoring is no longer a lasting block, and the existing test asserting that an ignored invitation cannot be sent again keeps holding only until the sender cancels. No migration.

**Never:** a GET that writes; a database id in a URL, the DOM or the event's stream name; telling the sender that their invitation was ignored.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Cancel pending | Lea's pending invitation to Sam | Gone from both screens; Sam's open screen updates live; Lea may invite Sam again | — |
| Cancel ignored | Sam ignored Lea's invitation; Lea still sees it pending | Deleted; Lea may invite Sam again and Sam sees the new one | — |
| Already answered | Sam accepted just before Lea cancels | Nothing changes; they stay friends | `Failure(:not_found)`, "Cette invitation n'existe plus." |
| Not the sender | Sam, or a stranger, posts Lea's token | Nothing changes | `Failure(:not_found)` |
| Signed out | Visitor posts the route | Refused by the policy | Sign-in required, as for accept |

</frozen-after-approval>

## Code Map

- `packs/game/app/operations/game/ignore_invitation.rb` -- the shape to copy: `require_player`, a pre-read, then `transaction` with `TradeLocks.players` and a locked `find_by`.
- `packs/game/app/operations/game/send_invitation.rb` -- `create_pending` publishes `InvitationSent` with `stream_name(player.id)`; copy that publish. Unchanged: once the row is deleted, `unanswered` no longer blocks a resend.
- `packs/game/app/operations/game/drop_friends_and_trades.rb` -- already deletes invitations with `delete_all`; deleting on cancel follows it.
- `packs/game/app/models/game/invitation.rb` -- `STATUSES`, scopes `pending`, `unanswered` (pending + ignored: what the sender sees and what blocks a resend).
- `packs/game/app/events/game/invitation_sent.rb` -- event class template.
- `app/models/player_stream.rb` -- add the event to `INVITATION_EVENTS`; its notices are `friends_notice` for sender and recipient, as for `InvitationSent`. `config/initializers/event_store.rb` already subscribes `PlayerStream::EVENTS`.
- `packs/game/app/handlers/game/handlers/player_activity.rb` -- leave cancelling out: it is not "making friends".
- `app/controllers/invitations_controller.rb`, `app/policies/invitation_policy.rb`, `config/routes.rb:77-81` -- add `cancel` beside `accept`/`ignore`, same token constraint and rate limit.
- `app/views/friends/show.html.erb:51-56` -- the sent row; copy the received row's `ButtonComponent` (`variant: :secondary`, `method: :post`, `size: :small`) inside `friends__actions`.
- `Game::InvitationsOf` -- `Row.token` is already the invitation token.

## Tasks & Acceptance

**Execution:**
- [x] `packs/game/app/events/game/invitation_cancelled.rb` -- the event: invitation_id, sender_id, recipient_id.
- [x] `packs/game/app/operations/game/cancel_invitation.rb` -- delete the sender's unanswered (pending or ignored) invitation by token and publish the event; `Failure(:not_found)` otherwise.
- [x] `app/models/player_stream.rb` -- the cancelled event refreshes both players' friends topic.
- [x] `config/routes.rb`, `app/policies/invitation_policy.rb`, `app/controllers/invitations_controller.rb` -- `POST friends/invitations/:token/cancel`; redirect to the Friends screen with "Invitation annulée." on the status line, or the failure message.
- [x] `app/views/friends/show.html.erb` -- the "Annuler" button on each sent row.
- [x] `config/locales/en.yml`, `config/locales/fr.yml` -- `friends.show.cancel`, `invitations.cancelled`.
- [x] `test/packs/game/invitation_test.rb`, `test/controllers/invitations_controller_test.rb`, `test/policies/invitation_policy_test.rb`, `test/models/player_stream_test.rb` -- the matrix rows, the event, the notices, the button and the line.

**Acceptance Criteria:**
- Given Lea sees "Envoyée à Sam · En attente", when she presses "Annuler", then the row is gone, the line reads "Invitation annulée.", and Sam's open Friends screen no longer shows "Lea vous invite".
- Given Lea cancelled her invitation to Sam, pending or ignored, when she sends Sam's code again, then a new pending invitation reaches Sam.

## Implementation Notes

- The status-line flash key was `invite_sent`; it is now `invite_done`, since the line also reports a cancel (`InvitationFeedback`, the view, the controller). The CSS class `friends__message--sent` is unchanged.
- The "En attente" chip moved inside the sent row's `friends__actions` beside "Annuler", so `justify-content: space-between` keeps the chip and button together on the right instead of spreading three children.
- The operation checks that the token belongs to the sender's unanswered invitation before locking, then re-reads it locked inside the transaction (as `IgnoreInvitation` does), so a cancel racing an accept fails `:not_found` and leaves the friendship.
- Added a live-update system test: a cancelled invitation leaves the recipient's open Friends screen without a reload.

## Plan Change Log

## Review Triage Log

| # | Lens | Finding | Verdict | Route | Evidence |
|---|------|---------|---------|-------|----------|
| 1 | quick | UX docs describe the sent row without "ANNULER" and list neither "Annuler" nor "Invitation annulée." | low | patch | `ux-gameble/DESIGN.md` Invitation row and `EXPERIENCE.md` Friends / Invite code messages rows checked: both predate the button. |
| 2 | quick | Every sent row's "Annuler" has the same accessible name | low | patch | The friend rows on the same screen name their target with `aria_label`; `ButtonComponent` takes `aria_label`, so the fix is one argument and one string. |
| 3 | quick | The ignored case of the resend criterion resends by link, not by code | low | patch | `invitation_test.rb` uses `recipient_token:`; the criterion says "sends Sam's code again". |
| 4 | quick | No test covers the rate limit on `cancel` | low | reject | Test gap with no defect; the limit is one symbol in the shared `only:` list, and adding the test is more than a direct correction. |

## Verification

**Commands:**
- `bin/rails test` -- expected: green
- `bin/rails test test/system/friends_test.rb test/system/live_updates_test.rb` -- expected: green
- `bundle exec packwerk check`, `bundle exec i18n-tasks missing`, `bin/rubocop` -- expected: clean
