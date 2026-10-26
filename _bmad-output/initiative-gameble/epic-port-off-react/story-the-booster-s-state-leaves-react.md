---
id: 2
tracker_status: review
tracker_id: 228
remote: https://github.com/theiereman/gameble/issues/228
type: story
title: "The booster's state leaves React"
parent: epic-port-off-react
covers: [R2, R6]
after: [1]
hitl: false
risk: medium
---

# The booster's state leaves React

## Description

Moves the booster's state and transitions (opening, reveal, store, layout, celebration, bank refresh, navigation lock) out of `Booster.tsx` into the DOM-free `app/frontend/lib/booster.ts`, shaped like the trade board's module from entry 1, leaving React a thin view that drives it so that the next entry replaces only the view, and adds the system tests the swap needs as its net (the desktop celebration) while React still draws.

## Acceptance Criteria

Verify: `test/system/booster_test.rb` passes unchanged with the added tests, and Vitest covers every transition of `lib/booster.ts`.

## References

- parent — _bmad-output/initiative-gameble/epic-port-off-react/epic-port-off-react.md
