---
id: 14
tracker_status: done
tracker_id: ""
type: story
title: "The booster's state module is cut under 400 lines"
parent: epic-human-readable-codebase
covers: [R3]
after: [epic-port-off-react]
hitl: false
risk: medium
---

# The booster's state module is cut under 400 lines

## Description

Runs on develop after epic 21 is merged. Splits `app/frontend/lib/booster.ts` (602 lines) and its 869-line test into cohesive modules (for example the opening exchange, the reveal sequence, the layout and tray rules) with unchanged exports used by the controllers.

## Acceptance Criteria

Verify: `npm run test:js`, `npm run typecheck` pass; each new file is at most 400 lines; the booster system tests (`bin/rails test test/system/booster_test.rb`) pass.

## References

- parent — _bmad-output/initiative-gameble/epic-human-readable-codebase/epic-human-readable-codebase.md
