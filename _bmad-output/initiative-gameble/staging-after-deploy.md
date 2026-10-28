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

Author's wish of 2026-10-28; nothing decided, to study before any change. From general knowledge, not checked against Cloudflare's current plans:

- The Free plan has covered DNS, the proxy with universal HTTPS, DDoS protection and basic caching, and a free Tunnel (`cloudflared`) that exposes the app without opening a public port. Running the Rails app itself on Cloudflare's platform would need containers, which are not part of the free plan: so the realistic target is staging behind Cloudflare as proxy or tunnel, still served by Kamal on the current server.
- To check before the move:
  - Kamal's proxy gets its certificate from Let's Encrypt: behind the orange cloud, use "Full (strict)" with an origin certificate, or keep the challenge reachable, and decide who terminates TLS.
  - Client IP: the rate limits (Rack::Attack, the `rate_limit` of the back-office actions, the public page throttle) read the remote IP; behind Cloudflare they must read `CF-Connecting-IP` through trusted proxies, otherwise every visitor shares one address.
  - Cached pages: public pages must not cache anything per player (no `Set-Cookie` or session on cached responses); set the cache rules by path.
  - Steam sign-in return URL and the OpenID realm stay on the staging domain.
  - Security headers and CSP set by the app must not be altered by the proxy.
  - WebSockets (Turbo Streams, cable) must pass: Cloudflare proxies them on the Free plan.
- Production will need the same decisions (the launch notes already list the Cloudflare setup as not done), so staging is the rehearsal.
