---
id: 3
tracker_status: done
tracker_id: ""
type: story
title: "Two mechanical checks: planning references and file sizes"
parent: epic-human-readable-codebase
covers: [R2, R3]
after: [epic-port-off-react, epic-public-launch-readiness, epic-friends-and-trades, epic-brotherhood, epic-season-preparation, epic-recognizable-sets, epic-card-catalog, epic-easier-trades, epic-screen-walkthrough, epic-visitor-landing]
hitl: false
risk: low
---

# Two mechanical checks: planning references and file sizes

## Description

Adds `script/check_planning_references` (fails on any `AD-n`, `CAP-n`, `R-n`, `story n.n`, `epic n`, `DESIGN.md`, `EXPERIENCE.md` in `app`, `config`, `db`, `lib`, `script`, `test`, and `packs` while it exists, naming the offending lines) and `script/check_file_sizes` (Ruby and TypeScript over 400 lines, CSS over 500, tests and generated `db/schema.rb`, `db/queue_schema.rb` exempt), each taking the paths to scan as arguments (so a story can verify its own directories) and with a test under `test/script` that plants offenders in a temporary directory; `*.test.ts` and `.mjs` files are outside the size limits; both are runnable and print the current offenders but are not yet in CI, which entry 29 does once they pass.

## Acceptance Criteria

Verify: Run on the current tree, the two scripts exit non-zero and list the planning reference lines and the over-limit TypeScript and CSS files; their tests plant one offender each.

## References

- parent — _bmad-output/initiative-gameble/epic-human-readable-codebase/epic-human-readable-codebase.md
