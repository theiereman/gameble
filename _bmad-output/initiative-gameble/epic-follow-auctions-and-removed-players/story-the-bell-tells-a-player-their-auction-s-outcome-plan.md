---
title: 'The bell tells a player their auction''s outcome'
type: 'feature'
ticket: '40.4'
created: '2026-11-10'
status: 'built'
baseline_revision: 'beb2dc7ad2776ec1418d585483a850bd471a923c'
route: 'full'
route_source: 'auto'
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/initiative-gameble/epic-follow-auctions-and-removed-players/epic-follow-auctions-and-removed-players.md'
  - '{project-root}/_bmad-output/initiative-gameble/epic-follow-auctions-and-removed-players/story-an-outbid-player-sees-a-bell-line-and-the-notice-on-the-annonce-plan.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A winner, a seller, a seller whose card got no offer and a bidder bought over learn nothing from the bell when an auction ends. Epic requirements R1 and R3 (the outcome half).

**Approach:** The first story's table, kinds, query and bell lines gain `won`, `sold`, `unsold` and `bought_over`, written by a handler of `AuctionSold` and of `AuctionUnsold`, each reloading the bell live through the `market` topic.

## Boundaries & Constraints

**Always:**
- `AuctionSold` writes `won` for the winner (the price), `sold` for the seller (what the seller receives, read from the ledger entries the sale just posted) and `bought_over` for the bidder a buy-now displaced (the other player is the buyer, the amount the released maximum). `AuctionUnsold` writes `unsold` for the seller. All through the same replacing upsert, so a buy-now line replaces the outbid line of the same listing, and no line is written for a player not involved.
- "Vous avez remporté <card> pour <amount>." and "<name> a acheté <card> immédiatement. Vos <amount> sont de nouveau disponibles." lead to the Annonce; "<card> s'est vendue. Vous recevez <amount>." and "<card> n'a reçu aucune offre. La carte vous est rendue." lead to MES VENTES. The action is "Voir".
- `PlayerStream` sends the `market` topic to the winner, the seller and the displaced bidder on `AuctionSold`, and to the seller on `AuctionUnsold`. Copy in `en.yml` and `fr.yml`.

**Never:**
- No migration; no new table or kind; no line for a lost bidder, a cancellation or a withdrawal; no edit of the operations that publish.

**Decisions (settled by Claude, no approval round in this batch; the author may revisit):**
- The `AuctionSold` branch of the first story's outbid handler moves to a new `Game::Market::Handlers::OutcomeNotices`, which owns both events and the four kinds; the outbid handler keeps only `BidPlaced`.
- A sale's received amount is the seller's `sale` and `commission` ledger entries of the listing summed, as the outcome query does, so the line states what actually reached the wallet.
- A won notice replaces the winner's earlier outbid line on that listing, as every line does.
- The bell line key keeps the listing token and notice time, so a line replaced by an outcome returns unseen.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Close with a winner | Auction ends sold | Winner's `won` line to the Annonce, seller's `sold` line to MES VENTES | No error expected |
| No bid | Auction ends with no leader | Seller's `unsold` line to MES VENTES | No error expected |
| Buy-now over a bid | B buys now over A's lead | A's outbid line replaced by `bought_over`, B's `won`, seller's `sold` | No error expected |
| Not involved | A third player | No line | No error expected |

</frozen-after-approval>

## Code Map

- `app/domains/game/app/handlers/game/market/handlers/outcome_notices.rb`, `outbid_notices.rb`, `config/initializers/event_store.rb` -- the handlers
- `app/helpers/bell_helper.rb`, `app/models/player_stream.rb` -- lines and live reload
- `config/locales/en.yml`, `fr.yml` -- copy

## Tasks & Acceptance

**Execution:**
- [ ] Outcome handler and subscription, outbid handler narrowed
- [ ] Bell lines and topic recipients, copy
- [ ] Tests: handler, helper, stream, one system test

**Acceptance Criteria:**
- Given an auction closes with a winner, then the winner's and the seller's bells each show their line, leading to the Annonce and to MES VENTES.

## Implementation Notes

Built as planned; nothing was run. A buy-now by the player already leading writes no bought-over line since nobody is displaced; the buyer's own earlier outbid line is replaced by the won line. The listing-close balance test and the unsold stream test now expect the market topic beside the balance one.

## Plan Change Log

## Review Triage Log

## Verification

**Commands:**
- `ruby -c`, `script/check_planning_references`, `script/check_file_sizes` -- expected: no finding
