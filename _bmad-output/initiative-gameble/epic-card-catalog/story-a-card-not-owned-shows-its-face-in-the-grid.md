---
id: 2
tracker_status: done
tracker_id: ""
type: story
title: "A card not owned shows its face in the grid"
parent: epic-card-catalog
covers: [R1, R3]
after: [1, 10.7]
hitl: false
risk: low
---

# A card not owned shows its face in the grid

## Description

In "Toutes les cartes" a game the viewer does not hold renders its published-season face through CardComponent with entry 1's not-owned treatment instead of the locked missing slot, for a player and a visitor, keeping the owned-first order, the copies badge and edition count on owned cards, the state filter's "missing" choice and the slot's link to the detail; set albums keep their missing slots; it shapes the not-owned treatment (a CardComponent option or class) that entry 3 reuses in the detail.

## Acceptance Criteria

Verify: On a seeded season, a player holding a few cards sees them first with their "×n", then every other card's face set apart, never a locked slot; a visitor sees every card's face; a set album still shows its missing slots; a search for a game the player lacks finds its face; the visitor's grid still runs no holdings query and its query count test holds; fr and en, phone and desktop.

## References

- parent — _bmad-output/initiative-gameble/epic-card-catalog/epic-card-catalog.md
- app/views/library/_grid.html.erb
- packs/game/app/queries/game/collection_states.rb
- test/controllers/library_controller_test.rb, the visitor cases: every slot missing without a holdings query, a visitor's seven queries, a visitor opening on every slot

## Notes

- Author, 2026-10-20: the not-owned treatment is variant A's face (45 % opacity, grey, rarity effects off) with variant E's bare pixel lock centred over the art, for a signed-in player only; a visitor's faces are plain; another player's full collection uses it by that player's holdings. A card not owned adds "non possédée" / "not owned" to its accessible name.
