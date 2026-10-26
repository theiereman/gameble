---
id: 24
tracker_status: done
tracker_id: 252
remote: https://github.com/theiereman/gameble/issues/252
type: story
title: "A set album's missing cards look like the not-owned cards of the catalog"
parent: epic-screen-walkthrough
after: []
hitl: false
risk: low
---

# A set album's missing cards look like the not-owned cards of the catalog

## Description

In a set album (`app/views/library/_album.html.erb`) the cards the player lacks are missing-card slots showing the game's name and year, while the same cards in Toutes les cartes are the published season's face, faded and grey with a pixel lock (EXPERIENCE.md, Card not owned (grid); mock `ux-gameble/mockups/catalog-not-owned.html`). The author wants the album to match the catalog (screen walkthrough, 2026-10-23, on staging). Show a missing card in a set album as that not-owned face, opening the card detail like any card, and drop the missing-card slot component; EXPERIENCE.md's Missing-card slot row and DESIGN.md follow.

## Acceptance Criteria

Verify: In a set album the missing cards render with the same not-owned face as in Toutes les cartes, in set order beside the owned cards, on the desktop and the phone, in French and in English, on the player's own album and on a public profile's album; the album and catalog system tests (retrying matchers) and the full suite pass.

## References

- parent — _bmad-output/initiative-gameble/epic-screen-walkthrough/epic-screen-walkthrough.md

## Notes

- Found in the screen walkthrough (ticket 16.1, finding 16), author, 2026-10-23: consistency with the catalog.
