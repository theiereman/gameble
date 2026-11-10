---
title: 'The data export includes the player''s market data'
type: 'feature'
ticket: '40.11'
created: '2026-11-10'
status: 'in-review'
baseline_revision: 'c4dbc97c3e5ca787f2315208bf4da69909f67919'
route: 'full'
route_source: 'auto'
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/initiative-gameble/epic-follow-auctions-and-removed-players/epic-follow-auctions-and-removed-players.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The data export leaves out the player's wallet, PiCoin ledger, listings and bids, so the player cannot take away the market data the privacy notice says they hold. Epic requirement R17.

**Approach:** `Game::ExportOf` gains the market data of the exporting player, read by a new `Game::Market::ExportOf` query, and `PlayerExport` writes it as `wallet`, `picoinEntries`, `listings` and `bids`, with cards written as the export already writes them and listings named by token.

## Boundaries & Constraints

**Always:**
- Only the exporting player's rows: their wallet, their ledger entries, the listings they sold, the bids they placed with the maximum they typed (every outcome, a voided one included).
- A listing is written without its leader, its leader's maximum and its buyer; a bid is written without anything of the other bidders.
- Every listing is named by its token, a card by its slug and season, a time as ISO 8601; no database id, no settings reference.
- A player with no market activity exports a zero wallet and empty lists.

**Never:**
- No other player's maximum, name or token; no migration; no change to the export's rate limit, file name or storage.

**Decisions (settled by Claude, no approval round in this batch; the author may revisit):**
- The wallet is `{ available, committed }`, read through `Game::Market::Balance`.
- Ledger entries are `{ kind, availableDelta, committedDelta, listing, at }` with `listing` the token or null, oldest first.
- Listings are `{ token, card, status, startingPrice, buyNowPrice, currentPrice, finalPrice, durationHours, listedAt, endsAt, soldAt }`, oldest first, null where the listing has no value.
- Bids are `{ listing, maximum, priceAfter, outcome, placedAt }`, oldest first, the listing being any auction the player bid on.
- The query lives in `Game::Market` and is carried by `Game::ExportOf::Result`, so the file-size limit holds and the card ids of listings join the export's card lookup.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Seller | One listing with a leader | Listing row without leader or maximum; the leader's name and token absent | No error expected |
| Bidder | Bids with a raise, a beaten bid | Each own maximum, listing by token, matching ledger entries | No error expected |
| Rival | Another player's higher maximum on the same listing | Not in the file | No error expected |
| No activity | Account never used the market | Zero wallet, three empty lists | No error expected |

</frozen-after-approval>

## Code Map

- `app/domains/game/app/queries/game/market/export_of.rb` -- the player's market rows
- `app/domains/game/app/queries/game/export_of.rb` -- carries them and their cards
- `app/models/player_export.rb` -- writes the four sections

## Tasks & Acceptance

**Execution:**
- [ ] Market export query and its place in the game export
- [ ] The four sections in the player export
- [ ] Tests: query, game export, player export

**Acceptance Criteria:**
- Given a seller and a bidder with ledger entries, when each exports, then each file lists their own rows and no other player's maximum.

## Implementation Notes

Built as planned; nothing was run, only static checks. No migration: the ledger, bid and listing tables are already indexed by player. The player export's test keeps its rule that an integer is only allowed under a counting key, so the amounts joined that list.

## Plan Change Log

## Review Triage Log

## Verification

**Commands:**
- `ruby -c`, `script/check_planning_references`, `script/check_file_sizes` -- expected: no finding
