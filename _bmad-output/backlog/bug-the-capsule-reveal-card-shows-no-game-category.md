---
id: bug-the-capsule-reveal-card-shows-no-game-category
type: bug
title: "The capsule's enlarged reveal card shows no game category"
parent: none
covers: []
after: []
assignee: ""
refined: false
hitl: false
risk: low
severity: P3
estimate: ""
tracker_id: "#77"
remote: https://github.com/theiereman/gameble/issues/77
---

# The capsule's enlarged reveal card shows no game category

## Description

A player opened a capsule on a phone (Chrome) and enlarged a revealed card: it showed the title, developer, year, rarity and card number, but no category or main theme. Reported once, on Dreamfall: The Longest Journey. Find whether the enlarged reveal face never renders the card's main theme, or whether this card has none (a UFO card, or a card-season without a recorded main theme), and fix the cause.

## Acceptance Criteria

Verify: an enlarged card in the capsule reveal shows its main theme, in French and English, like the card face elsewhere; a card without a main theme shows the same fallback as the other card faces; Dreamfall: The Longest Journey shows its category on staging.

## References

- issue — https://github.com/theiereman/gameble/issues/77 (screenshot attached there)

## Notes

- Filed on 2026-10-19 from GitHub issue #77.
