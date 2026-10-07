---
title: 'Collection opens on owned cards, with a filter zone and a search'
type: 'feature'
ticket: '7'
created: '2026-10-07'
status: 'in-review'
baseline_revision: '47cea18b653361d83cd2a5ab133491a1eade4cca'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: []
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The collection opens on every slot of the season and filters only by genre, through a row of links; a player cannot start from what they own, narrow by state, rarity or set, or search a title.

**Approach:** The grid opens on owned cards, newest first; one folded FILTRES zone of toggleable chips (state, rarity, set, genre; OR within a group, AND across) with an active count and a clear-all, plus a search over title and publisher, drive the grid server-side (GET params, a Turbo Frame around the grid so the zone and the search keep focus).

## Boundaries & Constraints

**Always:**
- Filtering happens in SQL, paginated as today (60 a page); `Catalog` answers cards (rarity, genre, set, text), `Game` answers holdings (state), the web layer joins them (AD-2, AD-15: no id on the page; sets as `kind:key`).
- State group: none chosen means POSSÉDÉES (owned); TOUT, MANQUANTES, NOUVELLES, DOUBLONS widen or switch it. A visitor, or a player owning nothing, with no state chosen sees every slot (EXPERIENCE: Collection empty).
- Whole-season order is newest gained first (NOUVEAU in front, unowned last, then season number); a set page keeps its slot order.
- Works without JavaScript (a GET form); Stimulus adds the live submit, the debounce and the live count. Copy in `config/locales/{en,fr}.yml`, French from EXPERIENCE.md, English written here; plain CSS on tokens.

**Never:** a sort or filter by market price (V2; leave room for another group); the RAPPORT panel or the set rows changed; the card detail; a new gem or migration.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Opening | player owns cards, no params | owned cards only, newest first, count 0 | — |
| Missing | `state[]=missing` | unowned slots naming the game | — |
| OR / AND | `genre[]=action&genre[]=rpg`, then `rarity[]=rare` | either genre; then both conditions | — |
| Search | `q=port` | cards whose title (locale) or publisher contains it, with the other filters | LIKE wildcards escaped |
| Empty | filters match nothing | the empty-filter line | — |
| Visitor / nothing owned | no params | every slot missing | owned/new/duplicates alone give an empty grid |
| Unknown value | unknown state, rarity, genre, set | ignored | — |
| Set page | `/library/tome/x?rarity[]=rare` | filters apply inside the set | no set group |

</frozen-after-approval>

## Code Map

- `packs/catalog/app/queries/catalog/collection_grid.rb` -- grid relation: replace `genre:` by `genres:`, add `rarities:`, `sets:`, `query:`; answers the valid chosen values.
- `packs/game/app/queries/game/collection_states.rb` (new) -- state filter and newest-first order over a card-season relation (LEFT JOIN holdings and player state; reuse `CollectionSlots::NEW`).
- `app/controllers/library_controller.rb` -- parse params, default state, apply states, `pluck` qualified.
- `app/views/library/_collection.html.erb`, new `_filters.html.erb`, `_grid.html.erb` -- form, zone, frame; `app/helpers/collection_helper.rb` -- chip params, clear path.
- `app/frontend/controllers/collection_filters_controller.ts` (new), `app/frontend/styles/collection.css`, `config/locales/{en,fr}.yml`.
- Tests: `test/controllers/library_controller_test.rb`, `library_set_test.rb`, `test/packs/catalog/collection_grid_test.rb`, `test/packs/game/collection_states_test.rb` (new), `test/system/library_test.rb`.

## Tasks & Acceptance

**Execution:**
- [ ] `collection_grid.rb` -- filters by genres, rarities, sets (OR in group, AND across), text -- grid scope
- [ ] `collection_states.rb` -- states and order -- holdings join
- [ ] controller, views, helper, CSS, Stimulus, locales -- the zone and the search
- [ ] tests for each matrix row; system test for typing and chip toggling

**Acceptance Criteria:**
- Given a player with cards, when they open the collection, then owned cards show first; switching state to missing shows empty slots naming the game.
- Given two genre chips on, then either genre shows; adding a rarity chip narrows to both.
- Given they type a title, then the grid narrows as they type; an empty result shows the empty-filter line.

## Implementation Notes

Implemented directly (no coding subagent: the investigation lived in this session). Built: `Catalog::CollectionGrid` (genres, rarities, sets, text), `Game::CollectionStates` (states, held-first newest-first order), controller, `library/_filters` form, frame around the grid, `collection-filters` Stimulus controller, CSS, en/fr copy, tests (controller, grid, states, system). Verification run green: rails test (minus card_face_visual), system `library_test.rb`, rubocop, packwerk, i18n-tasks missing and unused, typecheck, test:js. The `genre` parameter is now a list (`genre[]`, a single `genre=` still works). Query count of a player's request is 15 (was 14: the filtered count no longer shares the season count). Not done: the quick review and the commit, because the environment began refusing `git` commands (see the report).

## Plan Change Log

## Review Triage Log

## Design Notes

Decisions (author away): chips are checkboxes in a GET form (native on/off state, no JS needed) instead of `aria-pressed` buttons; the zone is one folded panel above the grid on every width, expanding in place on the phone instead of a modal sheet; the set group lists the sets of the aside's current list page plus any chosen set (publishers are too many for chips); the filters live outside a Turbo Frame holding the grid, so focus stays; the empty-filter line reuses `library.grid.empty` reworded (no longer genre or set specific).

## Verification

**Commands:**
- `bin/rails test` (minus card_face_visual_test.rb), `bin/rubocop`, `bin/packwerk check`, `bundle exec i18n-tasks missing`, `npm run typecheck`, `npm run test:js` -- all green
