---
id: 18
tracker_status: done
tracker_id: 286
remote: https://github.com/theiereman/gameble/issues/286
type: story
title: "The booster and trade board front end reads without comments"
parent: epic-human-readable-codebase
covers: [R2]
after: [3, 16, 17]
hitl: false
risk: low
---

# The booster and trade board front end reads without comments

## Description

Runs on develop after epic 21 is merged. Removes planning references and name-restating comments from the booster and trade board files left by entries 14 to 17 and their lib modules (`booster_motion.ts` has 96 comment lines).

## Acceptance Criteria

Verify: `script/check_planning_references` reports nothing under those files; `npm run test:js`, `typecheck`, `bin/rails test test/system/booster_test.rb test/system/trades_test.rb` pass.

## References

- parent — _bmad-output/initiative-gameble/epic-human-readable-codebase/epic-human-readable-codebase.md
