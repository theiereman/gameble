---
title: 'A sent invitation names the player, not their friend code'
type: 'bugfix'
ticket: ''
created: '2026-10-09'
status: 'built'
baseline_revision: 'fe2ecfd221e8c5945d582a2fe0c102324279a977'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** On the Friends screen a sent invitation reads "Envoyée à C8DD-6KST": the recipient's friend code, even when the invitation came from an invite link whose page already showed the player's name. A code sent from the code field also confirms with "Invitation envoyée à 8F2D-K9XM." rather than who it went to.

**Approach:** Name the recipient wherever a sent invitation is shown: the pending row and the confirmation line after sending by code. Fall back to the friend code only when the player has no usable name. Update the matching example lines in `EXPERIENCE.md`. Sending directly from an invite link and cancelling a sent invitation are a separate build.

</frozen-after-approval>

## Tasks & Acceptance

**Execution:**
- [ ] `app/helpers/friends_helper.rb` -- add a helper that returns the cleaned persona name, or the given friend code when the player has none -- one rule for the row and the confirmation
- [ ] `app/views/friends/show.html.erb` -- the sent row uses that helper (`sent_to` interpolates a name) -- the bug
- [ ] `app/controllers/invitations_controller.rb` -- on success, confirm with the recipient's name (code fallback) instead of the typed code -- the code path confirms who was invited
- [ ] `config/locales/en.yml`, `config/locales/fr.yml` -- `friends.show.sent_to` takes `%{name}` -- the string no longer names a code
- [ ] `test/controllers/invitations_controller_test.rb` -- code-sent row and line show "Sam"; link-sent row shows "Sam"; a nameless recipient's row shows the code
- [ ] `_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md` -- "Envoyée à 8F2D-K9XM" → "Envoyée à Sam", "Invitation envoyée à 8F2D-K9XM." → "Invitation envoyée à Sam."

**Acceptance Criteria:**
- Given Lea invited Sam by link or by code, when Lea opens the Friends screen, then the pending row reads "Envoyée à Sam · En attente".
- Given Lea sends a valid code belonging to Sam, when the screen reloads, then the line under the field reads "Invitation envoyée à Sam."
- Given the recipient has no usable persona name, when the sender opens the Friends screen, then the row shows the recipient's friend code.

## Implementation Notes

Oneshot: about 30 lines over a helper, a view, a controller, two locale files and one test file.

- `FriendsHelper#invited_name(player, code)`: the cleaned persona name, else the code, else the nameless label.
- `InvitationFeedback#report_sent` no longer takes the name from its caller; it reads the recipient and their friend code from the sent invitation, so the code and link paths confirm the same way.
- `DESIGN.md` carried the same "Envoyée à 8F2D-K9XM" example as `EXPERIENCE.md`; both now read "Envoyée à Sam".

## Plan Change Log

## Review Triage Log

Quick review, 3 findings: 1 medium patched, 1 low patched, 1 rejected.
- medium, patch: a nameless player invited by link was confirmed as "Officier sans nom" while the row showed their code. `report_sent` now reads the recipient's code with `Game::FriendCodeOf`; a link test with a nameless recipient covers it.
- low, patch: `DESIGN.md` line 819 still showed "Envoyée à 8F2D-K9XM". Updated to "Envoyée à Sam".
- low, rejected: the nameless fallback in `invited_name` is unreachable while every player has a friend code. It is a one-term guard against a missing code, and removing it would render "Envoyée à " in that state.

## Verification

**Commands:**
- `bin/rails test test/controllers/invitations_controller_test.rb test/helpers` -- expected: green
- `bundle exec i18n-tasks missing && bundle exec i18n-tasks unused` -- expected: no new findings
