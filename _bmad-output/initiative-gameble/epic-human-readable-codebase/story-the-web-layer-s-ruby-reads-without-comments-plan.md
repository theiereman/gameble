---
title: 'The web layer''s Ruby reads without comments'
type: 'refactor'
ticket: 8
created: '2026-10-27'
status: 'ready-for-dev'
baseline_revision: '18466900cf365e4353f63ae82117f209c30cd405'
route: 'full'
route_source: 'auto'
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** `app/controllers`, `helpers`, `policies`, `components`, `jobs`, `models` and the ERB views carry about 780 comment lines and 48 planning-id lines that narrate the code or cite documents a reader does not have.

**Approach:** Delete the narrating comments; keep a one-line comment only where an external constraint is not visible in the code; where a deleted comment held intent, let a name or an extracted method hold it. No behaviour or markup change.

## Boundaries & Constraints

**Always:** `script/check_planning_references` clean on the scoped directories; rendered HTML unchanged; rubocop and the controller, component, helper, policy suites green.

**Never:** touch `packs/`, `app/frontend`, tests, markup; add planning ids; write multi-line comments.

</intent-contract>

## Code Map

- `app/controllers` (+ `concerns`, `back_office`), `app/helpers`, `app/policies`, `app/components`, `app/jobs`, `app/models`, `app/views/**/*.erb` -- comment lines to delete.

## Tasks & Acceptance

**Execution:**
- [ ] `app/**/*.rb` in the scoped directories -- delete full-line comments, keep external-constraint one-liners
- [ ] `app/views/**/*.erb` -- delete `<%# %>` comment tags
- [ ] same files -- rename or extract where a deleted comment carried a non-obvious rule

**Acceptance Criteria:**
- Given the scoped directories, when `script/check_planning_references` runs, then it reports nothing.
- Given the suites, when they run, then they pass and HTML is unchanged.

## Implementation Notes

Mechanical across ~160 files; route full for the review of what the comments said.

## Plan Change Log

## Review Triage Log

## Verification

**Commands:**
- `script/check_planning_references app/controllers app/helpers app/policies app/components app/jobs app/channels app/models app/views` -- expected: exit 0
- `bin/rubocop` -- expected: no offenses
