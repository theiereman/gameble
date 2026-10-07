---
title: 'Profile visibility setting'
type: 'feature'
ticket: '2'
created: '2026-10-07'
status: 'built'
baseline_revision: 'fa1676d08778595dc0c244091066abb7b0b49786'
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

**Problem:** Every profile is public; a player cannot control who sees their collection (R1, CAP-14).

**Approach:** A `visibility` column on the player (public by default), set from the settings screen by a radio group applied at once through `Accounts::SetVisibility`. `Game::Visibility.visible?(viewer, owner)` is the single question; the public profile asks it and renders the same "not available" page for an unknown, banned or hidden owner.

## Boundaries & Constraints

**Always:** the owner always sees their own profile; a banned or missing owner is never visible; "friends only" counts no friend until epic 5 (so it behaves like private for everyone but the owner); strong_migrations rules (default + NOT NULL in one safe add, the check constraint added `validate: false` then validated in a second migration); English copy translated from the French.

**Never:** a second visibility check anywhere else; storing visibility on feed entries; export, deletion, reports (other stories); showing an owner on the shared card page.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected | Error Handling |
|----------|--------------|----------|----------------|
| Public | owner public, any viewer | profile shown | none |
| Private / friends only | visitor, stranger, banned-owner page | 404 "not available" page | same page as unknown token |
| Owner | owner private, viewer = owner | profile shown | none |
| Set | player, "private" | stored, redirected to settings | unknown value: `Failure(:invalid_setting)`, flash, nothing stored |
| Visitor sets | signed out | refused, sign_in_required | none |

</frozen-after-approval>

## Code Map

- `db/migrate/` -- two migrations: add `accounts_players.visibility` string default 'public' NOT NULL + check constraint not validated (expand); validate it (contract).
- `packs/accounts/app/models/accounts/player.rb` -- `enum :visibility` (prefix `visibility_`, `private` clashes with Ruby).
- `packs/accounts/app/operations/accounts/set_visibility.rb` -- new, modelled on `update_settings.rb` (Success(player) | Failure(:player_required | :invalid_setting)); `ApplicationOperation.failure_message`, locale `errors.accounts.*`.
- `packs/game/app/models/game/visibility.rb` -- new, `visible?(viewer, owner)`; `Game` depends on `Accounts`.
- `packs/accounts/app/models/accounts/public_profile.rb` -- drop `visible?` (moves to Game::Visibility); keep `code`.
- `app/controllers/public_profiles_controller.rb` (`load_owner`) -- ask `Game::Visibility`.
- `app/controllers/settings_controller.rb`, `config/routes.rb`, `app/policies/settings_policy.rb`, `app/views/settings/show.html.erb`, `app/frontend/styles/settings.css` -- the row: group of three submit buttons (`aria-pressed`, like the motion row), PATCH `/settings/visibility`, full page load like the motion row.
- `app/views/public_profiles/_summary.html.erb` -- the visibility line.
- `config/locales/{fr,en}.yml` -- copy; `test/**` -- tests.
- Shared card page (`cards_controller.rb`) names no owner (CAP-9): no change.

## Tasks & Acceptance

**Execution:**
- [ ] migrations, Player enum, `Accounts::SetVisibility`, `Game::Visibility` -- the domain
- [ ] controller, policy, route, settings row, summary line, CSS, locales -- the surface
- [ ] tests: operation, Game::Visibility, settings controller/policy (signed out), public profile controller (private, friends only, banned, owner), system test for the row

**Acceptance Criteria:**
- Given a private player, when a visitor, a stranger or anyone opens their profile or set page, then the unavailable page with 404 shows, identical to a missing token.
- Given a public player, the profile shows as before.
- Given the settings screen, choosing a visibility applies at once and the choice is marked.

## Implementation Notes

Decisions (author away, simplest option): (1) the shared card page has no owner in its URL or content, so it needs no "not available" state beyond the existing 404s; (2) `Accounts::PublicProfile.visible?` is removed, its single use goes to `Game::Visibility`; (3) the row is a group of three submit buttons with aria-pressed (the motion row's pattern), no new JS: role=radio without arrow keys would lie to assistive tech; (4) the owner still sees their own hidden profile (per the existing comment).

## Plan Change Log

## Review Triage Log

- medium, patch: no system test for the row -- added to test/system/settings_test.rb.
- medium, patch: role=radio without roving tabindex or arrows -- switched to aria-pressed buttons.
- low, patch: over-long comment line -- reflowed.

## Verification

**Commands:**
- `bin/rails test` (minus card_face_visual_test), `bin/rubocop`, `bin/packwerk check`, `bundle exec i18n-tasks health`, `npm run typecheck`, `npm run test:js` -- all green.
