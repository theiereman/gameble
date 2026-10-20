---
id: 7
tracker_status: dropped
tracker_id: 215
remote: https://github.com/theiereman/gameble/issues/215
type: story
title: "A visitor's collection entry suggests sets to discover"
parent: epic-card-catalog
covers: [R4]
after: [5]
hitl: false
risk: low
---

# A visitor's collection entry suggests sets to discover

## Description

On the collection entry (/library), a signed-out visitor sees a section "À DÉCOUVRIR" ("TO DISCOVER") in place of EN COURS and its empty line "Aucun set en cours pour l'instant…": a few popular sets of the published season (Catalog::PopularSets or its equivalent), as set rows with their name and kind only, no count, bar or tier (as 14.5 shows a visitor's search rows), each opening its album. A signed-in player keeps EN COURS and its empty line; a public profile is unchanged. Copy in French and English.

## Acceptance Criteria

Verify: Signed out, in fr and en, /library shows À DÉCOUVRIR with popular sets and no progress, each leading to its album, and no EN COURS; signed in, EN COURS and its empty line are unchanged; no database id; the full suite, vitest, packwerk, rubocop and typecheck pass.

## References

- parent — _bmad-output/initiative-gameble/epic-card-catalog/epic-card-catalog.md

## Notes

- Decision (author, 2026-10-20): replace the visitor's empty EN COURS line with a list of sets to discover. À DÉCOUVRIR existed for every player until 13.18 removed it (epic-recognizable-sets); its earlier build is in git history.
