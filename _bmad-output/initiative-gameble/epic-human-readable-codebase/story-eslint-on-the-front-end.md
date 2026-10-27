---
id: 28
tracker_status: dropped
tracker_id: 296
remote: https://github.com/theiereman/gameble/issues/296
type: story
title: "ESLint on the front end"
parent: epic-human-readable-codebase
covers: [R5]
after: [27]
hitl: false
risk: medium
---

# ESLint on the front end

## Description

Runs on develop after epic 21 is merged. Adds ESLint (flat config, typescript-eslint) and its npm script and fixes or consciously disables each finding with a reason in the config, not in the code.

## Acceptance Criteria

Verify: `npx eslint app/frontend` exits 0; `npm run test:js`, `typecheck` and the markup-API check pass.

## References

- parent — _bmad-output/initiative-gameble/epic-human-readable-codebase/epic-human-readable-codebase.md
