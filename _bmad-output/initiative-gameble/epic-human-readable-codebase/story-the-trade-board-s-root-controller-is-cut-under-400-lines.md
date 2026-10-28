---
id: 17
tracker_status: done
tracker_id: ""
type: story
title: "The trade board's root controller is cut under 400 lines"
parent: epic-human-readable-codebase
covers: [R3]
after: [epic-port-off-react]
hitl: false
risk: medium
---

# The trade board's root controller is cut under 400 lines

## Description

Runs on develop after epic 21 is merged. Cuts `app/frontend/controllers/trade_board_controller.ts` (544 lines) the same way, keeping the swap animation's classes and the `trade-board--editing` and `--swapping` classes.

## Acceptance Criteria

Verify: `npm run test:js`, `npm run typecheck` pass; each file is at most 400 lines; `bin/rails test test/system/trades_test.rb` passes unchanged.

## References

- parent — _bmad-output/initiative-gameble/epic-human-readable-codebase/epic-human-readable-codebase.md
