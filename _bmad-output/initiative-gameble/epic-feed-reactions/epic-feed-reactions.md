---
tracker_id: ""
key: ""
type: epic
title: "Reactions on the feed"
parent: initiative-gameble
covers: []
after: []
assignee: ""
risk: medium
estimate: ""
estimate_basis: ""
status: done
---

# Reactions on the feed

## Description

Players react to the entries of the activity feed with one of five pixel icons: a thumb, a heart, GG, wow and a middle finger. Each entry shows a counter per reaction; nobody sees who reacted, not even the player an entry is about.

## Outcome

For the players: the feed answers back. A player can react to what others pull, discover or trade, and sees how the community reacted, without any name attached.

## Requirements

No capability of the spec: author request of 2026-11-02, release 1.1.0.

## Done when

1. A signed-in player reacts to a visible feed entry with one of five fixed reactions, changes it or removes it; one reaction per player per entry.
2. Every entry shows a counter per reaction, for visitors too; no name or list of reactors is shown anywhere.
3. The reaction and the counters update in place, without a reload and keeping the scroll, and counters stay current through the live feed.
4. Reactions follow the feed's visibility (a hidden, banned or private player's entry takes no reaction and a banned player's reactions do not count), are erased with an account, and appear in the data export and in the privacy and retention pages.

## Boundaries

The five reactions are fixed; no free emoji, no comments, no notification, no reaction outside the feed.

## References

- parent — _bmad-output/initiative-gameble/initiative-gameble.md

## Notes

- Decision (2026-11-02, author): fixed set of five (thumb, heart, GG, wow, middle finger); counters only, no name visible to anyone.
