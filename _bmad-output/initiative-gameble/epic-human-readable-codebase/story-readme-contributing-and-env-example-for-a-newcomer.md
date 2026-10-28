---
id: 31
tracker_status: done
tracker_id: ""
type: story
title: "README, CONTRIBUTING and .env.example for a newcomer"
parent: epic-human-readable-codebase
covers: [R6, R7]
after: [26, 29, 30]
hitl: false
risk: low
---

# README, CONTRIBUTING and .env.example for a newcomer

## Description

Rewrites `README.md` as a quick summary anyone arriving on the repository reads fast: what gameble is, its architecture only at the surface, setup on Postgres 18 at port 5433, running and tests in a few lines, the AGPL-3.0 licence, and links to `CONTRIBUTING.md`, `RELEASING.md`, `docs/architecture.md`, `docs/glossary.md`, `docs/operations.md` and `docs/reporting-problems.md`. Rewrites `CONTRIBUTING.md` first of all as a guide for developers: setup pointers, workflow, tests, conventions, architecture detail and how to read the codebase. Adds `.env.example` listing the environment variables the code reads (27 at survey time).

## Acceptance Criteria

Verify: A reader finds setup, run and test commands in the README alone and the README is at most 150 lines, names AGPL-3.0 and `LICENSE` is present; `CONTRIBUTING.md` has no player-facing bug-report content; every variable read through `ENV` in `app config lib script` appears in `.env.example` (a script compares the two lists); every relative link in `README.md` and `CONTRIBUTING.md` resolves.

## References

- parent — _bmad-output/initiative-gameble/epic-human-readable-codebase/epic-human-readable-codebase.md
