---
remote: https://github.com/theiereman/gameble/issues/82
tracker_id: 82
key: ""
type: epic
title: "The Brotherhood"
parent: initiative-gameble
covers: [CAP-12, CAP-13, CAP-17, CAP-19, CAP-26]
after: []
assignee: ""
status: done
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

- R1 (CAP-12; AD-9, AD-10, AD-13): the weekly gauge is the sum of per-player contributions (one booster opened = 1, one completed trade = 1 counted once), summed by a periodic job, shown on the hub with the target and broadcast about every 10 seconds; the week starts Monday 00:00 UTC; no row is written by every player.
- R2 (CAP-12): the target is the number of players active the previous week (at least one booster opened) times 50, never below 200; reaching it grants every contributor of the week one reward booster; missed and week-rollover states are shown.
- R3 (CAP-12; AD-7, AD-14): the reward booster holds 5 cards with at least one Épique or better, is a pack of kind `reward`, lives outside the cap of ten in its own zone, and is granted once per player and week by a per-player operation run by a job.
- R4 (CAP-13; AD-11, AD-13): the feed shows pulls of Épique or better, first discoveries, trades and reposts, readable signed out through `Game::Visibility`; with few players it falls back to lower rarities and is never empty; a signed-in player's Friends tab shows only friends' events.
- R5 (CAP-13, CAP-19): the LIVE ticker shows pulls of Épique or better, first discoveries and trades, never reposts; a player reposts any card they own, any number of times; reposts show in the feed only and disappear with a hidden or banned profile.
- R6 (CAP-17): ten achievements are granted when their condition is met and show on the SUCCÈS screen; the set-completed, goal-reward and achievement events are published for the card-backs epic.
- R7 (CAP-12, CAP-26; brotherhood-tone.md): the Brotherhood speaks in its institutional voice where the spec places it: the weekly goal's panel and reward notice, and a one-time welcome to each new player; players read capsule for pack and the Gameblers' name (Constraints, Player-facing words).

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
- Decision (2026-10-07): a completed trade counts 1 in the gauge, once for the two players.
- Decision (2026-10-07): the weekly target is the previous week's active players times 50, minimum 200; a constant tuned in play.
- Decision (2026-10-07): the reward booster has 5 cards with at least one Épique or better.
- Decision (2026-10-07): the week starts Monday 00:00 UTC.
- Decision (2026-10-07): the reward booster is outside the cap of ten, in a zone of its own, so it is never lost.
- Decision (2026-10-07): ten starting achievements: first booster, first Épique, first Légendaire, first complete set, first trade, 10, 100 and 500 boosters opened, three complete sets, first repost.
- Decision (2026-10-07): the ticker follows the spec only; set completions and hourly totals are added later if the feed looks empty.
- Decision (2026-10-07): reposts are not limited until measured in play.
- Not built here: card backs (epic 9, after the launch) consume the events this epic publishes.
- Decision (2026-10-08, author): set tier and set completion lines in the feed and the LIVE ticker are delivered by epic-recognizable-sets (13.6), which waits on 6.1, 6.2, 6.4 and 6.7; this epic's stories do not change.
