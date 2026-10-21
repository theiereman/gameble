---
title: 'An import builds beside the draft and replaces it only once validated'
type: 'feature'
ticket: '1'
created: '2026-10-21'
status: 'built'
baseline_revision: 'b8027876a054eb41e276b9a2d2fc73ab161c1ad5'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** An import writes the draft season's cards directly, page by page, then prunes them; a failed or bad run leaves a mixed draft, and the only way back is to run again.

**Approach:** The cards pass writes each card-season's scores into a staged batch of its own, owned by `Catalog`; the administrator reviews the finished run on its page (gap with the draft, rarity spread, preview) and promotes it to replace the draft's card-seasons in one transaction, or discards it. The games' identity (texts, publisher, image) keeps refreshing in place.

## Boundaries & Constraints

**Always:**
- Only card-season values (score, score version, rating, review count) are staged; `Catalog::UpsertDraftCard` keeps upserting identity in place.
- A failed or discarded run leaves the draft exactly as it was; promotion replaces the draft entirely in one transaction and the promoted draft can still be published.
- One finished run waits for promotion at a time: a new import cannot start, and the season cannot be published, until it is promoted or discarded.
- Rescore writes a new staged batch from the stored Steam data, reviewed and promoted like an import, and is refused while a batch waits; it never edits the draft in place.
- A failed run keeps its staged rows so a resume continues; abandoning it discards them. The rule refusing to abandon a run that wrote cards goes, since a failed run no longer touches the draft.
- The draft promotion is refused when the season the run began on was published since (the batch is then stale and is discarded).
- Writes go through operations that each publish one event; the staging table is owned by `Catalog`, never read from `Steam`'s tables by `Catalog`; every string in `en.yml` and `fr.yml`; expand/contract migrations.

**Never:**
- No merge of staged cards into a draft that has manual removals; no change to published seasons, theme classification or publication rules.
- No new menu entry: the review lives on the import run's page.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Run completes | Cards pass ends | Run waits for promotion; draft untouched | No error |
| Promote | Waiting run, draft season still the same | Draft card-seasons replaced in one step; run marked promoted | Season published meanwhile: refused as stale |
| Discard | Waiting or failed run | Staged rows deleted; draft untouched | None |
| New import | A run waits | Refused with the reason | `:run_awaiting_promotion` |
| Publish | A run waits | Refused: promote or discard first | Flash |
| Rescore | Latest run completed or promoted, none waiting | New staged batch to review | Refused while one waits |

</frozen-after-approval>

## Code Map

- `packs/steam/app/operations/steam/import_cards_page.rb` -- only writer of cards; switch card-season writes to staging, prune becomes staging completion
- `packs/catalog/app/operations/catalog/upsert_draft_card.rb` -- keep identity upsert; split out the card-season part into a staged write
- `packs/catalog/app/operations/catalog/prune_draft.rb`, `publish_season.rb` -- prune moves into promotion; publish refused while a run waits
- `packs/catalog/app/queries/catalog/{draft_preview,season_rows,score_panel,season_scores}.rb` -- `SeasonRows::Row` is the seam: preview and gap read staged rows
- `packs/steam/app/operations/steam/{start_import,complete_import,fail_import,abandon_import,rescore_cards,resume_import}.rb` -- new waiting state, new refusals, rescore re-stages
- `packs/steam/app/models/steam/import_run.rb`, `steam_import_runs` -- new `ready` and `promoted` statuses; partial unique index on `ready`
- `app/controllers/back_office/{import_runs,seasons}_controller.rb`, `app/views/back_office/import_runs/show.html.erb`, `import_runs_policy.rb`, `config/routes.rb` -- review panel, promote and discard actions, publish gate
- `config/locales/{en,fr}.yml`, `test/packs/{catalog,steam}/`, `test/controllers/back_office/`, `architecture-gameble.md` (AD-5, AD-19) -- strings, tests, architecture amendment first

## Tasks & Acceptance

**Execution:**
- [ ] `_bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md` -- amend AD-5 and AD-19 for staged batches and promotion -- the epic requires it first
- [ ] `db/migrate/*` and `db/schema.rb` -- staged card-seasons table keyed by batch token; run status check widened expand/contract; partial unique index on `ready`; regenerate schema as CI does
- [ ] `packs/catalog/app/operations/catalog/` -- `StageCardSeason`, `PromoteStagedBatch`, `DiscardStagedBatch`; events each -- one operation, one event
- [ ] `packs/catalog/app/queries/catalog/` -- staged rows, gap with the draft, rarity spread -- the review panel's reads
- [ ] `packs/steam/app/operations/steam/` -- staged cards pass, waiting state, refusals, rescore re-staging, abandon discards -- run lifecycle
- [ ] `app/controllers`, views, policy, routes, locales -- review panel with PROMOUVOIR and JETER -- the administrator's step
- [ ] `test/` -- failed and discarded runs leave the draft untouched, promotion in one step and publishable, one waiting run, stale promotion, rescore, policies -- every matrix row

**Acceptance Criteria:**
- Given a failed or discarded run, when the draft is read, then it equals its state before the run.
- Given a completed run, when the administrator promotes it, then the draft holds exactly its cards, and the season can be published.
- Given a waiting run, when an import or a publish is attempted, then each is refused with its reason.

## Implementation Notes

## Plan Change Log

## Review Triage Log

## Design Notes

Staging lives in `Catalog` (rows keyed by a batch token the run passes in) so `Catalog` never reads `Steam`'s tables and promotion stays one `Catalog` operation. The deferred-work check on the prestige formula is stale: the import and rescore already use `Steam::PrestigeScore` (current version) through `Steam::CardMapping`.

## Verification

**Commands:**
- `bin/rails test test/packs/catalog test/packs/steam test/controllers/back_office test/policies/back_office` -- expected: passes
- `bundle exec packwerk check` and `bin/rails zeitwerk:check` -- expected: clean
- `bin/ci` -- expected: passes
