---
title: 'The alt signals cover sales and bids between tied accounts'
type: 'feature'
ticket: '41.8'
created: '2026-11-10'
status: 'in-review'
baseline_revision: '265e0e12dbfb5ca554ea98ff0231161bb96e563d'
route: 'full'
route_source: 'auto'
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/initiative-gameble/epic-prices-economy-health-and-opening/epic-prices-economy-health-and-opening.md'
  - '{project-root}/_bmad-output/initiative-gameble/spec-gameble/market-economy.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** An alt account can move value through the market itself: sales far from the market price, minimum-price sales, and bids on a seller's listing. The signals of story 41.7 do not see them. Epic requirements R16 and R17.

**Approach:** `AltSignals` gains three detectors on the same table, operation and page: sales outside market price and minimum-price sales between the same two accounts, then bids on a listing from an account tied to its seller. Each row names the other account and gives its facts as a locale-key sentence.

## Boundaries & Constraints

**Always:**
- The tie comes only from the pair signals of the same run: one-way trades, sales outside market price and minimum-price sales, a pair read without order. A bid signal never makes a tie, and no other source (same device, same address, friendship) does.
- A sale is read as the seller and the listing's leader at its sale; a listing with no leader is skipped. The detectors read the sold listings and the bids, never write, and take `now`.
- Sentences have no plural forms; no signal reaches a player, no sanction is written, no id or token of a listing is shown.
- Copy in `en.yml` and `fr.yml`.

**Never:** a new table, operation or page; a tie from a signal other than a pair signal; a change to settlement or to bidding.

**Decisions (settled by Claude, no approval round in this batch; the author may revisit):**
- The edition's average at sale is the `average_after_sale` of the edition's previous sale, so a sale is never compared with itself; it needs at least the few-sales threshold of earlier sales of that edition, otherwise there is no market price to depart from.
- Outside market price: a final price under half or over twice that average. Signalled at 2 or more such sales between the same two accounts in 30 days; one row per seller and buyer. Facts: sales, below, above.
- Minimum-price sale: the final price equals the minimum price of its rarity in the settings version the listing was created under. Signalled at 3 or more in 30 days between the same pair, per seller and buyer. Facts: sales.
- Tied bids: any bid by an account on a listing of a seller it is tied to, opened in the last 30 days; one row per bidder and seller. Facts: listings, bids. The threshold is one listing, the tie being the evidence.
- The sentence of a row is rendered by one component, so the page and its component test read the same text.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Outside price edge | Sales at exactly half and twice the average / just beyond | Counted only beyond; two needed | No error expected |
| Too little history | Edition with fewer earlier sales than the few-sales threshold | Sale never counted | No error expected |
| Minimum-price edge | 3 sales at the minimum / 2 / 3 one above it | A row for the first only | No error expected |
| Tie | A bid by an account paired by a pair signal / not paired / paired only by another bid signal | Row only for the first | No error expected |
| No leader | Sold listing with no leader | Skipped | No error expected |

</frozen-after-approval>

## Code Map

- `app/domains/game/app/queries/game/market/alt_signals.rb` and `alt_signals/` -- the thresholds and detectors of story 41.7, extended here.
- `app/domains/game/app/operations/game/market/auction_settlement.rb` -- where `average_after_sale` is stored.
- `app/views/back_office/market_signals/` -- the page that renders each sentence.
- `config/locales/en.yml`, `fr.yml`.

## Tasks & Acceptance

**Execution:**
- [ ] The three detectors and the tie, wired into `AltSignals.call`
- [ ] `AltSignalSentenceComponent` used by the page
- [ ] Copy in both locales
- [ ] Tests: each signal at its threshold and below, the tie only from a pair signal, a component test of each sentence

**Acceptance Criteria:**
- Given seeded sales and bids, when the refresh runs, then each signal appears at its threshold and not below it, a tie comes only from another pair signal, and the page shows each new signal's sentence.

## Implementation Notes

Built as planned; nothing was run. `SalesOutsidePrice` reads each sold listing with the previous sale's `average_after_sale` through window functions in one SQL query; `MinimumPriceSales` compares the final price with the minimum of the listing's rarity in its own settings version; `TiedBids` takes the pairs of the three pair signals as ties, so a bid never makes one. `AltSignals.call` runs the pair detectors first and hands their pairs to `TiedBids`. Row direction: the seller for the two sale signals, the bidder for the bid signal, each naming the other account. No migration, operation or page changed beyond the sentences.

## Plan Change Log

## Review Triage Log

## Verification

**Commands:**
- `ruby -c`, YAML parse and en/fr parity, `script/check_planning_references`, `script/check_file_sizes` -- expected: no finding
