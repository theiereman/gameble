---
tracker_id: ""
key: ""
type: epic
title: "Unlimited feed"
parent: initiative-gameble
covers: []
after: []
assignee: ""
risk: low
estimate: ""
estimate_basis: ""
status: done
---

# Unlimited feed

## Description

The feed shows the 30 latest notable entries (10 at least, padded with pulls) and stops there. A player who wants to read further back cannot. The feed pages without end: older entries load as the player reaches the bottom.

## Outcome

For the players: the feed can be read as far back as it goes, with no cap on the visible records.

## Requirements

No capability of the spec: an author request of 2026-11-02, release 1.1.0.

## Done when

1. The feed page loads older entries on demand, with no upper bound, in the same order and with the same visibility rules as today.
2. The live feed keeps adding new entries at the top without breaking the pagination.

## Boundaries

The feed only. No change to which entries are notable or visible, and no change to the live broadcast.

## References

- parent — _bmad-output/initiative-gameble/initiative-gameble.md

## Notes

- Decision (2026-11-02, author): unlimited pagination instead of a cap on the visible records, in release 1.1.0.
