---
id: 1
type: story
title: "An import builds beside the draft and replaces it only once validated"
parent: none
covers: [CAP-2, CAP-3]
after: []
assignee: ""
refined: false
hitl: true
risk: high
estimate: ""
---

# An import builds beside the draft and replaces it only once validated

## Description

An import run writes its cards into a staging draft of its own instead of the season's draft; an administrator reviews it and promotes it to replace the draft, or throws it away, so a failed or bad run never leaves a mixed draft and can always be rolled back.

## Acceptance Criteria

Verify: a run that fails or is discarded leaves the current draft exactly as it was; promoting a completed run replaces the draft in one step; a promoted draft can still be published as today.

## References

- spec — _bmad-output/initiative-gameble/spec-gameble/catalog-and-rarity.md, section Import
- architecture — _bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md, AD-5, AD-19 (to amend first through bmad-architecture)
- plan — _bmad-output/initiative-gameble/epic-steam-catalog/story-import-hardening-before-season-1-plan.md, the rules it supersedes

## Notes

- The author: "il faut pouvoir rollback et donc faire un import à côté en attendant de le valider ou qqch dans le genre" (2026-10-05).
- Supersedes story 2.11's rule that a run which wrote cards cannot be abandoned, and the edge cases tied to it.
- hitl: the design (where the staging lives, how validation looks in the back-office) is settled with the author before the build.
