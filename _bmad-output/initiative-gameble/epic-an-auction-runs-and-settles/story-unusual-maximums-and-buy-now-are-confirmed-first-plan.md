---
title: 'Unusual maximums and buy-now are confirmed first'
type: 'feature'
ticket: '39.8'
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
  - '{project-root}/_bmad-output/initiative-gameble/epic-an-auction-runs-and-settles/story-a-player-bids-with-my-maximum-plan.md'
  - '{project-root}/_bmad-output/initiative-gameble/epic-an-auction-runs-and-settles/story-the-annonce-shows-its-history-and-its-outcome-plan.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Bidding is one gesture, so a typing slip (an extra zero) holds a large sum with no way back, and a buy-now is irreversible yet takes effect from a plain field. Epic requirements R7 and R19.

**Approach:** On the existing form, a client-side gate decides before submitting: a maximum at or above the version's unusual multiple of the price, and below any buy-now, opens the `MONTANT INHABITUEL` dialog; a maximum reaching the buy-now, or the new `ACHETER MAINTENANT` button, opens the `ACHAT IMMÉDIAT` dialog, which takes precedence. Both are server-rendered `<dialog>`s driven by the `annonce` root; the server rules do not change.

## Boundaries & Constraints

**Always:**
- The gate is display and consent only, in `app/frontend/lib/annonce_confirm.ts` (pure, no DOM): `gate(state, submitter)` returns `none`, `unusual` or `buy_now`. Precedence: the `ACHETER MAINTENANT` submitter or a maximum at or above the buy-now price gives `buy_now`; otherwise a maximum with `maximum >= multiple * price` (the integer multiple from the current settings version) and below any buy-now price gives `unusual`; otherwise `none` and the bid is placed in one gesture. The truncated multiple shown is `floor(maximum / price)`. The server never trusts the gate: `PlaceBid` and its refusals are unchanged and a confirmation that the server then refuses shows the refusal inline as any other.
- `Game::Market::BidSheet` (the previous story's reader) gains `unusual_multiple` (from `CurrentSettings`), `buy_now_hold` (the buy-now price less the leader's own held maximum when the viewer leads, else the buy-now price) and `can_buy_now` (`available >= buy_now_hold`). It reads `AuctionMath` for nothing new and adds no formula.
- Both dialogs are server-rendered inside `#annonce-bid` (so every redraw refreshes their numbers), opened with the existing `openDialog(dialog, opener)` and closed by the existing `dialog` controller (Esc, scrim, `ANNULER`, `✕`). Each takes focus on its title (`h2`, `tabindex="-1"`, `autofocus`) so the amount is read before any button. The dialog's amounts that depend on the typed text (the maximum and its multiple) are written by the controller into existing text targets with `writeText`; no markup is built in script.
  - `MONTANT INHABITUEL`: the amount, the truncated multiple, "ce montant sera bloqué sur votre solde et l'offre ne peut pas être annulée", `ANNULER`, `✕`, `CONFIRMER <amount>`. Cancelling, `✕` or Esc return focus to the field, value unchanged.
  - `ACHAT IMMÉDIAT`: names the card (title and rarity) and the price paid, the amount that will be held (buy-now less the player's own held maximum, a line shown only when they lead and the two differ), that the card joins their collection and that the purchase cannot be cancelled, `ANNULER`, `ACHETER · <held>`. Cancelling returns focus to the control that opened it (`ACHETER MAINTENANT`, or `ENCHÉRIR`/`RELEVER` when the typed maximum reached the buy-now).
- `ACHETER MAINTENANT` is a `ButtonComponent` (secondary) shown on an open listing with a buy-now for a signed-in non-seller; it is `disabled` when `can_buy_now` is false, with `Disponible : <available> PiCoins` written beside it. It submits the form with `name="buy_now" value="1"` and leaves the typed text alone; the controller then sets the maximum to the listing's buy-now price read from `BidSheet` (a listing with no buy-now answers `invalid_price`). A maximum typed at the buy-now price takes the same path through the dialog and posts the typed text unchanged.
- Confirming closes the dialog, marks the state as consented for exactly that submitter and text, and calls `form.requestSubmit(submitter)`; the guarded submit of the previous story then lets it through once. A text edit, a different submitter or a redraw clears the consent.
- On the buy-now branch the answer is the buyer's outcome partial of the Annonce story (`VOUS AVEZ ACHETÉ <card>`, `Vous payez <amount>. La carte rejoint votre collection.`, `VOIR LA CARTE`), its heading focused; the previous story's controller already routes that branch there, this story adds no second panel.
- AD-30 shape kept: the `annonce` root holds the confirmation state in its module; a new child `annonce-dialog` (one per dialog) reports `confirmed` by `dispatch` and is opened by the root through an outlet; it never references another child.
- Every string in `en.yml` and `fr.yml`. Files stay under 400 lines; the module and fixture are tested.

**Never:**
- No change to `PlaceBid`, `AuctionMath`, `BidTerms` or any operation, event, migration or ledger rule; no server-side "confirmed" flag; no confirmation for a leader's raise below the thresholds; no dialog on a refusal; no live recomputation of the multiple when the price changes (the live-refresh stories redraw the region, which refreshes the dialogs' numbers).
- No dialog markup built in script, no `style` attribute, no new `gameble:*` event, no React.
- No second definition of the unusual threshold: the multiple is a settings value read once by `BidSheet`; the script only compares.

**Decisions (settled by Claude, no checkpoint in this run; the author may revisit):**
- The unusual multiple is read from the current settings version, as the Copy deck says "the current version's", not the listing's own version (it concerns the player's confirmation, not the auction's arithmetic).
- Threshold rule: `maximum >= multiple * price` is unusual (`at least 3 times`, as the UX says), `multiple * price` computed with safe integers and skipped (no dialog, the server decides) when it exceeds `Number.MAX_SAFE_INTEGER`.
- The buy-now dialog's sentence names the price paid, and the held amount is the button's amount and an extra line for a leader, because the ticket asks to name "the amount held" while the Copy deck's sentence names the price. For a bidder with no maximum on the listing the two are equal and the extra line is absent.
- The cancel of the unusual dialog returns to the field; the cancel of the buy-now dialog returns to its opener, per the Focus table.
- The shared fixture is `test/fixtures/files/unusual_maximums.json` (rows `{price, maximum, multiple, buy_now, gate}`), read by Vitest against `gate` and by a Ruby test that only checks the multiple the markup carries equals the settings value; the browser computes the comparison, no Ruby rule exists to compare to.
- `ACHETER MAINTENANT` uses a plain submit button with `name`/`value` rather than a second form, so one form, one guard and one rate limit cover every bid.
- A confirmed submit that the server answers with `more_than_available` (a maximum reaching the buy-now with too little available) shows the refusal inline and the dialog is already closed; only the button path is pre-disabled.
- The `ACHETER MAINTENANT` row and both dialogs are absent for the seller, the visitor, a closed or due auction, as the form is.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Ordinary bid | Maximum under 3 times the price | `ENCHÉRIR` places the bid in one gesture, no dialog | No error expected |
| Unusual maximum | Price 20,000, maximum 60,000, no buy-now or buy-now above | `MONTANT INHABITUEL` opens, title focused, reads 60,000 and 3 times | No error expected |
| Unusual, cancelled | Esc, `✕`, scrim or `ANNULER` | Dialog closes, focus on the field, text unchanged, no request | No error expected |
| Unusual, confirmed | `CONFIRMER 60 000` | One request, normal answer panel | Server refusals inline as usual |
| Truncated multiple | Maximum 79,999 on a price of 20,000 | Reads 3 times | No error expected |
| Buy-now by maximum | Maximum at or above the buy-now | `ACHAT IMMÉDIAT` opens, not the unusual dialog even at 3 times or more | No error expected |
| Buy-now button | `ACHETER MAINTENANT` | `ACHAT IMMÉDIAT` opens with the card, price, held amount; cancel returns to the button | No error expected |
| Buy-now confirmed | `ACHETER · <held>` | One request with the buy-now price as maximum; the region shows `VOUS AVEZ ACHETÉ <card>` and `VOIR LA CARTE`, heading focused; the card is in the collection | `more_than_available` inline if funds fell short |
| Leader buys | Leader holds 30,000, buy-now 50,000 | Dialog names price 50,000 and holds 20,000 more; button `ACHETER · 20 000` | No error expected |
| Cannot pay | Available under the held amount | `ACHETER MAINTENANT` disabled, `Disponible : <amount> PiCoins` beside it | No dialog |
| No buy-now | Listing without one | No `ACHETER MAINTENANT`, no buy-now dialog | No error expected |
| Forged `buy_now` | POST with `buy_now=1` on a listing with no buy-now | Nothing changes | `Failure(:invalid_price)` inline |
| Stale consent | Text edited after consenting, or a redraw | The next submit asks again | No error expected |
| Double confirm | Confirm pressed twice | One request | No error expected |

</frozen-after-approval>

## Code Map

- `app/frontend/lib/annonce.ts`, `annonce_view.ts`, `app/frontend/controllers/annonce_controller.ts`, `annonce_field_controller.ts`, `annonce_foot_controller.ts` (previous story) -- the root, state and children to extend with the gate and the dialogs.
- `app/frontend/controllers/dialog_controller.ts`, `dialog_opener_controller.ts`, `app/frontend/lib/dialog.ts` -- the existing dialog conventions (`openDialog`, `takeOpener`, focus back to the opener on close).
- `app/frontend/lib/dom_writes.ts`, `picoins.ts`, `i18n.ts`, `app/frontend/lib/listing_form.test.ts` (shared fixture reading) -- text writes, formatting, fixture pattern.
- `app/domains/game/app/queries/game/market/bid_sheet.rb` (previous story), `current_settings.rb`, `models/game/market/settings.rb` (`unusual_maximum_multiple`) -- the sheet's new fields.
- `app/controllers/market/bids_controller.rb`, `app/views/market/bids/_form.html.erb`, `_foot.html.erb`, `_region.html.erb`, `app/views/market/listings/_outcome.html.erb` -- where the `buy_now` parameter, the button row and the dialogs fit, and the bought outcome that answers.
- `app/components/button_component.rb`, existing dialog markup in `app/views/` (an `ANNULER`/confirm dialog such as the delete-set dialog) -- markup and component conventions.
- `config/locales/en.yml`, `fr.yml`, `app/frontend/styles/market-bid.css`.

## Tasks & Acceptance

**Execution:**
- [ ] `app/domains/game/app/queries/game/market/bid_sheet.rb` -- add `unusual_multiple`, `buy_now_hold`, `can_buy_now` -- the numbers the dialogs and the button read
- [ ] `app/components/button_component.rb`, its template and `test/components/button_component_test.rb` -- the component has no `name`/`value` today: add optional `name:` and `value:` rendered on the plain and submit `<button>` only (not on a `method`/`href` form button, not with `opens:`) -- `ACHETER MAINTENANT` needs them
- [ ] `app/controllers/market/bids_controller.rb` -- when `params[:buy_now] == "1"` and the sheet exists, take the maximum from the sheet's buy-now price, or answer `Failure(:invalid_price)` inline when the listing has none; when the sheet is nil (closed, due, seller, withdrawn) post the typed maximum unchanged so `PlaceBid` gives the real refusal; no other change -- the button's server path
- [ ] `app/views/market/bids/_buy_now.html.erb` -- `ACHETER MAINTENANT` (`ButtonComponent`, secondary, `name="buy_now" value="1"`, `disabled` when `can_buy_now` is false) and the `Disponible : <amount> PiCoins` text beside it -- the entry point
- [ ] `app/views/market/bids/_unusual_dialog.html.erb` and `_buy_now_dialog.html.erb` -- the two `<dialog>`s (the card's title and rarity come from the region's `listing:` local) with title (`autofocus`, `tabindex="-1"`), text targets for amount and multiple, `ANNULER`, `✕`, confirm button, the card's title and rarity, the held amount line -- the dialogs
- [ ] `app/views/market/bids/_form.html.erb` and `_region.html.erb` -- render the button row and both dialogs when the sheet allows; add the sheet's `unusual_multiple`, `buy_now` and `buy_now_hold` as scalar values on the field markup -- the gate's inputs
- [ ] `app/frontend/lib/annonce_confirm.ts` -- `gate`, `ask`, `grant`, `revoke`, `multipleOf`, pure -- the decision
- [ ] `app/frontend/lib/annonce.ts` and `annonce_view.ts` -- carry `unusualMultiple`, `buyNow`, `buyNowHold`, `price`, the pending gate, its submitter and consent in the state; view fields for the dialogs' texts -- state for the gate
- [ ] `app/frontend/controllers/annonce_controller.ts` -- `submit` consults the gate before the single-submit guard marks the form submitting (a gated submit must not leave it stuck): for `none` it continues as before; otherwise it prevents default, remembers the submitter, writes the dialog's text and opens it through the outlet with the right opener (field for unusual, the pressed control for buy-now); `confirmed` closes, consents and `requestSubmit(submitter)`; a keystroke or redraw revokes -- the flow
- [ ] `app/frontend/controllers/annonce_dialog_controller.ts` -- text targets, `open(opener, texts)`, `confirm` and `cancel` intents, one per dialog -- dialog child
- [ ] `app/frontend/styles/market-bid.css` -- buy-now row, dialog layout on desktop and phone, no inline style -- look
- [ ] `config/locales/en.yml` and `fr.yml` -- under `market.bids`: `unusual.title|body|cancel|close|confirm`, `buy_now.title|body|held_extra|cancel|confirm|button|available`, with the Copy deck's French and an English equivalent -- the text
- [ ] `test/fixtures/files/unusual_maximums.json` -- threshold rows: below, at, above, truncation (79,999), with buy-now above, at, below the maximum, huge amounts -- shared fixture
- [ ] `app/frontend/lib/annonce_confirm.test.ts` -- `gate` against every fixture row, precedence of buy-now, the disabled and absent states, consent revoked by a text change, the safe-integer skip -- module tests
- [ ] `app/frontend/controllers/annonce_controller.test.ts` -- extend: the dialog opens for an unusual maximum and Esc returns focus to the unchanged field without a request; confirm submits once; `ACHETER MAINTENANT` opens the buy-now dialog and cancel focuses the button -- controller tests
- [ ] `test/domains/game/market/bid_sheet_test.rb` -- extend: `unusual_multiple` equals the current version's value, `buy_now_hold` with and without a held maximum, `can_buy_now` at, above and below available -- the reader
- [ ] `test/controllers/market/bids_controller_test.rb` -- extend: `buy_now=1` buys at the buy-now price and answers the bought outcome with `VOIR LA CARTE`, a leader buying holds only the difference, a listing without buy-now answers `invalid_price`, an unaffordable buy-now answers `more_than_available`, the page never carries another player's maximum -- server path
- [ ] `test/system/market_bidding_test.rb` -- its own test: a maximum at three times the price asks confirmation, Esc returns to the field with the amount kept and no bid, then confirm places it; a buyer presses `ACHETER MAINTENANT`, cancels (focus back on the button), presses it again, confirms and reads `VOUS AVEZ ACHETÉ`, with the card in their collection -- the ticket's system test

**Acceptance Criteria:**
- Given a maximum below the unusual multiple, when `ENCHÉRIR` is pressed, then the bid is placed with no dialog.
- Given a maximum at or above the multiple and below any buy-now, when `ENCHÉRIR` is pressed, then `MONTANT INHABITUEL` opens on its title, states the amount and the truncated multiple, and `ANNULER`, `✕` or Esc return to the field with its text unchanged and no request made.
- Given a maximum reaching the buy-now price or a press on `ACHETER MAINTENANT`, when it is submitted, then `ACHAT IMMÉDIAT` opens, takes precedence over the unusual dialog, names the card and the amount held, and cancelling returns to the control that opened it.
- Given a confirmed buy-now, when the server answers, then the region shows the bought outcome with `VOIR LA CARTE` and the copy is in the buyer's collection.
- Given a player who cannot pay the held amount, when the Annonce renders, then `ACHETER MAINTENANT` is disabled with the available amount beside it.
- Given a confirmation, when the typed text changes or the region is redrawn, then the next submit asks again.

## Implementation Notes

## Plan Change Log

- 2026-11-10, approver (one round): body only, frozen block untouched. `ButtonComponent` cannot carry `name`/`value`, so the task adds them; the buy-now dialog's card comes from the region's `listing:` local; `buy_now=1` with no sheet falls through to `PlaceBid`'s own refusal rather than a misleading `invalid_price`; the gate runs before the submit guard.

## Review Triage Log

## Design Notes

- Consent is bound to a submitter and a text, so a confirmation can never be reused for a different amount: any edit or redraw revokes it, and the server rules still run on whatever is finally posted.
- One form keeps one guard: the dialogs call `requestSubmit(submitter)`, so the single-submission rule, the rate limit and the refusals of the previous story apply unchanged to confirmed and unconfirmed bids alike.

```ts
// lib/annonce_confirm.ts (shape)
type Gate = "none" | "unusual" | "buy_now"
const gate = (s: AnnonceState, amount: number, buyNowButton: boolean): Gate =>
  buyNowButton || (s.terms.buyNow !== null && amount >= s.terms.buyNow) ? "buy_now"
  : amount >= s.terms.unusualMultiple * s.terms.price ? "unusual" : "none"
```

## Verification

**Commands:**
- `ruby -c` and `bundle exec rubocop` on each touched Ruby file; `npm run format:check`, `npm run lint:css` -- expected: no offence
- `npm run test:js` -- expected: green (run once at the end of the market build)
- `bundle exec packwerk check` and `bin/rails zeitwerk:check` -- expected: pass
- `script/check_planning_references` and `script/check_file_sizes` -- expected: pass
- `bin/rails test test/domains/game/market/bid_sheet_test.rb test/controllers/market/bids_controller_test.rb` and `bin/rails test test/system/market_bidding_test.rb -n /confirm|buy/` -- expected: green (run once at the end of the market build, not by the build agent)
- `bundle exec i18n-tasks missing` -- expected: pass
