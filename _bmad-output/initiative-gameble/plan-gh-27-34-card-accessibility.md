---
title: 'Accessible visitor invitations and card links'
type: 'bugfix'
ticket: ''
created: '2026-10-14'
status: 'built'
baseline_revision: '30b630953109893329ff6078aa022dde3991cbc5'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The visitor invitation on a card detail repeats its visible sentence in an aria-label, and linked card faces omit the release year from their accessible names.

**Approach:** Reference the invitation paragraph with aria-labelledby and give the invitation its own CSS block. Include the year between title and rarity in English and French card link names. Keep labels short without adding the optional theme. Preserve visual appearance. The user requested both issues with Luna subagents and explicit approval before any commit.

</frozen-after-approval>

## Implementation Notes

Small mechanical accessibility changes use the oneshot route, with implementation delegated to Luna agents as requested. The existing initiative-gameble folder supplies the planning context. The first agent owns the invitation view, matching CSS, and invitation controller tests. The second owns the helper, locale keys, and linked-face assertions. Catalog release dates are required, so no speculative unknown-year fallback is needed. AGENTS.md disables system test execution; existing assertions may be maintained without running that suite.

Implemented the invitation block and paragraph reference without changing CSS declarations. Card labels now include the year in both locales; existing assertions were updated and bilingual helper coverage added. The user confirmed Rails tests will run in CI. No commit or push was made.

## Plan Change Log

## Review Triage Log

The Luna quick reviewer reported no findings. Parent tightened the invitation selector to explicitly reject aria-label on the section itself and added a collection-grid label assertion. No deferred findings.

## Verification

- `npm install` before Rails tests.
- `docker compose up -d` for Postgres 18 on port 5433.
- `bin/rails test` should pass, including invitation markup and English/French labels.
- `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `npm run test:js`, Ruby lint and translation checks should pass.
- Inspect generated invitation naming and card link labels; CSS declarations must remain unchanged.

**Results:** 277 JavaScript tests passed; TypeScript and git diff whitespace checks passed. Rails tests are delegated to CI by user instruction. Browser accessibility and visual checks were not run locally. Dependency installation artifacts in lockfiles were reverted.
