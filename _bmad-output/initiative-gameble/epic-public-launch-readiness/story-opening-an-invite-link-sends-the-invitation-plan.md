---
title: 'Opening an invite link sends the invitation'
type: 'feature'
ticket: '30'
created: '2026-10-13'
status: done
baseline_revision: '4b1584fd04a547ca8d905a0a0f447a1b345d972a'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: [oversized]
deferred:
  - summary: >-
      A page on another site can send a signed-in player to an invite link, which then sends the invitation, or accepts the owner's pending one, without a click.
    evidence: |-
      The session cookie is SameSite=Lax (config/initializers/session_store.rb sets none), so a top-level cross-site GET arrives signed in; the page's own POST carries a valid CSRF token. This is the auto-send the ticket asks for; the page cannot tell a chat app's link from a hostile redirect. Cancelling a sent invitation exists, but once the link's owner accepts (or the auto-submit accepts theirs) no path removes a friendship. Possible answers for the author: keep it, never auto-accept the owner's pending invitation, or add removing a friend.
    location: >-
      app/views/invite_links/show.html.erb
    severity: medium
---

<intent-contract>

## Intent

**Problem:** Opening a friend's invite link shows a page with an "Envoyer une invitation" button; nothing is sent until the player presses it, so a link opened from a chat costs an extra step, and a signed-out visitor lands back on that page after Steam sign-in and must press it again.

**Approach:** The invite page, when the viewer can still invite the owner, carries a Stimulus controller that submits the page's existing POST form once on load (replacing the page in history so Back never re-sends); the button stays as the no-JavaScript fallback. The signed-out path keeps its current route: Steam sign-in returns to the invite page, which then submits itself. When the viewer already sent an unanswered invitation to the owner or is already their friend, the page says so, links to Friends and submits nothing.

## Boundaries & Constraints

**Always:** the GET of the invite page only reads (it runs on the reading role); the invitation is written only by the existing POST `invite_links#create` through `Game::SendInvitation`; the web layer reads Game state through a Game query; every new string in both `en.yml` and `fr.yml`; the auto-submit never fires while Turbo shows a cached preview, and fires at most once per page load.

**Never:** sending an invitation from a GET or from the Steam callback; a database id in the page; telling the sender that their invitation was ignored (an ignored invitation reads as "already sent", as `SendInvitation` already treats it); a new system test; changing `Game::SendInvitation`'s rules.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Signed in, first open | GET `/fr/invite/<owner token>` | Page renders the send form with the auto-submit controller; on load it POSTs; lands on Friends with "Invitation envoyée à Sam." and the sent row | No error expected |
| Signed out | GET link, then Steam sign-in with the link as origin | Callback redirects to the link (unchanged); the page renders the auto-submit form; the POST sends | Sign-in failure keeps the existing failure path |
| No JavaScript | same page | The "Envoyer une invitation" button POSTs | No error expected |
| Opened again | an unanswered (pending or ignored) invitation from viewer to owner exists | Page says the invitation is already sent, links to Friends, no auto-submit form | POST still refuses `:already_sent` |
| Already friends | friendship exists | Page says they are already friends, links to Friends, no auto-submit form | POST still refuses `:already_friends` |
| Owner invited the viewer | pending invitation owner → viewer | Auto-submit form shown; the POST accepts it (existing behaviour), Friends shows the new-friend toast | No error expected |
| Own link / unknown / banned | as today | Unchanged: own-link message; 404 page | Unchanged |
| Turbo preview of a cached copy | `html[data-turbo-preview]` | No submit | — |

</intent-contract>

## Code Map

- `app/controllers/invite_links_controller.rb` -- `show` loads `@owner`; add the viewer's relation to the owner (already friends / already invited) read through Game queries. `create` stays as is.
- `app/views/invite_links/show.html.erb` -- branches: signed out (sign-in opener), own link, new state branches, else the send form. The send form is `ButtonComponent.new(href: request.path, method: :post)`; wrap it (or its container) with the auto-submit controller.
- `app/components/button_component.rb` -- renders `button_to` with `form_class: "button-form"`; do not change it, the controller finds the `form` inside its element.
- `packs/game/app/queries/game/friendship_between.rb` -- reuse for "already friends".
- `packs/game/app/models/game/invitation.rb` -- `unanswered` scope (pending + ignored); a new query `Game::InvitationAwaiting.call(sender, recipient)` answers whether an unanswered invitation from sender to recipient exists (false for nil players).
- `app/controllers/sessions_controller.rb` -- `invite_origin` already redirects to the invite path after sign-in; no change.
- `app/frontend/controllers/` -- Stimulus controllers are auto-registered by file name (`*_controller.ts`); vitest runs pure modules from `app/frontend/lib/*.test.ts` in a node environment (no DOM).
- `test/controllers/invitations_controller_test.rb` -- existing invite-link tests (`sign_in` helper with OmniAuth test mode, `@alice`/`@bob` as Lea/Sam); extend here.
- `test/packs/game/friend_profile_queries_test.rb` -- style for Game query tests.
- `config/locales/en.yml` / `fr.yml` -- `invite_links.show.*` (line ~845 / ~865).

## Tasks & Acceptance

**Execution:**
- [ ] `packs/game/app/queries/game/invitation_awaiting.rb` -- add the query -- the page must know without writing whether the viewer already invited the owner.
- [ ] `test/packs/game/invitation_awaiting_test.rb` -- pending and ignored count, accepted/none/reverse direction/nil do not.
- [ ] `app/controllers/invite_links_controller.rb` -- in `show`, after the owner is found and the viewer is signed in and not the owner, set a `@relation` (`:friends`, `:invited` or nil) from `Game::FriendshipBetween` and `Game::InvitationAwaiting`.
- [ ] `app/views/invite_links/show.html.erb` -- add the two state branches (message + "To your friends" link) and put the send form inside an element with `data-controller="auto-submit"`.
- [ ] `app/frontend/lib/auto_submit.ts` + `auto_submit.test.ts` -- a pure `submitOnce(form, { preview })` that skips a preview or an already-submitted form, marks the form submitted, sets `data-turbo-action="replace"` and calls `requestSubmit()`; tested with a fake form.
- [ ] `app/frontend/controllers/auto_submit_controller.ts` -- on connect, finds the `form` in its element and calls `submitOnce` with the preview flag from `document.documentElement`.
- [ ] `config/locales/en.yml`, `config/locales/fr.yml` -- `invite_links.show.already_invited` and `already_friends` (with the name).
- [ ] `test/controllers/invitations_controller_test.rb` -- page carries the auto-submit controller around a POST form to the link; after a send, reopening shows "already sent" and no form; friends see "already friends" and no form; signed-out sign-in lands on a page with the auto-submit form; the GET writes nothing.

**Acceptance Criteria:**
- Given a signed-in player opening a friend's link for the first time, when the page loads, then it holds a POST form to the link inside the auto-submit controller and no invitation exists yet; posting it lands on Friends with the invitation listed as sent.
- Given a sent invitation, when the player opens the link again, then the page says it is already sent, links to Friends, and has no form, and the invitation count stays one.
- Given a signed-out visitor who signs in from the link, when the callback finishes, then they land on the link page with the auto-submit form.

## Implementation Notes

- All execution tasks built as mapped. `Game::InvitationAwaiting` (`packs/game/app/queries/game/invitation_awaiting.rb`) reads `Invitation.unanswered` from sender to recipient, false for nil without a query. `InviteLinksController#show` sets `@relation` (`:friends`, `:invited`, nil) only for a signed-in viewer who is not the owner; the unknown/banned branch now `return`s before it.
- The view moves the `friends__label` line into each branch: the signed-out, own-link and send branches print it as before, and the two new state branches replace it with a neutral `friends__message` ("Invitation déjà envoyée à Sam." / "Sam et vous êtes déjà amis.") and the existing "To your friends" secondary button. The send form sits in a `tag.div data-controller="auto-submit"`; `ButtonComponent` is unchanged.
- `submitOnce` marks the form with `data-auto-submitted` (so a restored Turbo snapshot, which keeps the attribute, is skipped too), sets `data-turbo-action="replace"` and calls `requestSubmit()`; the controller passes `html[data-turbo-preview]` as the preview flag.
- After review: when the owner has a pending invitation to the viewer, `relation_to` returns nil before the `InvitationAwaiting` check (read through `Game::InvitationsOf(...).received`), so a viewer whose own invitation was ignored still gets the auto-submit form, and the POST accepts the owner's invitation as `SendInvitation` does; covered by a controller test. The explanatory comments in `auto_submit.ts` and `auto_submit_controller.ts` were removed.
- Verified: `bin/rails test` 2371 runs (after the review patch), 0 failures; `npm run test:js` 229 passed; `tsc --noEmit`, `zeitwerk:check`, `packwerk check`, rubocop on the changed Ruby files clean; `i18n-tasks missing` clean (`i18n-tasks health` reports only a pre-existing interpolation mismatch on `back_office.seasons.index.confirm.one` and a pre-existing normalization notice).

## Plan Change Log

## Review Triage Log

### 2026-10-13 — Review pass
- verdicts: 4 findings — high 0, medium 1, low 3, false 0, maybe-false 0
- findings:
  - `[low]` `[patch]` `relation_to` answered `:invited` when the viewer's invitation was ignored and the owner has since sent a pending one, so the page said "already sent" where the POST would accept — `relation_to` now returns nil first when the owner has a pending invitation to the viewer (`Game::InvitationsOf(...).received`); controller test added.
  - `[medium]` `[defer]` A page on another site can send a signed-in player to a link (SameSite=Lax cookie, top-level GET), and the auto-submit then sends the invitation, or accepts the owner's pending one, without a click — the auto-send is what the ticket asks for (the author paired it with cancelling a sent invitation); invite links are opened from other sites (chat apps) by design, so the page cannot tell them apart. Recorded for the author in `deferred-work.md`.
  - `[low]` `[patch]` The comments in `auto_submit.ts` and `auto_submit_controller.ts` broke the AGENTS.md comment rule — both deleted.
  - `[low]` `[reject]` After Steam sign-in from a link, the welcome toast flashes on the invite page and is gone once it submits itself — cosmetic; the Friends screen confirms the sign-in worked by listing the invitation, and carrying the flash across would need a flash merge with the invitation's own message.

## Design Notes

The send goes through the page's own POST so no GET writes; Turbo honours `data-turbo-action` on a submitted form, so `replace` drops the invite page from history and Back never reopens it to submit again. A restored or previewed snapshot is guarded by `html[data-turbo-preview]` and by the server-side state branches.

## Verification

**Commands:**
- `bin/rails test` -- expected: all pass
- `npm run test:js` -- expected: all pass
- `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bin/rubocop`, `bundle exec i18n-tasks health` (if configured) -- expected: clean

## Auto Run Result

**Summary:** Opening an invite link signed in now sends the invitation by itself: the page's existing POST form sits in an `auto-submit` Stimulus controller that submits it once on load (never from a Turbo preview, replacing the page in history), and the button stays as the no-JavaScript fallback. The GET only reads. A signed-out visitor signs in through Steam, returns to the link (unchanged callback) and the page then submits itself. Reopening the link after sending (pending or ignored) says the invitation is already sent, and a friend is told they are already friends; neither page carries a form. When the owner has a pending invitation to the viewer, the form is shown and the POST accepts it.

**Files changed:**
- `packs/game/app/queries/game/invitation_awaiting.rb` -- whether an unanswered invitation runs from one player to another.
- `app/controllers/invite_links_controller.rb` -- `show` reads the viewer's relation to the owner (friends, invited, or neither).
- `app/views/invite_links/show.html.erb` -- the two state branches and the auto-submit wrapper.
- `app/frontend/lib/auto_submit.ts`, `auto_submit.test.ts`, `app/frontend/controllers/auto_submit_controller.ts` -- submit once, never from a preview, replacing history.
- `config/locales/en.yml`, `config/locales/fr.yml` -- `invite_links.show.already_invited`, `already_friends`.
- `test/controllers/invitations_controller_test.rb`, `test/packs/game/invitation_awaiting_test.rb` -- request and query tests.
- `_bmad-output/initiative-gameble/deferred-work.md` -- the cross-site auto-send entry.

**Review:** quick lens, 4 findings. Patched 2 (low: reverse pending invitation read as "already sent"; low: comments against the AGENTS.md rule). Deferred 1 (medium: cross-site redirect sends or accepts without a click, a decision for the author). Rejected 1 (low: the welcome toast is lost after sign-in from a link; cosmetic, Friends confirms the outcome).

**Follow-up review recommended:** false (patched: high 0, medium 0, low 2).

**Verification:** `bin/rails test` 2371 runs, 0 failures; `npm run test:js` 229 passed; `bin/rails zeitwerk:check` all good; `bundle exec packwerk check` no offenses; `bin/rubocop` no offenses; `i18n-tasks missing` none; `tsc --noEmit` clean. No system test run or added; the auto-submit is covered by vitest and server-rendered markup checks, not a real browser.

**Residual risks:** the auto-submit has not run in a real browser; the cross-site auto-send deferred above.
