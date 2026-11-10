---
title: 'A player bids with My maximum'
type: 'feature'
ticket: '39.7'
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
  - '{project-root}/_bmad-output/initiative-gameble/epic-an-auction-runs-and-settles/story-bids-follow-the-auction-rules-plan.md'
  - '{project-root}/_bmad-output/initiative-gameble/epic-an-auction-runs-and-settles/story-the-annonce-shows-its-history-and-its-outcome-plan.md'
  - '{project-root}/_bmad-output/initiative-gameble/epic-an-auction-runs-and-settles/story-a-seller-lists-a-card-from-mettre-en-vente-plan.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** `PlaceBid` works but no player can reach it: the Annonce has no form, no rate limit, no answer panel and no polite status region. Epic requirements R13, R18 and R22.

**Approach:** The Annonce gets a "My maximum" form drawn on the server (a field, its minimum, the fixed and live sentences, one button) and wired by one root Stimulus controller `annonce` with its module `app/frontend/lib/annonce.ts`. A POST by listing token goes through a `Market::BidsController` with `BidPolicy` and a per-player rate limit into `PlaceBid`; the answer or the refusal comes back as one Turbo Stream replacing the form region, with focus following the Copy deck. The page also gains its one polite status region.

## Boundaries & Constraints

**Always:**
- The form region is the element `#annonce-bid` inside the Annonce. Its content, chosen on the server in this order: the outcome or `Clôture en cours…` of the listing story when the listing is closed or due; nothing for the seller; `Connectez-vous pour enchérir` with the sign-in link (`sign_in_button`, origin the Annonce) for a visitor; the form for a signed-in non-seller. A suspended market still draws the form (a later story greys it); a bid sent while closed answers `market_closed` inline.
- The form: one `type="text"`, `inputmode="numeric"`, `autocomplete="off"` field labelled `MON MAXIMUM`, empty on arrival, its minimum written beside it (`Au moins <amount>`; for the leader `Plus que votre maximum actuel, <amount>` and a raising form); the fixed sentence under it; a live sentence region that the script fills; the fixed finality sentence `Une offre ne peut pas être annulée.` and the soft-close sentence with the version's window minutes beside the button; the button `ENCHÉRIR` until the typed text is a valid whole amount, then `ENCHÉRIR · <amount>` (leader: `RELEVER · <amount>`; at or above the buy-now: `ACHETER · <buy-now>`). The button's accessible name is `Enchérir, maximum <amount> PiCoins`. All amounts in the markup come from one query, `Game::Market::BidSheet`, which reads the minimum only through `AuctionMath` (`minimum_bid`, `raise_minimum`) and treats a removed leader as no leader, as `PlaceBid` does.
- A leader sees the raising form built from their own maximum, read only for them by `BidSheet` (`leader_maximum` is selected in that one owner-only branch and nowhere else). No other form, page, data attribute or log line carries any maximum.
- The browser displays but never decides: typed text is parsed as digits only (spaces removed, anything else makes the amount invalid), the live sentence and the button label come from the module, and the server alone accepts or refuses. The commitment shown (`typed`, `typed - own maximum` for a leader raise, `buy-now - own maximum` at the buy-now) is tested against `BidTerms#needed` through a shared fixture.
- `Market::BidsController#create` (route `post "market/listings/:token/bids"`, helper `market_listing_bids_path`) runs `authorize %i[market bid], :create?` (`BidPolicy#create?` is `player?`), maps the token to a listing id with the new query `Game::Market::ListingIdByToken` (unknown token: 404; the id never leaves the server), calls `PlaceBid` with the posted `maximum` text unchanged and answers a Turbo Stream replacing `#annonce-bid`. Visitors get the app's `sign_in_required` answer; a banned or deleted bidder (`player_required`) gets the app's forbidden answer.
- Rate limit: 20 bids per player per minute (the player's id, the remote IP for a visitor), implemented with Rails `rate_limit` and a `with:` that renders the same refusal stream (status 429, message `Trop d'offres d'un coup. Patientez un instant.`, amount kept) instead of `throttle_player`'s redirect, which would lose the typed amount.
- Answers replace the form's foot with a panel in the state's colour and its action (Copy deck, Answer to my bid): `new_leader` and the raise of a leader get `VOUS ÊTES EN TÊTE` (price and own maximum, `RELEVER MON MAXIMUM` focusing the field) and `MAXIMUM RELEVÉ` (own maximum, price unchanged); `beaten` gets `UN AUTRE JOUEUR AVAIT UN MAXIMUM PLUS HAUT`, or the equal-maximum title, with the new price and the new minimum. On the `buy_now` branch (a maximum at or above the buy-now price, which the live sentence announces before validation) the region is replaced by the listing story's outcome partial for the buyer (`VOUS AVEZ ACHETÉ <card>`, `VOIR LA CARTE`, heading focused); the confirmation dialogs that precede it are the next story's. The region is redrawn from a fresh `BidSheet`, so the minimum, the leader state and the available figure are current. Focus: leading or raise accepted, the panel's heading (`tabindex="-1"`); beaten at once, the field, cleared, with the panel as its `aria-describedby`; a refusal, the field with the typed text kept.
- Refusals are inline under the field (`p` with `role="alert"`, `aria-invalid="true"` on the input, `aria-describedby` pointing at it), keep the typed amount, clear on the next edit and use the Copy deck: `below_minimum` (with the fresh minimum; `Le prix vient de changer. Il faut maintenant au moins <amount>.` when the minimum the form was drawn with, posted back as `drawn_minimum`, differs from the fresh one), `more_than_available` (fresh available), `invalid_price`, `own_listing`, `market_closed`, `market_busy`, throttled. `auction_ended` and `listing_withdrawn` replace the region with the outcome partial (or `Clôture en cours…`), the line `Votre montant n'a pas été enregistré.`, and focus on that heading.
- The page holds exactly one polite status region (`role="status"`, `aria-live="polite"`, visually hidden, empty at load) as the child controller `annonce-status`, outside the replaced region, with an operation `say(text)`. Only the live part of the sentence under the field is posted, 500ms after the last keystroke, never twice the same text; the later live-refresh story extends this region and never creates another.
- Enter in the field moves focus to the button and never submits. A double activation submits once: the root marks the form submitting, cancels any second submit and releases on `turbo:submit-end`. Focus and amounts follow the Focus table of the Copy deck; the Balance chip refreshes through the existing `BidPlaced` balance notice after commit (nothing new to publish).
- AD-30 shape: root controller `annonce` on the Annonce's section, state module `app/frontend/lib/annonce.ts` (pure transitions, no DOM) with `lib/annonce_view.ts` (view builders), children `annonce-field`, `annonce-foot`, `annonce-status` reporting by `dispatch` and driven through outlets, no child referencing another, no outlet reaching the chrome; initial state from scalar Stimulus values on the field's markup, strings as an `Object` value of templates; no markup built in script (the panel, errors and dialogs are server-rendered, toggled by `hidden`); no `style` attribute; no new `gameble:*` event.
- Only operations write: this story writes through `PlaceBid` and nothing else. The POST is the only write; the Annonce's GET stays on the reading role.
- Every string in `en.yml` and `fr.yml`; every `errors.game` code the controller can show already exists in both (the five added by the bidding story), plus the keys added here. Files stay under 400 lines (Ruby, TypeScript) and 500 (CSS).

**Never:**
- No unusual-maximum dialog, no `ACHETER MAINTENANT`, no buy-now or unusual-maximum confirmation (the confirmation story), no live refresh, no extension or last-hour posts, no notice, no outbid panel, no suspended-state greying, no cancel, no MES ENCHÈRES row.
- No second computation of the minimum, the price or the increment in script or in a view; no refusal decided in the browser (the client blocks nothing but a second submission); no `maximum` of another player anywhere; no database id in the URL, the markup or a DOM id.
- No React, no markup built in script, no controller writing a model, no GET that writes.

**Decisions (settled by Claude, no checkpoint in this run; the author may revisit):**
- The page's one polite region is created here as its own tiny controller, outside the replaced form region, because a Turbo Stream replace of the region would otherwise drop it and the live-refresh story needs it for viewers who have no form.
- The answer is one `turbo_stream.replace "annonce-bid"` of the whole region (field, panel, foot) rather than a patch of the foot alone: the minimum, the field's cleared value and the leader's raising state all change together, and a replaced region reconnects its children so the root re-reads its state from the markup.
- The panel and the foot (sentences and button) are both in the markup; the panel shows after an answer and the foot returns on the first keystroke (the root toggles `hidden`), so the Copy deck's "replaces the form's foot" holds without script building markup.
- The leader's raise below or equal to their own maximum answers `below_minimum` through `PlaceBid`; the form's minimum for them is `AuctionMath.raise_minimum`, drawn as `Plus que votre maximum actuel, <amount>` where the amount is their current maximum.
- `invalid_price` text uses the existing `errors.game.invalid_price`; an empty field submits and is refused by the server with it (no client rule).
- The posted `maximum` is passed to `PlaceBid` as text; the controller parses nothing.
- The visitor form is the sign-in line only; the seller sees no form (a forged POST gets `own_listing` inline).
- No JavaScript-free fallback: a non-Turbo POST redirects (303) to the Annonce, which shows the current state. The app already needs JavaScript on every screen.
- The system test drives the second bidder from Flow 7 in the browser (the first bidder's 30,000 is placed through `PlaceBid` in the arrangement), then the same player takes the lead and raises as the leader. The ticket's "first player's raise" is taken as the leader's raise, since the first bidder is outbid by then.
- The 500ms debounce and the "unchanged text is not posted" rule live in the root controller's timer plus a `posted` field of the module state, not in the child.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Typing | `30000` in the field | Button `ENCHÉRIR · 30 000`; after 500ms the live sentence `30 000 PiCoins seront bloqués…` posts once | No error expected |
| Invalid text | `3x0` or empty | Button stays `ENCHÉRIR`, no live sentence; submitting is refused by the server with `invalid_price`, text kept | `Failure(:invalid_price)` shown inline |
| First bid | No leader, 30,000, minimum 20,000 | Panel `VOUS ÊTES EN TÊTE`, price 20,000, own maximum 30,000; heading focused; form redrawn as the raising form | No error expected |
| Beaten at once | Leader 30,000 at 20,000, bid 25,000 | Panel with new price 26,300 and new minimum 27,700; field cleared and focused, panel as its description | No error expected |
| Equal maximum | Bid equal to the leader's maximum | Equal-maximum title, same sentence | No error expected |
| Buy-now by maximum | Typed maximum at or above the buy-now price | Live sentence says it buys at once, button `ACHETER · <buy-now>`; on submit the region shows `VOUS AVEZ ACHETÉ <card>` and `VOIR LA CARTE`, heading focused, no confirmation yet | No error expected |
| Leader raises | Leader types 35,000 | `RELEVER · 35 000`; panel `MAXIMUM RELEVÉ`, price unchanged | No error expected |
| Below minimum | Price moved since the form was drawn | `Le prix vient de changer. Il faut maintenant au moins <amount>.`, field focused, text kept, `aria-invalid` | `Failure(:below_minimum)` |
| Below minimum, price unchanged | Typed under the drawn minimum | `Il faut au moins <amount>.` | `Failure(:below_minimum)` |
| Above available | Typed above the bidder's available | `Vous pouvez engager au plus <amount>.` with the fresh figure | `Failure(:more_than_available)` |
| Busy | Deadlock | `market_busy` text, field and text kept | `Failure(:market_busy)` |
| Too many bids | 21st POST within a minute | 429 stream with the throttle sentence, text kept | Rate limit |
| Auction ended while typing | Bid at or after the end, or listing withdrawn | Region becomes `Clôture en cours…` or the outcome, plus `Votre montant n'a pas été enregistré.`, heading focused | `Failure(:auction_ended)` or `:listing_withdrawn` |
| Seller | Opens own Annonce; or forges a POST | No form; the forged POST is refused inline | `Failure(:own_listing)` |
| Visitor | Opens the Annonce | `Connectez-vous pour enchérir` with the sign-in link; a POST answers `sign_in_required` | Policy refusal |
| Banned bidder | POST by a removed player | Forbidden answer | `Failure(:player_required)` |
| Double activation | Two quick clicks | One request, one bid row | No error expected |
| Unknown token | Wrong token | 404 | Not found |

</frozen-after-approval>

## Code Map

- `app/views/market/listings/show.html.erb`, `app/views/market/listings/_outcome.html.erb` (listing story) -- the Annonce and the region where the form sits; the section becomes the `annonce` root and holds the status region.
- `app/controllers/market/listings_controller.rb` -- `show` loads the `BidSheet` for a signed-in non-seller viewer.
- `app/controllers/market/sales_controller.rb`, `app/views/market/sales/_refusal.html.erb`, `_fields.html.erb` -- the refusal pattern (slots, `role="alert"`, kept values) and field markup to mirror; `throttle_player` in `app/controllers/application_controller.rb` and `refuse` there.
- `app/domains/game/app/operations/game/market/place_bid.rb`, `bid_terms.rb`, `bid_answer.rb` -- the operation and the answer object the panels read; unchanged.
- `app/domains/game/app/models/game/market/auction_math.rb`, `queries/balance.rb`, `settings.rb` -- the only formulas, the available figure and the soft-close window.
- `app/models/player_stream.rb` -- already gives a balance notice for `BidPlaced`.
- `app/frontend/controllers/listing_form_controller.ts`, `listing_fields_controller.ts`, `app/frontend/lib/listing_form.ts`, `listing_form_view.ts`, `picoins.ts`, `dom_writes.ts`, `screen.ts` -- the root, child, outlet, `Intent` and `writeText` conventions to follow; `entrust_controller.test.ts` -- the controller test pattern.
- `app/frontend/lib/events.ts` -- unchanged (no new `gameble:*` event).
- `app/helpers/picoins_helper.rb`, `market_helper.rb`, `local_time_helper.rb` -- amounts and times in views.
- `test/support/market_bidding.rb`, `market_auctions.rb`, `market_listings.rb`, `test/controllers/market/sales_controller_test.rb`, `test/system/market_listing_test.rb`, `test/fixtures/files/listing_amounts.json` -- arrangement, controller and system test patterns, and the shared-fixture pattern.
- `config/routes.rb`, `config/locales/en.yml`, `fr.yml`, `app/frontend/entrypoints/application.css`.

## Tasks & Acceptance

**Execution:**
- [ ] `app/domains/game/app/queries/game/market/listing_id_by_token.rb` -- `ListingIdByToken.call(token)` returns the id or nil -- the only way the controller reaches `PlaceBid` without an id in the URL
- [ ] `app/domains/game/app/queries/game/market/bid_sheet.rb` -- `BidSheet.call(token:, player:)` returns nil unless the listing is open, not due and the player is neither its seller nor removed; else `Data` with `minimum`, `leading`, `own_maximum` (leader only), `available`, `current_price`, `buy_now_price`, `soft_close_minutes`; removed leader counts as none -- one reader for form, refusals and redraws
- [ ] `config/routes.rb` -- `post "market/listings/:token/bids" => "market/bids#create", as: :market_listing_bids` -- the write endpoint
- [ ] `app/policies/market/bid_policy.rb` -- `create?` is `player?` -- Pundit for the action
- [ ] `app/controllers/market/bids_controller.rb` -- `create` as stated (a refusal answers 422, the rate limit 429, both as the same stream; a non-Turbo POST redirects 303), `rate_limit` with the stream refusal, refusal mapping per failure code, success answer by branch, concerns kept small (move the refusal text building to `app/controllers/concerns/market/bid_refusals.rb` if the file nears 150 lines) -- the endpoint
- [ ] `app/views/market/bids/_region.html.erb` -- the region's states (outcome/closing, seller nothing, visitor line, form), taking locals `listing:` (the `ListingByToken` detail, which carries the card), `sheet:`, `outcome:` (`ListingOutcome`, viewer-aware), `refusal:` and `focus:`; the Annonce's show renders it in place of the listing story's direct `_outcome` render, and the controller builds the same locals from the same three queries for every answer -- one place that decides what sits in `#annonce-bid`; when `sheet` is nil and the failure is neither `auction_ended` nor `listing_withdrawn` (the seller's forged POST), the region holds only the refusal in a `role="alert"` paragraph; the server writes the focus target (`heading`, `field` or none) as a Stimulus value on the region so the root focuses it when the replaced region connects, instead of guessing the stream's render timing
- [ ] `app/views/market/bids/_form.html.erb` and `_foot.html.erb` -- field, minimum, sentences, button, error slot, answer panel (hidden by default), status hooks, hidden `drawn_minimum` -- the form
- [ ] `app/views/market/bids/_answer.html.erb` -- panel by branch with its heading, body and action -- the answer
- [ ] `app/views/market/bids/create.turbo_stream.erb` -- `turbo_stream.replace "annonce-bid"` of the region -- the one response
- [ ] `app/views/market/listings/show.html.erb` -- add `data-controller="annonce"` and its `data-action` mappings on the section, the status region child, render the region -- wires the screen
- [ ] `app/helpers/market_bids_helper.rb` -- `bid_refusal_text(code, sheet, posted)`, `bid_answer_text` and the button/name templates for `stringsValue`; keys are written statically (a `case` on the branch), never interpolated, so `i18n-tasks unused` stays green -- keeps views thin
- [ ] `app/frontend/lib/annonce.ts` -- state and pure transitions: `start`, `type`, `parse`, `commitment`, `reachesBuyNow`, `buttonKind`, `submit`, `submitted`, `posted` -- the screen's module
- [ ] `app/frontend/lib/annonce_view.ts` -- `footViewOf(state, forms)`: button label, accessible name, live sentence, panel visibility -- view builders using `picoins` and `t`
- [ ] `app/frontend/controllers/annonce_controller.ts` -- root: applies transitions, owns the 500ms timer, the single-submit guard, focus moves, outlets to the three children -- thin controller
- [ ] `app/frontend/controllers/annonce_field_controller.ts` -- input events (`typed`), Enter (`entered`), error clearing, `focus()`, `clear()`, `terms()` -- field child
- [ ] `app/frontend/controllers/annonce_foot_controller.ts` -- renders button, live sentence, panel toggle; `focusSubmit()`, `focusHeading()`, `raise` intent -- foot child
- [ ] `app/frontend/controllers/annonce_status_controller.ts` -- `say(text)` into the polite region -- the page's one status region
- [ ] `app/frontend/styles/market-bid.css` and `application.css` import -- field, sentences, button row, panels by state colour (lime for leading and raised, orange for beaten, alert for refusals), phone layout, 44px targets, no inline style -- the form's look
- [ ] `config/locales/en.yml` and `fr.yml` -- under `market.bids`: `form.label`, `form.minimum`, `form.minimum_raise`, `form.fixed`, `form.live_hold`, `form.live_raise`, `form.live_buy_now`, `form.final`, `form.available`, `form.button` (idle, bid, raise, buy, name), `form.sign_in`, `answers.leading|raised|beaten|equal` (title, body, action), `refusals.price_moved|throttled`, `not_recorded`, with the Copy deck's French and an English equivalent -- the form's text
- [ ] `test/fixtures/files/bid_commitments.json` -- rows of `{maximum, own_maximum, buy_now, needed}` -- the shared fixture for the browser's displayed commitment
- [ ] `test/domains/game/market/bid_sheet_test.rb` and `listing_id_by_token_test.rb` -- minimum with and without leader, a removed leader, the leader's own maximum only for the leader, nil for seller, ended and due listings, soft-close minutes from the listing's version -- the readers
- [ ] `test/domains/game/market/bid_commitment_fixture_test.rb` -- each fixture row against `BidTerms#needed` -- display equals authority
- [ ] `test/policies/market/bid_policy_test.rb` -- visitor refused, player allowed
- [ ] `test/controllers/market/bids_controller_test.rb` -- a visitor refused with `sign_in_required`, the seller refused inline, banned bidder forbidden, the rate limit (21st request answers 429 with the amount kept, inside `with_counting_rate_limit(Market::BidsController)` from `test/support/counting_rate_limit.rb`, as the sales test does), each refusal's text in English and French including the drawn-minimum comparison, `auction_ended` replacing the region with the outcome and the not-recorded line, success per branch (panel text, fresh minimum, status; the buy-now branch answering with the buyer's outcome), the stream targeting `annonce-bid`, no database id in any response, unknown token 404 -- controller rules
- [ ] `app/frontend/lib/annonce.test.ts` and `annonce_view.test.ts` -- parse rules, button kinds, live sentences, commitment rows from the shared fixture, double submit, unchanged live text not reposted -- the module
- [ ] `app/frontend/controllers/annonce_controller.test.ts` -- Enter moves focus to the button without submitting, a double activation submits once, the live sentence posts once after the debounce, the first keystroke after an answer shows the foot again -- the controller
- [ ] `test/system/market_bidding_test.rb` -- the second bidder of Flow 7: the first bidder leads at 20,000 with 30,000 (arranged through `PlaceBid`); the browser player types 25,000, reads the beaten panel with price 26,300 and minimum 27,700, the field focused and empty; types 40,000 and leads at 31,500; raises to 45,000 and reads `MAXIMUM RELEVÉ` with the price unchanged; the Balance chip shows the committed amount -- the ticket's system test

**Acceptance Criteria:**
- Given a signed-in non-seller on an open Annonce, when they type a valid amount, then the button names it and the live sentence posts once to the one polite region after 500ms.
- Given a typed maximum, when they press Enter, then focus moves to the button and nothing is submitted; given a double click on the button, then exactly one bid is placed.
- Given each branch of `PlaceBid`, when the answer returns, then the matching Copy deck panel replaces the foot, focus lands where the Focus table says, and the Balance chip refreshes after commit.
- Given a refusal, when it returns, then it shows under the field with `aria-invalid` and `aria-describedby`, the amount is kept and the next edit clears it.
- Given a price that moved, when the stale form is submitted below the new minimum, then the refusal says the price changed and names the fresh minimum.
- Given a visitor, the seller or a closed auction, when the Annonce renders, then no form is present, a visitor sees the sign-in line, and a forged POST is refused.
- Given any request or page, when it is read, then no maximum of another player and no database id appears.

## Implementation Notes

## Plan Change Log

- 2026-11-10, approver (one round): body only, frozen block untouched. The region takes `listing:`/`sheet:`/`outcome:` locals (the listing story's `_outcome` takes locals, not ivars) so Turbo Stream answers can render it and the next story's dialogs can name the card; a nil sheet (seller) still shows a forged POST's refusal; focus after a replace is a server-written value, not render-timing luck; i18n keys static; the rate-limit test uses the existing counting helper.

## Review Triage Log

## Design Notes

- One reader (`BidSheet`) feeds the first draw, every redraw after an answer and every refusal's fresh figures, so the form, the refusal text and the redraw can never disagree about the minimum.
- The module owns what the browser may decide (display, debounce, single submission); the server owns every rule. The shared fixture is the only bridge, and it checks a sum, not a rule.

```ts
// lib/annonce.ts (shape)
type Terms = { minimum: number; available: number; buyNow: number | null; ownMaximum: number | null }
type AnnonceState = { terms: Terms; text: string; submitting: boolean; posted: string; answered: boolean }
const commitment = (s: AnnonceState, amount: number) => (reachesBuyNow(s, amount) ? s.terms.buyNow! : amount) - (s.terms.ownMaximum ?? 0)
```

## Verification

**Commands:**
- `ruby -c` and `bundle exec rubocop` on each touched Ruby file; `npm run format:check`, `npm run lint:css` -- expected: no offence
- `npm run test:js` -- expected: green (run once at the end of the market build)
- `bundle exec packwerk check` and `bin/rails zeitwerk:check` -- expected: pass
- `script/check_planning_references` and `script/check_file_sizes` -- expected: pass
- `bin/rails test test/domains/game/market/bid_sheet_test.rb test/domains/game/market/listing_id_by_token_test.rb test/domains/game/market/bid_commitment_fixture_test.rb test/policies/market/bid_policy_test.rb test/controllers/market/bids_controller_test.rb` and `bin/rails test test/system/market_bidding_test.rb` -- expected: green (run once at the end of the market build, not by the build agent)
- `bundle exec i18n-tasks missing` -- expected: pass
