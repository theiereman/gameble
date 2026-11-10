---
title: 'A seller follows MES VENTES, cancels and relists'
type: 'feature'
ticket: '39.9'
created: '2026-11-10'
status: 'in-review'
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
  - '{project-root}/_bmad-output/initiative-gameble/epic-an-auction-runs-and-settles/story-a-seller-lists-a-card-from-mettre-en-vente-plan.md'
  - '{project-root}/_bmad-output/initiative-gameble/epic-an-auction-runs-and-settles/story-unusual-maximums-and-buy-now-are-confirmed-first-plan.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A seller has no list of their listings, cannot take a listing back while no bid stands, and cannot relist an unsold card without retyping it. Epic requirements R3 and the MES VENTES half of R21.

**Approach:** A `CancelListing` operation releases the reservation of an open listing with no leader (also while the market is closed). A MES VENTES screen, reached by a chip on the market screen's chip row, lists the seller's listings in two groups of compact rows; ANNULER confirms in a dialog, REMETTRE EN VENTE opens the existing Mettre en vente on its second step with the start and buy-now prefilled. The Annonce shows the same ANNULER to its seller.

## Boundaries & Constraints

**Always:**
- `Game::Market::CancelListing#call(player:, listing_id:)`: `require_player`, then in one transaction `lock_bank(player)`, then `Listing.lock.find_by(id:, seller_id: player.id)`, then the seller's holding lock (`TradeLocks.holdings`), in that order. Refusals: no such listing for this seller `Failure(:listing_not_found)`; a status other than `open`, or `ends_at` reached, `Failure(:auction_ended)`; a leader present (removed or not) `Failure(:bid_standing)`; a deadlock `Failure(:market_busy)`. It never reads the market's open flag. On success it lowers the holding's `reserved` by one (the step extracted from `CloseAuction` into a shared module, see Code Map), sets the status `cancelled`, writes no ledger entry (the stamp is never refunded, nothing is held) and publishes one `Game::Market::ListingCancelled` (`listing_id`, `seller_id`, identifiers only) inside the transaction.
- The event joins no balance notice: no wallet moves.
- The POST is `post "market/listings/:token/cancellation"` (helper `market_listing_cancellation_path`) to `Market::CancellationsController#create`, which maps the token with `ListingIdByToken` (unknown: 404), authorizes with `Market::CancellationPolicy#create?` on the listing's public detail (`player? && record.seller.id == player.id`, so a visitor gets `sign_in_required` and another player the forbidden answer), rate limits with `throttle_player`, calls the operation and always answers a 303 redirect: success to MES VENTES (or the Annonce when the form came from it) with the notice `Vente annulée.`; a refusal to the same place with the operation's `failure_message` as alert, so `bid_standing` reads the Copy deck's `Une offre vient d'arriver. La vente ne peut plus être annulée.`
- `Market::MySalesController#show` (route `get "market/my-sales"`, helper `market_my_sales_path`) authorizes `Market::MySalePolicy#show?` (`player?`), so a visitor gets `sign_in_required`. It never writes. It reads only through `Game::Market::SellerListings`.
- `SellerListings.call(player:, locale:)` returns the seller's own listings as rows in two groups: `in_progress` (status `open`, soonest end first) and `ended` (sold, unsold, cancelled, withdrawn whose end is in the last 30 days, newest first, at most 100). A row carries: token, card view, status, current price, end time, the end of an ended listing (`sold_at`, else `ends_at`), `received` for a sold row (the seller's own `sale` plus `commission` ledger rows of that listing, summed in one grouped query for all rows; never another player's), `can_cancel` (open, no leader, `ends_at` ahead) and, for an unsold row, a relist offer (`ref` from `EntrustableCopies.ref(card.id, card.season_number)`, the listing's `starting_price` and `buy_now_price`) only while it is the seller's latest listing of that edition and a free copy of it exists now (one holdings query for all rows). No leader or bidder identity, no maximum.
- Rows are the new `MarketRowComponent`: a 40px thumbnail (decorative image, no `style` attribute), the title as a link to the Annonce stretched over the whole row by CSS, the status chip in words (EN COURS, VENDUE, SANS OFFRE, ANNULÉE, RETIRÉE) with the Status chip colours, labelled columns (Prix, Fin), and the action as a sibling after the link, never inside it. A sold row shows `Reçu <amount>, après l'Effort de la Confrérie` in gold; an unsold row `Aucune offre, carte rendue. Le timbre n'est pas remboursé.` Amounts go through `PicoinAmountComponent`, compact on rows. Each group has an `h2` with `tabindex="-1"`.
- ANNULER shows only on a row with `can_cancel`, and on the Annonce for its seller while the listing is open, has no leader and is not due; its accessible name is `Annuler la vente, <card>`. It opens one dialog per row (id `cancel-<token>`): title `ANNULER CETTE VENTE ?` focused on opening, text `<card> vous revient. Le timbre n'est pas remboursé.`, `GARDER LA VENTE` (secondary, left, safe) and `ANNULER LA VENTE` (primary), ✕ and Esc closing it. The dialog's form posts `return_to` (`sales` or `annonce`, anything else treated as `sales`) and `landing`: the token of the row that follows in the group, empty for the last.
- Focus after a cancel from MES VENTES follows the Copy deck's rule: the redirect carries `landing`; the page's `row-focus` controller focuses that row's title link, or the group's heading when there is none or it is gone. A visit without `landing` focuses nothing. From the Annonce the redirect lands on the Annonce, whose `h1` takes focus on arrival as it always does.
- REMETTRE EN VENTE is a `ButtonComponent` link to `new_market_sale_path(ref:, start:, buy_now:, relisting: 1)` (the prefill parameters `Market::SalesController` already reads); the relist is a new listing with a new stamp, made by the unchanged `ListCard`. Its accessible name is `Remettre en vente, <card>`.
- The MES VENTES chip joins the market screen's chip row, drawn by one shared partial used by the market and MES VENTES screens: a link for a player, `aria-current="page"` on the current one, a greyed `aria-disabled` span for a visitor. The MES VENTES screen carries the Balance chip in its header as the market does, the phone back link to the market, and `noindex` is inherited from the signed-in layout. Empty: `Vous n'avez mis aucune carte en vente.` with a link variant `METTRE EN VENTE` as the way on.
- Controllers write nothing: only `CancelListing` writes. No database id in a URL, the HTML, a DOM id or the redirect; the dialog id and `landing` are tokens.
- Every string in `en.yml` and `fr.yml`, including the new `errors.game.bid_standing` added by hand in both. Files stay under 400 lines (Ruby, TypeScript) and 500 (CSS).

**Never:**
- No suspended-market greying or banner on the new screens (the next-but-one story), no MES ENCHÈRES chip or screen, no outbid badge, no live refresh, no bell line, no refund of a stamp, no cancel of a listing that has a leader, no new write in a GET, no React, no markup built in script, no controller reaching a model.

**Decisions (settled by Claude, no checkpoint in this run; the author may revisit):**
- Cancelling goes through plain redirects with the app's toast, not a Turbo Stream: the same handling for the success, the refusal and the throttle, and focus is restored from a server-written `landing` token on the next GET instead of a render-timing guess.
- MES VENTES has its own address and controller (`market/my-sales`) beside the market screen rather than a tab inside it: the screen's chips are links, each screen is read on arrival, and the market screen's paging and sorts stay unshared.
- Two groups only, EN COURS and TERMINÉES: the ticket's five statuses are the chips of the rows, and the focus rule's "group heading" needs groups. The ticket gives no window for ended sales; the screen keeps the last 30 days and at most 100 rows so the page stays bounded.
- A cancel refuses once the end is reached (`auction_ended`) even with no leader: the close job turns that listing `unsold` within seconds, and a cancel racing it must not leave two outcomes. A leader that is removed still counts as a leader here; the removal story releases it.
- `CancelListing` reuses `auction_ended` and `listing_not_found`; only `bid_standing` is a new code.
- The relist offer needs a free copy of the edition now and the row to be the latest listing of that edition: it prevents a dead link and a second relist of the same old row. Otherwise the row simply has no action.
- The chip order is ANNONCES, MES ENCHÈRES, MES VENTES as the UX documents and the mockups show; this story draws ANNONCES and MES VENTES and the next story inserts MES ENCHÈRES between them, so the ticket's "after MES VENTES" is read as the build order.
- Empty group of the open rows after the last cancel: its heading stays with `Aucune vente en cours.` (not in the Copy deck; to be approved with the other English lines).
- One cancel dialog per row, not one shared dialog: no script has to carry a card name, and a dialog is server-rendered with the row.
- The throttle is 20 cancels per player per minute, redirecting to MES VENTES with the app's throttle alert.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Cancel, no bid | Open listing, no leader, seller confirms | Status `cancelled`, `reserved` lowered by one, no ledger entry, `ListingCancelled` published, redirect with `Vente annulée.`, focus on the next row's title or the group heading | No error expected |
| Cancel while closed | Settings version closed, no leader | Same as above | No error expected |
| Bid arrived first | A leader stands when the lock is taken | Nothing changes; redirect with the Copy deck's `Une offre vient d'arriver…` | `Failure(:bid_standing)` |
| Already ended | Sold, unsold, cancelled, withdrawn, or due | Nothing changes; `Cette enchère est terminée.` | `Failure(:auction_ended)` |
| Someone else's listing | Another player posts the token | Forbidden answer, nothing changes | `Pundit::NotAuthorizedError` |
| Visitor | No session | `sign_in_required` answer | Policy refusal |
| Unknown token | Wrong token | 404 | Not found |
| Deadlock | Concurrent writers | `market_busy` text | `Failure(:market_busy)` |
| Double submit | Two cancels | The second finds status `cancelled` and answers `auction_ended` | `Failure(:auction_ended)` |
| Relist an unsold card | Unsold row, a free copy, latest of the edition | Mettre en vente on step 2, edition chosen, start and buy-now prefilled, the relisting line shown, a new stamp on submit | No error expected |
| Relist without a free copy | Unsold row whose copy is reserved again | No action on the row | No error expected |
| Sold row | Sold listing | `VENDUE`, `Reçu <amount>` from the seller's own ledger rows | No error expected |
| Empty | Seller never listed | The empty line with its way on | No error expected |

</frozen-after-approval>

## Code Map

- `app/domains/game/app/operations/game/market/close_auction.rb` -- holds the private `release_reservation`; moves into the shared module below, behaviour unchanged.
- `app/domains/game/app/operations/game/market/auction_settlement.rb` -- the sibling module pattern to follow.
- `app/domains/game/app/operations/game/market/list_card.rb`, `app/controllers/market/sales_controller.rb`, `app/views/market/sales/new.html.erb` -- the operation shape, `prefill` (`ref`, `start`, `buy_now`, `relisting`) and the relisting line that already exist.
- `app/domains/game/app/queries/game/market/listing_id_by_token.rb`, `listing_by_token.rb`, `listing_outcome.rb` -- token to id, the public detail the policy reads, and the seller-ledger `received` reading to mirror.
- `app/controllers/application_controller.rb` (`throttle_player`, `redirect_refused`, `refuse`), `app/controllers/market/sales_controller.rb` -- the throttle and redirect-with-alert patterns.
- `app/views/markets/screen.html.erb`, `app/views/market/listings/show.html.erb`, `app/views/market/bids/_region.html.erb` -- the chip row, the Annonce, and the region where the seller sees nothing today.
- `app/views/friends/_remove_dialog.html.erb`, `app/views/market/bids/_buy_now_dialog.html.erb`, `app/frontend/controllers/dialog_controller.ts`, `dialog_opener_controller.ts` -- the dialog markup and its controllers.
- `app/components/button_component.rb`, `picoin_amount_component.rb`, `app/helpers/market_helper.rb`, `local_time_helper.rb`, `market_sales_helper.rb` -- buttons (`opens:`, link variant), amounts, time left.
- `app/domains/catalog/app/queries/catalog/card_view.rb`, `app/domains/game/app/queries/game/market/entrustable_copies.rb` (`ref`) -- the card facts and the edition reference.
- `config/routes.rb`, `config/locales/en.yml`, `fr.yml`, `app/frontend/entrypoints/application.css`, `test/support/market.rb`, `market_listings.rb`, `market_auctions.rb`, `holdings.rb`.

## Tasks & Acceptance

**Execution:**
- [ ] `app/domains/game/app/operations/game/market/listing_reservation.rb` -- module with `release_reservation(listing, now)` moved out of `CloseAuction` -- one place lowers `reserved`
- [ ] `app/domains/game/app/operations/game/market/close_auction.rb` -- include the module, delete its private copy -- no duplicate
- [ ] `app/domains/game/app/events/game/market/listing_cancelled.rb` -- the event class, empty like its siblings
- [ ] `app/domains/game/app/operations/game/market/cancel_listing.rb` -- the operation as stated, with the Success value the listing -- the write
- [ ] `app/domains/game/app/queries/game/market/seller_listings.rb` -- rows and groups as stated, one query per fact (listings, cards, received, free copies, latest-per-edition), no N+1; the end of a cancelled or withdrawn row, for its window, order and `Fin`, is its `updated_at` (its `ends_at` may still lie ahead and nothing writes it afterwards), with no upper bound on the window; a listing whose card view cannot be built is left out -- the screen's only reader
- [ ] `config/routes.rb` -- `get "market/my-sales"` and `post "market/listings/:token/cancellation"` beside the market routes -- addresses
- [ ] `app/policies/market/my_sale_policy.rb`, `app/policies/market/cancellation_policy.rb` -- `show?` is `player?`; `create?` is `player? && record.seller.id == player.id` -- Pundit for both actions
- [ ] `app/controllers/market/my_sales_controller.rb` -- `show` reads `SellerListings`, passes `params[:landing]` through as a plain string -- the screen
- [ ] `app/controllers/market/cancellations_controller.rb` -- `create` as stated, `return_to` and `landing` allow-listed -- the write endpoint
- [ ] `app/views/markets/_chips.html.erb` -- the shared chip row (`current:` local), ANNONCES and MES VENTES, greyed for a visitor -- one place for the row
- [ ] `app/views/markets/screen.html.erb` -- render the shared chips in place of the lone chip -- wiring
- [ ] `app/views/market/my_sales/show.html.erb`, `_group.html.erb` -- header with the Balance chip, chips, the two groups with headings, the empty states, `data-controller="row-focus"` with the landing value -- the screen
- [ ] `app/components/market_row_component.rb` and `.html.erb` -- the row with an `action` slot, chip tone by status, stretched title link -- shared with MES ENCHÈRES next
- [ ] `app/views/market/cancellations/_dialog.html.erb` -- the confirmation dialog with its form, `return_to`, `landing` -- one per cancellable row and on the Annonce
- [ ] `app/views/market/bids/_region.html.erb`, `app/views/market/listings/show.html.erb` -- when the viewer is the seller of an open, leaderless, not-due listing the region holds the ANNULER opener and its dialog (`return_to: annonce`) -- the Annonce's own ANNULER
- [ ] `app/helpers/market_rows_helper.rb` -- status labels (static keys in a `case`), chip tone, the relist path, the received line -- thin views
- [ ] `app/frontend/controllers/row_focus_controller.ts` and `row_focus_controller.test.ts` -- on connect, with a `landing` value, focus the title link carrying that token else the heading target; nothing without the value -- the focus rule
- [ ] `app/frontend/styles/market-rows.css`, `application.css` import -- compact rows, stretched link, 44px actions, chip colours, phone wrap with the action on its own line -- the look, no inline style
- [ ] `config/locales/en.yml`, `fr.yml` -- `market.chips.sales`, `market.my_sales.*` (heading, groups, labels, empty lines, received, no-bid note), `market.rows.status.*`, `market.cancellations.*` (dialog texts, buttons, notice, throttle), `errors.game.bid_standing`, with the Copy deck's French and an English equivalent -- the text
- [ ] `test/domains/game/market/cancel_listing_test.rb` -- cancel releases `reserved`, writes no ledger entry and publishes the event; cancel while closed; refused with a leader (also a removed one), after the end, when not open, for another seller and unknown id; a bid placed first refuses (`PlaceBid` then `CancelListing`); a race of `PlaceBid` and `CancelListing` ends with either a leader and an open listing or a cancelled listing and no hold, ledger reconciled; the stamp is not refunded -- the operation
- [ ] `test/domains/game/market/close_auction_test.rb` -- the existing unsold and withdrawn cases still release `reserved` once -- the extraction
- [ ] `test/domains/game/market/seller_listings_test.rb` -- groups and order, the 30-day and 100-row bounds (a listing cancelled with its `ends_at` still ahead is in `ended`, dated by its cancel), `received` equal to the seller's ledger rows and none for others, `can_cancel` rules, the relist offer (latest of the edition only, free copy needed, prefill values), no other player's data -- the reader
- [ ] `test/controllers/market/cancellations_controller_test.rb` -- visitor `sign_in_required`, other player forbidden, unknown token 404, success redirect and notice for both origins, refusal alert texts in English and French, the throttle, allow-listed `return_to`, no database id in the redirect -- controller rules
- [ ] `test/controllers/market/listings_controller_test.rb` -- the Annonce draws ANNULER and its dialog (`return_to` annonce) only for the seller of an open, leaderless, not-due listing; not with a leader, not once ended or due, not for another player or a visitor -- the Annonce's own ANNULER
- [ ] `test/controllers/market/my_sales_controller_test.rb` -- visitor refused, rows and chips, ANNULER only on cancellable rows with its dialog, REMETTRE link parameters, empty state, `landing` written as a value, chips on the market screen (links for a player, greyed for a visitor) -- the screen
- [ ] `test/policies/market/my_sale_policy_test.rb`, `cancellation_policy_test.rb` -- visitor, other player, seller
- [ ] `test/components/market_row_component_test.rb` -- chip words and tones, title link before the action, accessible names, no `style` attribute
- [ ] `test/system/market_sales_test.rb` -- the ticket's test: a seller cancels from MES VENTES, confirms in the dialog, gets the card back and focus lands on the next row; relists an unsold copy with the amounts prefilled and lands on the new Annonce; a late bid makes the cancel refuse with the Copy deck line -- the end-to-end check

**Acceptance Criteria:**
- Given an open listing with no leader, when its seller confirms ANNULER, then the copy is free again, the stamp is not refunded, and the listing reads ANNULÉE.
- Given a bid that leads, when the seller tries to cancel, then nothing changes and the Copy deck's refusal shows.
- Given an unsold auction, when the seller activates REMETTRE EN VENTE, then Mettre en vente opens on its second step with the start and buy-now prefilled and says so, and submitting creates a new listing with a new stamp.
- Given a visitor, when the market screen draws, then MES VENTES is greyed; when they request MES VENTES or the cancel POST, then they get `sign_in_required`.
- Given the pages and the redirects, when they are read, then no database id and no other player's maximum appears.

## Implementation Notes

## Plan Change Log

- 2026-11-10, approver (one round): status set to `ready-for-dev`. Body only, except one reading of the frozen block that would otherwise draw wrong code: "the end of an ended listing (`sold_at`, else `ends_at`)" and the 30-day window read `updated_at` for a cancelled or withdrawn row, because a listing cancelled before its end keeps a future `ends_at` and would show a future `Fin` and sort first. Also added the Annonce ANNULER controller tests the acceptance criteria rely on. Lock order (bank, listing, holding), refusals and tokens checked against `PlaceBid`, `CloseAuction` and `ListCard`: no cycle.

## Review Triage Log

## Design Notes

- The lock order of `CancelListing` (bank, listing, holding) is the same as `PlaceBid` and `CloseAuction` take, so a bid and a cancel can only serialize, never deadlock against each other.
- `MarketRowComponent` is deliberately generic (card, chip, labelled facts, an action slot): MES ENCHÈRES builds its rows from it without copying markup.

```erb
<%# a row: the link is the row, the action is its sibling %>
<li class="market-row"> <img alt=""> <a class="market-row__title" href="…">Hades</a> <span class="market-row__chip">EN COURS</span> … <button>ANNULER</button> </li>
```

## Verification

**Commands:**
- `ruby -c` and `bundle exec rubocop` on each touched Ruby file; `npm run format:check`, `npm run lint:css` -- expected: no offence
- `npm run test:js` -- expected: green (run once at the end of the market build)
- `bundle exec packwerk check` and `bin/rails zeitwerk:check` -- expected: pass
- `script/check_planning_references` and `script/check_file_sizes` -- expected: pass
- `bundle exec i18n-tasks missing` and `bundle exec i18n-tasks unused` -- expected: pass
- `bin/rails test` on the files above and `bin/rails test test/system/market_sales_test.rb` -- expected: green (run once at the end of the market build, not by the build agent)
