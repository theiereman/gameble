---
title: 'Refactor sweep'
type: 'refactor'
ticket: '5'
created: '2026-10-28'
status: done
baseline_revision: '56a017f4'
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

**Problem:** The epic's build records and the review findings deferred during it leave small debts; none had been settled.

**Approach:** Every deferred finding found in the epic's plans and in `deferred-work.md` is fixed, recorded as left open on purpose, or dropped with a reason. Only cleanup: no behaviour, markup or copy changes.

</frozen-after-approval>

## Implementation Notes

Oneshot, written by an agent that was told not to run any test; the author runs the suites.

- Fixed: `CardBacksController` and `ProfileTitlesController` each carried an identical refusal responder (`back_refused`, `title_refused`: alert toast on turbo, redirect with alert on html, error body on json). It now lives once in `app/controllers/concerns/personalization_refusal.rb` as `personalization_refused`, included by both. Responses are unchanged.
- Deferred findings: none in `deferred-work.md` names a plan under epic-personalization. The card-backs spec-text item (CAP-20 "in the profile") already carries a `resolved:` line pointing at ticket 26.2, so no `resolved:` line was added.
- Left as is, no debt: the two Choose operations share a shape (lock the bank, upsert the state row, update, publish) but each is four lines with different columns and events; merging them would add indirection. The build records of the five stories list no open follow-up.
- File sizes: no file of this epic is near the limit.

## Verification

**Commands:**
- `bundle exec rubocop` on the three controller files -- clean
- Not run by this agent: `bin/ci`, `npm run test:js`, `bin/rails zeitwerk:check` (the new concern must autoload), the card back and title controller tests and system tests.
