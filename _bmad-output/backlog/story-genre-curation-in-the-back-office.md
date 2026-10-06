---
id: 2
type: story
title: "An administrator curates the tome genres in the back-office before publishing"
parent: none
covers: [CAP-2, CAP-6]
after: []
assignee: ""
refined: false
hitl: true
risk: medium
estimate: ""
---

# An administrator curates the tome genres in the back-office before publishing

## Description

Between an import and a publication, a back-office screen lists every Steam tag the import met, with how many draft games have it as their most-voted tag; the administrator maps each tag to a genre (merging neighbours), makes it a genre of its own, or ignores it, and manages the genres themselves with French and English labels (the tag's English name by default, editable); a rescore applies the mapping to the draft and the preview shows the tome sizes; a draft with any unclassified tag cannot be published. It replaces the curated list in code (`Steam::GenreTags`), seeded from its 25 genres.

## Acceptance Criteria

Verify: after an import, every tag met is listed with its game count; mapping Roguelite to Roguelike and rescoring moves those games into Roguelike tomes in the preview; a new tag left unclassified blocks the publish with a reason; a renamed genre shows its French and English labels on the tomes; a published season's tomes never change.

## References

- spec — _bmad-output/initiative-gameble/spec-gameble/catalog-and-rarity.md, Sets (Tomes)
- architecture — _bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md, AD-4, AD-5, AD-18 (an exception to settle: genre labels become catalog data, like card text), AD-19
- code — packs/steam/app/models/steam/genre_tags.rb, the list it replaces

## Notes

- The author: "après un import et avant de publier une saison je peux voir tous les genres qui ont été ajoutés et c'est moi qui décide lesquels fusionner vers un genre" (2026-10-06).
- The author: every tag must be classified before publishing; the English tag name is the default label, translations entered by hand.
- Not urgent: needed before the next season's import. Replaces the open question on folding neighbouring genres.
- hitl: the screen's design and the AD-18 exception are settled with the author (bmad-architecture update) before the build.
