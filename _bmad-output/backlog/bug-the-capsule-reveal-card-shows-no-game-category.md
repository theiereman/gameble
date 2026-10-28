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
---

# The capsule's enlarged reveal card shows no game category

## Description

A player opened a capsule on a phone (Chrome) and enlarged a revealed card, Dreamfall: The Longest Journey: it showed no category. The investigation (plan beside this file) found the face renders the main theme when there is one; Dreamfall has none, because none of its five most-voted Steam tags (Adventure, Female Protagonist, Story Rich, Fantasy, Sci-fi) belongs to a theme, so it is a UFO. The author's choice (2026-10-19): add a theme for adventure games to the theme list in code, covering the Adventure tag (and Story Rich or other narrative tags only if the staging tag counts show they fit and keep the UFOs' share down), named in French and English, so seasons published from now on give such games a main theme. Published seasons stay as they are (main themes are frozen at publication), and cards without a theme keep showing no genre.

## Acceptance Criteria

Verify: the theme list holds the new adventure theme in both languages; a season published in a test makes a card tagged Adventure (Dreamfall's tags) part of that theme with it as main theme, and no longer a UFO; the UFOs' share on staging's catalog drops, measured and recorded in the plan; published seasons are unchanged.

## References

- issue — https://github.com/theiereman/gameble/issues/77 (screenshot attached there)

## Notes

- Filed on 2026-10-19 from GitHub issue #77.
