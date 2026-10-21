---
id: 1
tracker_status: in-progress
tracker_id: 186
remote: https://github.com/theiereman/gameble/issues/186
type: story
title: "An import builds beside the draft and replaces it only once validated"
parent: epic-season-preparation
covers: [CAP-2, CAP-3]
after: [2.12]
hitl: true
risk: high
---

# An import builds beside the draft and replaces it only once validated

## Description

An import run writes its cards into a staging draft of its own; an administrator reviews it and promotes it to replace the draft, or throws it away, so a failed or bad run never leaves a mixed draft.

## Acceptance Criteria

Verify: A run that fails or is discarded leaves the current draft exactly as it was; promoting a completed run replaces the draft in one step; a promoted draft can still be published.

## References

- parent — _bmad-output/initiative-gameble/epic-season-preparation/epic-season-preparation.md

## Notes

- il faut pouvoir rollback et donc faire un import à côté en attendant de le valider ou qqch dans le genre
- vérifier que l'import utilise bien la nouvelle formule (2026-10-08 ; voir deferred-work.md)
