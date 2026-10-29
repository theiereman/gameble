---
title: 'Players are identified by identity rows, ready for sign-ins other than Steam'
type: 'feature'
ticket: '6'
created: '2026-10-29'
status: 'draft'
baseline_revision: 'eea101800f31d57fa671ae4e29e2bb3566afcec1'
route: 'full'
route_source: 'auto'
review: ''
review_source: ''
lenses_ran: []
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
