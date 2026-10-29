---
title: 'The sign-in screen offers Discord, Google and email through Clerk'
type: 'feature'
ticket: '7'
created: '2026-10-29'
status: 'draft'
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
