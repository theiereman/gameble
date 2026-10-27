---
id: 26
tracker_status: done
tracker_id: 294
remote: https://github.com/theiereman/gameble/issues/294
type: story
title: "The operations runbook and the player bug-report guide get their own files"
parent: epic-human-readable-codebase
covers: [R6]
after: [2, 25]
hitl: false
risk: low
---

# The operations runbook and the player bug-report guide get their own files

## Description

Moves the operations material now bloating `README.md` (deployment, Discord announcement, Sentry, staffing, retention, backups, job queue, Steam import, calibration; lines 42 to 268) into `docs/operations.md`, and the player-facing bug-report and idea guide out of `CONTRIBUTING.md` into `docs/reporting-problems.md`, with its links updated; the text is moved, not rewritten, apart from fixing links and headings; README and CONTRIBUTING keep a one-line pointer each until entry 31 rewrites them.

## Acceptance Criteria

Verify: `docs/operations.md` and `docs/reporting-problems.md` exist and hold the moved sections; no operations section remains in `README.md` beyond a pointer; every relative link in the three files and in `RELEASING.md` resolves.

## References

- parent — _bmad-output/initiative-gameble/epic-human-readable-codebase/epic-human-readable-codebase.md
