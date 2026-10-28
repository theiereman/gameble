---
id: 3
tracker_status: done
tracker_id: ""
type: story
title: "The booster in Stimulus"
parent: epic-port-off-react
covers: [R3, R4, R5, R6]
after: [1, 2]
hitl: false
risk: high
---

# The booster in Stimulus

## Description

Replaces the booster island in one change with a server-rendered tree holding its three layouts and each card's faces per size as `<template>`s, its copy per AD-18 under `booster.strings`, a `booster` root controller driving `lib/booster.ts` and child controllers per region, using the trade board's conventions and the shared HTML helper from entry 1, then deletes the island's components.

## Acceptance Criteria

Verify: `test/system/booster_test.rb` passes unchanged except renamed locale scopes and its code-loading failure test, replaced by the no-JavaScript form test, and Vitest still covers every transition of `lib/booster.ts`.

## References

- parent — _bmad-output/initiative-gameble/epic-port-off-react/epic-port-off-react.md

## Notes

- Unknown: Whether the whole view swap fits one session; if not, it is split on a branch merged once, never React and Stimulus side by side on develop.
- The revealed-cards counter ("n / 5" on the booster) is not rebuilt: the author finds it useless (screen walkthrough, 2026-10-23); the Stimulus view omits it and its `booster.strings.revealedCount` copy.
