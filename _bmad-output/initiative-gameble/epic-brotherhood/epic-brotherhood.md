---
tracker_id: ""
key: ""
type: epic
title: "The Brotherhood"
parent: initiative-gameble
covers: [CAP-12, CAP-13, CAP-17, CAP-19]
after: []
assignee: ""
risk: medium
estimate: ""
estimate_basis: ""
---

# The Brotherhood

## Description

The community becomes visible: a weekly shared goal fed by pack openings and trades, a public live feed of notable pulls, first discoveries, trades and players' reposts, with a Friends tab, and simple achievements.

## Outcome

For every player: the feeling of playing alongside others, and a reason to contribute each week.

## Requirements

Completed at this epic's inception. The source lines are CAP-12, CAP-13, CAP-17 and CAP-19 of the spec.

## Done when

1. The weekly gauge rises as players open packs and trade; when the goal is reached, every contributor receives a rare pack.
2. The feed shows notable pulls, first discoveries, trades and reposts as they happen, and is readable without an account; a signed-in player's Friends tab shows only their friends' pulls, trades and reposts.
3. A player reposts any card they own to the feed; reposting a card they do not own is refused.
4. With few players, the feed falls back to lower-rarity events and is never empty while any activity exists.
5. An achievement is granted when its condition is met and shows as earned on the achievements screen.
6. No single database row is written by every player.

## Boundaries

Event handlers, the weekly goal, the feed, achievements and their broadcasts. Not the fee-fed Brotherhood Pass (V3).

## References

- parent — _bmad-output/initiative-gameble/initiative-gameble.md, section Requirements
- spec — _bmad-output/initiative-gameble/spec-gameble/spec-gameble.md, section Capabilities
- architecture — _bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md, AD-9, AD-10, AD-13
- design — _bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md, sections Component Patterns, State Patterns

## Notes

- Open question: the list of achievements (spec).
- Open question: how much a trade counts in the weekly goal, and the odds of the rare pack (spec).
- Unknown: the weekly target formula (spine, Deferred).
- The 2026-10-05 redesign: only the weekly goal carries a Brotherhood line (`brotherhood-tone.md`); `DESIGN.md` and `EXPERIENCE.md` do not cover the repost action or the Friends tab yet. Card backs (CAP-20) have their own epic after this one (epic-card-backs); this epic publishes the events they unlock on (Game::SetCompleted, goal rewards, achievements).
