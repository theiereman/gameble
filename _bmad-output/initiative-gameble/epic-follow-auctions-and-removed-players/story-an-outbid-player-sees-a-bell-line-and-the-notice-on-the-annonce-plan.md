---
title: 'An outbid player sees a bell line and the notice on the Annonce'
type: 'feature'
ticket: '40.1'
created: '2026-11-10'
status: 'built'
baseline_revision: '5918140903aab7936f12e3e3bbc99c8e91f6342e'
route: 'full'
route_source: 'auto'
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/initiative-gameble/epic-follow-auctions-and-removed-players/epic-follow-auctions-and-removed-players.md'
  - '{project-root}/_bmad-output/initiative-gameble/spec-gameble/market-economy.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A player outbid on a running auction is told nothing: the bell has no market line and the Annonce they reopen shows no sign that someone passed them. Epic requirements R1, R2 and R3 (the outbid half).

**Approach:** One table, `game_market_notices`, holds one row per player and listing, written by a handler of `BidPlaced` and `AuctionSold` through a replacing upsert and read by `Game::Market::MarketNotices`. `BellItems` renders its rows as market lines, `PlayerStream` reloads the bell live through a `market` topic, and the Annonce shows the outbid panel above the form to an outbid, non-leading viewer.

## Boundaries & Constraints

**Always:**
- The table owns every notice kind the epic will write, checked from the start: `outbid`, `won`, `sold`, `unsold`, `bought_over`, `lead_voided`, `withdrawn`. Columns: owning player, listing, kind, the other player (nullable), the amount (nullable, never negative) and the time. Unique on (player, listing), the unique index in its own concurrent migration. Later stories add handlers and lines, never a migration.
- `Notice.record` is the one write: an upsert on (player, listing) replacing kind, other player, amount and time, so a listing keeps one line whatever happens next.
- The handler runs in the publishing transaction and publishes nothing. `BidPlaced` writes an `outbid` notice for `outbid_player_id` naming the bidder and the released amount; `AuctionSold` writes one for its `outbid_player_id` naming the winner. No outbid player, no notice.
- `MarketNotices.call(player:, locale:)` returns that player's notices only, newest first, at most five, each with the card title, the other player and the amount.
- The bell line sits after the reaction lines, before the daily capsule, one per notice. Its key holds the listing token and the notice time, so a newer outbid on the same listing returns unseen. It follows the bell's per-browser clearing: its path is the Annonce, so opening the Annonce clears it. Sentence "<name> a dépassé votre maximum sur <card>." with the action "Voir", the name through the names component.
- `PlayerStream` sends `{ player_id:, topic: "market" }` to the outbid player on `BidPlaced` and `AuctionSold`; the job turns the topic into a `market-updated` signal the bell reloads on. Broadcasts stay behind the job, enqueued after commit.
- The outbid panel shows above the form to a signed-in viewer who holds an outbid notice on the listing, is not leading and sees the listing open. It never moves focus and never replaces the field or the button; it carries the alert colour. Copy in `en.yml` and `fr.yml`; no database id leaves the server.

**Never:**
- No other notice kind written or rendered here; no live refresh of the Annonce, no extended panel, no count badge, no status post, no toast.
- No read of another player's notice anywhere; no write of a notice outside `Notice.record`.

**Decisions (settled by Claude, no approval round in this batch; the author may revisit):**
- The columns are `player_id`, `listing_id`, `kind`, `other_player_id`, `amount`, `noticed_at`, with foreign keys to the players and the listings. `amount` is the released maximum for an outbid line, the price for a won line, what the seller receives for a sold line and nil when the kind needs none.
- The buy-now case writes `outbid` in this story, as the ticket says; the outcome story turns that branch into `bought_over`.
- The handler is `Game::Market::Handlers::OutbidNotices`, subscribed to the two events beside the other handlers in `event_store.rb`.
- The names component gains a `linked:` option (true by default). The bell line is itself a link, so it names the other player without a nested link; a removed player reads anonymous as everywhere else.
- The panel's action "VOIR L'ANNONCE" is a link-variant button to the Annonce with `focus=maximum`, which puts the cursor in the field on a deliberate click only.
- The panel is part of the bid region, so a turbo-stream answer to the viewer's own bid redraws it and the page shows it on load.
- `Game::Market::AnnonceEvents` (a query) answers the panel's facts for a viewer; the extended panel of the live-refresh story joins it.
- No index beyond the unique one: a player's notices are few.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Outbid | B takes the lead from A | A has one `outbid` notice naming B and the released amount; A's bell reloads | No error expected |
| Outbid again | C then outbids A once more on the same listing | Still one row for A, now naming C with the new time | No error expected |
| Nobody outbid | First bid, a raise or a bid beaten at once | No notice | No error expected |
| Buy-now over a lead | B buys now over A's lead | A's notice names B and the released amount | No error expected |
| Another player | B reads the bell or the query | Never sees A's notice | Notice scoped by player |
| Back in the lead | A raises after the notice | The Annonce shows no outbid panel | No error expected |

</frozen-after-approval>

## Code Map

- `db/migrate/20261110150000_create_game_market_notices.rb`, `20261110150001_add_player_listing_index_to_game_market_notices.rb` -- the table, then its unique index
- `app/domains/game/app/models/game/market/notice.rb` -- the record and the replacing write
- `app/domains/game/app/handlers/game/market/handlers/outbid_notices.rb` -- the handler
- `app/domains/game/app/queries/game/market/market_notices.rb`, `annonce_events.rb` -- the bell's and the panel's reads
- `app/domains/game/app/queries/game/bell_items.rb`, `app/helpers/bell_helper.rb` -- the market lines
- `app/models/player_stream.rb`, `app/jobs/player_stream_job.rb`, `app/frontend/lib/stream_actions.ts`, `app/frontend/lib/events.ts`, `app/frontend/controllers/bell_controller.ts` -- the live reload
- `app/views/market/bids/_region.html.erb`, `app/views/market/listings/_events.html.erb`, `app/frontend/styles/market-events.css` -- the panel
- `app/components/player_name_component.rb` -- the unlinked option

## Tasks & Acceptance

**Execution:**
- [ ] Migrations, model, handler and subscription
- [ ] `MarketNotices` and `AnnonceEvents` queries
- [ ] Bell lines, stream topic, signal and bell reload
- [ ] Outbid panel, copy in both locales, styles
- [ ] Tests: handler, query, bell items and helper, stream, panel, one system test

**Acceptance Criteria:**
- Given A leads and B outbids A from another session, when A's bell is open, then its line shows live and opening it leads to the Annonce with the outbid panel above an empty field.
- Given a notice of A, when any other player reads, then it is never visible.

## Implementation Notes

Built as planned; no test or CI was run in this batch. The existing player stream tests that listed every notice of a bid or a sale now select the balance notices, since the same events also carry the market topic. The new copy keys sit under `market.listings.events` and `shell.bell.market`, the latter ignored by the unused-key check because the line's key is built from the notice kind.

## Plan Change Log

## Review Triage Log

## Verification

**Commands:**
- `ruby -c` on each new Ruby file, ERB compiled through `ERB#src`, `npm run format:check`, `npm run lint:css`, `npx tsc --noEmit` -- expected: no error
- `script/check_planning_references`, `script/check_file_sizes` -- expected: no finding
