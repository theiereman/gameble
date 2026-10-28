---
id: 27
tracker_status: done
tracker_id: ""
type: story
title: "Prettier and Stylelint on the front end"
parent: epic-human-readable-codebase
covers: [R5]
after: [18, 19, 20, 21, 22, 23, 24]
hitl: false
risk: medium
---

# Prettier and Stylelint on the front end

## Description

Runs on develop after epic 21 is merged. Adds Prettier (TypeScript, CSS, JSON) and Stylelint with configs and npm scripts, formats the whole front end in one mechanical commit with no logic change, and fixes the Stylelint findings or records a short list of relaxed rules in the config.

## Acceptance Criteria

Verify: `npx prettier --check app/frontend` and `npx stylelint 'app/frontend/**/*.css'` exit 0; `npm run test:js`, `typecheck` pass; `script/compare_css_cascade` shows no difference once cosmetic spelling is normalized; `script/check_file_sizes` stays clean.

## References

- parent — _bmad-output/initiative-gameble/epic-human-readable-codebase/epic-human-readable-codebase.md
