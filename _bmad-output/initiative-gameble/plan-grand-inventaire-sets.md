---
title: 'Le Grand Inventaire: Set de la Confrérie'
type: 'feature'
created: '2026-11-19'
status: 'built'
route: 'oneshot'
review: 'none'
---

# Le Grand Inventaire: Set de la Confrérie

## Intent

One game set of the published season judged by the whole Brotherhood's first discoveries, at `/:locale/inventory/:kind/:key` (`brotherhood_sets#show`), open without an account. Spec: EXPERIENCE.md `### Le Grand Inventaire` rows Set de la Confrérie, Found card (grid), Card to discover (grid), Names, Visitor; DESIGN.md `### Grand Inventaire`.

Route choice: oneshot, one screen modelled on the existing Set album.

## Contract with the parallel slices

- `Game::GrandInventory` is built by another slice; this slice calls only `new(seasons: :all | :current)`, `#found?(card)`, `#pioneer_of(card)` (Discovery: `card`, `player`, `discovered_at`) and `#set_progress(set)`. The card passed is a `Catalog::CardView` of the published season; the set is the `Catalog::Set`.
- `grand_inventory_path` (the phone back) is another slice's route.

## Design

- `BrotherhoodSetsController#show`: `authorize :page, :show?`; the set album from `Catalog::SetAlbum`; `seasons=current` picks the scope; the filters and paging of the Set album.
- `BrotherhoodSetFilters < SetAlbumFilters`: states DÉCOUVERTES (`found`), TOUT (`all`), À DÉCOUVRIR (`undiscovered`), and MES DÉCOUVERTES (`mine`) signed in only; the rarity group and search are the Set album's.
- `BrotherhoodCardComponent`: Found card / Card to discover cell (face, game name, pioneer name per the Names rule, VOUS badge, accessible name ending with its pioneer).
- Card detail: a card opened from here carries `from=inventory` (and `seasons`) beside `set_kind`/`set_key`; its back reads "Grand Inventaire" and leads to the set's page; ◀ ▶ follow set order and keep the context.
- The shared filter partials take optional `state_labels` and `hidden_fields` locals.

## Acceptance

- Given a published set with some cards discovered, when anyone (visitor included) opens its Set de la Confrérie, then the header shows the set name and found / total with a progress bar without ticks, found cards show their face, name and pioneer, the others the Card not owned face and "To discover".
- Given every card of the set discovered, then the "FULLY DISCOVERED" stamp shows beside the name.
- Given a signed-in pioneer, then their cards carry the VOUS badge and "You", and MES DÉCOUVERTES keeps only them; a visitor gets no MES DÉCOUVERTES chip and the join line with the Steam sign-in.
- Given `seasons=current`, the reading uses the current-season scope and every link (filters, cards, back) keeps it.

## Auto Run Result

Built without running suites (they run once after the four slices are integrated).
