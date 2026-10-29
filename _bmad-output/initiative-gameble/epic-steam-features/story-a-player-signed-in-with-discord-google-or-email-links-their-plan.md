---
title: 'A player signed in with Discord, Google or email links their Steam account from the settings'
type: 'feature'
ticket: '2'
created: '2026-10-29'
status: done
baseline_revision: 'b2502b00996838fd84ad97296549a0ff59fc2732'
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

**Problem:** A player who signed in with Discord, Google or an email code cannot attach Steam: the Steam return only signs in or creates a player, so signing in with Steam gives them a second account, and future Steam features need a Steam identity on the player.

**Approach:** A Link Steam button in the settings' sign-ins row, shown only to a player without a Steam identity, records a link intent and starts the Steam sign-in; the Steam return, with a signed-in player and that intent, adds the Steam identity to that player through a new `Accounts::AddSteamSignIn` and returns to the settings without opening a new session. A Steam id held by another player is refused with a clear message; accounts are never merged.

## Boundaries & Constraints

**Always:** the write goes through `Accounts::AddSteamSignIn`, which publishes only the `IdentityAdded` that `Accounts::AddIdentity` already publishes; the persona lookup stays in the web layer (Accounts never calls Steam); the intent action is a POST with a Pundit policy; the intent is consumed by the Steam return and by the failure path, so a stale intent never turns a later sign-in into a link; every new string in `en.yml` and `fr.yml`, the error key added by hand to both.

**Never:** an account merge; a new session or `reset_session` on the link path; a change to `AddIdentity`'s rules, to the login CSRF marker check or its order, or to `skip_forgery_protection` on the callback; a new row in the settings list (the button lives inside the Sign-ins row).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Link | Clerk player, no Steam identity, Steam id unused | Back on the settings, Steam listed among sign-ins, notice "Steam linked", same session, persona name taken from Steam when the lookup answers | No error expected |
| Already linked | Same player, same Steam id already on it | Back on the settings, notice that Steam is already linked, no new row | No error expected |
| Taken | Steam id on another player (identity row or legacy `steam_id`) | Back on the settings, nothing linked, still signed in as the same player | Alert: this Steam account already belongs to another gameble account |
| No intent | Normal Steam sign-in | Unchanged sign-in flow | Unchanged |
| Intent, signed out | Intent in session but no current player (session expired, banned) | Normal sign-in flow; intent dropped | Unchanged |
| Steam cancelled | `/auth/failure` with an intent | Back to the origin with the existing failure alert; intent dropped | Existing `fail_sign_in` |
| Steam player | Player already has a Steam identity | No Link Steam button | — |

</frozen-after-approval>

## Code Map

- `app/domains/accounts/app/operations/accounts/add_clerk_sign_in.rb` -- model for the new operation: lock player `FOR NO KEY UPDATE`, re-check, `refuse_taken`, skip `AddIdentity` when the exact identity exists
- `app/domains/accounts/app/operations/accounts/add_identity.rb` -- `call(player:, provider:, uid:)`; for steam refuses a player that has any steam identity or a `steam_id` held elsewhere; sets `player.steam_id`; publishes `IdentityAdded`. Do not change.
- `app/domains/accounts/app/operations/accounts/sign_in_through_identity.rb:94-98` -- `store_persona_name` (clean, update only when different); reuse the same rule
- `app/controllers/sessions_controller.rb` -- `create` (marker check l.16, `steam_id_from` l.18, session opening l.27-33), `failure` l.37, `persona_name_or_nil` l.58-69, `fail_sign_in` l.75
- `config/initializers/omniauth.rb:36` -- `before_request_phase` sets the login marker; `/auth/steam` is POST-only middleware with CSRF protection
- `app/components/steam_sign_in_component.html.erb` -- how `/auth/steam` is posted (`origin` param, `data-turbo=false`)
- `app/controllers/sign_in_methods_controller.rb`, `app/policies/sign_in_method_policy.rb` -- model for the intent action and policy (`player?`), redirect with notice/alert `status: :see_other`
- `app/controllers/settings_controller.rb:16-18`, `app/views/settings/show.html.erb:70-84` -- `@identities`; the sign-ins row
- `config/initializers/rack_attack.rb:17` -- `SignInThrottle::CLERK_POST_PAGES`; `test/integration/rate_limit_test.rb:58`
- `config/locales/en.yml` / `fr.yml` -- `errors.accounts` (en l.829, fr l.2162), `sign_in_methods.create`, `settings.show.sign_ins`
- Tests to model: `test/domains/accounts/add_clerk_sign_in_test.rb`, `test/controllers/sign_in_methods_controller_test.rb`, `test/controllers/settings_name_test.rb` (`sign_in_through_clerk`), `test/controllers/sessions_controller_test.rb` (marker tests l.253-292, `stub_player_summary`), `test/support/steam_sign_in.rb`, `test/system/settings_test.rb`; `settings_controller_test.rb:132` pins the row labels

## Tasks & Acceptance

**Execution:**
- [ ] `app/domains/accounts/app/operations/accounts/add_steam_sign_in.rb` -- `call(player:, steam_id:, persona_name:)`: lock, `Failure(:steam_taken)` when another player holds the id (identity or `steam_id`), success without a write when this player already has it, else `AddIdentity` provider steam and store the cleaned persona name -- the single write path
- [ ] `app/controllers/steam_links_controller.rb`, `app/policies/steam_link_policy.rb`, `config/routes.rb` -- `post "settings/steam"`: set `session[:steam_link]`, then `redirect_to "/auth/steam", status: :temporary_redirect` so the browser re-posts the form (token and `origin` = settings path) -- records the intent behind a policy
- [ ] `app/controllers/sessions_controller.rb` -- after the marker check and the Steam id read: when the intent is present and `current_player` is set, look up the persona, call `AddSteamSignIn`, redirect to the settings with a notice or alert; delete the intent in `create` and `failure`
- [ ] `app/views/settings/show.html.erb` -- Link Steam button in the sign-ins row when `@identities.none? { it.provider == "steam" }`, posting with `data-turbo=false`
- [ ] `config/initializers/rack_attack.rb` -- the new POST joins the throttled sign-in pages
- [ ] `config/locales/en.yml`, `config/locales/fr.yml` -- button label, linked and already-linked notices, `errors.accounts.steam_taken`
- [ ] Tests -- operation test (link, already linked, taken by identity, taken by legacy `steam_id`, removed player); controller tests for the intent action (policy, signed out) and the sessions link branch (link, taken, no current player, failure drops the intent); rate-limit list; system test: a Steam-signed-in player whose Steam identity is removed in setup links another mocked Steam id and sees Steam listed

**Acceptance Criteria:**
- Given a Clerk player in the settings, when they click Link Steam and come back from Steam, then they are on the settings, still signed in as themselves, Steam is listed, and no second player exists.
- Given the button rendered in French, when the page loads, then its label and the outcome toasts are in French.

## Design Notes

The 307 hand-off keeps the intent behind a controller and its policy while `/auth/steam` stays the only place that starts OpenID. If the re-posted request fails OmniAuth's CSRF check, fall back to posting straight to `/auth/steam` with a `link` param and setting the intent in `before_request_phase` only for a signed-in session, and record why in Implementation Notes.

## Verification

**Commands:**
- `bin/rails test test/domains/accounts test/controllers test/integration/rate_limit_test.rb` -- expected: no failures
- `bin/rails test test/system/settings_test.rb` -- expected: no failures
- `bundle exec packwerk check && bundle exec rubocop && bundle exec i18n-tasks health && script/check_planning_references && script/check_file_sizes` -- expected: clean

## Implementation Notes

- The settings form posts with the global authenticity token (`form_with ... authenticity_token: form_authenticity_token`), not `button_to`: per-form tokens (`load_defaults 8.1`) are bound to `/en/settings/steam` and OmniAuth would refuse them at `/auth/steam`. `test/integration/steam_open_id_test.rb` proves the 307 hand-off with forgery protection on, through the real OpenID flow.
- `SignInThrottle::CLERK_POST_PAGES` became `LOCALIZED_POST_PAGES`, since it now lists `settings/steam` too.

## Plan Change Log

- Review finding (high): a link intent left in the session by an abandoned Steam page let a forged Steam return, made by an attacker for their own Steam id, link that Steam id to the victim. Amended in place rather than reverted, the rest of the build being sound: the intent is a random nonce, the 307 goes to `/auth/steam?link=<nonce>`, OmniAuth carries the query into Steam's signed `return_to`, and the link runs only when the return's `link` matches the session's nonce (a mismatch fails the sign-in; a return without `link` stays a sign-in and links nothing). KEEP: the operation, the policy, the global-token form, the consumption of the intent in `create` and `failure`.

## Review Triage Log

Quick review, one pass: 1 high, 1 low, both patched.

- high, patched (see Plan Change Log): forged Steam return linked to a victim holding a stale intent; tests cover the return without `link` and a replayed return after a cancel.
- low, patched: `AddSteamSignIn` linked a player whose own legacy `steam_id` differed, and the system test built that state; the operation now answers `identity_taken`, the system test clears `steam_id`, an operation test covers the refusal.
