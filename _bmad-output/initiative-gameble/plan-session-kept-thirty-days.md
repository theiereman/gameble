---
title: 'Players stay signed in for 30 days after their last visit'
type: 'feature'
ticket: ''
created: '2026-10-10'
status: 'built'
baseline_revision: '23662bed5b42a1de7f3e74ec47560dad6c6278ce'
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

**Problem:** The session cookie (Rails' default cookie store, no `expire_after`) is a browser-session cookie: closing the browser signs the player out. The author wants players to stay signed in across browser restarts.

**Decision (author, 2026-10-10):** The session lasts 30 days, sliding: each visit pushes the expiry 30 days further; sign-out still ends it at once. It stays an encrypted, HttpOnly cookie. Local storage was considered and rejected: any script on the page can read it, it is never sent with server-rendered requests, and it is no safer "strictly necessary" storage than a cookie.

**Approach:** Configure the session store in `config/initializers/session_store.rb`: cookie store, the key Rails uses today (`_gameble_session`) so existing sessions survive, `expire_after: 30.days`; keep the current same_site (Lax) and HttpOnly defaults, and rely on production's `force_ssl` for the Secure flag. Update the privacy notice's cookie sentence in both locales ("keeps you signed in for 30 days after your last visit, or until you sign out" / "vous garde connecté pendant 30 jours après votre dernière visite, ou jusqu'à la déconnexion"), the rest unchanged, and bump `pages.legal.updated` to 10 October 2026. Update the spec or architecture only if one states the session ends when the browser closes.

**Tests:** an integration test that a sign-in response sets the session cookie with an expiry about 30 days ahead, that a later request pushes it forward (`travel`), and that sign-out clears it. The legal page test stays green.

**Assumptions (author unavailable, recorded by the builder):**
- Neither `spec-gameble/` nor `architecture-gameble.md` says the session ends when the browser closes (AD-14 says only "an encrypted cookie holding only the player id"), so no planning document changes.
- Every response to a request carrying a non-empty session rewrites the cookie with a fresh expiry (rack-session forces the write when `expire_after` is set), so a signed-out visitor's session (flash, sign-in marker) also lasts 30 days; it holds no player id.
- No `secure:` option: `force_ssl` already flags every cookie Secure in production, and setting it would stop development over plain HTTP from keeping a session.

</frozen-after-approval>

## Implementation Notes

Oneshot: one initializer line, two locale strings, two test assertions on the legal date and a handful of session tests, well under 100 lines.

- `config/initializers/session_store.rb` (new): cookie store, key `_gameble_session` (checked with `Rails.application.config.session_options` before the change: the same key, `cookie_only: true`, same_site Lax), `expire_after: 30.days`. CookieStore still defaults same_site to Lax and HttpOnly; production's `force_ssl` keeps flagging it Secure.
- Sliding works without code: with `expire_after` set, rack-session 2.1 commits any non-empty session on every response (`force_options?`), so the cookie gets a fresh `expires` on each visit even when its data did not change. Rails also seals the expiry into the encrypted cookie's metadata, so a copied cookie replayed after 30 days is refused server-side.
- A GET that rewrites the cookie writes no row; `ReadOnlyRequestsTest` and the full suite stay green.
- Sign-out (`SessionsController#destroy`), account deletion (`AccountsController#destroy`) and the ban check in `ApplicationController#current_player` all keep working unchanged: `reset_session` / `session.delete(:player_id)` drop the player id and the next response rewrites the cookie without it. The Steam sign-in marker (`steam_sign_in_started`) and the presence mark ride in the same session, unaffected; rate limits key on the player or IP, not the session.
- `config/locales/en.yml`, `config/locales/fr.yml`: `pages.legal.privacy.cookies` sentence and `pages.legal.updated` (10 October 2026).
- `test/controllers/pages_controller_test.rb`: the two `.legal__updated` assertions.
- `test/controllers/sessions_controller_test.rb`: five tests (sign-in sets a 30-day HttpOnly Lax cookie; a later visit, and a further one that leaves the session data unchanged, push the expiry forward; away more than 30 days is signed out; an expired cookie replayed is refused; sign-out ends the session at once). Four of them fail with the initializer removed (checked); the sign-out one guards the existing behaviour.
- No planning document says the session ends when the browser closes, so none changed.

## Review Triage Log

Quick lens, run by the builder itself: no subagent tool was available in this run and the author was not, so the context-free reviewer could not be launched separately. Counts: high 0, medium 0, low 1 (patched), false 1.

- low, patched: the sliding test's later visit also wrote the presence mark, so it did not show that a visit leaving the session data unchanged still pushes the expiry. Added a second visit 30 seconds later (inside the presence throttle) asserting the fresh expiry.
- false: "existing signed-in players are signed out by the deploy". The key stays `_gameble_session` (read from `session_options` before the change) and a cookie without expiry metadata still decrypts; its first response rewrites it with the 30-day expiry.

## Verification

**Commands:**
- `bin/rails test` -- expected: green
- `bin/rails test test/system/shell_test.rb test/system/settings_test.rb` plus system tests covering sign-in/sign-out -- expected: green
- `npm run test:js`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bin/rubocop`, `bundle exec i18n-tasks missing`, `bundle exec i18n-tasks unused` -- expected: clean

## Auto Run Result

Environment: Postgres 16 on 5432 (no Docker), Ruby 4.0.7. `RAILS_ENV=test bin/rails db:prepare` left `db/schema.rb` unchanged; `npm install` touched `package-lock.json`, restored with `git checkout`.

- `bin/rails test` -- 2156 runs, 24763 assertions, 0 failures, 0 errors, 0 skips
- `bin/rails test test/controllers/sessions_controller_test.rb test/controllers/read_only_requests_test.rb` (after the review patch) -- 59 runs, 0 failures
- `bin/rails test test/system/shell_test.rb test/system/settings_test.rb test/system/hub_test.rb test/system/public_profile_test.rb test/system/card_detail_test.rb test/system/share_card_test.rb test/system/trades_test.rb` (every system test that signs out) -- 85 runs, 854 assertions, 0 failures
- `npm run test:js` -- 24 files, 217 tests passed
- `bin/rails zeitwerk:check` -- All is good
- `bundle exec packwerk check` -- No offenses
- `bin/rubocop` -- 654 files, no offenses
- `bundle exec i18n-tasks missing` -- none missing
- `bundle exec i18n-tasks unused` -- none unused
