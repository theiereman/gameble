---
title: 'Le Grand Inventaire: the screen'
type: 'feature'
ticket: ''
created: '2026-11-19'
status: 'built'
baseline_revision: '6039d4a701321e163bea6cd4b18be6aa3e3d754b'
route: 'oneshot'
route_source: 'pinned'
review: 'none'
review_source: 'pinned'
lenses_ran: []
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: ['multiple-goals']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Players cannot see the Brotherhood's collection: which cards of the published season anyone has found, who found each first, and what is still missing.

**Approach:** Slice 1 of four parallel slices: a public, read-only screen `GET /:locale/inventory` (`GrandInventoriesController#show`) backed by the query `Game::GrandInventory` (the shared API other slices call), with the head, the Sets panel, a slot for slice 2's pioneer boards partial, and the "Cartes" grid (search, filter zone, paging), phone tabs, visitor line, and the card detail's "◀ GRAND INVENTAIRE" back. Spec: `ux-gameble/EXPERIENCE.md` § Le Grand Inventaire, `DESIGN.md` § Grand Inventaire.

## Boundaries & Constraints

**Always:** GET never writes; Pundit `authorize :page, :show?`; no database ids in URLs or DOM; strings in `grand_inventories.*` of both locales; names follow the Pioneer row rule (link only when the viewer may see the profile, removed players "anonyme"); scope `seasons=current` in the address, absent means all seasons.

**Never:** build slice 2's `Game::PioneerBoard` or `_pioneer_boards` partial, slice 3's `BrotherhoodSetsController` or route, slice 4's hub panel, tile, landing link or settings note; run test suites (they run after integration).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| All seasons | a card found in S1 and again in S2 | found, pioneer = earliest discovered edition's | none |
| Current season | the published edition has no discovery | not found in `:current` | none |
| Removed pioneer | pioneer banned or deleted | card still found; name reads "anonyme", no link | none |
| Latest discovery | discoveries across editions | the newest row of a published card, same in both scopes | nil when none |
| No published season | none published | screen shows the no-season line | none |

</intent-contract>

## Implementation Notes

Route pinned to oneshot: the caller spawned this agent as the builder of the slice and asked it to implement directly, not to hand off to another agent. Tests are written, not run (caller's rule); they run once in the main tree after the four slices merge.

Decisions:
- `Game::GrandInventory` loads the published season's cards and the scope's discoveries once (one row per card, about the season's size) and answers the counts, rarities and set progress from them; the grid orders in SQL through `cards_in_order`, joining the same discoveries subquery. `Discovery.card` is always a `Catalog::CardView` of the published edition (links need its slug and number). Extra public methods beyond the contract: `pioneers_of(card_ids)` (batch), `set_progresses`, `cards_in_order`, `.states`, `scope`, `season`.
- The pace line counts first discoveries of any edition of a published card (week from Monday 00:00 UTC, the UTC day); the latest discovery is the newest such row, the same in both scopes.
- The scope chips are submit buttons of a GET form targeting the `grand-inventory` frame (head, tabs and views), so the focus stays on the chip; the Stimulus controller presses the chip, empties then fills the polite status. Phone tabs are links into the same frame; the controller focuses the shown view's h2.
- The grid reuses `library/filters` (filter row) with two new optional locals, `state_filter` and `hidden`, and `library/pages`; the card detail walks the grid through `inventory_browse` in `CardsController`, its back "Grand Inventaire".
- Under a card the pioneer's name is plain text, never a link: the lines under the face are hidden from assistive technology, and a link there would be a focusable element inside `aria-hidden`. The profile link stays in the pace line and on the card detail.
- `PlayerNameComponent` takes an optional `friends:` set so a page of names reads friendships once.
- Stylesheet named `grand-inventory.css` (the repo's hyphenated naming).

## Auto Run Result

- Summary: the Grand Inventaire screen (`GET /:locale/inventory`), its query `Game::GrandInventory`, the card detail's way back, written with a unit test, an integration test and a system test.
- Files: `app/domains/game/app/queries/game/grand_inventory.rb` (query), `app/controllers/grand_inventories_controller.rb` + `concerns/grand_inventory_grid.rb` (screen, grid shared with the card detail), `app/controllers/cards_controller.rb` (inventory browse), `app/helpers/grand_inventories_helper.rb`, `app/views/grand_inventories/*`, `app/views/library/_filters.html.erb` and `_filter_row.html.erb` (optional state partial and hidden fields), `app/components/player_name_component.rb` (friends set), `app/helpers/shell_helper.rb` (SETS tab current), `app/frontend/{lib/grand_inventory.ts,controllers/grand_inventory_controller.ts,styles/grand-inventory.css}`, `config/routes.rb`, both locales, tests.
- Review: none, no lenses launched.
- Verification: Ruby and ERB syntax compiled; prettier applied. No suite run, by the caller's rule: the tests need slice 2's `_pioneer_boards` partial and slice 3's `brotherhood_set_path`, present only after integration.
- Residual risks: untested until integration; the visitor line's order beside slice 2's boards depends on that partial's markup; the full sets list renders every set of the season in the page.
