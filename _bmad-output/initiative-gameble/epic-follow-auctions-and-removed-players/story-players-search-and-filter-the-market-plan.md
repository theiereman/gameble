---
title: 'Players search and filter the market'
type: 'feature'
ticket: '40.7'
created: '2026-11-10'
status: 'in-review'
baseline_revision: 'ee385caffd1868936402b29b20042aabb8201400'
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

**Problem:** The market lists every open auction with only a sort, so finding a game, a rarity or a price means scrolling. Epic requirement R11.

**Approach:** `Game::Market::OpenListings` takes a search by game title, rarity, set, genre, season and a price range on the current price, combined with its four sorts, all as URL parameters; the market screen gets the search field, the folded FILTRES panel with its active count and the PRIX group, and keeps the filters through sorting and "Charger plus".

## Boundaries & Constraints

**Always:**
- OR within a group and AND across groups. Parameters: `q`, `rarity[]`, `sets[]` (`kind:key`), `genre[]`, `season[]` (season numbers), `min_price`, `max_price`; none is a database id. An invalid value is ignored, never an error.
- The filters live in `Game::Market::ListingFilters` (parsing and the conditions), read through the reading role; the four sorts and their order are unchanged.
- The PRIX group is a partial of two labelled number fields "Prix minimum" and "Prix maximum", written so the collection's price filter can render it unchanged.
- The sort chooser and "Charger plus" carry the filters. A filtered list with no match says "Aucune annonce ne correspond à ces filtres."; with no filter the existing empty line stays.
- A concurrent index on open listings by current price, in its own migration after the feed entries' ones.
- Copy in `en.yml` and `fr.yml`.

**Never:**
- No change to the sorts, the tile or the page size. No live list. No database id in a URL, DOM id or parameter.

**Decisions (settled by Claude, no approval round in this batch; the author may revisit):**
- The form is a plain GET form that works without script, with its apply button; a small Stimulus controller submits it after a checkbox change or a pause in typing and reloads the set options, reusing the collection's pure helpers.
- The set group follows the collection's: a kind chooser and a typed search of sets offered through a turbo frame, answered by the market screen itself.
- The season group lists the published seasons by number; a price is in whole PiCoins; a maximum below the minimum matches nothing.
- The search matches the card title in the page's locale and the publisher, as the collection's does.
- The price index is `(current_price, id)` where the listing is open, serving the two price sorts and the range.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Search | `q=tin` | Listings of cards whose title matches | No error expected |
| Group combination | Two rarities and one season | Either rarity, in that season | No error expected |
| Price range | `min_price=5000&max_price=10000` | Current price within, ends included | No error expected |
| Invalid | `min_price=abc`, `rarity[]=nope` | Ignored | Ignored |
| No match | Filters match nothing | "Aucune annonce ne correspond à ces filtres." | No error expected |
| Sort with filters | `sort=price_asc` plus filters | Filters kept, sorted | No error expected |

</frozen-after-approval>

## Code Map

- `app/domains/game/app/queries/game/market/open_listings.rb`, `listing_filters.rb` -- the query and its filters
- `app/controllers/markets_controller.rb`, `app/helpers/market_helper.rb` -- parameters and link builders
- `app/views/markets/*` -- screen, filters, price group, sorts, pages
- `app/frontend/controllers/market_filters_controller.ts`, `app/frontend/styles/market-filters.css` -- script and style
- `db/migrate/20261110160003_*` -- the price index
- `config/locales/en.yml`, `fr.yml` -- copy

## Tasks & Acceptance

**Execution:**
- [ ] Filters value and query, index migration
- [ ] Controller parameters, helpers, sort and page links carrying the filters
- [ ] Filter views, controller and style
- [ ] Copy in both locales
- [ ] Tests: query, controller, one system test

**Acceptance Criteria:**
- Given a visitor, when they search a game, keep Rare listings of one season under a maximum price and sort by price ascending, then the list matches and, after a filter with no match, shows the no-match line.

## Implementation Notes

Built as planned; nothing was run. Text fields (search, prices) submit on Enter or the apply button, never on blur, so tabbing between the two price fields keeps focus; checkboxes submit at once. A set choice absent from the published season is dropped. The PRIX group is `app/views/filters/_price.html.erb` with the `filters.price` copy, ready for the collection. The price index is migration `20261110160003`; `db/schema.rb` is left to be regenerated.

## Plan Change Log

## Review Triage Log

## Verification

**Commands:**
- `ruby -c`, `npx prettier --check`, `npm run lint:css`, `npx tsc --noEmit`, YAML parse and en/fr parity, `script/check_planning_references`, `script/check_file_sizes` -- expected: no finding
