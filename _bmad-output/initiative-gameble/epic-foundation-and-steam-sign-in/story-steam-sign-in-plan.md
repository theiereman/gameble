---
title: 'Steam sign-in'
type: 'feature'
ticket: '6'
created: '2026-10-02'
status: 'built'
baseline_revision: 'a47113e550be5373b4c63d456a2a1f15d0a47977'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md'
  - '{project-root}/_bmad-output/initiative-gameble/spec-gameble/brotherhood-tone.md'
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** Nobody can have an account. CAP-1 and AD-14 require Steam as the only sign-in: a visitor signs in with Steam, becomes a player, signs in again as the same player, with no stored password and a session that is an encrypted cookie holding the player id.

**Approach:** Add OmniAuth with `omniauth-openid` against Steam's OpenID 2.0 endpoint. `Steam` turns the verified OpenID response into a Steam id; the web layer hands that id to `Accounts::SignIn`, which creates or reuses the player and publishes `Accounts::PlayerRegistered` on creation. The session stores the player id. The status band shows a Steam sign-in button when signed out and a sign-out button when signed in.

## Boundaries & Constraints

**Always:**
- Gems from the Stack table: `omniauth ~> 2.1.4`, `omniauth-openid ~> 2.0.2`, `omniauth-rails_csrf_protection ~> 2.0.1`; plus `rexml` (Ruby 4 no longer bundles it and `ruby-openid` requires it), added to the Stack table with its version.
- `ruby-openid` must verify Steam's TLS certificate: set `OpenID.fetcher.ca_file` to the system CA bundle (`OpenSSL::X509::DEFAULT_CERT_FILE`). By default it does not verify.
- Replay protection works across processes: the OpenID store is a small `Steam` class backed by `Rails.cache` whose `use_nonce` writes with `unless_exist` and returns false for a nonce already seen; nonce skew is 5 minutes.
- The sign-in request phase is POST only, CSRF-protected (`omniauth-rails_csrf_protection`).
- A Steam id is accepted only from a claimed id of the exact form `https://steamcommunity.com/openid/id/<17 digits>`; anything else is a failure.
- Dependency direction (AD-2): `Steam` knows nothing of `Accounts`; the web layer calls both. `Accounts::SignIn` is an `ApplicationOperation`; its failures have keys under `errors.accounts.*` in both locales.
- Players: table `accounts_players` with `steam_id` (string, not null, unique index) and a public random `token` (not null, unique index, AD-15), timestamps. No name, avatar or password column.
- `ApplicationRecord` moves from `app/models` to the `lib` package so pack models can inherit it (Packwerk: packs may depend on `lib`, never on the root).
- Signing in resets the session (no fixation) then stores only `player_id`. Signing out resets the session.
- All copy (buttons, flash messages) in `en.yml` and `fr.yml`, Brotherhood tone.

**Never:**
- No Steam Web API call (names, avatars): later epic. No ban check, roles or policies (story 1.7). No attic page (story 1.8). No rate limit (story 1.9).
- No other sign-in method, no password, no email.
- No event handler for `PlayerRegistered` (the pack bank comes with epic 3).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| First sign-in | callback with claimed id `https://steamcommunity.com/openid/id/76561197960287930`, no player with that Steam id | one player created with a token; one `Accounts::PlayerRegistered` event carrying only the player id; session holds the player id; redirect home with a welcome flash | No error expected |
| Returning sign-in | same callback, player exists | no new player, no new event; session holds the existing player's id | No error expected |
| Malformed claimed id | callback with uid `https://evil.example/openid/id/123` | no player, no event, signed out | redirect home with a failure flash from `errors.accounts.*` or `errors.steam.*` |
| OpenID failure | OmniAuth failure (cancelled, invalid response) | no player, signed out | `/auth/failure` redirects home with a failure flash |
| Sign-in by GET | `GET /auth/steam` | not started | 404 (OmniAuth POST only) |
| Sign out | `DELETE /session` while signed in | session reset; status band shows the sign-in button | No error expected |
| Replayed nonce | the store's `use_nonce` called twice with the same server, timestamp and salt | first call true, second false | Response rejected by ruby-openid |

</intent-contract>

## Code Map

- `app/models/application_record.rb` -- `primary_abstract_class`; move to `lib/application_record.rb` (autoloaded through `config.autoload_lib`, package `lib`).
- `lib/application_operation.rb` -- base operation (`transaction`, `publish(event, stream_name:)`, `failure_key`); see `test/lib/application_operation_test.rb` for the pattern. Nested operations are called through `step`.
- `lib/package.yml`, `packs/{accounts,steam}/package.yml` -- `accounts` depends on `lib` only; `steam` on `catalog` and `lib`. Each pack has `app/models/.keep`; packs-rails loads `packs/<pack>/app/*` as autoload roots, so `packs/accounts/app/models/accounts/player.rb` defines `Accounts::Player` and `packs/accounts/app/operations/accounts/sign_in.rb` defines `Accounts::SignIn`.
- `config/initializers/event_store.rb` -- `Rails.configuration.event_store` (JSON client); events subclass `RubyEventStore::Event`.
- `config/routes.rb` -- `/up`, `scope ":locale"` with `root "pages#home", as: :home`, and `root "locales#redirect"`. OmniAuth paths (`/auth/steam`, `/auth/steam/callback`, `/auth/failure`) live outside the locale scope.
- `app/controllers/application_controller.rb` -- `switch_locale` (validated param), `default_url_options` adds `locale`; `allow_browser versions: :modern`.
- `app/views/layouts/application.html.erb` -- status band `<header class="status-band">` with a gauge `<section>` and a counters `<section>`; add the sign-in / sign-out control to the counters side and a flash region above `<main>`.
- `app/components/button_component.rb` -- `variant:`, `href:`, `type:`; renders a link or a `<button>`. A POST sign-in needs a form (`button_to`); give the component or the layout what it needs without breaking existing callers.
- `config/environments/test.rb` -- `raise_on_missing_translations = true`; test cache store is `:null_store`.
- `config/environments/production.rb` -- cache store is Solid Cache. Confirm Solid Cache honours `unless_exist`; if it does not, record it and use an atomic alternative in `Steam`.
- `db/schema.rb` -- committed; CI fails on drift. strong_migrations checks new migrations.
- OmniAuth test mode -- `OmniAuth.config.test_mode = true` and `OmniAuth.config.mock_auth[:steam]` let integration tests drive the callback without Steam.

## Tasks & Acceptance

**Execution:**
- [x] `Gemfile`, `Gemfile.lock`, `architecture-gameble.md` -- add the four gems; Stack row for `rexml` -- sign-in stack
- [x] `lib/application_record.rb` (moved from `app/models/`) -- pack models inherit it
- [x] `db/migrate/*_create_accounts_players.rb`, `db/schema.rb` -- the players table -- AD-15, CAP-1
- [x] `packs/accounts/app/models/accounts/player.rb` -- `has_secure_token :token`, validations -- the player
- [x] `packs/accounts/app/events/accounts/player_registered.rb` -- event with `player_id` only -- AD-10
- [x] `packs/accounts/app/operations/accounts/sign_in.rb` -- `call(steam_id:)`: validate the id, find or create the player safely under concurrency (unique index), publish on creation -- AD-3
- [x] `packs/steam/app/models/steam/sign_in_identity.rb` -- plain Ruby class; turn an OmniAuth auth hash into a Steam id or a failure code -- AD-4, AD-14
- [x] `packs/steam/app/models/steam/open_id_store.rb` -- `OpenID::Store::Interface` on `Rails.cache`; stateless: associations are not kept -- replay protection
- [x] `config/initializers/omniauth.rb` -- the `:open_id` provider named `steam`, identifier `https://steamcommunity.com/openid`, the store above, CA file, nonce skew, failure endpoint -- one place for sign-in config
- [x] `config/routes.rb`, `app/controllers/sessions_controller.rb` -- callback (Steam id → `Accounts::SignIn` → session), failure, `DELETE /session` -- web layer orchestrates
- [x] `app/controllers/application_controller.rb` -- `current_player` from `session[:player_id]`, exposed to views -- signed-in state
- [x] `app/views/layouts/application.html.erb`, `app/components/button_component.*` (a form mode for POST and DELETE, existing callers unchanged) -- sign-in / sign-out control in the status band; flash region -- the visible path
- [x] `config/locales/{en,fr}.yml` -- button labels, flashes, `errors.accounts.*`, `errors.steam.*` -- AD-18
- [x] tests: `test/packs/accounts/sign_in_test.rb` (operation: success, reuse, each failure), `test/packs/steam/*_test.rb` (identity parsing, store nonce), `test/controllers/sessions_controller_test.rb` (every web matrix row) -- AD-22

**Acceptance Criteria:**
- Given OmniAuth test mode, when a visitor signs in twice with the same Steam id, then one player exists and the session holds its id both times.
- Given the status band, when signed out it shows the Steam sign-in button (a POST form), and when signed in it shows the sign-out button.
- Given the suite, when tests, Packwerk, i18n-tasks, RuboCop, zeitwerk, Brakeman and the migration drift check run, then all pass.

## Implementation Notes

- **Stateless OpenID needs no association request.** A store that keeps no association still let ruby-openid negotiate one at each sign-in (`AssociationManager#get_association` only skips when the store is `nil`). Steam would then sign with a shared key that, per OpenID 2.0 §11.4.2, it refuses to verify through `check_authentication`. `config/initializers/omniauth.rb` prepends a small module to `OpenID::Consumer::AssociationManager` that returns no association when the store answers `stateless?`. Verified against the real endpoint: the request log says "using stateless mode" and the redirect carries no `openid.assoc_handle`.
- **Solid Cache and `unless_exist`:** honoured (`write_entry` → `entry_lock_and_write`, `SELECT … FOR UPDATE` then upsert), but not atomic for a key that does not exist yet: two writers racing on the same new nonce can both see no row and both report a write. `increment` uses the same path, so it is no better. Kept `unless_exist` (AD-12: no direct Solid Cache call); the window is milliseconds, and every response is also verified by Steam's `check_authentication`, which per spec answers once per assertion. A strictly atomic guard would need a unique-index table in `Steam`.
- **Store built per request:** the provider's `setup` lambda sets `options[:store] = Steam::OpenIdStore.new`, so the reloadable Steam pack is not autoloaded at boot.
- **OmniAuth failures redirect in every environment:** `on_failure` calls `FailureEndpoint#redirect_to_failure` directly (the default raises in development).
- **Return page and locale (review fix):** the sign-in form posts `origin` = the current request path. Success and failure redirect to it only when it is a local path whose first segment is a locale (`SessionsController::ORIGIN_PATH`), else to home; the flash locale is that segment's. A CSRF failure in the request phase has no origin and falls back to home in the default locale.
- **Login CSRF (review fix):** `OmniAuth.config.before_request_phase` (after the CSRF check) sets `steam_sign_in_started` in the session; `SessionsController#create` consumes it and refuses a callback without it.
- **Failures keep the session (review fix):** only a successful sign-in resets the session; a failed, cancelled or forged one leaves a signed-in player signed in.
- **`current_player`** reads through `Accounts::PlayerById` (AD-3).
- **Nonce TTL (review fix):** a nonce key expires at its timestamp + skew + 1 minute, after the last moment it can be accepted.
- **No uniqueness validation on `Accounts::Player#steam_id`:** a validation would race and raise `RecordInvalid` instead of the index conflict `create_or_find_by!` recovers from.
- **`ButtonComponent`** gained `method:`, `params:` and `turbo:`; with an href and a method it renders `button_to` (form class `button-form`). The sign-in form sets `data-turbo=false` because its response leaves the site.
- **Flash region** renders only when there is a flash, so `body > header.status-band + main` holds on a plain page.
- Steam's return URL carries `?_method=post` (hard-coded by omniauth-openid); Rails only overrides the method of POST requests, so the callback stays a GET.

## Plan Change Log

## Review Triage Log

### 2026-10-02 — Review pass
- verdicts: 5 findings — high 1, medium 1, low 3, false 0, maybe-false 0
- findings:
  - `[high]` `[patch]` Login CSRF: nothing tied the callback to the browser that started the sign-in, so an attacker's unused callback URL could sign a victim in as the attacker — `before_request_phase` (after the CSRF check) leaves a one-time session marker that `create` requires and consumes; tests cover a callback without it and a reused one.
  - `[medium]` `[patch]` `GET /auth/failure` and failing callbacks called `reset_session`, so a plain link signed a player out — failure paths keep the session; only a successful sign-in resets it.
  - `[low]` `[patch]` EXPERIENCE.md Flow 1 returns a refused or cancelled sign-in to the page the visitor was on, but every outcome redirected home — the form posts `request.path`, and success and failure redirect there only when it is a local path under a valid locale, else home; external and malformed origins are tested.
  - `[low]` `[patch]` `current_player` read `Accounts::Player` from the web layer, against AD-3 — new query `Accounts::PlayerById` owned by the pack.
  - `[low]` `[patch]` The nonce cache key could expire exactly when a future-dated nonce stopped being accepted — the key now expires at nonce time + skew + one minute; a test replays at the last accepted second.

## Design Notes

Production check (hitl, by the author once deployed): sign in on the production URL with a real Steam account, then again; one player, same id. The OmniAuth `full_host` follows the request host, so the return URL is the production host behind Cloudflare; if Cloudflare terminates TLS, Rails must see `https` (`config.assume_ssl`).

Over OpenID, Steam returns only the claimed id (the OmniAuth `uid`); it sends no profile data.

## Verification

**Commands:**
- `bin/rails test` -- expected: all green
- `RAILS_ENV=test bin/rails db:drop db:create db:migrate && git diff --exit-code -- db/schema.rb` -- expected: no strong_migrations error; no drift once the schema is committed (before committing, the regenerated schema equals the development one)
- `bundle exec packwerk validate && bundle exec packwerk check` -- expected: clean
- `bundle exec i18n-tasks missing` -- expected: none
- `bin/rubocop && bin/rails zeitwerk:check && bin/brakeman -q --no-pager` -- expected: clean

**Manual checks (if no CLI):**
- With `bin/dev` and network access, pressing the sign-in button redirects to `steamcommunity.com/openid/login` with `openid.return_to` pointing at `/auth/steam/callback`.

## Auto Run Result

**Summary:** Steam is the only sign-in, through OmniAuth and omniauth-openid in stateless mode with TLS verification and a shared, replay-safe nonce store. `Steam::SignInIdentity` turns the verified claimed id into a Steam id; the web layer hands it to `Accounts::SignIn`, which creates or reuses the player (random public token, unique Steam id) and publishes `Accounts::PlayerRegistered` on creation. The session holds only the player id. The status band shows the sign-in or sign-out button; sign-in failures keep the session and return to the starting page.

**Files changed:**
- `Gemfile`, `Gemfile.lock`, `architecture-gameble.md` -- omniauth, omniauth-openid, omniauth-rails_csrf_protection, rexml (Stack row)
- `lib/application_record.rb`, `lib/package.yml` -- `ApplicationRecord` moved to the `lib` package
- `db/migrate/20261002154023_create_accounts_players.rb`, `db/schema.rb` -- `accounts_players`
- `packs/accounts/app/{models,events,operations,queries}/accounts/*` -- player, event, sign-in operation, `PlayerById` query
- `packs/steam/app/models/steam/{sign_in_identity,open_id_store}.rb` -- claimed id parsing, nonce store
- `config/initializers/omniauth.rb` -- provider, CA file, nonce skew, stateless associations, sign-in marker
- `config/routes.rb`, `app/controllers/{sessions,application}_controller.rb` -- callback, failure, sign-out, `current_player`
- `app/views/layouts/application.html.erb`, `app/components/button_component.*`, `app/frontend/entrypoints/application.css` -- sign-in / sign-out control, flash region
- `config/locales/{en,fr}.yml` -- labels, flashes, errors
- `test/packs/**`, `test/controllers/sessions_controller_test.rb`, `test/components/button_component_test.rb` -- matrix rows and review fixes

**Review findings:** 5 patches applied (1 high, 1 medium, 3 low); 0 deferred; 0 rejected.

**Follow-up review recommended:** true — a high (login CSRF on the callback) was patched. The risk to check: the one-time marker set in `before_request_phase` must survive the round trip to Steam and be the only way into `create`, including under the stateless association patch.

**Verification:** `bin/rails test` (88 runs, 0 failures), system tests (3 runs), migrations from scratch without strong_migrations errors and the schema matching development, Packwerk, i18n-tasks, RuboCop, zeitwerk, Brakeman, typecheck clean. Against the real Steam endpoint, `POST /auth/steam` redirects to `steamcommunity.com/openid/login` in stateless mode with no TLS warning; `GET /auth/steam` is 404.

**Residual risks:**
- Production check still owed by the author (hitl): a real Steam sign-in on the production URL, twice. If Cloudflare terminates TLS, `config.assume_ssl` is needed for the return URL.
- `config/initializers/omniauth.rb` prepends onto `OpenID::Consumer::AssociationManager`, an internal of ruby-openid 2.9.2.
- Nonce replay protection via `Rails.cache` with `unless_exist` is not strictly atomic under a race of milliseconds.
- A running `bin/dev` must be restarted.
