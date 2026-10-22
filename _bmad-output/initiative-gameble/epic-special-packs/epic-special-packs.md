---
remote: https://github.com/theiereman/gameble/issues/108
tracker_id: 108
key: ""
type: epic
title: "Special packs stand apart"
parent: initiative-gameble
covers: [CAP-4, CAP-5, CAP-12, CAP-16]
after: []
assignee: ""
risk: medium
estimate: ""
estimate_basis: ""
---

# Special packs stand apart

## Description

Every pack that is not a regular pack (today the daily bonus and the weekly goal reward) waits in its own reserve with no cap, counted apart on the hub, chosen apart on the capsule screen, drawn in its origin's colour, and opened after a short intro naming that origin. A player no longer opens a reward without noticing it. Asked for by a player in GitHub issue 49; the claim button the author asked for in the issue's comment is already built (6.17, the community pack claimed with a button).

## Outcome

A player who earns a reward or a daily bonus sees it waiting apart and opens it knowingly; the signal is that no special pack is opened from the regular reserve anymore.

## Requirements

- R1 (CAP-4, CAP-12, CAP-16; issue 49 point 1): every pack whose kind is not regular joins a special reserve with no cap; the regular reserve keeps its cap of 10 and its regeneration; claiming the daily bonus or a goal reward is never refused because a reserve is full.
- R2 (CAP-4; issue 49 point 1): the hub shows how many special packs wait, beside the regular count.
- R3 (CAP-5; issue 49 point 2): on the capsule screen the player switches between the regular and the special reserve; both open through the same reveal.
- R4 (CAP-5; issue 49 point 3): each kind of special pack has its own look by origin (the goal reward red, the daily bonus its own); a later kind adds its own.
- R5 (CAP-5; issue 49 point 4): opening a special pack plays a short intro naming its origin before the usual reveal, which is unchanged; reduced motion shortens it.

## Done when

1. A player holding 10 regular packs collects the daily bonus and a goal reward; both wait in the special reserve, and the regular reserve still refills to 10 at most.
2. The hub shows the regular and the special counts.
3. On the capsule screen the player switches to special packs and opens one through the usual reveal; opening a regular pack is unchanged.
4. A goal reward and a daily bonus look different from a regular pack and from each other, and each plays its intro before the reveal.
5. Shipped to production.

## Boundaries

The pack reserve in `packs/game`, the hub's pack counters and the top bar's packs chip, the capsule screen and its booster island, the pixel art export. Not new kinds of special packs, not the odds or contents of any pack, not the weekly goal or the daily bonus rules beyond the cap, not bank healing at a season's publication (it already counts regular packs only and redraws every kind).

## References

- parent — _bmad-output/initiative-gameble/initiative-gameble.md, section Requirements
- spec — _bmad-output/initiative-gameble/spec-gameble/spec-gameble.md, CAP-4, CAP-5, CAP-12, CAP-16
- architecture — _bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md, AD-7, AD-23
- source — https://github.com/theiereman/gameble/issues/49
- design — _bmad-output/initiative-gameble/ux-gameble/DESIGN.md and EXPERIENCE.md (Capsule, Hub, Opening protocol), updated by entry 1
- prior work — _bmad-output/initiative-gameble/epic-brotherhood/story-the-community-pack-is-claimed-with-a-button-plan.md

## Notes

- Decision (2026-10-15): a new epic (author).
- Decision (2026-10-15): with a special reserve without cap, claiming is never refused for a full reserve (author).
- Decision (2026-10-15): special means every pack that is not regular: the daily bonus and the goal reward today (author).
- Decision (2026-10-15): the look, counter, switch and intro are designed with bmad-ux before they are built (author); one design pass blocks entries 2 to 5, so it is its own hitl entry first rather than spread over each story.
- Source conflict: CAP-12 — the reward pack is "outside the bank's cap of 10 in its own zone" vs the built claim, refused while 10 packs of any kind are available. CAP-16 — the daily bonus "joins their bank" and its claim is disabled at 10 vs the decisions above. Entry 1 carries the spec update.
- Source conflict: AD-7 — `OpenPack` consumes the oldest available pack of any kind, the shown reserve counts every unopened pack of any kind, and the daily bonus fails with `reserve_full` vs R1 and R3. Entry 1 carries the architecture update.
- Decision (2026-10-15): until entry 3 adds the switch, opening keeps taking the oldest available pack of any kind and the capsule screen counts both reserves for its empty state, so a player holding only special packs can still open them (author).
- Decision (2026-10-15): tracer bullet is entry 2 (the special reserve, the hub and top bar counters); it does not cross the booster island, which entry 3 reaches. The least certain is entry 5 (the intro). Entries 3, 4 and 5 change the booster island in that order. Entry 3 waits on 13.5 and 13.15, which change the same island and the counts it reads, and on 17.1, which also changes the opening.
- Touch point: 13.7 also changes the hub's panel; a minor merge with entry 2, no order needed. Epic 9 (card backs, not yet incepted) touches the same island and the pixel art export; its inception orders against entries 3 to 5.
- Decision (2026-10-15): built after the public release (author).
- Waits on epic 12 because: built after the public release.
- Waits on epic 13 because: 13.5 and 13.15 change the booster island and the counts it reads.
- Waits on epic 17 because: 17.1 changes the opening operation entry 3 changes too.
- Waits on epic 21 because: 21.3 replaces the booster island that entries 3 to 5 change; until it lands the booster takes bug fixes only (architecture AD-31).
