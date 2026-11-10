---
title: 'A banned or deleted leader''s bid is voided and the auction resumes'
type: 'feature'
ticket: '40.8'
created: '2026-11-10'
status: 'draft'
baseline_revision: '7e2188be18f2ebdd2b1b019873346127609b6b3a'
route: 'full'
route_source: 'auto'
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/initiative-gameble/epic-follow-auctions-and-removed-players/epic-follow-auctions-and-removed-players.md'
  - '{project-root}/_bmad-output/initiative-gameble/epic-follow-auctions-and-removed-players/story-the-annonce-refreshes-live-while-it-is-open-plan.md'
  - '{project-root}/_bmad-output/initiative-gameble/epic-follow-auctions-and-removed-players/story-the-bell-tells-a-player-their-auction-s-outcome-plan.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A banned or deleted player can keep leading an open auction, holding PiCoins and blocking a real bidder; nothing voids the bid, tells the seller or shows it in the history. Epic requirements R3, R12 and R14 (the leader half).

**Approach:** A new `Game::Market::VoidLead` operation, driven every minute by a new `Game::Market::DropPresenceJob`, releases the removed leader's maximum, records a `voided` bid, resets the listing to its starting price with no leader and the same end, and publishes `LeadVoided`; a handler tells the seller, the streams refresh, and the history shows the voided line.

## Boundaries & Constraints

**Always:**
- `VoidLead` takes `player:` (the seller, `require_account`, so a removed seller works) and `listing_id:`. Lock order as `PlaceBid` and `CloseAuction`: `TradeLocks.players(seller_id, leader_id)` (bank locks ascending), then `Listing.lock.find`, then a recheck inside the lock: status `open`, `ends_at > now`, `leader_id` still the one seen, and that leader banned or deleted. No holdings are touched. One `Ledger.post` (a `release` entry: available plus the maximum, committed minus it), then one `publish(LeadVoided)` on the seller's stream, all in the transaction; `rescue ActiveRecord::Deadlocked` gives `Failure(:market_busy)`.
- The listing keeps its `ends_at`; `leader_id` and `leader_maximum` become null and `current_price` becomes `starting_price`. The leader's `leading` bid rows go to `outbid` through `Bid.displace`, then one `voided` row is created for them (the maximum released, `price_after` the starting price). Releasing never depends on the seller's state.
- `DropPresenceJob` runs every minute on queue `default` in both blocks of `config/recurring.yml`, with a comment line like its neighbours. It reads through a new query `Game::Market::RemovedPresence` (open listings with `ends_at` in the future whose leader is banned or deleted, as `[listing_id, seller_id]`, joined from the listings so the scan starts from the few open ones), runs one operation per listing and one transaction per listing, skips the benign `Failure(:lead_not_voidable)` constant, and reports any other error with `Rails.error.report(error, context: { listing_id: })` then moves on, as `CloseDueAuctionsJob` does. Stories 9 and 10 add steps to the same `perform`, in the order withdraw listings, void leads, forfeit wallets.
- Events: new `Game::Market::LeadVoided` (`listing_id`, `seller_id`, `leader_id`, `released`). `ListingStream::EVENTS` gains it. `PlayerStream` renders it as a balance notice for the leader and a `market` topic notice for the seller. A new handler `Game::Market::Handlers::RemovalNotices`, subscribed to `LeadVoided` in `config/initializers/event_store.rb`, writes the seller's `lead_voided` notice (no other player, no amount); story 9 adds `ListingWithdrawn` to it.
- `Notice.record` writes nothing for a banned or deleted player: a notice to a removed player is never read, and a deleted player's notices must not reappear after `ReleasePlayer` erased them.
- The history includes `voided` rows for every viewer (a new `Bid.history_visible` scope: every outcome but `raise`, with the viewer's own raises added as today); `public_outcomes` stays as it is for badges, notices and counts. A `:voided` history line has no name and reads "Offre annulée : joueur retiré" with its time. The bell line `lead_voided` leads to MES VENTES.
- Copy in both locales: `market.listings.history.voided` and `shell.bell.market.lead_voided_html`; fr "Offre annulée : joueur retiré" and "Le joueur en tête sur %{card} a été retiré. L'enchère repart de son prix de départ."; en "Bid voided: player removed" and "The leading player on %{card} was removed. The auction restarts from its starting price."

**Never:**
- No migration (the `voided` outcome and the `lead_voided` kind are in their checks already), no edit of `PlaceBid` or of its rules, no handler that publishes or writes through anything but `Notice.record`, no write from a GET, no toast, no database id in a stream or DOM id.

**Decisions (settled by the plan author, to approve):**
- The removal is found by the job only; the ban and delete flows are not touched, so `Game` reacts to nothing in `Accounts` and the ban transaction stays short. The window is under a minute.
- A listing already past its end is left to `CloseAuction`, which already releases a removed leader and ends the auction unsold or withdrawn; `VoidLead` answers `Failure(:lead_not_voidable)` for it, so an ended auction is never resumed.
- A bid placed by another player while the removed leader is still on the listing already releases that leader's hold in `PlaceBid` and replaces the lead; the job then finds nothing, and that race writes no voided row and no seller notice. Accepted: it lasts under a minute and the money is right.
- The recheck reads the leader's removal inside the locks without locking the player row; an unban landing between the read and the commit loses the bid, harmlessly, as the maximum is released to the player.
- Bidders beaten earlier keep their `outbid` or `beaten` rows: their maximums were released when they were beaten and are never revived, so the next bid starts from the starting price against nobody.
- A listing with a removed seller and a removed leader is withdrawn by story 9's step, which runs first in the pass; this story's operation also handles it alone (released once, no notice for a removed seller).
- No new error keys: the operation is reached only by the job, never by a controller.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Banned leader | Open listing, leader banned | Maximum released in the ledger, voided row, starting price, no leader, same end, seller's notice | No error expected |
| Deleted leader | Leader deleted, wallet kept | Same; the notice for a removed seller is not written | No error expected |
| Second run | Same listing again | No leader found, nothing posted | No error expected |
| Next bid | After the void, a player bids the starting price | Leads at the starting price against nobody | No error expected |
| Leader and seller removed | Both removed | Released once, no notice written | No error expected |
| Ended meanwhile | `ends_at` passed or listing closed | `Failure(:lead_not_voidable)`, skipped | Job ignores it |
| Operation raises | Any other error | Reported with the listing id, next listing runs | Rolled back, reported |

</frozen-after-approval>

## Code Map

- `app/domains/game/app/operations/game/market/void_lead.rb`, `app/domains/game/app/events/game/market/lead_voided.rb` -- new operation and event
- `app/domains/game/app/jobs/game/market/drop_presence_job.rb`, `app/domains/game/app/queries/game/market/removed_presence.rb`, `config/recurring.yml` -- job, query, schedule
- `app/domains/game/app/handlers/game/market/handlers/removal_notices.rb`, `config/initializers/event_store.rb`, `app/domains/game/app/models/game/market/notice.rb` -- notice and its removed-player guard
- `app/domains/game/app/models/game/market/bid.rb`, `app/domains/game/app/queries/game/market/bid_history.rb`, `app/helpers/market_history_helper.rb`, `app/views/market/listings/_history.html.erb` -- voided line
- `app/models/player_stream.rb`, `app/models/listing_stream.rb`, `app/helpers/bell_helper.rb`, `config/locales/en.yml`, `config/locales/fr.yml` -- live refresh, bell line, copy

## Tasks & Acceptance

**Execution:**
- [ ] `lead_voided.rb`, `void_lead.rb` -- event and operation, locks and recheck as above
- [ ] `removed_presence.rb`, `drop_presence_job.rb`, `recurring.yml` -- finder, job, both environment blocks
- [ ] `notice.rb`, `removal_notices.rb`, `event_store.rb` -- guard for removed players, seller notice, subscription
- [ ] `bid.rb`, `bid_history.rb`, history helper and view -- visible voided line without a name
- [ ] `player_stream.rb`, `listing_stream.rb`, `bell_helper.rb` (`lead_voided: :sales`), both locales -- streams, bell line, copy
- [ ] Tests: operation (ledger release, bid rows, starting price, same end, deleted leader, both removed, second run, next bid, ended listing, concurrent `PlaceBid`), job (batch, error isolation, recurring config in both environments), handler and the `Notice.record` guard, history query and helper, `PlayerStream` and `ListingStream` event lists, reconciliation balanced after a void, one system test

**Acceptance Criteria:**
- Given a leader is banned, when the job runs, then the Annonce shows the voided line, the starting price and no leader with the same end, and the seller's bell shows the line leading to MES VENTES.

## Implementation Notes

## Plan Change Log

## Review Triage Log

## Design Notes

`RemovedPresence.leaders(now:)` returns `Listing.open_now.where(ends_at: now..).where.not(leader_id: nil).joins(:leader).merge(Accounts::Player.removed).pluck(:id, :seller_id)`; the job fetches the sellers by id as `CloseDueAuctionsJob` does and calls `VoidLead.new.call(player: seller, listing_id:)`.

## Verification

**Commands:**
- `ruby -c`, `bundle exec rubocop`, `bundle exec packwerk check`, `script/check_planning_references`, `script/check_file_sizes` -- expected: no finding
- `npm run format:check` -- expected: no finding
