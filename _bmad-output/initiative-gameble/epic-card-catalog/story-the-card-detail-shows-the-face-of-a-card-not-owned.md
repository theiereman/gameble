---
id: 3
tracker_status: done
tracker_id: ""
type: story
title: "The card detail shows the face of a card not owned"
parent: epic-card-catalog
covers: [R2]
after: [2, 10.2]
hitl: false
risk: low
---

# The card detail shows the face of a card not owned

## Description

CardsController#show and cards/_detail show a card the viewer does not hold, opened from the grid, with its face and entry 2's not-owned treatment instead of the faded card back, in the detail column on desktop and on the detail page on the phone, with entry 1's choice for a detail opened from a set album's missing slot; share and repost stay absent for a card not owned.

## Acceptance Criteria

Verify: From the grid, a card the player does not own opens a detail showing its face set apart, beside the grid at 1280 px and as a page on the phone, with ◀ ▶ walking the grid; an owned card's detail is unchanged; the controller test of a visitor browsing a grid, which expects the faded back, follows the new rule, and the set case follows entry 1's choice; fr and en.

## References

- parent — _bmad-output/initiative-gameble/epic-card-catalog/epic-card-catalog.md
- app/controllers/cards_controller.rb, @faded
- app/views/cards/_detail.html.erb
- test/controllers/cards_controller_test.rb, the faded back cases

## Notes

- Author, 2026-10-20, supersedes this entry's description: the detail shows the real card, never greyed or locked, owned or not, signed in or not (no faded back); PARTAGER is on every card for every viewer; repost and the showcase buttons stay for owned cards; a player's copies and ÉDITIONS rows read "Aucun" / "Aucune" for a card not owned, a visitor has neither row.
