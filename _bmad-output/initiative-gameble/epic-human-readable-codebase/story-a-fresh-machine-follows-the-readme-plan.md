---
title: 'A fresh machine follows the README'
type: 'chore'
ticket: '33'
created: '2026-10-28'
status: 'in-progress'
baseline_revision: 'd8997473ad6fef5f7c0160f1d755448a9a3dc2d8'
route: 'oneshot'
route_source: 'auto'
review: ''
review_source: ''
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

Oneshot: a documentation pass driven by one evidence run, under 100 lines of change. The container starts from a Ruby 4.0.7 image plus Node 24.15.0, the two toolchain prerequisites the README names; everything else must come from the README.

## Verification

**Commands:**
- `docker run` on a fresh clone: `docker compose up -d`, `npm install`, `bin/setup --skip-server`, `bin/rails test`, `npm run test:js`, `bin/dev` then `curl` the home page -- expected: all succeed with no step outside the README

**Manual checks (if no CLI):**
- Epic Done when 1 to 6, each walked once and recorded below.
