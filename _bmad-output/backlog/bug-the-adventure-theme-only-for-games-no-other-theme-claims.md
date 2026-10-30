---
id: bug-the-adventure-theme-only-for-games-no-other-theme-claims
type: bug
title: "The adventure theme only for games no other theme claims"
parent: none
covers: []
after: []
assignee: ""
refined: true
hitl: false
risk: low
severity: P3
estimate: ""
tracker_id: "#77"
---

# The adventure theme only for games no other theme claims

## Description

The fix of GitHub issue #77 (commit 5df828f, plan `bug-the-capsule-reveal-card-shows-no-game-category-plan.md`) made Adventure an ordinary theme. Adventure is heavily voted and would take the main theme from more specific themes (RPG, Puzzle, Horror) and grow one of the largest sets. The author (2026-10-19): Adventure stays a broad tag; the adventure theme ("Aventure" / "Adventure") becomes a fallback, given only to a game none of whose five most-voted tags belongs to another theme, and it then covers the tags Adventure, Action-Adventure, Story Rich and Female Protagonist. A game with none of these and no theme stays a UFO. The spec keeps Adventure among the broad tags and gains one sentence for the fallback theme. Published seasons stay unchanged.

## Acceptance Criteria

Verify: a game tagged Adventure and RPG gets RPG as main theme and is not in the adventure set; a game with Dreamfall's tags (Adventure, Female Protagonist, Story Rich, Fantasy, Sci-fi) gets the adventure theme as main theme; a game tagged only Story Rich and Indie gets it too; a game with only broad tags stays a UFO; the probe beside the #77 plan reports the UFO share and the adventure set's size for the latest season, recorded in the plan.

## References

- plan — _bmad-output/backlog/bug-the-capsule-reveal-card-shows-no-game-category-plan.md
- probe — _bmad-output/backlog/bug-the-capsule-reveal-card-shows-no-game-category-probe.rb
- spec — _bmad-output/initiative-gameble/spec-gameble/catalog-and-rarity.md, Themes

## Notes

- Filed on 2026-10-19 from the author's decisions on the day's builds.
- Dropped (2026-10-30, author): Adventure stays an ordinary theme; the fallback rule is not built.
