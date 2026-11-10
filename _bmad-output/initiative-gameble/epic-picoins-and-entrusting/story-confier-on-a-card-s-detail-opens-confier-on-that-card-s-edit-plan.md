---
title: "CONFIER on a card's detail opens Confier on that card's editions"
type: 'feature'
ticket: '38.7'
created: '2026-11-10'
status: 'draft'
baseline_revision: '7575ad08a540ba6ca7576e0127e0c41785d126a7'
route: 'full'
route_source: 'auto'
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/initiative-gameble/epic-picoins-and-entrusting/epic-picoins-and-entrusting.md'
  - '{project-root}/_bmad-output/initiative-gameble/epic-picoins-and-entrusting/story-the-confier-screen-previews-the-batch-as-the-player-ticks-plan.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A player can only reach Confier by typing its address; the card detail, where a spare copy is noticed, has no way in, and Confier cannot be opened on one card.

**Approach:** The card detail of an owned card shows a secondary CONFIER button once the market has first opened and while it is open, greyed with the reserved count when no copy is free. It links to Confier at a new address carrying the card's slug (its public token): the same page, listing only that card's free editions, DOUBLONS off, a single free edition already ticked. Epic requirement R9.

## Boundaries & Constraints

**Always:** the button is decided by one Game query from the player, the card and `MarketState` (nothing in the view reads settings or holdings); the button shows only when the player holds at least one copy of an edition with a rarity, the market `first_opened?` and `open?`, and the viewer is signed in; it is a `ButtonComponent` `variant: :secondary` with no amount; greyed (`disabled: true`) with "<n> reserved copies" beside it when every owned copy is reserved; the filtered address is a GET that writes nothing, reuses `Market::EntrustmentsController#new` and the same templates; the card is found by slug, never by id, and an unknown slug answers not found; DOUBLONS starts off from the server markup and the root controller's state starts from that markup; a single free edition (one cell) starts ticked at one copy; after a refusal on the form, the card filter, DOUBLONS off and the ticks are kept; every string in `en.yml` and `fr.yml`; the route helper `new_market_card_entrustment_path(slug:)` is stable, and the unfiltered `new_market_entrustment_path` stays the one epic 39's CONFIER DES CARTES links to.

**Never:** a price or amount on the button; a per-card warning; showing the button before the first opening, while suspended (the epic and ticket say absent; the UX Market suspended row's "disabled" line is superseded for the card detail by its own Card detail and the market row) or to a visitor; a database id in a URL or the DOM; touching METTRE EN VENTE (epic 39); changing entrusting itself; a second Confier template.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Two free editions | open market, card held in two editions, free copies | CONFIER enabled; Confier filtered on the card: two cells, DOUBLONS off, nothing ticked | none |
| One free edition | one held edition with free copies | Confier opens with that cell ticked at 1 copy | none |
| Fully reserved | every owned copy reserved | CONFIER greyed, "<n> reserved copies" beside it | none |
| Reserved elsewhere | one edition fully reserved, another free | enabled; only the free edition has a cell | none |
| Not open yet | no settings version ever opened | no button | none |
| Suspended | first opened, `open` false | no button | none |
| Visitor / not owned | signed out, or no copy of the card | no button | none |
| Unknown token | `/market/entrust/cards/nope` | not found | 404 |
| Closed, by address | known slug, suspended market | page opens with the closed notice, validation disabled | existing notice |
| Refusal | stale settings posted from the filtered page | page redrawn filtered on the card, DOUBLONS off, ticks kept | existing inline refusal |

</frozen-after-approval>

## Code Map

- `config/routes.rb` -- `market/entrust` GET/POST at lines 36-37; the filtered address joins them.
- `app/controllers/market/entrustments_controller.rb` -- `new`, `load_page`, `ticked_on`; `create` redraws through `load_page` on refusal.
- `app/domains/game/app/queries/game/market/entrustable_copies.rb` -- SQL of free copies per card-season, `Copy` data; gains an optional card slug.
- `app/domains/game/app/models/game/market/market_state.rb` -- `first_opened?`, `open?`, built from `CurrentSettings`.
- `app/controllers/cards_controller.rb` -- `show` loads `@editions` (`Game::HeldEditions`), `@copies`; the entrustment state joins them.
- `app/views/cards/show.html.erb` and `_detail.html.erb` -- locals passed to the detail; actions block `.card-detail__actions` (no `holder-actions` wrapper when nothing to repost or showcase).
- `app/views/market/entrustments/new.html.erb`, `_filters.html.erb`, `_cell.html.erb` -- the page, the hardcoded `checked` DOUBLONS box, the `data-ticked` cell.
- `app/helpers/market_entrustments_helper.rb` -- `entrust_root_data` writes the root's values.
- `app/frontend/controllers/entrust_controller.ts` -- `startFromMarkup` builds the state with `start(...)`; `app/frontend/lib/entrust.ts` -- `start`, `DEFAULT_FILTER`, `CLEARED_FILTER`.
- `test/controllers/market/entrustments_controller_test.rb`, `test/controllers/cards_controller_test.rb`, `test/system/market_entrust_test.rb`, `test/support/market.rb` (`open_market!`, `close_market!`), `test/support/holdings.rb` (`hold ... reserved:`), `app/frontend/lib/entrust.test.ts`, `app/frontend/controllers/entrust_controller.test.ts`.

## Tasks & Acceptance

**Execution:**
- [ ] `app/domains/game/app/queries/game/market/card_entrustment.rb` -- new `Game::Market::CardEntrustment.call(player, card_id:, state: MarketState.call)` returning nil, or `Data.define(:free, :reserved)`: nil unless `player`, `state.first_opened? && state.open?` and the player holds copies (`quantity > 0`) of an edition with a rarity; `free` and `reserved` are the sums of `quantity - reserved` and `reserved` over those holdings. Then the view needs only `free.zero?` -- one read decides the button.
- [ ] `app/domains/game/app/queries/game/market/entrustable_copies.rb` -- add `card_slug: nil` to `call`; the SQL gains `AND (CAST(:card_slug AS text) IS NULL OR catalog_cards.slug = :card_slug)`; the order and `Copy` are unchanged.
- [ ] `config/routes.rb` -- `get "market/entrust/cards/:slug" => "market/entrustments#new", as: :new_market_card_entrustment`, beside the existing two, so the slug is the page's token and no new controller exists.
- [ ] `app/controllers/market/entrustments_controller.rb` -- `card_slug` from `params[:slug]` on GET or from a posted `card` on a refusal; if present and no `Catalog::Card` has that slug (reuse the existing slug lookup, or add `Catalog::CardIdBySlug`), `raise ActiveRecord::RecordNotFound`; `load_page` passes it to `EntrustableCopies`, sets `@card_slug`, `@doubles = card_slug.nil?` and, when filtered, a single free edition (`@copies.one?`) and no posted ticks, `@ticked = { ref => 1 }`; `ticked_on` still wins when ticks were posted.
- [ ] `app/views/market/entrustments/new.html.erb` -- when `@card_slug`: a hidden `card` field in the form, a line naming the card with a `ButtonComponent` `variant: :link` back to `new_market_entrustment_path` ("all cards"); pass `doubles: @doubles` to `entrust_root_data`.
- [ ] `app/views/market/entrustments/_filters.html.erb` -- the DOUBLONS box is `checked` only when `@doubles`; the count shows `0` and is `hidden` when off.
- [ ] `app/helpers/market_entrustments_helper.rb` -- `entrust_root_data(open:, cap_left:, doubles:)` writes `entrust_doubles_value`.
- [ ] `app/frontend/lib/entrust.ts` -- `start(copies, capLeft, ticked, doubles = true)` begins with `{ ...DEFAULT_FILTER, doubles }`; `app/frontend/controllers/entrust_controller.ts` -- add a `doubles` boolean value (default true) and pass it in `startFromMarkup`; no markup built in script.
- [ ] `app/controllers/cards_controller.rb` -- in `show`, `@entrustment = Game::Market::CardEntrustment.call(current_player, card_id: @detail.card_id)` unless `@public`.
- [ ] `app/views/cards/show.html.erb` and `_detail.html.erb` -- pass `entrustment:`; in `.card-detail__actions` add a `card-detail__market` block (outside `holder-actions`) when present: enabled `ButtonComponent.new(variant: :secondary, href: new_market_card_entrustment_path(slug: view.id))`, or `disabled: true` plus `<p class="card-detail__market-note">` with the reserved count; styles in the card detail stylesheet using existing tokens, no `style` attribute.
- [ ] `config/locales/en.yml` and `config/locales/fr.yml` -- `card_details.entrust.button` ("Entrust" / "CONFIER" as the repo writes its buttons), `card_details.entrust.reserved` with `zero`/`one`/`other` (fr "%{count} exemplaires réservés", `zero` form present), `market.entrustments.new.card_only` and `all_cards` for the filtered line; run `i18n-tasks` normalisation check.
- [ ] `test/domains/game/market/card_entrustment_test.rb`, `test/domains/game/market/entrustable_copies_test.rb` -- state matrix (not open, closed after opening, visitor, not owned, only unranked holdings, free, fully reserved, mixed) and the slug filter.
- [ ] `test/controllers/cards_controller_test.rb` -- button absent before first opening, while closed and for a visitor; present with the right href when open and owned; greyed with "<n> reserved copies" when fully reserved; absent when not owned.
- [ ] `test/controllers/market/entrustments_controller_test.rb` -- filtered page lists only that card's cells, DOUBLONS box unchecked, one free edition ticked, two not; unknown token 404; a GET writes nothing; a refused POST with `card` redraws filtered and keeps ticks.
- [ ] `app/frontend/lib/entrust.test.ts`, `app/frontend/controllers/entrust_controller.test.ts` -- `start` with doubles off shows single-copy cells; the controller reads the value from the markup.
- [ ] `test/system/market_entrust_test.rb` -- from a card detail with two free editions the player reaches Confier filtered on that card with DOUBLONS off and nothing ticked; from a card with one free edition it opens ticked.

**Acceptance Criteria:**
- Given the market has opened and is open, when a signed-in player views a card of which they hold a free copy, then CONFIER shows as a secondary button without an amount and links to the filtered Confier.
- Given every owned copy of the card is reserved, when the detail loads, then CONFIER is disabled and "<n> reserved copies" sits beside it.
- Given the market never opened, is suspended, or the viewer is signed out, when the detail loads, then no CONFIER shows.
- Given the filtered address, when it loads, then only that card's free editions are cells, DOUBLONS is off in the markup and in the screen's state, and a lone free edition is ticked.
- Given an unknown slug, when the filtered address is requested, then the response is 404.

## Implementation Notes

## Plan Change Log

## Review Triage Log

## Design Notes

- Slug as token: the card detail already addresses a card by slug (`cards/:slug`), so it is the public token; the filtered address reuses `new` and one template, so the epic 39 link to the unfiltered Confier is untouched.
- Greyed versus absent: the ticket and epic make suspended absent and fully reserved greyed; "free" counts only holdings with a rarity, since Confier cannot show the others.
- Doubles read: `start` takes the initial DOUBLONS value from markup so the server and the state never disagree; the existing "clear filters" still unticks it.

## Verification

**Commands:**
- `bundle exec rubocop` on touched Ruby files and `bundle exec packwerk check` -- expected: no offence
- `script/check_planning_references` and `script/check_file_sizes` -- expected: pass
- `/home/teyermann/projets/gameble/node_modules/.bin/prettier --write` on touched frontend files -- expected: formatted
- Final run, once: `bin/rails test test/domains/game/market test/controllers/cards_controller_test.rb test/controllers/market/entrustments_controller_test.rb`, `npm run test:js`, `bin/rails test test/system/market_entrust_test.rb -n /detail/` -- expected: green

**Manual checks (if no CLI):**
- On a card detail with two free editions, CONFIER opens Confier on that card with DOUBLONS off, nothing ticked; suspend the market and the button disappears.
