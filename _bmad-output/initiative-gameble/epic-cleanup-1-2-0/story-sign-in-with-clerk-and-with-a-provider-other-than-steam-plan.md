---
title: 'Players are identified by identity rows, ready for sign-ins other than Steam'
type: 'feature'
ticket: '6'
created: '2026-10-29'
status: 'built'
baseline_revision: 'eea101800f31d57fa671ae4e29e2bb3566afcec1'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
context: ['_bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** a player is keyed on a Steam id, so no other sign-in can exist, and a player without Steam cannot be stored.

**Approach:** the first slice of the Clerk story builds everything that does not depend on Clerk: an identity row per way in, a provider-neutral sign-in operation (steam, discord, google and email), an address normaliser for the hash, a handle for a player without Steam, adding an identity to one's own account, the email-hash lookup, and the data rules (deletion, export). The Clerk client, its callback, the buttons, the settings section, the legal pages and the secrets are the second slice, after a spike on a Clerk development instance.

## Boundaries & Constraints

**Always:** follow the adopted identity design in the architecture; Steam keeps its OpenID path and still signs in exactly as today; the email is never stored, only a salted hash of a verified one; schema changes are expand then contract with strong_migrations; every string in both locale files; no database id in a URL; writes only through operations.

**Never:** call Clerk or add a gem in this slice; merge two existing players; ban across identities; edit db/schema.rb by hand; run tests in agents.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected | Error |
|---|---|---|---|
| Steam sign-in | known Steam id | same player, identity row exists | none |
| New provider uid | unknown, no hash match | new player with a generated handle, no steam_id | none |
| Email already known | verified hash of another player's identity | no account, a refusal naming the provider | failure code |
| Banned player | any identity of a banned player | refused | :banned |
| Add identity | signed in, free uid | row added to that player | uid owned by another player: refused |
| Email alias | same mailbox written with +tag or Gmail dots | same hash as the plain address | none |
| Deletion | player with identities | identity rows removed with the account | none |

</frozen-after-approval>

## Code Map

- `db/migrate` -- add accounts_identities (player_id, provider, uid, email_hash), unique on provider and uid, index on email_hash; backfill Steam rows; relax the deleted check to "deleted has no steam_id" with validate in the next migration
- `app/domains/accounts/app/models/accounts/player.rb` -- steam_id validation only for a Steam player
- `app/domains/accounts/app/operations/accounts/sign_in.rb` -- take provider and uid, find or create through the identity; Steam path calls it
- `app/domains/accounts/app/operations/accounts/delete_player.rb` -- delete identity rows
- `app/domains/accounts/app/queries/accounts/export_of.rb`, `app/models/player_export.rb` -- list identities
- `app/domains/accounts/app/queries/accounts/player_search.rb`, `current_ban_reason.rb` -- read through identities
- `app/controllers/sessions_controller.rb` -- Steam callback passes provider steam
- `test/support/steam_sign_in.rb`, fixtures -- identity rows for the fixture players

## Tasks & Acceptance

**Execution:**
- [ ] `db/migrate` -- two expand migrations and one validate, backfill included
- [ ] identity model, handle generator, `Accounts::AddIdentity`, `Accounts::IdentityByEmailHash`
- [ ] `Accounts::SignIn` -- provider-neutral, ban refusal, email-hash refusal
- [ ] deletion, export, search, ban reason through identities
- [ ] locale keys for the new refusals in en.yml and fr.yml
- [ ] tests for each matrix row; fixtures updated

**Acceptance Criteria:**
- Given a Steam player, when they sign in, then nothing visible changes.
- Given a player with no steam_id, when they exist, then the app renders every screen with their handle.

## Verification

**Commands:**
- `bin/rails test test/domains/accounts test/integration` -- expected: pass
- `bundle exec packwerk check && bin/rails zeitwerk:check` -- expected: pass

## Design Notes

Shared contract, fixed so three implementers can work on disjoint files at once. Domain code lives in `app/domains/accounts/app/...`; operations return Success or Failure(:code) and are named Accounts::VerbNoun.

- Table `accounts_identities`: `player_id` (bigint, not null, foreign key to accounts_players), `provider` (string, not null), `uid` (string, not null), `email_hash` (string, null), timestamps. Unique index on `provider, uid`; plain index on `email_hash`; a check that `provider` is one of steam, discord, google, email, added not validated then validated in the next migration. Steam rows are backfilled from `accounts_players.steam_id` in its own data migration.
- `accounts_players`: the check `(steam_id IS NULL) = (deleted_at IS NOT NULL)` becomes `deleted_at IS NULL OR steam_id IS NULL` ("a deleted account has no steam_id"), added not validated, then validated. `steam_id` stays nullable.
- `Accounts::Identity` (model): `belongs_to :player`, `PROVIDERS = %w[steam discord google email]`, validations of provider and uid; `Accounts::Player` gains `has_many :identities`; its steam_id validation applies only when a steam_id is present (format), never presence.
- `Accounts::EmailNormaliser.call(address)` returns the lower-cased address with any `+tag` removed and, for gmail.com and googlemail.com, the dots removed. `Accounts::EmailHash.call(address)` returns nil for a blank address, else the hex HMAC-SHA256 of the normalised address keyed with `Rails.application.key_generator.generate_key("identity-email-hash")`.
- `Accounts::HandleGenerator.call` returns a handle like `Brother-4F7K2Q` that no player holds; a player without Steam stores it in `persona_name`.
- `Accounts::SignInThroughIdentity.new.call(provider:, uid:, persona_name: nil, email_hash: nil)` is the provider-neutral core: Failure(:invalid_identity), Failure(:invalid_steam_id) for a steam uid that is not 17 digits, Failure(:banned), Failure(:email_known) when a new identity's email_hash belongs to another player's identity (no account is created, the failure carries no data about the other player). A steam identity also writes `steam_id` on the player. `Accounts::SignIn.new.call(steam_id:, persona_name: nil)` stays and delegates with provider `steam`, so existing callers and tests keep working.
- `Accounts::AddIdentity.new.call(player:, provider:, uid:, email_hash: nil)` returns Success(identity) or Failure(:player_required, :invalid_identity, :identity_taken, :email_known) and publishes `Accounts::IdentityAdded` (player_id, provider).
- `Accounts::IdentityByEmailHash.call(hash)` returns the identity or nil. `Accounts::PlayerByIdentity.call(provider:, uid:)` returns the player or nil.
- Failure messages: `errors.accounts.<code>` in both locale files, added by hand.
- Fixtures: `test/fixtures/accounts/identities.yml` holds one steam row per fixture player that has a steam_id.
- Implementers run no tests, run no git command, and never touch `db/schema.rb`; the main session regenerates it and runs the suites once.

## Review Triage Log

| Finding | Verdict | Route | Evidence |
|---|---|---|---|
| Email-known refusal does not name the provider | medium | patch | The failure is now `email_known_<provider>`, with a message per provider in both locales. |
| A second Steam identity is accepted by AddIdentity | medium | patch | `refuse_taken` now refuses a player already holding a Steam identity; a test covers it. |
| AddIdentity race raises RecordNotUnique | medium | patch | The insert is rescued into `Failure(:identity_taken)`. |
| No test for a player with no steam_id across screens | maybe-false | defer | No view dereferences `steam_id`; a request test needs a Clerk sign-in, which slice 2 adds. |
| Normaliser: empty local part collapses; googlemail not unified | low | patch | A tag with no name before it is kept; googlemail.com maps to gmail.com. |
| Migration header comment | low | patch | The comment is removed. |
| Unrelated locale churn | medium | patch | An i18n-tasks normalise reflowed the files; en.yml restored and pagy/en.yml reverted, only the new keys kept. |
| Privacy notice omits identities | medium | patch | The deletion paragraph names sign-in methods in both locales. |
