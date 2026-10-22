---
title: 'Module 06 shows the roadmap'
type: 'feature'
ticket: '11'
created: '2026-10-22'
status: 'built'
baseline_revision: '6550584e5b04c17003d8c7fd0a3eb3de080cac64'
route: 'full'
route_source: 'auto'
review: 'none'
review_source: 'pinned'
lenses_ran: []
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/initiative-gameble/ux-gameble/DESIGN.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Module 06 of the landing shows only its legend; the roadmap staff curate in the database is not displayed.

**Approach:** Module 06 shows the milestones staff chose to show, at most six, each with its first two shown stories, in the wording of the locale and with the status written in text; six in a row on a desktop, three per row at medium widths, one sideways-scrolling row on a phone that is a single tab stop while it overflows.

## Boundaries & Constraints

**Always:**
- Only shown milestones and shown stories, in staff order; each data block cached per locale.
- Every status (milestone and story) is text, never only a marker.
- The link to the full roadmap page belongs to the roadmap page ticket.

**Never:**
- No `h3` in the module (the landing's heading outline is fixed).

</frozen-after-approval>

## Code Map

- `packs/catalog/app/queries/catalog/landing_roadmap.rb` (new) -- the shown milestones and stories of a locale, cached
- `app/controllers/landings_controller.rb`, `app/views/landings/show.html.erb`, `app/views/landings/_roadmap.html.erb` -- load and render the line
- `app/frontend/controllers/overflow_focus_controller.ts`, `app/frontend/lib/overflow_focus.ts` -- the row is a tab stop only while it overflows
- `app/frontend/styles/landing.css`, `tokens.css` -- the progress line, three layouts
- `config/locales/{en,fr}.yml` -- `landings.show.roadmap.line_label`
- `test/controllers/landings_controller_test.rb`, `test/system/landing_roadmap_test.rb`, `app/frontend/lib/overflow_focus.test.ts`

## Tasks & Acceptance

**Execution:**
- [x] Query, controller, view, styles, controller, locales
- [x] Controller, system and vitest tests

**Acceptance Criteria:**
- Given shown milestones and stories, when a visitor opens the landing in either language, then module 06 lists them in the staff's wording with Fait, En cours or À venir (Done, In progress, To come).
- Given a phone, when the row overflows, then it is one tab stop and the arrow keys scroll it.

## Implementation Notes

The per-locale cache has a ten-minute lifetime, like the sample cards; a stale roadmap is accepted.

## Plan Change Log

## Review Triage Log

## Design Notes

## Verification

**Commands:**
- `bin/rails test test/controllers/landings_controller_test.rb`, `bin/rails test test/system/landing_roadmap_test.rb`, `npm run test:js`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bundle exec i18n-tasks missing` -- expected: clean
