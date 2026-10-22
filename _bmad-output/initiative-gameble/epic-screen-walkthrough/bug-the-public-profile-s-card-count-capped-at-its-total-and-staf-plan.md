---
title: "The public profile's card count capped at its total, and staff see a banned player's line again"
type: 'bugfix'
ticket: 9
created: '2026-10-22'
status: 'built'
baseline_revision: 'd30be8384935e7671fac9473ac6323dbfc2a0ab5'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: []
deferred:
  - summary: >-
      The owner's library page shows the same over-total pair without a cap.
    evidence: |-
      load_summary in collection_grid_loading.rb sums HeldGames.by_rarity against Catalog::CardCount; outside the ticket's named figure.
    location: >-
      app/controllers/concerns/collection_grid_loading.rb:152
    severity: low
---

<intent-contract>

## Intent

**Problem:** The public profile's CARTES figure counts games held in any edition over the published season's total, so it can read above its total. Staff on a banned player's profile no longer see that the player is banned.

**Approach:** Cap the figure at the total in the controller, without a new query. Add a banned line to the identity band's meta row; only staff reach a banned owner's profile, so the line shows whenever the owner is banned.

</intent-contract>

## Implementation Notes

Oneshot: a few lines in one controller, one partial, two locale files and one test file.

## Verification

**Commands:**
- `bin/rails test test/controllers/public_profiles_controller_test.rb` -- expected: pass
- `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `bundle exec i18n-tasks health` -- expected: pass

## Review Triage Log

### 2026-10-22 — Review pass
- verdicts: 3 findings — high 0, medium 0, low 1, false 1, maybe-false 0
- findings:
  - `[medium]` `[patch]` package-lock.json name rewritten by npm install — reverted, not committed
  - `[low]` `[defer]` library page shows the same uncapped pair — outside the ticket's named figure
  - `[false]` `[reject]` cap adds a query — the card count query already ran; no query added

## Auto Run Result

Capped the profile's CARTES at the season total in the controller and added a banned line (staff only reach a banned profile) in the identity band, English and French, with three controller tests. Verification: public profiles controller tests 52 runs pass, zeitwerk and packwerk pass; i18n-tasks health reports only a pre-existing interpolation inconsistency on back_office.seasons.index.confirm.one.
