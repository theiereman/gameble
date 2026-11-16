---
title: 'An achievement for joining the gameble Discord, checked by a bot'
type: 'feature'
ticket: ''
created: '2026-11-16'
status: 'built'
baseline_revision: '35c3e6b8835320a660ca5c59ba1c7b4881d32553'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The author wants an achievement for joining the gameble Discord server. Players can already link a Discord account at sign-in, so a bot of the server can say whether that account is a member.

**Approach:** A recurring job asks the Discord API, with the bot token, whether the Discord account linked to each player not yet marked is a member of the server. A member gets a marker, an event, and one catalogue entry reads the marker. With no token or guild id configured, the job does nothing.

## Boundaries & Constraints

**Always:** Follow `plan-achievements-untraced-actions.md` for the marker on `game_player_states` (expand-only migration, regenerated `db/schema.rb`), the operation and event, the handler trigger, the glyph (reuse `friends`), both locales, the privacy and export wording. The HTTP client follows `Steam::WebApi` (Faraday, injectable adapter, the token redacted from every error and log) and lives in the Accounts domain next to `ClerkClient`. Credentials follow `config/initializers/steam.rb`: environment variables `DISCORD_BOT_TOKEN` and `DISCORD_GUILD_ID`, falling back outside production to git-ignored key files (never committed). The job checks a bounded batch per run, least recently checked first, and stops on a rate-limit answer. The achievement's condition tells the player to link their Discord account in the settings. The privacy text names Discord as a service that is asked whether the linked account is a member.

**Decisions (author, 2026-11-16):** Verified by a bot, not by a click. Name: fr "Réunion d'équipe", en "Team Meeting"; glyph `friends`. A member who later leaves keeps the achievement. A player is checked again only while not yet marked.

**Never:** No change to how Discord sign-in works; no Discord data kept beyond the player's marker and a last-checked time; no real network call in tests; no secret in the repo. The author still creates the bot, adds it to the server and sets the two variables.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected |
|----------|--------------|----------|
| Member | Linked Discord account, API answers 200 | marker set, event published, achievement granted |
| Not a member | API answers 404 | last-checked time updated, nothing else |
| No Discord account linked | Player without a discord identity | never asked |
| Already marked | Marker set | never asked again |
| Not configured | Token or guild id missing | job returns at once, no request |
| Rate limited | API answers 429 | the run stops, nothing marked, tried again next run |
| Other failure | 5xx or network error | the error is reported, the player stays unmarked |

</frozen-after-approval>

## Code Map

- `app/domains/accounts/app/clients/accounts/clerk_client.rb`, `app/domains/steam/app/clients/steam/web_api.rb`, `config/initializers/steam.rb`, `clerk.rb` -- client and credentials patterns.
- `app/domains/accounts/app/models/accounts/identity.rb` (`provider` "discord", `uid` = Discord user id), `clerk_identities.rb`.
- `config/recurring.yml`, `app/domains/game/app/jobs/game/*_job.rb` -- recurring job pattern.
- `app/domains/game/app/operations/game/mark_link_opened.rb`, `grant_code_contribution.rb` -- marker operation pattern; `app/domains/game/app/models/game/player_state.rb`.
- Catalogue, metric, handler, glyph, locales, `export_of.rb`, privacy services text, as in the previous plans. Game may read Accounts, never the reverse: the job lives in Game and calls the Accounts client.

## Tasks & Acceptance

**Execution:**
- [ ] Migration: `discord_member_at` and `discord_checked_at` datetimes on `game_player_states`; regenerate `db/schema.rb`.
- [ ] `Accounts::DiscordClient` (membership check), `config/initializers/discord.rb`, `Game::CheckDiscordMembershipsJob`, `config/recurring.yml` entry (hourly), `Game::MarkDiscordMember` operation, `Game::DiscordMemberFound` event.
- [ ] Catalogue entry `discord_member` (metric `discord_member`, threshold 1), metric, handler trigger, glyph, strings, privacy and export wording.
- [ ] Tests with a stubbed adapter: each matrix row, the client's redaction, the operation, the metric.

**Acceptance Criteria:**
- Given a player with a linked Discord account who joined the server, when the job runs, then they earn the achievement and see the toast.

## Verification

**Commands:**
- `bin/rails test` and `npm run test:js` -- green
- `node script/pixel_art/export.mjs --check`, `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `script/check_file_sizes`, `script/check_planning_references`, `bundle exec i18n-tasks missing`, `npm run format:check` -- clean

## Implementation Notes

## Plan Change Log

## Review Triage Log

- Pass 1 (quick): 3 patched, 4 rejected.
  - patched · medium -- every 404 meant "not a member", so a wrong `DISCORD_GUILD_ID` or a bot outside the server would silently stamp everyone as checked: only Discord's unknown-member and unknown-user codes (10007, 10013) mean not a member, any other 404 is an error; a test covers the unknown server (10004).
  - patched -- class and initializer comments restated the names: removed, one line kept on the initializer for the variable names.
  - rejected -- a 5xx stamps `discord_checked_at`: deliberate, so a permanently failing account rotates to the back instead of starving the batch; the player stays unmarked as the plan says.
  - rejected -- one report per failing player in a run: bounded at 50 an hour; the run goes on so one bad account cannot block the others.
  - rejected -- the `MarkDiscordMember` result is discarded: a lost write for a player removed in between is harmless and retried next hour.
  - rejected -- `stub_const_batch`: test-only, works.
