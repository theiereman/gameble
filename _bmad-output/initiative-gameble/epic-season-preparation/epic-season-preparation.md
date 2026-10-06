---
tracker_id: ""
key: ""
type: epic
title: "Season preparation"
parent: initiative-gameble
covers: [CAP-2, CAP-3, CAP-6]
after: []
assignee: ""
risk: medium
estimate: ""
estimate_basis: ""
---

# Season preparation

## Description

The back-office path from a new import to a published season, safe and curated: an import builds its cards beside the current draft and replaces it only once the administrator validates it (or throws it away, with nothing broken), and the administrator classifies every Steam tag into the tome genres, with French and English labels, before publishing.

## Outcome

For the author: a new season prepared without risk, with tomes that make sense, before the season 2 import.

## Requirements

Completed at this epic's inception. The sources are the two stories below (author's decisions of 2026-10-06), CAP-2, CAP-3 and CAP-6 of the spec, and AD-4, AD-5, AD-18, AD-19 of the architecture, to amend first.

## Done when

1. An import builds its cards apart from the current draft; promoting it replaces the draft in one step; discarding it leaves the draft untouched.
2. After an import, every Steam tag met is listed with its game count and classified by the administrator (merged into a genre, its own genre, or ignored), with editable French and English genre labels.
3. A season cannot be published while a tag is unclassified; the preview shows the tome sizes from the current classification.
4. A published season's cards, tiers, numbers and tomes never change.

## Boundaries

`Steam` (import runs, tags, the tag-to-genre mapping), `Catalog` (draft, genres, publication), the back-office pages. Not the player screens.

## References

- parent — _bmad-output/initiative-gameble/initiative-gameble.md, section Requirements
- spec — _bmad-output/initiative-gameble/spec-gameble/catalog-and-rarity.md, sections Sets and Import
- architecture — _bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md, AD-4, AD-5, AD-18, AD-19

## Notes

- Decision (2026-10-06): the two backlog stories (import staging with rollback, genre curation) grouped in this epic by the author; not urgent, needed before the next season's import.
- Unknown: the back-office screens' design and the architecture amendments (staging draft, genre data, AD-18 exception); settled with the author before inception.
- Decision (2026-10-06, author): story 2.11's rules on abandoning a run that wrote cards, rescoring the previous run once a later one is abandoned, and refusing publication after a failed cards pass are to be replaced by story 1's staging with rollback.
