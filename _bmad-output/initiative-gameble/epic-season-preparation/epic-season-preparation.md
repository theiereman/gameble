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

The back-office path from a new import to a published season, safe and curated: an import builds its cards beside the current draft and replaces it only once the administrator validates it (or throws it away, with nothing broken), and the administrator curates the theme list from every Steam tag met, with French and English names, before publishing.

## Outcome

For the author: a new season prepared without risk, with themes that make sense, before the season 2 import.

## Requirements

Completed at this epic's inception. The sources are the two stories below (author's decisions of 2026-10-06), CAP-2, CAP-3 and CAP-6 of the spec, and AD-4, AD-5, AD-18, AD-19 of the architecture, to amend first.

## Done when

1. An import builds its cards apart from the current draft; promoting it replaces the draft in one step; discarding it leaves the draft untouched.
2. After an import, every Steam tag met is listed with its game count and classified by the administrator as a theme or not, with editable French and English theme names.
3. A season cannot be published while a tag is unclassified or while the UFOs exceed the agreed share; the preview shows the theme sizes and the UFOs' share from the current classification.
4. A published season's cards, tiers, numbers and sets never change.

## Boundaries

`Steam` (import runs, tags), `Catalog` (draft, the theme list, publication), the back-office pages. Not the player screens.

## References

- parent — _bmad-output/initiative-gameble/initiative-gameble.md, section Requirements
- spec — _bmad-output/initiative-gameble/spec-gameble/catalog-and-rarity.md, sections Sets and Import
- architecture — _bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md, AD-4, AD-5, AD-18, AD-19

## Notes

- Decision (2026-10-06): the two backlog stories (import staging with rollback, genre curation) grouped in this epic by the author; not urgent, needed before the next season's import.
- Unknown: the back-office screens' design and the architecture amendments (staging draft, genre data, AD-18 exception); settled with the author before inception.
- Decision (2026-10-06, author): story 2.11's rules on abandoning a run that wrote cards, rescoring the previous run once a later one is abandoned, and refusing publication after a failed cards pass are to be replaced by story 1's staging with rollback.
- Decision (2026-10-08, author): story 2 curates the theme list instead of tome genres (change-recognizable-sets); both rules hold before publishing: every tag classified, and the UFOs under the agreed share. Waits on epic-recognizable-sets for the theme list in code and the new set kinds.
- Decision (2026-10-08, author): the rarity is reworked again before the next season (story 3): popularity (the review count) decides almost alone, the rating only orders games of the same popularity; placed first, since every later import and publication uses it.
