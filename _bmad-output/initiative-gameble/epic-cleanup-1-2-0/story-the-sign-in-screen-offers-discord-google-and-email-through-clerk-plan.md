---
title: 'The sign-in screen offers Discord, Google and email through Clerk'
type: 'feature'
ticket: '7'
created: '2026-10-29'
status: 'built'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
baseline_revision: 'd52da79754bea9cd36a69cfc34755701962e7cc3'
route: 'full'
route_source: 'auto'
context: ['_bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** the sign-in screen offers only Steam; Discord, Google and email, the add-a-sign-in section and the erasure of a Clerk user do not exist yet.

**Approach:** Clerk proves the identity only. The sign-in screen renders server-side buttons for Discord and Google and a form for an email code; a small Stimulus controller loads Clerk's browser script on that screen only and starts the flow headless, since Clerk documents no flow for a server that never loads its script. Once Clerk holds a session, the browser posts to a callback; the server verifies the session token against Clerk's keys, reads the Clerk user and its verified external account and email through Clerk's Backend API, hashes the verified email, and calls the provider-neutral sign-in operation (or the add-identity operation for a signed-in player). The app keeps its own session. Erasing an account also deletes its Clerk user through a retried job.

## Boundaries & Constraints

**Always:** follow the adopted identity design (Clerk proves identity only, no merging of two existing players, a verified email already known is refused naming the provider, the email itself never stored); the Clerk script and its origins are allowed only on the sign-in and settings screens; the Clerk client takes an injectable adapter like the Steam Web API client; every string in both locales; staging uses the Clerk development instance and production the production instance, each with its own keys; the legal and privacy pages and the export name Clerk, the email hash and the processors.

**Never:** commit a Clerk key; trust the provider claimed by the browser (the provider and uid come from the Backend API read with the secret key); let the sign-in callback or the settings section write on a GET; rely on Clerk's automatic account linking; add React.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected | Error |
|---|---|---|---|
| Discord or Google sign-in | new verified account | new player with a generated handle | none |
| Returning sign-in | known provider uid | same player, session opened | none |
| Email code sign-in | verified address, unknown | new player under the `email` provider | none |
| Email already known | verified address matches another player's hash | refused, message names the provider to use | email_known_<provider> |
| Banned player | any identity | refused with the ban notice | banned |
| Unverified email | provider gives no verified address | account created without a hash | none |
| Clerk merged two providers into one user | the same Clerk user shows two external accounts | the provider used is the one the session token's external account names; if it cannot be told, refuse | invalid_identity |
| Add a sign-in | signed-in player completes Clerk for a free identity | row added, back to the settings | identity_taken, email_known |
| Forged callback | token missing, expired, wrong origin or wrong signature | refused, nothing written | invalid_identity |
| Erasure | player with a Clerk user | Clerk user deleted by a retried job, never blocking the erasure | job retries on a Clerk error |

</frozen-after-approval>

## Code Map

- `app/domains/accounts/app/` -- `Accounts::ClerkClient` (JWKS verification with the jwt gem, Backend API read of a user, user deletion over Faraday, injectable adapter), `Accounts::ClerkIdentity` (the provider, uid and verified email read from a Clerk user), `Accounts::DeleteClerkUserJob`, hook in `DeletePlayer` after commit
- `app/controllers/clerk_sessions_controller.rb`, `app/policies/clerk_session_policy.rb`, `config/routes.rb` -- POST callback for sign-in and for add-a-sign-in; throttles in `config/initializers/rack_attack.rb`
- `app/views/sign_ins/show.html.erb`, `app/frontend/controllers/clerk_sign_in_controller.ts`, `app/frontend/lib/clerk.ts` -- provider buttons and the email code form rendered by the server, the controller loads Clerk's script and starts the flow
- `config/initializers/content_security_policy.rb` -- Clerk script, API and image origins for the two screens only
- `app/views/settings/` and its controller/policy -- the "Add a sign-in" section listing the player's identities
- `config/locales/en.yml`, `fr.yml` -- strings, legal and privacy wording
- `config/clerk_secret_key.<destination>.key`, `.kamal/secrets.*`, `.github/workflows`, `docs/operations.md`, `RELEASING.md` -- secrets and publishable keys per destination
- `test/` -- client tests against a stubbed adapter, callback integration tests, system test of the screen with the script stubbed

## Tasks & Acceptance

**Execution:**
- [ ] Spike on the Clerk development instance with a real browser sign-in (needs the author): confirm the session token carries the user id, that the Backend API returns the external accounts with provider, provider user id and verification, and what happens when two providers share a verified email
- [ ] Clerk client, identity reader and tests against a stubbed adapter
- [ ] Callback controller, policy, routes, throttles
- [ ] Sign-in screen buttons and email code form, Stimulus controller, Clerk script origins in the content security policy
- [ ] Settings "Add a sign-in" section
- [ ] Erasure job for the Clerk user, privacy and legal wording, export wording
- [ ] Secrets, deployment and operations documentation for local, staging and production

**Acceptance Criteria:**
- Given a Clerk development instance, when a visitor signs in with Discord, Google or an email code, then a player exists with that identity and the app session is opened.
- Given a verified email already held by another player, when a new identity presents it, then no account is created and the message names the provider to use.
- Given a signed-in player, when they add a sign-in from the settings, then the same account holds both identities.
- Given an erased account, when the job runs, then its Clerk user is deleted and a Clerk error only retries the job.
- Given a forged or expired token, when posted to the callback, then nothing is written.

## Verification

**Commands:**
- `bin/rails test`, `npm run test:js`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `script/check_planning_references`, `script/check_file_sizes`, `npm run format:check`, `npm run lint:css`

## Design Notes

Open facts the spike settles: how the session token names the provider used when Clerk merged two providers into one user; whether the script's session cookie reaches the app domain on a development instance; the exact Backend API field names. The plan changes only outside the frozen block if the spike contradicts the approach; if it contradicts the approach itself, the author decides.

### Spike result (2026-10-29, Clerk development instance, real sign-ins)

- Clerk's browser script sets the `__session` cookie on the app's own origin, so the server can read the session token from the callback request. The token carries `sub` (the Clerk user id), `sid`, `iss` (the instance's Frontend API), `azp` (the page origin) and `exp` after 60 seconds. It carries no provider and no sign-in method.
- The Backend API read of a user returns `external_accounts` with `provider` (`oauth_discord`, `oauth_google`), `provider_user_id`, `email_address`, `email_address_verified` and a verification status, plus `email_addresses` with their verification.
- An email code sent to an address already verified through Discord signs in the same Clerk user, with a new session, and nothing in the token or the user tells which method was used. The frozen row "the provider used is the one the token names" therefore cannot be applied.
- Discord and Google accounts with different addresses are two Clerk users, as intended. Two OAuth providers sharing one address were not exercised; by the same mechanism they would be one Clerk user.

### Decision (author, 2026-10-29): one Clerk user is one player

The callback reads the Clerk user and looks for the player through any of the user's external accounts (provider and provider user id), then through the Clerk user id kept as an `email` identity. A found player is signed in, and the user's external accounts missing from the player's identities are added when free. A user matching nothing becomes a new player holding one identity per external account, or the `email` identity keyed on the Clerk user id when there is none. A user whose verified address hash belongs to another player's identity is refused naming the provider. This replaces the frozen row on a merged Clerk user.

## Review Triage Log

| Finding | Verdict | Route | Evidence |
|---|---|---|---|
| Duplicate `clerk_unavailable` and `invalid_session` keys in both locales | medium | patch | Both packages defined them; the first definitions are removed and one message each remains. |
| No ban reason shown for a banned Clerk player | low | defer | The ban page renders with 403 and the generic text; the reason lookup works through a Steam id only. |
| Erasure job dropped silently without a secret key | medium | patch | It now raises, so the job retries and fails visibly; a test covers it. |
| Clerk user re-signs in between the erasure commit and the job | low | defer | Needs a sign-in within seconds of an erasure; an email-code user would lose the new account when the job runs. |
| Erasing one player deletes a Clerk user another player signs in through | medium | patch | Clerk user ids still held by another player's identities are no longer erased; a test covers it. |
| Key list fetch under the mutex, refetch cooldown not applied after a failed fetch | medium | patch | The cooldown now counts every attempt; holding the lock across the fetch stays, the sign-in throttle bounds it. |
| Email duplicate check hashes only the Clerk primary verified address | medium | defer | A new Clerk user whose external account address differs from its primary address bypasses the check; hashing every verified address is a larger change to the sign-in operations. |
| `add_missing` swallows refusals | false | none | Intended: a returning player is signed in and identities owned by others are ignored, as the plan states. |
| Console log carried Clerk objects; buttons stayed disabled after a failed fresh start | low | patch | Only a short message is logged; the buttons are enabled again with the error shown. |
| CSP Cloudflare origins apply to the whole page, no image origin | low | false | The headless flow needs no image origin; the extra origins are limited to the two Clerk screens. |
| Explanatory comments | low | patch | The client and identities comments are removed; the initializer header follows the Steam initializer's precedent. |
| Single `clerk_secret.key` instead of one per destination | low | false | Each destination writes its own value to that file; one file name mirrors the Steam key. |
| Export does not name Clerk | low | defer | The export lists identities by provider; wording in the export file itself is not changed. |

## Code Review

### 2026-10-29

Review of tickets 27.6 and 27.7 together, production code from `eea10180` to `fb70c2d0` (2430 lines; tests, locales and styles left out). 1 `decision-needed`, 3 `patch`, 2 `defer`, 14 rejected.

- [ ] [Review][Decision] The production proxy answers on www.gameble.net but Clerk sessions are accepted only for the apex origin — a sign-in started from www fails the `azp` check with the generic error. Redirect www to the apex, or accept the www origin [app/domains/accounts/app/clients/accounts/clerk_client.rb:27, config/deploy.production.yml:38]
- [x] [Review][Patch] A failed first key fetch leaves the key set empty, so every sign-in refetches under the lock, with the client's retries, and the 30-second cooldown never applies [app/domains/accounts/app/clients/accounts/clerk_client.rb:37]
- [x] [Review][Patch] A returning player found through a later key never gets the first key attached: `add_missing` skips `keys.first`, which only a new registration adds [app/domains/accounts/app/operations/accounts/sign_in_through_clerk.rb:17]
- [x] [Review][Patch] No test pins the settings page's Clerk CSP origins, so the add-a-sign-in widget can break again like the sign-in screen did [test/controllers/sign_in_methods_controller_test.rb]
- [x] [Review][Defer] The Stimulus controller's wiring (submit on `signedIn`, buttons re-enabled after a failure, strategy whitelist) has no test — deferred: browser glue over Clerk's SDK, a mocked vitest of the controller fits
- [x] [Review][Defer] The form is submitted right after `setActive`, and the server reads the `__session` cookie: unverified (medium) that Clerk has written it by then — deferred: settled by a real sign-in on staging with Discord, Google and an email code after the CSP fix

#### Rejected

- Production SSH port dropped: false, `deploy.production.yml` sets `ssh: port: 22` and its own proxy command.
- Missing `CLERK_SECRET_KEY` secret: false, both `.kamal/secrets.*` files read it from `config/clerk_secret.key`.
- Missing locales, styles, schema and tests: false, those files were left out of the reviewed diff, not missing.
- Erasure job dropped silently after 10 attempts: false, `retry_on` re-raises after the last attempt, so the job lands in the failed executions and reports.
- Ban reason missing for an unstamped banned player: false, a Clerk player is stamped by their first successful sign-in, which precedes any ban; a new Clerk identity of a banned Steam player is a different account.
- Shared Clerk user deleted by a concurrent sign-in: low, one Clerk user is one player, so no second player can hold it.
- Acceptance notice absent on the callback screen: low, the callback only follows the start screen that shows it.
- `frame-src` replaced instead of extended: low, no frame source is set before it.
- `+tag` stripped for every domain in the email hash: low, the author's anti-duplicate choice.
- Buttons stay disabled when Clerk's script fails to load: low, the error shows and a reload retries.
- Sign-out does not end the Clerk session: low, the sign-in screen signs the stale session out first.
- Duplicated private helpers, `@registered`, count comparison for "already added": low, no named harm, and the fix is a refactor.
- Unrelated changes in the diff (staging tunnel, showcase rename): out of scope for this review.
- Config hygiene (duplicated development key, silent Clerk off): low, production sets the key.
