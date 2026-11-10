---
title: 'A suspended market stays readable'
type: 'feature'
ticket: '39.11'
created: '2026-11-10'
status: 'ready-for-dev'
baseline_revision: 'c38e74f58ede0041b64a02d0b1d838c2bbd16332'
route: ''
route_source: ''
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/initiative-gameble/epic-an-auction-runs-and-settles/epic-an-auction-runs-and-settles.md'
  - '{project-root}/_bmad-output/initiative-gameble/epic-an-auction-runs-and-settles/story-a-seller-follows-mes-ventes-cancels-and-relists-plan.md'
  - '{project-root}/_bmad-output/initiative-gameble/epic-an-auction-runs-and-settles/story-a-bidder-follows-mes-encheres-plan.md'
  - '{project-root}/_bmad-output/initiative-gameble/epic-an-auction-runs-and-settles/story-a-player-bids-with-my-maximum-plan.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** After a first opening, a closed settings version still lets the market screen, the Annonce, MES VENTES and MES ENCHÈRES draw live-looking actions that the operations then refuse, and only Confier and Mettre en vente explain why. Epic requirement R13.

**Approach:** One state question (`MarketState#suspended?`) feeds every market screen: the suspended banner above the content, listings and auctions readable, CONFIER, METTRE EN VENTE, ENCHÉRIR, RELEVER, REMETTRE EN VENTE and ACHETER drawn disabled with the banner as their reason, ANNULER untouched, and a form sent as the market closes answering with the banner and the Copy deck's line.

## Boundaries & Constraints

**Always:**
- `Game::Market::MarketState#suspended?` is `first_opened? && !open?`; the three controllers that each repeat that expression (`MarketsController`, `Market::EntrustmentsController`, `Market::SalesController`) use it, and so do the new screens and the Annonce. Before a first opening nothing of this story shows: the teaser stays, and `suspended?` is false.
- The banner is the existing `market/_suspended_banner` partial (`#market-suspended-banner`, `role="status"`, its Brotherhood line, a link back to the market), drawn above the content of the market screen, the Annonce, MES VENTES and MES ENCHÈRES. Every disabled action carries `aria-describedby="market-suspended-banner"` (the `describedby:` of `ButtonComponent`), so the banner is its reason.
- Market screen: while suspended, CONFIER DES CARTES and METTRE EN VENTE are disabled `ButtonComponent`s (they are links when open); tiles, sorts, the chips and paging stay live and readable; ANNONCES, MES ENCHÈRES and MES VENTES stay links.
- Annonce: the banner sits in a stable slot `#annonce-suspension` above the layout. For a viewer who has a bid sheet the region draws a disabled form with no Stimulus controllers: the `MON MAXIMUM` field disabled, its minimum line, a disabled `ENCHÉRIR` (`RELEVER` for the leader, whose own maximum is still drawn from the sheet), and a disabled `ACHETER MAINTENANT` when the listing has a buy-now, all described by the banner; the two confirmation dialogs are not drawn. The seller keeps `ANNULER` and its dialog; a visitor keeps the sign-in line; an ended listing keeps its outcome. History, price and time left are unchanged, and a due auction still shows `Clôture en cours…` then its outcome.
- MES VENTES: `ANNULER` stays enabled and works (`CancelListing` never reads the open flag); `REMETTRE EN VENTE` is drawn disabled. MES ENCHÈRES: `RELEVER` is drawn disabled on every row. Both screens draw the banner.
- Mettre en vente and Confier keep their present suspended behaviour (banner with its link back to the market, submit disabled, a POST refused with `market_closed`); a relist link arriving with a prefill while suspended draws the same banner and a disabled submit, and the page's way back is the banner's link to the market.
- A bid POST answered while suspended: `PlaceBid` refuses with `market_closed`; the Turbo Stream answer replaces `#annonce-bid` with the disabled form carrying the refusal `Le marché est suspendu pour le moment.` (`role="alert"`, `tabindex="-1"`, focus target `refusal`, since the field is disabled and cannot take focus), and updates `#annonce-suspension` with the banner, so a page drawn while the market was open learns it is suspended. The typed amount is dropped (the field is disabled). The existing `errors.game.market_closed` texts in both languages are the line and stay unchanged.
- `CloseDueAuctionsJob` and `CloseAuction` keep running while the market is closed: due auctions still settle, and a cancel is still accepted. No operation is changed by this story.
- Disabled styling uses the design's disabled tokens and the banner's alert frame (`market-suspended.css`, `market-bid.css`, `market-rows.css`), no `style` attribute; the banner is announced once, not once per disabled action. Every string already exists or is added in `en.yml` and `fr.yml`. Files stay under 400 lines (Ruby, TypeScript) and 500 (CSS).

**Never:**
- No new operation, no change to a refusal rule, no hiding of listings or history while suspended, no banner before a first opening, no script change in the `annonce` controllers (the disabled form has none), no live refresh when the market closes under an open page (a later load or a refused submit shows it), no GET that writes.

**Decisions (settled by Claude, no checkpoint in this run; the author may revisit):**
- The suspended Annonce form is a separate server-rendered partial with no controllers, not the live form with a flag: the live form's script re-enables its button from typed text, and the disabled state must not depend on script.
- The field is disabled as well as the buttons: a typed maximum could not be sent, and a disabled field makes the state plain to a screen reader; the typed text is lost on the refusal, which is accepted since nothing could be submitted anyway.
- Focus after a refused submit goes to the refusal line rather than the banner: the line is the answer to the player's action, and the banner is reached by its `role="status"` announcement and by the line's `aria-describedby`.
- The banner on the Annonce lives in a slot outside `#annonce-bid`, so the one Turbo Stream answer can update both without replacing the page.
- `MarketState#suspended?` is added to the existing value object rather than a new helper: every caller already holds a `MarketState`, and the rule is the domain's.
- Mettre en vente is not redirected while suspended: the existing screen already leads back through the banner's link, and a redirect would lose the banner's explanation. This is the reading of "leads back to the market"; the request test pins it for the card-scoped address and a prefilled relist as well.
- RELEVER and REMETTRE EN VENTE are drawn disabled rather than removed, as the ticket says, so the player sees the action and the reason.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Market screen, suspended | First opening recorded, current version closed | Banner above the chips; tiles readable; CONFIER DES CARTES and METTRE EN VENTE disabled and described by the banner | No error expected |
| Never opened | No first opening | The teaser; no banner anywhere | No error expected |
| Annonce, bidder | Open auction, suspended | Banner, disabled field, `ENCHÉRIR` and `ACHETER MAINTENANT` disabled, price, history and time left readable | No error expected |
| Annonce, leader | The viewer leads | `RELEVER` disabled, own maximum still read | No error expected |
| Annonce, seller | Own open listing with no bid | `ANNULER` enabled, no bid form | No error expected |
| Annonce, visitor | No session | Banner and the sign-in line | No error expected |
| Submit as the market closes | The page was drawn open, then the market closed, the bidder submits | Stream answer: banner in its slot, disabled form with `Le marché est suspendu pour le moment.`, focus on that line, no bid, no ledger entry | `Failure(:market_closed)` |
| Cancel while suspended | Seller confirms ANNULER on a leaderless listing | Cancelled as when open | No error expected |
| MES VENTES, suspended | An unsold row and an open row | Banner; `REMETTRE EN VENTE` disabled; `ANNULER` enabled on the open row | No error expected |
| MES ENCHÈRES, suspended | Outbid row | Banner; `RELEVER` disabled | No error expected |
| A due auction | Suspended, `ends_at` passed with a leader | The job settles it; the Annonce then shows the outcome | No error expected |
| Mettre en vente, suspended | Card-scoped address or relist prefill | Banner with its link to the market, submit disabled | A POST: `market_closed` |

</frozen-after-approval>

## Code Map

- `app/domains/game/app/models/game/market/market_state.rb` -- the value object that gets `suspended?`.
- `app/controllers/markets_controller.rb`, `app/controllers/market/entrustments_controller.rb`, `app/controllers/market/sales_controller.rb` -- the three repeated `first_opened? && !open?` expressions.
- `app/controllers/market/listings_controller.rb`, `app/controllers/market/my_sales_controller.rb`, `my_bids_controller.rb` (previous stories), `app/controllers/concerns/market/bid_refusals.rb`, `app/views/market/bids/create.turbo_stream.erb` -- where the state is read and the one stream answer.
- `app/views/market/_suspended_banner.html.erb`, `app/frontend/styles/market-suspended.css` -- the banner and its style.
- `app/views/markets/screen.html.erb`, `_chips.html.erb`, `app/views/market/listings/show.html.erb`, `app/views/market/bids/_region.html.erb`, `_form.html.erb`, `_foot.html.erb`, `_buy_now.html.erb` -- the live form and region the disabled variant mirrors.
- `app/views/market/my_sales/*`, `app/views/market/my_bids/*`, `app/helpers/market_rows_helper.rb`, `app/components/button_component.rb` -- the rows' actions and the `disabled` plus `describedby` options.
- `app/helpers/market_bids_helper.rb` -- `bid_refusal_text` (already answers `market_closed`).
- `app/domains/game/app/operations/game/market/close_auction.rb`, `cancel_listing.rb` -- unchanged behaviour to pin by tests.
- `test/controllers/market/sales_controller_test.rb`, `entrustments_controller_test.rb`, `markets_controller_test.rb`, `bids_controller_test.rb`, `test/system/market_test.rb`, `market_suspension_test.rb`, `test/support/market.rb` (`close_market!`).

## Tasks & Acceptance

**Execution:**
- [ ] `app/domains/game/app/models/game/market/market_state.rb` -- add `suspended?` -- the one rule
- [ ] `app/controllers/markets_controller.rb`, `market/entrustments_controller.rb`, `market/sales_controller.rb` -- read `suspended?` instead of repeating the expression -- no duplicate rule
- [ ] `app/views/markets/screen.html.erb` -- banner above the chips when `@suspended`; CONFIER and METTRE EN VENTE as disabled buttons described by the banner -- the market screen
- [ ] `app/controllers/market/listings_controller.rb`, `app/controllers/concerns/market/bid_refusals.rb` -- compute `suspended` from `MarketState` and pass it to the region and the slot; with a refusal while suspended the focus target is `refusal` -- one source for the page and the answer
- [ ] `app/views/market/listings/show.html.erb` -- the `#annonce-suspension` slot (banner or empty) above the layout -- stable target for the stream
- [ ] `app/views/market/bids/_region.html.erb` -- `suspended:` local; for a viewer with a sheet and a suspended market render `_suspended_form` instead of the live form and dialogs; seller, visitor and outcome branches unchanged -- the Annonce's state
- [ ] `app/views/market/bids/_suspended_form.html.erb` -- disabled field, minimum line, disabled `ENCHÉRIR`/`RELEVER`, disabled `ACHETER MAINTENANT` when a buy-now exists, all described by the banner, the refusal line when given -- the disabled form
- [ ] `app/views/market/bids/create.turbo_stream.erb` -- also `turbo_stream.update "annonce-suspension"` with the banner when suspended, empty otherwise -- the closing-under-the-form case
- [ ] `app/controllers/market/my_sales_controller.rb`, `my_bids_controller.rb` -- set `@suspended` from `MarketState#suspended?` for the banner and the disabled actions -- the state the two lists read
- [ ] `app/views/market/my_sales/_group.html.erb`, `app/views/market/my_bids/_group.html.erb`, their `show.html.erb`, `app/helpers/market_rows_helper.rb` -- banner when suspended; REMETTRE EN VENTE and RELEVER disabled and described, ANNULER untouched -- the two lists
- [ ] `app/frontend/styles/market-suspended.css`, `market-bid.css`, `market-rows.css` -- disabled field and button tokens, the banner's spacing above each screen -- the look
- [ ] `config/locales/en.yml`, `fr.yml` -- only if a disabled control needs a new line; the banner and `errors.game.market_closed` exist -- text
- [ ] `test/domains/game/market/market_state_test.rb` -- `suspended?` for never opened, open, closed after an opening -- the rule
- [ ] `test/controllers/markets_controller_test.rb` -- suspended: banner present, CONFIER and METTRE EN VENTE disabled with `aria-describedby`, tiles and chips still present and linked; never opened: teaser, no banner; visitor too -- the screen
- [ ] `test/controllers/market/listings_controller_test.rb` -- suspended: banner in its slot, disabled field and buttons described by it, no dialog and no `data-controller~=annonce-field`, the leader's `RELEVER`, the seller's enabled `ANNULER`, the visitor's sign-in line; open: no banner -- the Annonce
- [ ] `test/controllers/market/bids_controller_test.rb` -- a POST while suspended places no bid and no ledger entry, answers 422 with the stream updating `annonce-suspension` and `annonce-bid`, the refusal line in English and French, focus target `refusal` -- the closing-under-the-form case
- [ ] `test/controllers/market/my_sales_controller_test.rb`, `my_bids_controller_test.rb` -- suspended: banner, disabled REMETTRE and RELEVER, enabled ANNULER -- the lists
- [ ] `test/controllers/market/cancellations_controller_test.rb` -- a cancel while suspended succeeds -- R3
- [ ] `test/controllers/market/sales_controller_test.rb` -- the card-scoped address and a prefilled relist while suspended draw the banner with its link back to the market and a disabled submit -- "leads back to the market"
- [ ] `test/domains/game/market/close_auction_test.rb` -- a due auction settles while the current version is closed -- settlement continues
- [ ] `test/system/market_test.rb` -- its own test: an administrator closes the market, a player reads the banner on the market screen and on a listing's Annonce with ENCHÉRIR disabled, cancels their own listing and gets the card back, and a due auction still settles -- the ticket's system test

**Acceptance Criteria:**
- Given a market closed after its first opening, when any player or visitor opens the market screen, an Annonce, MES VENTES or MES ENCHÈRES, then the banner is above the content, every listing and its history are readable, and the named actions are disabled with the banner as their reason.
- Given the same state, when a seller cancels a leaderless listing, then it is cancelled and the copy is free.
- Given a bid form drawn while the market was open, when it is submitted after the market closed, then no bid is placed and the answer shows the banner and `Le marché est suspendu pour le moment.` with focus on that line.
- Given a market never opened, when the market address is requested, then the teaser shows and no banner appears anywhere.
- Given a due auction while the market is closed, then it settles on the next job run.

## Implementation Notes

## Plan Change Log

- 2026-11-10, approver (one round): status set to `ready-for-dev`, frozen block untouched. Body only: the two list controllers now carry the suspended state in the task list (the Code Map named them, the tasks did not). The stream answer keeps `PlaceBid`'s `market_closed` refusal as the only rule; `BidSheet` does not read the open flag, so the disabled form is drawn for the same viewers as the live one.

## Review Triage Log

## Design Notes

- One value-object method and one partial carry the whole state, so the next screen that draws a market action has one question to ask and one banner to show.

## Verification

**Commands:**
- `ruby -c` and `bundle exec rubocop` on each touched Ruby file; `npm run format:check`, `npm run lint:css` -- expected: no offence
- `bundle exec packwerk check` and `bin/rails zeitwerk:check` -- expected: pass
- `script/check_planning_references` and `script/check_file_sizes` -- expected: pass
- `bundle exec i18n-tasks missing` and `bundle exec i18n-tasks unused` -- expected: pass
- `bin/rails test` on the files above and `bin/rails test test/system/market_test.rb` -- expected: green (run once at the end of the market build, not by the build agent)
