---
id: 15
tracker_status: done
tracker_id: 283
remote: https://github.com/theiereman/gameble/issues/283
type: story
title: "The booster's root controller: opening sequences and rendering leave it"
parent: epic-human-readable-codebase
covers: [R3]
after: [14]
hitl: false
risk: high
---

# The booster's root controller: opening sequences and rendering leave it

## Description

Runs on develop after epic 21 is merged. First half of cutting `app/frontend/controllers/booster_controller.ts` (1,322 lines): moves the opening sequences (`retract`, `blowAndDeal`, `fadeAndDeal`, `openBooster`, the countdown and bank refresh) and the render region (`render` through `renderCelebrations`, about 300 lines) into modules under `app/frontend/lib` and, where a region owns DOM, child controllers talking by dispatch and outlets (the anatomy AGENTS.md prescribes), without changing the markup, `data-*` names, events or timings. The reveal, store and celebration sequences stay for entry 16.

## Acceptance Criteria

Verify: `npm run test:js`, `npm run typecheck`, `script/check_markup_apis` pass; the moved regions each fit within 400 lines; `bin/rails test test/system/booster_test.rb` passes unchanged.

## References

- parent — _bmad-output/initiative-gameble/epic-human-readable-codebase/epic-human-readable-codebase.md
