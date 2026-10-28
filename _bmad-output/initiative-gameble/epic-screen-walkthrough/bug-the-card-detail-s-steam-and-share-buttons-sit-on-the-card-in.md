---
id: 17
tracker_status: done
tracker_id: ""
type: bug
title: "The card detail's Steam and share buttons sit on the card information's background"
parent: epic-screen-walkthrough
after: []
refined: false
hitl: true
risk: low
---

# The card detail's Steam and share buttons sit on the card information's background

## Description

On the card page (`app/views/cards/_detail.html.erb`, "Voir sur Steam" and "Partager", class `card-detail__share-button`) the buttons are drawn on the same background as the card's information, which reads oddly (author, 2026-10-23, on staging). Take the buttons out of that background so it holds the card's information only, on the public card page and the signed-in detail, desktop and phone; DESIGN.md's card detail section follows.

## Acceptance Criteria

Verify: On the public card page and the signed-in card detail, desktop and phone, the information background wraps the card's information only and the Steam and share buttons stand outside it, checked by the author on staging; the card detail system tests and the full suite pass.

## References

- parent — _bmad-output/initiative-gameble/epic-screen-walkthrough/epic-screen-walkthrough.md

## Notes

- Found in the screen walkthrough (ticket 16.1, finding 7), author, 2026-10-23.
