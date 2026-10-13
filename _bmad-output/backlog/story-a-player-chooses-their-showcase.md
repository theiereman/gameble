---
id: story-a-player-chooses-their-showcase
type: story
title: "A player chooses the cards of their showcase"
parent: none
covers: []
after: []
assignee: ""
refined: false
hitl: true
risk: medium
estimate: ""
---

# A player chooses the cards of their showcase

## Description

A player picks the three cards their friends and visitors see in their showcase, instead of the three highest tiers they hold in the published season (`Game::ShowcaseCards` today).

## Acceptance Criteria

Verify: a player chooses three cards from their collection and their friends see exactly those three on their profile; before any choice the showcase falls back to today's highest tiers; a chosen card the player no longer holds leaves the showcase and the fallback fills its place.

## References

- source — _bmad-output/initiative-gameble/pending-approvals.md, settled 2026-10-13 (A friend's showcase, story 5.10)
- ux — _bmad-output/initiative-gameble/ux-gameble/ (to design first)

## Notes

- Decision (author, 2026-10-13): a backlog ticket, designed in UX first (where the choice is made, the default before any choice, a chosen card that leaves the collection).
- Open question: where the player chooses (profile and settings, the collection, the card detail).
