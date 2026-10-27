---
id: 19
tracker_status: done
tracker_id: 287
remote: https://github.com/theiereman/gameble/issues/287
type: story
title: "The rest of the front end's TypeScript reads without comments"
parent: epic-human-readable-codebase
covers: [R2]
after: [epic-port-off-react, 3]
hitl: false
risk: low
---

# The rest of the front end's TypeScript reads without comments

## Description

Runs on develop after epic 21 is merged. Same cleanup for every other `app/frontend/lib` and `app/frontend/controllers` file (37 reference lines in all, 911 comment lines; led by `tilt.ts` 58, `history_trail.ts` 47, `card_art/worker_job.ts` 35, `history_back_controller.ts` 34, `sub_view_controller.ts` 31); the booster and trade board files are entry 18's.

## Acceptance Criteria

Verify: `script/check_planning_references` reports nothing under `app/frontend` TypeScript; `npm run test:js` and `typecheck` pass.

## References

- parent — _bmad-output/initiative-gameble/epic-human-readable-codebase/epic-human-readable-codebase.md
