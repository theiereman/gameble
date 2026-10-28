---
title: 'A fresh machine follows the README'
type: 'chore'
ticket: '33'
created: '2026-10-28'
status: done
baseline_revision: 'd8997473ad6fef5f7c0160f1d755448a9a3dc2d8'
route: 'oneshot'
route_source: 'auto'
review: 'none'
review_source: 'auto'
lenses_ran: []
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The README and CONTRIBUTING were rewritten for a newcomer but never followed on a machine that has none of the project's tooling, so a missing prerequisite or a wrong command would only surface for a stranger.

**Approach:** Clone the repository fresh into an empty container, follow only the README (and the CONTRIBUTING it points to) to start Postgres, install, run the app and both test suites, and fix the documentation wherever a step fails or is missing. Then walk the epic's six Done when checks and tick them.

## Boundaries & Constraints

**Always:** Change documentation and `.env.example` only; every fix is the smallest text that makes the step work; all text in English.

**Never:** Change application code, tests or behaviour to make a step pass (a defect found there goes to `deferred-work.md`); use a step that is not in the README or CONTRIBUTING.

</frozen-after-approval>

## Implementation Notes

Oneshot: a documentation pass driven by one evidence run, under 100 lines of change. No documentation needed fixing. The container starts from a Ruby 4.0.7 image plus Node 24.15.0, the two toolchain prerequisites the README names; everything else must come from the README.

## Verification

**Commands:**
- `docker run` on a fresh clone: `docker compose up -d`, `npm install`, `bin/setup --skip-server`, `bin/rails test`, `npm run test:js`, `bin/dev` then `curl` the home page -- expected: all succeed with no step outside the README

**Manual checks (if no CLI):**
- Epic Done when 1 to 6, each walked once and recorded below.

## Run record

Clean clone of `develop` at d8997473 in a `ruby:4.0.7` container with Node 24.15.0 added, Postgres from the clone's `docker compose up -d` on the host, the app on port 3100 because 3000 was taken on the host. Only the README and CONTRIBUTING steps were used.

- `npm install`, `bin/setup --skip-server`: exit 0.
- `bin/rails test`: 3202 runs, 34559 assertions, 0 failures, 0 errors, 0 skips.
- `npm run test:js`: 71 files, 723 tests passed.
- `bin/dev`, then the home page: HTTP 200.

Done when of the epic:

1. [x] `bundle exec packwerk check` reports no offenses and the full suite is green.
2. [x] `script/check_planning_references` passes.
3. [x] `script/check_file_sizes` passes.
4. [x] `npm run format:check` and `npm run lint:css` pass; `bin/rails zeitwerk:check` passes.
5. [x] The README alone ran the app and both suites; the architecture overview, glossary, CONTRIBUTING, `.env.example` and the AGPL-3.0 `LICENSE` are present.
6. [x] No `192.168.` address or `/home/<user>` path in tracked app, config, db, lib, script, bin or .github files.

One surprise: `PixelArtExportTest` hung for 20 minutes on a `node script/pixel_art/export.mjs --check` that sat idle (futex wait) under eight parallel workers; killing that process let the suite finish green, and the same command run alone exits 0 in seconds. Recorded in `deferred-work.md`.

## Review Triage Log

No review lens ran: the change is this plan and a deferred-work entry, with no code or documentation diff.
