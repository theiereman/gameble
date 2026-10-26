---
id: 32
tracker_status: review
tracker_id: 260
remote: https://github.com/theiereman/gameble/issues/260
type: story
title: "A feed entry is rebuilt for balance and legible parts"
parent: epic-screen-walkthrough
after: [31]
hitl: true
risk: medium
---

# A feed entry is rebuilt for balance and legible parts

## Description

A line of the activity feed (`app/views/feeds/_entry.html.erb`, also rendered by the landing's LIVE module and the hub's ticker) is badly balanced: the player, the game, the sentence, the date and the rarity are not told apart, and the card it shows is too large for the line (author, 2026-10-23, on staging). Redesign the entry from the design rules: with the author, set a clear hierarchy (who, what, which game, when), give the player's name and the game's name their own treatments distinct from the plain text, a timestamp in a quiet place, and size the card so it supports the line without taking it over; the same entry serves the feed, the landing and the hub, so each context's size is checked; reduced motion, the visitor's read-only view and the entries' kinds (draws, discoveries, trades, reposts, tiers and completions) all keep working; EXPERIENCE.md's Fil d'activité row and DESIGN.md follow.

## Acceptance Criteria

Verify: Every kind of feed entry on the desktop and the phone, in French and in English, tells the player, the game, the text and the date apart with a card sized to the line, in the feed, in the landing's LIVE module and in the hub's ticker, as the author approves on staging; the feed and landing system tests (retrying matchers) and the full suite pass.

## References

- parent — _bmad-output/initiative-gameble/epic-screen-walkthrough/epic-screen-walkthrough.md

## Notes

- Found in the screen walkthrough (ticket 16.1, finding 25), author, 2026-10-23: a rework within the design rules, not a restyle of colours only.
