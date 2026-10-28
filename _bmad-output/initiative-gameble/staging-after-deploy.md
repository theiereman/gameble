# Staging: what to run around the 1.2.0 deploy

Noted from the builds of 2026-10-28. Every task below is idempotent: running it twice changes nothing. Run each with `bin/rails <task>` inside the app container on the destination (staging first, then production, where the same list applies except where noted).

## Before the deploy

1. `bin/rails catalog:number_seasons` (card numbers, ticket 27.1)
   - Numbers the cards of every published season that has none yet.
   - It must run before the deploy: the second migration validates a check that every rated card has a number, and it refuses to run with a clear message naming this task when one card is unnumbered.
   - Publish no season while the deploy runs: the check is added by the first migration before it is validated, so a publish by the old code (rarity written before number) would fail.

## Right after the deploy, in this order

2. `bin/rails game:backfill_player_states` (seasonal allocation, tickets 17.1 and 17.2)
   - Gives every player without one a `game_player_states` row, banned included. The migration of ticket 17.1 only sets the received and seen season markers on rows that exist, so a player without a row would be missing the markers.
3. `bin/rails game:backfill_card_backs` (set backs, ticket 9.2)
   - Unlocks, without a toast, the back of every set whose back tier a player in good standing already reached. New tiers unlock their back by themselves from the deploy on.

## To check on staging after the tasks

- A player with an earlier-season card and no state row reaches the hub without an error (ticket 17.2 fix).
- Number of unlocked backs: `Game::CardBackUnlock.count` is above zero once `backfill_card_backs` has run.
- Opening a capsule and accepting a trade receive the season allocation once (one `SeasonAllocationReceived` per player and season).

## Not needed for this release

- `steam:fill_card_sources`: already run on staging (v0.0.4-beta).
- `game:backfill_achievements`, `game:backfill_friend_codes`, `game:drop_friends_and_trades`: no change in this release.

## Still to do by hand (author)

- Walkthrough of the seven screens never marked, plus phone, staff and English (ticket 27.4).
- Rehearsal of a season change on staging (ticket 17.5, when it is built).

## Wish: put staging behind Cloudflare, only if it stays free

Author's wish of 2026-10-28; nothing decided. Production already runs this way (`config/deploy.production.yml`, `docs/operations.md`, `RELEASING.md`): `cloudflared` runs as a systemd service on the host, no port is open, Cloudflare terminates TLS (`ssl: false` on the Kamal proxy, `forward_headers: true` to keep `X-Forwarded-For` and `X-Forwarded-Proto`), and Kamal reaches the host over SSH through the same tunnel (`ssh.<domain>`, guarded by Cloudflare Access, `proxy_command: cloudflared access ssh --hostname %h`). So staging can copy the production destination file and its setup steps; the Tunnel and Access are free on Cloudflare's current free tier as far as the production setup shows, to confirm for a second hostname.

To check for staging:

- A staging hostname and its tunnel route, plus an SSH route guarded by Access for the deploy from the CI or from the author's machine.
- Client IP: the production file already trusts the tunnel's private address for `X-Forwarded-For`; the same setting must apply to staging so the rate limits do not see one shared address.
- Steam sign-in return URL and OpenID realm stay on the staging domain.
- The deploy workflow secrets (`SSH_KNOWN_HOSTS`, Access service token) for a staging destination, if staging is to be deployed by a workflow.
