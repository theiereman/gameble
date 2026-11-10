---
title: 'The Annonce shows its history and its outcome'
type: 'feature'
ticket: '39.6'
created: '2026-11-10'
status: 'built'
baseline_revision: 'f5b7d792e87f7e996e8cc0c7f5abc2ce04e4c007'
route: 'full'
route_source: 'auto'
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/initiative-gameble/epic-an-auction-runs-and-settles/epic-an-auction-runs-and-settles.md'
  - '{project-root}/_bmad-output/initiative-gameble/spec-gameble/market-economy.md'
  - '{project-root}/_bmad-output/initiative-gameble/epic-an-auction-runs-and-settles/story-a-listed-copy-shows-on-the-market-and-its-annonce-plan.md'
  - '{project-root}/_bmad-output/initiative-gameble/epic-an-auction-runs-and-settles/story-bids-follow-the-auction-rules-plan.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Bids exist but the Annonce cannot show them: the history column is an empty placeholder, the leader is a fact row, tiles always read zero offers, and once an auction ends the page says nothing about how it went. Epic requirements R14, R15, R16 and R17.

**Approach:** Two read-only queries feed the Annonce on arrival: `BidHistory` (the public lines, plus the viewer's own raises) and `ListingOutcome` (what the closed auction means for this viewer). `OfferCounts` stops being a zero stub. The view gains a history partial, an outcome partial and the "En tête" line in the price block; nothing is written and nothing is live (epic 40).

## Boundaries & Constraints

**Always:**
- Both new queries run on the reading role inside the GET, select explicit columns and never select `maximum` from `game_market_bids`. The public history selects `id`, `player_id`, `price_after`, `outcome`, `extended_until`, `created_at`; the viewer's raise lines add nothing (a raise line prints name and time, never an amount). The only reads of `leader_maximum` and of the viewer's ledger entries sit in `ListingOutcome`, and only for the winner and the seller of a sold listing respectively.
- Every player name goes through `PlayerNameComponent` (viewer-aware link, anonymous for a banned or deleted player). Ids never reach HTML, DOM ids or JSON; the history is read by listing token (a join on `game_market_listings.token`), never by id.
- `OfferCounts.call(listing_ids)` counts bid rows whose outcome is not `raise` and not `voided`, grouped by listing, returning a `Hash.new(0)`; it is the one definition of "public validated bid", shared with the history.
- History order is newest first. One line per public bid row; an extension line (`Enchère prolongée jusqu'à <time>`, from `extended_until`) sits directly above the bid that caused it; a raise line (`<name> a relevé son maximum`) appears only when the bid row's player is the viewer; the listing's creation line (`Mise en vente par <name>`, from `created_at` and the seller) is always last. The "En tête" mark (gold, in words) goes on the single `leading` row of the listing's current leader while the listing is `open`; it is absent once the listing is closed (the outcome says who won).
- The Annonce's price block shows `En tête : <name>` through `PlayerNameComponent` when there is a leader and the leader is not removed; the old "Leading" fact row in the facts list is removed. A removed leader prints the anonymous name (the listing keeps pointing at them until the removed-players epic).
- Between `ends_at` and the settlement (status still `open`, `ends_at` at or before now) the Annonce shows `Clôture en cours…` in the region where the bid form will sit. Once the status is not `open`, the outcome panel replaces that region for the viewer, chosen in this order: `cancelled`, `withdrawn`, `unsold` (`Aucune offre.`), then for `sold` the winner (`VOUS AVEZ REMPORTÉ <card>` with the surplus sentence only when `leader_maximum - final_price` is positive, and `VOIR LA CARTE`), a bought-at-once winner (`VOUS AVEZ ACHETÉ <card>`), the seller (`VENDUE`, received amount from the seller's `sale` and `commission` entries of that listing), a viewer who had bids on it (`lost`: `ENCHÈRE TERMINÉE`, PiCoins returned) and any other viewer or visitor (`ENCHÈRE TERMINÉE`, winner and price). A sale at the buy-now price (final price equals the buy-now price) adds `en achat immédiat` to the seller and viewer lines and is the only case of the bought variant.
- The history stays on screen after the close. The outcome heading is an `h2` with `tabindex="-1"` and the id `listing-outcome-heading`, so later stories can focus it; nothing moves focus here (arrival focus stays on the h1).
- A GET writes nothing. Only the view and queries change; no operation, no event, no migration, no schema change.
- Every string in `en.yml` and `fr.yml`; the English wording follows the French Copy deck. Server HTML carries no `style` attribute. Source files stay under their size limits (the Annonce view moves its regions into partials).

**Never:**
- No bid form, no polite status region, no rate limit, no controller or route besides the existing `show` (the bidding story), no live refresh, throttled posts or end-time wording (the live-refresh stories), no voided line and no bell line (the removed-players and notices epic), no cancel or relist, no `MES ENCHÈRES`/`MES VENTES` rows.
- No second definition of a public bid, a commission or a surplus: the offer count and history share one exclusion list, the seller's received amount is read from the ledger rows the settlement wrote, and the winner's surplus is `leader_maximum - final_price`.
- No `maximum` of any other player in any query, view, data attribute or log line; no database id in the markup.

**Decisions (settled by Claude, no checkpoint in this run; the author may revisit):**
- The card detail's pioneer row already renders through `PlayerNameComponent` (card detail and public card page); the ticket's sentence about it is satisfied by the listing story. Nothing changes there; a view test keeps it covered.
- A `voided` bid is neither a public line nor an offer in this story; the removed-players epic adds its line (`Offre annulée : joueur retiré`) with the code that writes voided rows.
- The history query takes the listing token and the viewer (a player or nil) and returns `Line` data objects (`kind`, `player`, `price`, `at`, `until`, `leading`); kinds are `bid`, `extension`, `raise`, `created`. The view never reads a row.
- `ListingOutcome.call(token:, viewer:)` returns `nil` while the listing is open and not due, a `Closing` marker while it is open and due, and an `Outcome` data object otherwise (`kind`, `card`, `winner`, `price`, `surplus`, `received`, `buy_now`). Kinds: `won`, `bought`, `lost`, `seller_sold`, `viewer_sold`, `no_bid`, `cancelled`, `withdrawn`. The query is the single owner-aware reader; `ListingByToken` stays public and keeps selecting no maximum.
- "Lost" means the viewer holds at least one bid row of that listing with outcome `lost` (the settlement turns every non-winner's `leading`, `outbid` and `beaten` rows to `lost`); a viewer whose only rows are raises is their own leader and therefore the winner, never "lost".
- `Clôture en cours…` is a plain visible `p` in the outcome partial. The page's single polite status region is created by the bidding story and extended by the live stories; this story adds no live region.
- The history column is 330px on desktop and last on the phone (CSS grid areas); each line shows the time through the existing `local_time_tag` helper, price through `PicoinAmountComponent`.
- A leader's "En tête" mark is looked up from the `leading` row, not recomputed from prices, so an equal-maximum tie (earlier leader keeps the lead) stays correct.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Three bids, open | Bids 30,000 (leading), 25,000 (beaten), 40,000 (new leader, extension) | Lines newest first: the 40,000 line with `En tête` and, above it, the extension line; the 25,000 line; the 30,000 line; creation line last. Offer count 3 | No error expected |
| Raise, owner vs others | The leader raised their maximum | The leader reads a raise line; every other viewer and a visitor read none; offer count does not count it | No error expected |
| No bid | Listing open, no bid | History is the creation line only; tile reads `0 offres` | No error expected |
| Due, not settled | Open, `ends_at` past | `Clôture en cours…` where the form will sit; history stays | No error expected |
| Won | Viewer is the winner, maximum above price | `VOUS AVEZ REMPORTÉ`, price, surplus sentence, `VOIR LA CARTE` | No error expected |
| Won, no surplus | Winner's maximum equals the final price | Same without the second sentence | No error expected |
| Bought at once | Final price equals the buy-now price | Winner reads `VOUS AVEZ ACHETÉ`; seller and viewers read `en achat immédiat` | No error expected |
| Lost | Viewer has a `lost` bid row | `ENCHÈRE TERMINÉE`, winner name via the shared component, price, PiCoins returned | No error expected |
| Seller, sold | Sold listing, viewer is seller | `VENDUE`, buyer, price, amount received (sale less commission) | No error expected |
| Viewer or visitor | Sold listing | `ENCHÈRE TERMINÉE`, winner and price; no amounts of any maximum | No error expected |
| Unsold / cancelled / withdrawn | Status set by the settlement or later stories | The matching Copy deck panel | No error expected |
| Removed participant | Winner or leader banned or deleted | Name prints as the anonymous key, no link | No error expected |
| Privacy | Any viewer | No query selects `maximum` from bids; no id in the HTML | A query test fails if it does |

</frozen-after-approval>

## Code Map

- `app/views/market/listings/show.html.erb` -- the Annonce; holds the empty `market-listing__history` placeholder and the leader fact row; split into partials and gains the outcome region.
- `app/controllers/market/listings_controller.rb` -- `show` loads `@listing`; gains `@history` and `@outcome` from the new queries; stays a GET on the reading role with `PublicRead`.
- `app/policies/market/listing_policy.rb` -- `show?` already true for visitors; unchanged.
- `app/domains/game/app/queries/game/market/listing_by_token.rb` -- public detail reader to mirror (explicit `select`, `CardViews`); unchanged.
- `app/domains/game/app/queries/game/market/offer_counts.rb` -- zero stub; becomes the real count.
- `app/domains/game/app/queries/game/market/open_listings.rb`, `app/views/markets/_tile.html.erb`, `app/helpers/market_helper.rb` -- already read `OfferCounts` and print `n offres`; unchanged except tests.
- `app/domains/game/app/models/game/market/bid.rb` -- gains the `public_outcomes` scope used by both queries (outcome not `raise`, not `voided`).
- `app/domains/game/app/models/game/market/ledger_entry.rb` -- the seller's `sale` and `commission` rows, read by `ListingOutcome`.
- `app/components/player_name_component.rb` -- names every player; unchanged.
- `app/helpers/local_time_helper.rb`, `app/components/picoin_amount_component.rb` -- time and amount rendering.
- `app/frontend/styles/market-listing.css`, `app/frontend/entrypoints/application.css` -- Annonce layout; a new `market-history.css` imported beside it.
- `config/locales/en.yml`, `fr.yml` -- `market.listings.*` keys.
- `test/support/market_bidding.rb`, `market_auctions.rb`, `market_listings.rb`, `test/controllers/market/listings_controller_test.rb`, `test/system/market_listing_test.rb` -- arrangement and tests to reuse or extend.

## Tasks & Acceptance

**Execution:**
- [ ] `app/domains/game/app/models/game/market/bid.rb` -- add `scope :public_outcomes, -> { where.not(outcome: %w[raise voided]) }` -- one definition of a public validated bid
- [ ] `app/domains/game/app/queries/game/market/offer_counts.rb` -- `Bid.public_outcomes.where(listing_id: ids).group(:listing_id).count` into a `Hash.new(0)` -- tiles read real counts
- [ ] `app/domains/game/app/queries/game/market/bid_history.rb` -- `BidHistory.call(token:, viewer:)`: join listing by token, select the explicit columns, the viewer's raise rows plus `public_outcomes`, newest first by `id`; build `Line` objects (bid, extension above its bid, raise for the viewer, creation last), load players in one query, mark the leader's `leading` row only while the listing is open -- the public read never selects a maximum
- [ ] `app/domains/game/app/queries/game/market/listing_outcome.rb` -- `ListingOutcome.call(token:, viewer:, locale:)` returning nil, `Closing` or `Outcome` as decided; reads `leader_maximum` only when the viewer is the sold listing's leader, the seller's `sale`/`commission` entries only for the seller (`received` is the sum of their `available_delta` for that listing and the seller, the `commission` row being absent when the commission is zero, never `sale` alone), the viewer's `lost` rows only for the viewer -- owner-only reads in one place
- [ ] `app/controllers/market/listings_controller.rb` -- load `@history` and `@outcome` after `@listing` -- the page reads them on arrival
- [ ] `app/views/market/listings/show.html.erb` -- remove the leader fact row, add `En tête : <name>` under the price, render `_history` and `_outcome`; keep the file short -- price block and regions
- [ ] `app/views/market/listings/_history.html.erb` -- `HISTORIQUE` heading, `ol` of lines newest first, `En tête` word mark, extension, raise, creation lines -- the history column
- [ ] `app/views/market/listings/_outcome.html.erb` -- rendered inside an element `id="annonce-bid"` on the Annonce and taking `outcome:` and `viewer:` as locals (never instance variables, so the bidding story can render it from a Turbo Stream); `Clôture en cours…` or the outcome panel (heading `h2` with `tabindex="-1"`, body, `VOIR LA CARTE` as a `ButtonComponent` link to the card) by kind -- the closed Annonce
- [ ] `app/helpers/market_helper.rb` (or a new `app/helpers/market_history_helper.rb` if the file nears 400 lines) -- `history_line_text(line)`, `outcome_body(outcome)` assembling `t()` keys; no copy in Ruby literals -- keeps views thin
- [ ] `app/frontend/styles/market-history.css` and `application.css` import -- 330px column on desktop, last on the phone, gold `En tête` mark, outcome panel colours by kind class, no inline style -- the layout
- [ ] `config/locales/en.yml` and `fr.yml` -- under `market.listings`: `show.leader` ("Leading:" / "En tête :"), `history.heading` (HISTORY / HISTORIQUE), `history.leading` (Leading / En tête), `history.bid` (`%{name}`, price and time are separate elements), `history.extension` ("Auction extended until %{time}" / "Enchère prolongée jusqu'à %{time}"), `history.raise` ("%{name} raised their maximum" / "%{name} a relevé son maximum"), `history.created` ("Listed by %{name}" / "Mise en vente par %{name}"), `outcome.closing` ("Closing…" / "Clôture en cours…"), `outcome.won.title|body|body_surplus|see_card`, `outcome.bought.title|body`, `outcome.lost.title|body`, `outcome.viewer.title|body`, `outcome.seller.title|body`, `outcome.buy_now_suffix`, `outcome.no_bid.title|body`, `outcome.cancelled.title|body`, `outcome.withdrawn.title|body`, each with the Copy deck's French and an English equivalent -- every new string in both languages
- [ ] `test/domains/game/market/offer_counts_test.rb` -- counts ignore raises and voided rows, are per listing, absent listing reads 0 -- the count
- [ ] `test/domains/game/market/bid_history_test.rb` -- order newest first, extension above its bid, raise visible only to its owner, creation last, `En tête` only on the open listing's leading row, name data for a removed player, and a SQL-subscriber assertion that no statement selects `maximum` from `game_market_bids` -- the privacy rule
- [ ] `test/domains/game/market/listing_outcome_test.rb` -- every kind from the matrix, surplus present and absent, received amount equals the ledger's `sale` less `commission`, `Closing` when due and open, buy-now suffix, lost vs raise-only viewer, visitor (nil viewer) -- the outcome
- [ ] `test/controllers/market/listings_controller_test.rb` -- extend: a visitor reads history and outcome, no token or id of a player in the markup, the page makes no write -- reading rules
- [ ] `test/helpers/market_helper_test.rb` -- tile label keeps working with real counts -- regression
- [ ] `test/components/player_name_component_test.rb` or `test/views/cards/` -- assertion that the card detail pioneer row renders the component (existing behavior kept) -- the ticket's pioneer sentence
- [ ] `test/system/market_annonce_test.rb` -- after three bids through `PlaceBid` and a close, the winner, the loser, the seller and a visitor each read their outcome; the history lists the bids newest first with the extension line and no raise line for the visitor -- the ticket's system test

**Acceptance Criteria:**
- Given a listing with three bids, an extension and a raise, when a visitor opens its Annonce, then the history shows the bids newest first with the extension line, the creation line last, `En tête` on the leader's line, and no raise line.
- Given the same listing, when the leader opens it, then their raise line appears and no amount of any maximum is on the page.
- Given a listing with no settlement yet and an end in the past, when anyone opens it, then `Clôture en cours…` stands where the form will sit.
- Given a closed listing, when the winner, a loser, the seller and a visitor open it, then each reads the outcome of the Copy deck for them, with the history unchanged.
- Given the market screen, when a listing holds bids, then its tile reads the number of public bids and a raise does not add to it.
- Given any of these reads, when the request is a GET, then no row is written and no id of any table is in the HTML.

## Implementation Notes

## Plan Change Log

- 2026-11-10, approver (one round): body only, frozen block untouched. `_outcome` takes locals and sits in `#annonce-bid` so the bidding story reuses it in a Turbo Stream; `received` is the sum of the seller's `sale` and `commission` rows (the commission row is not written when zero).

## Review Triage Log

## Design Notes

- One shared exclusion list keeps tiles and history honest: a raise is private and a voided bid is the removed-players story's line, so both queries start from `Bid.public_outcomes`.
- The outcome is chosen by the viewer, not by the listing: the same sold listing is `won`, `lost`, `seller_sold` or `viewer_sold`. Reading `leader_maximum` or the ledger is allowed only on the branch where the viewer owns that number.

```ruby
Line = Data.define(:kind, :player, :price, :at, :until, :leading)
Outcome = Data.define(:kind, :card, :winner, :price, :surplus, :received, :buy_now)
# kind: :won, :bought, :lost, :seller_sold, :viewer_sold, :no_bid, :cancelled, :withdrawn
```

## Verification

**Commands:**
- `ruby -c` and `bundle exec rubocop` on each touched Ruby file -- expected: no offence
- `bundle exec erb_lint` or the project's view lint if configured, `npm run lint:css`, `npm run format:check` -- expected: pass
- `bundle exec packwerk check` -- expected: no violation (the queries stay in `Game`, the controller reads through them)
- `script/check_planning_references` and `script/check_file_sizes` -- expected: pass
- `bin/rails test test/domains/game/market/offer_counts_test.rb test/domains/game/market/bid_history_test.rb test/domains/game/market/listing_outcome_test.rb test/controllers/market/listings_controller_test.rb test/helpers/market_helper_test.rb` and `bin/rails test test/system/market_annonce_test.rb` -- expected: green (run once at the end of the market build, not by the build agent)
- `bin/rails zeitwerk:check` and `bundle exec i18n-tasks missing` -- expected: pass
