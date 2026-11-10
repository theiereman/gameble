---
title: 'A banned or deleted seller''s listings leave the market'
type: 'feature'
ticket: '40.9'
created: '2026-11-10'
status: 'ready-for-dev'
baseline_revision: '7e2188be18f2ebdd2b1b019873346127609b6b3a'
route: 'full'
route_source: 'auto'
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/initiative-gameble/epic-follow-auctions-and-removed-players/epic-follow-auctions-and-removed-players.md'
  - '{project-root}/_bmad-output/initiative-gameble/epic-follow-auctions-and-removed-players/story-a-banned-or-deleted-leader-s-bid-is-voided-and-the-auction-resumes-plan.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A banned or deleted seller's open listings stay on the market, their leader's PiCoins stay held, and a deleted seller's missing holding makes releasing the reservation fail. Epic requirements R3, R12 and R13.

**Approach:** A new `Game::Market::WithdrawListing` operation, run by `DropPresenceJob` for every open listing of a removed seller, ends the listing as `withdrawn` through the same ending code `CloseAuction` uses, releases the leader's maximum and publishes the existing `ListingWithdrawn`; a handler tells the leader, and the bidders' badges refresh.

## Boundaries & Constraints

**Always:**
- `WithdrawListing` takes `player:` (the seller, `require_account`) and `listing_id:`. Lock order as `CloseAuction`: `TradeLocks.players(seller_id, leader_id)`, then `Listing.lock.find`, then the recheck (status `open`, seller still banned or deleted, leader unchanged), then the holdings lock inside the reservation release, then one `Ledger.post`, then one publish of `ListingWithdrawn` on the seller's stream, in one transaction. Failures: `Failure(:listing_not_withdrawable)` as a constant the job skips; `rescue ActiveRecord::Deadlocked` gives `Failure(:market_busy)`. A listing past its end is withdrawn too (the result equals what `CloseAuction` does for a removed seller).
- The ending code moves out of `CloseAuction` into a shared concern `Game::Market::ListingEnding` (`end_without_sale`, `release_entries`, including `ListingReservation`); `CloseAuction` and `WithdrawListing` both include it, so the status, the leader release and the `ListingWithdrawn` data (`listing_id`, `seller_id`, `leader_id`, `released`) are written in one place. Behaviour of `CloseAuction` is unchanged.
- `ListingReservation#release_reservation` becomes a no-op when the seller's holding is gone (deleted seller, `ReleasePlayer` removed it): it reads the locked holdings without `fetch` and returns when the card is absent. This also fixes `CloseAuction` for a deleted seller. The stamp is never refunded.
- `DropPresenceJob#perform` gains its first step, before story 8's: it withdraws the listings found by a new `RemovedPresence.sellers` (open listings whose seller is banned or deleted, `[listing_id, seller_id]`), with the same error handling per listing. A listing with a removed seller and leader is withdrawn here, so the leader step never sees it.
- `Game::Market::Handlers::RemovalNotices` also subscribes to `ListingWithdrawn`, covering this withdrawal and the one `CloseAuction` makes at close: it writes the leader's `withdrawn` notice (amount released, no other player) when the event carries a leader. The bell line "<card> a été retirée du marché. Vos <amount> sont de nouveau disponibles." leads to the Annonce (`MARKET_TARGETS` gains `withdrawn: :annonce`). `Notice.record`'s removed-player guard from story 8 covers a removed leader.
- `PlayerStream` hears `ListingCancelled` and sends a `market` topic notice to every bidder of the listing (`ListingBidders`), so the outbid badges and the MARCHÉ count refresh when a listing with voided or beaten bidders is cancelled; `ListingWithdrawn` already does so and its balance notice already covers the seller and leader. `ListingCancelled` joins `PlayerStream::EVENTS` in a market list.
- MES VENTES already shows RETIRÉE and the Annonce already shows the withdrawn outcome; this story only proves them in a test. Copy in both locales: `shell.bell.market.withdrawn_html`, fr "%{card} a été retirée du marché. Vos %{amount} sont de nouveau disponibles.", en "%{card} was withdrawn from the market. Your %{amount} are available again."

**Never:**
- No migration, no refund of the stamp, no new auction rule, no edit of `CancelListing`, no write by `PlayerStream`, no database id in a stream.

**Decisions (settled by the plan author, to approve):**
- A withdrawal is final: an unbanned seller does not get the listing back and the stamp stays destroyed.
- A banned seller's card returns to their holding (the reservation is released); a deleted seller's holding no longer exists, so nothing is released and the card goes with the account.
- Only the leader is told by the bell; the other bidders hold nothing, learn through their refreshed badge and the Annonce, and keep their earlier outbid lines.
- `ListingCancelled` joins the player stream here, not in story 8, because the stale badge appears when a voided listing, which has no leader, is later cancelled or withdrawn.
- A removed seller's listing is withdrawn even when an auction end falls in the same minute; whichever of `CloseAuction` and this operation locks first wins and the other answers its skipped failure.
- No new error keys: the operation is reached only by the job.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Banned seller, bid on the listing | Open, leader present | Withdrawn, leader's maximum released, reservation released, leader's `withdrawn` notice | No error expected |
| No bid | Open, no leader | Withdrawn, reservation released, no notice, no ledger entry | No error expected |
| Deleted seller | Holding already deleted | Withdrawn, reservation release a no-op | No error expected |
| Both removed | Seller and leader removed | Withdrawn, released, no notice written for either | No error expected |
| Stamp | Any withdrawal | No stamp refund entry | No error expected |
| Second run | Same listing again | Not found by the finder, nothing posted | No error expected |
| Already closed | Closed or cancelled meanwhile | `Failure(:listing_not_withdrawable)`, skipped | Job ignores it |
| Close of a removed seller's due auction | `CloseAuction` runs | Same withdrawal; the leader's notice is written by the same handler | No error expected |

</frozen-after-approval>

## Code Map

- `app/domains/game/app/operations/game/market/withdraw_listing.rb`, `listing_ending.rb`, `close_auction.rb`, `listing_reservation.rb` -- new operation, extracted ending, tolerant release
- `app/domains/game/app/queries/game/market/removed_presence.rb`, `app/domains/game/app/jobs/game/market/drop_presence_job.rb` -- the seller finder and the first step
- `app/domains/game/app/handlers/game/market/handlers/removal_notices.rb`, `config/initializers/event_store.rb` -- withdrawn notice
- `app/models/player_stream.rb`, `app/helpers/bell_helper.rb`, `config/locales/en.yml`, `config/locales/fr.yml` -- cancelled event, bell line, copy

## Tasks & Acceptance

**Execution:**
- [ ] `listing_ending.rb`, `close_auction.rb`, `listing_reservation.rb` -- extract the ending, make the release tolerant
- [ ] `withdraw_listing.rb` -- operation with the lock order above
- [ ] `removed_presence.rb`, `drop_presence_job.rb` -- seller step first
- [ ] `removal_notices.rb`, `event_store.rb`, `bell_helper.rb`, `player_stream.rb`, both locales -- notice, bell line, cancelled event, copy
- [ ] Tests: operation (leader and no leader, deleted seller, banned seller's reservation, stamp never refunded, ledger release once, second run, both removed, closed meanwhile), `CloseAuction` with a deleted seller, job order (sellers before leaders), handler for a withdrawal at close and by the job, `PlayerStream` for `ListingCancelled`, MES VENTES and the Annonce showing the withdrawn state, one system test

**Acceptance Criteria:**
- Given a seller with a bid on their listing is banned, when the job runs, then the leader's bell shows the withdrawn line, their balance has the maximum available again, and the Annonce shows ANNONCE RETIRÉE.

## Implementation Notes

## Plan Change Log

- 2026-11-10 approver: no change to the frozen block. Body only: `ListingEnding` must be self-contained (it includes `ListingReservation` and publishes through `publish(event, stream_name: stream_name(listing.seller_id))` itself rather than relying on `AuctionSettlement#publish_to_seller`, which `WithdrawListing` does not include); `ListingCancelled` gets an explicit `when` branch in `PlayerStream.notices` placed before the generic `when *BALANCE_EVENTS` branch and is not added to `BALANCE_EVENTS`; the withdrawn-notice amount is the event's `released`. Approved after checking that the order bank locks, listing, holdings, wallets is the one `CancelListing`, `PlaceBid` and `CloseAuction` use, that the leader recheck prevents releasing a leader whose bank was not locked, and that the tolerant release also removes the `KeyError` `CloseAuction` raises today for a deleted seller.

## Review Triage Log

## Design Notes

`release_reservation` becomes `holding = TradeLocks.holdings(listing.seller_id, [ card ])[card]; return unless holding`, then the same update.

## Verification

**Commands:**
- `ruby -c`, `bundle exec rubocop`, `bundle exec packwerk check`, `script/check_planning_references`, `script/check_file_sizes` -- expected: no finding
