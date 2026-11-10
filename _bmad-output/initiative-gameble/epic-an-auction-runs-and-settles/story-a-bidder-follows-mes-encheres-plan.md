---
title: 'A bidder follows MES ENCHÈRES'
type: 'feature'
ticket: '39.10'
created: '2026-11-10'
status: 'draft'
baseline_revision: 'c38e74f58ede0041b64a02d0b1d838c2bbd16332'
route: ''
route_source: ''
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/initiative-gameble/epic-an-auction-runs-and-settles/epic-an-auction-runs-and-settles.md'
  - '{project-root}/_bmad-output/initiative-gameble/spec-gameble/market-economy.md'
  - '{project-root}/_bmad-output/initiative-gameble/epic-an-auction-runs-and-settles/story-a-seller-follows-mes-ventes-cancels-and-relists-plan.md'
  - '{project-root}/_bmad-output/initiative-gameble/epic-an-auction-runs-and-settles/story-a-player-bids-with-my-maximum-plan.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A bidder cannot see the auctions they bid on, whether they lead or were outbid, or how the last ones ended, and has no shortcut back to the field to raise. The MES ENCHÈRES half of R21.

**Approach:** A MES ENCHÈRES screen, reached by a chip on the market chip row, lists the player's auctions in EN COURS and TERMINÉES RÉCEMMENT (ended in the last 7 days) as the compact rows of the previous story, each with its status in words, price, own maximum and time left; RELEVER opens the Annonce with the My maximum field focused, filled only when the player is outbid.

## Boundaries & Constraints

**Always:**
- `Market::MyBidsController#show` (route `get "market/my-bids"`, helper `market_my_bids_path`) authorizes `Market::MyBidPolicy#show?` (`player?`); a visitor gets `sign_in_required`. It never writes and reads only through `Game::Market::BidderListings`.
- `BidderListings.call(player:, locale:)` returns the listings the player has a bid on, in two groups. Selection: listings with at least one of the player's own `game_market_bids` rows whose outcome is not `voided`, and either status `open`, or ended (any other status) with an end in the last 7 days, the end being `sold_at` else `ends_at`. `in_progress` is ordered by `ends_at` ascending, `recent` by end descending. Per row: token, card view, status, price, own maximum, end time, whether RELEVER applies. The only maximum read is the largest `maximum` among the player's own bid rows of that listing (a raise rewrites it upward), selected with `player_id` fixed to the viewer; the listing's `leader_maximum` and every other player's bid rows are never selected.
- Status in words: an open listing whose `leader_id` is the player is EN TÊTE, an open one with another or no leader DÉPASSÉ; a sold listing whose `leader_id` is the player REMPORTÉE, otherwise PERDUE; unsold PERDUE; withdrawn RETIRÉE; a cancelled one cannot hold a bid and is not selected. Price: the current price for an open row, the final price for a sold one. These map to the existing `MarketRowComponent` chip tones (EN TÊTE lime, DÉPASSÉ orange, REMPORTÉE gold, PERDUE and RETIRÉE muted).
- A row shows the 40px thumbnail, title (the stretched link to the Annonce), rarity in its colour, the chip, `Prix`, `Mon maximum` (read only for its owner, exact amount), `Fin` (the time left through the existing time-left helper for an open, not due row; `Clôture en cours…` for a due open row; the local end time for an ended row). On the phone each row wraps and its action sits on its own line.
- RELEVER is on every EN COURS row that is not due: a filled primary `ButtonComponent` link only while the player is DÉPASSÉ, a secondary link while EN TÊTE; its accessible name is `Relever, <card>`. It links to `market_listing_path(token:, focus: "maximum")`. Ended rows carry no action.
- `Market::ListingsController#show` reads `params[:focus]`: only the value `maximum` is meaningful, and it becomes the region's server-written focus target `field` when the viewer has a bid sheet; any other value or no sheet changes nothing. The existing `annonce` root focuses it when the region connects, so the Annonce arrives with the field focused instead of the `h1`. The GET still writes nothing.
- The MES ENCHÈRES chip joins the shared chip row between ANNONCES and MES VENTES (the order of the UX documents), greyed `aria-disabled` for a visitor; the screen has the Balance chip in its header, the phone back link, the two groups with `h2` headings, and the empty line `Vous n'avez enchéri sur aucune carte.` with a link variant to the market as the way on. Each group states its own empty line when only it is empty (`Aucune enchère en cours.`, `Aucune enchère terminée récemment.`).
- Reuses `MarketRowComponent`, the chip partial and `market-rows.css` of the previous story; this story adds a bidding variant of the row facts, not a second row.
- Only operations write; this story writes nothing. No database id in a URL, the HTML or a DOM id. Every string in `en.yml` and `fr.yml`. Files stay under 400 lines (Ruby, TypeScript) and 500 (CSS).

**Never:**
- No outbid count badge on the chip, the MARCHÉ tab or the menu, no bell line, no live refresh of the rows, no suspended-market greying (the next story), no new script, no maximum of another player, no leader's name, no cancel or bid from the list.

**Decisions (settled by Claude, no checkpoint in this run; the author may revisit):**
- The page is its own address and controller like MES VENTES, for the same reasons.
- "My maximum" is the largest of the player's own bid rows rather than the listing's `leader_maximum`: it is the player's own figure for every status (a beaten maximum included), and a leader's raise is one of those rows, so the leader's figure is the same.
- A listing the player bid on that ended unsold (its leader was removed) reads PERDUE and a withdrawn one RETIRÉE: the Copy deck has no neutral chip, and both keep the player's PiCoins untouched.
- RELEVER shows on the player's leading rows too, as a secondary link, so the way to the field from MES ENCHÈRES is always present; the ticket's "filled only when outbid" is the filled style, not the presence.
- Focus on the field uses the `?focus=maximum` query on the Annonce GET read by the server, because a fragment would not focus an input and the page's `h1` carries `autofocus`; the region's existing focus value wins since it runs after load.
- The 7-day window is measured from `sold_at` else `ends_at`; a withdrawn listing whose end lies in the future stays visible until 7 days after that end, which is harmless.
- Voided bids are excluded now though only the removal story writes that outcome, so that story needs no change here.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Leading | Open auction, the player leads with 30,000 | `EN TÊTE`, price, `Mon maximum` 30,000, time left, secondary `RELEVER` | No error expected |
| Outbid | Another player took the lead | `DÉPASSÉ`, filled `RELEVER` to the Annonce with the field focused | No error expected |
| Beaten at once | The player's bid never led | `DÉPASSÉ` with their typed maximum | No error expected |
| Won | Sold, the player is the leader, ended 2 days ago | In `TERMINÉES RÉCEMMENT`, `REMPORTÉE`, final price, no action | No error expected |
| Lost | Sold to another player | `PERDUE` | No error expected |
| Older than 7 days | Ended 8 days ago | Not listed | No error expected |
| Due, not yet closed | Open, `ends_at` passed | In `EN COURS`, `Clôture en cours…`, no RELEVER | No error expected |
| Visitor | No session | `sign_in_required` answer; the chip is greyed on the market | Policy refusal |
| Never bid | Player with no bid | The empty line with its way on | No error expected |
| Focus parameter | `?focus=maximum`, viewer can bid | Annonce opens with the field focused | Ignored when there is no form |

</frozen-after-approval>

## Code Map

- `app/views/markets/_chips.html.erb`, `app/components/market_row_component.rb`, `.html.erb`, `app/helpers/market_rows_helper.rb`, `app/frontend/styles/market-rows.css`, `app/views/market/my_sales/show.html.erb`, `_group.html.erb` (previous story) -- the shared chip row, row component, helper, styles and the screen skeleton to mirror.
- `app/controllers/market/listings_controller.rb`, `app/views/market/listings/show.html.erb`, `app/views/market/bids/_region.html.erb` -- the Annonce and its region whose `data-focus` the root already honours (`regionTargetConnected` in `app/frontend/controllers/annonce_controller.ts`).
- `app/domains/game/app/models/game/market/bid.rb`, `listing.rb`, `queries/game/market/bid_history.rb`, `bid_sheet.rb`, `listing_outcome.rb` -- bid outcomes and the owner-only reading rules to keep.
- `app/helpers/market_helper.rb` (`listing_seconds_left`, `listing_time_left`), `local_time_helper.rb`, `app/components/picoin_amount_component.rb`, `card_strings.rb` (rarity names).
- `app/domains/catalog/app/queries/catalog/card_view.rb` -- `image_url`, `title`, `rarity`.
- `config/routes.rb`, `config/locales/en.yml`, `fr.yml`, `test/support/market.rb`, `market_listings.rb`, `market_auctions.rb`, `market_bidding.rb`.

## Tasks & Acceptance

**Execution:**
- [ ] `app/domains/game/app/queries/game/market/bidder_listings.rb` -- the reader as stated: own bid maxima grouped by listing in one query, listings and cards in two more, statuses and window in Ruby from the listing's columns -- the screen's only reader
- [ ] `config/routes.rb` -- `get "market/my-bids" => "market/my_bids#show", as: :market_my_bids` -- address
- [ ] `app/policies/market/my_bid_policy.rb` -- `show?` is `player?` -- Pundit
- [ ] `app/controllers/market/my_bids_controller.rb` -- `show` authorizes `%i[market my_bid]`, reads `BidderListings` -- the screen
- [ ] `app/views/market/my_bids/show.html.erb`, `_group.html.erb` -- header, chips, the two groups and empty lines, rows built from `MarketRowComponent` with the bid facts and RELEVER -- the screen
- [ ] `app/views/markets/_chips.html.erb` -- add MES ENCHÈRES between ANNONCES and MES VENTES -- the chip
- [ ] `app/helpers/market_rows_helper.rb` -- bid status labels and tones (static keys), the RELEVER link and its accessible name, the end column text -- thin views
- [ ] `app/controllers/market/listings_controller.rb`, `app/views/market/listings/show.html.erb` -- pass `focus: "field"` to the region when `params[:focus] == "maximum"` -- the arrival on the field
- [ ] `app/frontend/styles/market-rows.css` -- the bidding columns (`Prix`, `Mon maximum`, `Fin`) and the filled/secondary action on the phone line -- the look
- [ ] `config/locales/en.yml`, `fr.yml` -- `market.chips.bids`, `market.my_bids.*` (heading, groups, labels, empty lines), `market.rows.status.leading|outbid|won|lost|withdrawn`, `market.rows.relever`, with the Copy deck's French -- the text
- [ ] `test/domains/game/market/bidder_listings_test.rb` -- groups and order, every status mapping, the 7-day edge (inside and outside), voided bids and cancelled listings excluded, own maximum equals the largest own bid row after a raise, never another player's maximum nor the listing's `leader_maximum` in the result, a due open listing, no bid no rows -- the reader
- [ ] `test/controllers/market/my_bids_controller_test.rb` -- visitor refused with `sign_in_required`, rows and chips with status words, filled `RELEVER` only for DÉPASSÉ with its accessible name and the `focus=maximum` link, no action on ended rows, empty lines, no database id, no other player's maximum in the page -- the screen
- [ ] `test/controllers/market/listings_controller_test.rb` -- `focus=maximum` writes the field focus value for a bidder, nothing for the seller, a visitor or another value -- the arrival
- [ ] `test/policies/market/my_bid_policy_test.rb` -- visitor refused, player allowed
- [ ] `test/system/market_bids_test.rb` -- the ticket's test: a player is outbid, sees `DÉPASSÉ`, follows `RELEVER` to the Annonce with the field focused; after the close finds the auction under `TERMINÉES RÉCEMMENT` as `PERDUE` -- the end-to-end check

**Acceptance Criteria:**
- Given a player who bid on three auctions, when they open MES ENCHÈRES, then each appears once with the right status word, price and their own maximum, in the right group.
- Given an outbid player, when they activate the filled RELEVER, then the Annonce opens with the My maximum field focused.
- Given an auction that ended 8 days ago, when MES ENCHÈRES draws, then it is absent; given one that ended yesterday, then it is under TERMINÉES RÉCEMMENT.
- Given any response, when it is read, then no other player's maximum, no leader maximum and no database id appears.
- Given a visitor, when the market screen draws, then MES ENCHÈRES is greyed, and the address answers `sign_in_required`.

## Implementation Notes

## Plan Change Log

## Review Triage Log

## Design Notes

- The reader selects `MAX(maximum)` from the viewer's own rows, filtered by `player_id`, so the owner-only rule is held by the query's shape and one test, as `BidSheet` does for the leader.

## Verification

**Commands:**
- `ruby -c` and `bundle exec rubocop` on each touched Ruby file; `npm run format:check`, `npm run lint:css` -- expected: no offence
- `bundle exec packwerk check` and `bin/rails zeitwerk:check` -- expected: pass
- `script/check_planning_references` and `script/check_file_sizes` -- expected: pass
- `bundle exec i18n-tasks missing` and `bundle exec i18n-tasks unused` -- expected: pass
- `bin/rails test` on the files above and `bin/rails test test/system/market_bids_test.rb` -- expected: green (run once at the end of the market build, not by the build agent)
