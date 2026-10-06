---
title: 'First real import and calibration'
type: 'feature'
ticket: '8'
created: '2026-10-02'
status: done
baseline_revision: 'd69b583c21c4dd3534028fd2eb6b075357427fe4'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
context: ['{project-root}/_bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md', '{project-root}/_bmad-output/initiative-gameble/spec-gameble/catalog-and-rarity.md', '{project-root}/_bmad-output/initiative-gameble/epic-steam-catalog/story-publish-a-season-with-its-tiers-plan.md', '{project-root}/_bmad-output/initiative-gameble/epic-steam-catalog/story-sets-of-the-season-plan.md', '{project-root}/_bmad-output/initiative-gameble/epic-steam-catalog/story-prestige-score-and-cards-in-the-draft-season-plan.md']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The prestige formula, the tier shares and the tome size were chosen without real data; before season 1 is published the author must see what they produce on the real catalog, and recomputing the scores after a formula change would cost a whole new import (epic 2, Done when 3–5; the open question on the prestige formula).

**Approach:** Add a calibration preview of the draft season to the back-office seasons page — what publishing it now would produce — and a way to re-run only the `cards` step of the latest completed import, so the author can run the first real import on the test server, read the preview, adjust the constants in code, rescore, and publish. Starts once story 2.7 is committed. The build ends at `built`; ticket 8 stays open until the author has done the hitl part (`pending-approvals.md`) and written its results in the epic Notes.

## Boundaries & Constraints

**Always:**
- `Catalog::DraftPreview.call` reads the draft without a lock and returns nil without a draft, an `empty_season` verdict for a draft with no card-season, or: card count; prestige percentiles p10, p50, p90, p99 by nearest rank (`ranked_asc[ceil(p × N / 100) − 1]`, integer arithmetic), min and max, shown to 3 decimals; projected tier sizes and each tier's threshold from `RarityThresholds` (the cut `PublishSeason` uses), or the `empty_tier` verdict replacing only that block; the share of cards per dust level (`Dust.level_for` at today's UTC date); the ten highest and ten lowest cards by `prestige_score` (ties by `card_id`) with their English title and rating; cards per first genre (raw keys, e.g. `free_to_play`, and `none`) with projected tomes per genre; projected set counts per kind from `SetBuilder`'s public methods. It uses `Catalog::SeasonRows` (story 2.7) plus one query for the twenty titles: two queries in all, at any size (tested with `assert_queries_count` on 15,000 seeded rows). No Steam term in `Catalog`: "rating", never "reviews".
- The seasons page shows the preview as its own section after the seasons table, headed with the draft's number, with the publish form moved below it, also while an import is unfinished (with the existing notice); administrators only; copy in `fr` and `en`, no `catalog.genres.*` keys; numbers carry `data-preview-{tier,threshold,percentile,dust,top,bottom,genre,set-kind}` attributes.
- `Steam::RescoreCards.new.call(import_run_id:)` reopens the latest completed run on its `cards` step with cursor 0 and enqueues it (refused when the run is not the latest, not completed, or another run is unfinished; one event), so a formula change rewrites the draft's scores without refetching Steam; the run page offers it on the latest completed run, administrators only. Changing `SHARES` or `SetBuilder::TOME_SIZE` needs no rescore: the preview reflects them on the next page load.
- The README gains "Calibrating a season": where the import runs (the test server after `bin/kamal deploy`; constants changed there need a redeploy), reading the preview, which constant to change (`Steam::PrestigeScore`, `Catalog::RarityThresholds::SHARES`, `Catalog::SetBuilder::TOME_SIZE`), rescoring after a formula change, publishing.

**Never:** no constants editable from the browser; no publication from the preview; no real Steam call in tests; no change to `PublishSeason`'s results.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Preview | story 2.7's 150-card draft (`distinct_scores(150)`, scores 1–150) | tiers 2/6/15/37/90 with thresholds 149/143/128/91; p10 15, p50 75, p90 135, p99 149, min 1, max 150; sets 1/4/3; genres action 75 → 3 tomes, rpg 44 → 1, none 31 | — |
| Too small | draft of 20 cards | `empty_tier` verdict in the tier block; the rest shown | — |
| Empty draft | draft without card-season | `empty_season` verdict, no numbers | — |
| Ties | ranks 10 and 11 share a score | the lower card id is in the top ten | — |
| No draft | only published seasons | no preview section | — |
| Queries | 15,000 seeded rows | exactly 2 queries | — |
| Consistency | the 150-card draft, then publish | published tier sizes and set counts equal the preview's | — |
| Rescore | latest run completed; formula stubbed differently | run back on `cards`, completed again; draft scores changed; no Steam call | refused if not latest, not completed, or another run unfinished |
| Not admin | visitor / player / moderator | as the seasons and import-runs policies | policy |

</frozen-after-approval>

## Code Map

- `packs/catalog/app/queries/catalog/season_rows.rb`, `app/models/catalog/{set_builder,rarity_thresholds,dust}.rb` (2.6, 2.7) -- the rows and pure rules to reuse.
- `packs/catalog/app/queries/catalog/season_summaries.rb`, `app/controllers/back_office/seasons_controller.rb`, `app/views/back_office/seasons/index.html.erb` -- the page; existing button tests may move with the form.
- `packs/steam/app/operations/steam/{resume_import,finish_import_step}.rb`, `app/models/steam/import_run.rb` (`cursor_for`), `app/queries/steam/unfinished_import_run.rb` -- golden examples for `RescoreCards`.
- `app/controllers/back_office/import_runs_controller.rb`, `app/policies/back_office/import_runs_policy.rb`, `app/views/back_office/import_runs/show.html.erb`.
- `test/support/catalog_seeds.rb` -- titles and the 150-card layout from 2.7.

## Tasks & Acceptance

**Execution:**
- [x] `packs/catalog/app/queries/catalog/draft_preview.rb`; seasons page section and locales.
- [x] `packs/steam/app/operations/steam/rescore_cards.rb` and its event; route, policy, run-page button, locales.
- [x] `README.md` -- "Calibrating a season".
- [x] `test/` -- every matrix row.

**Acceptance Criteria:**
- Given story 2.7's 150-card draft, when an administrator opens the seasons page, then the preview shows 2/6/15/37/90 per tier with their thresholds, 1/4/3 sets per kind and the ten highest-scored cards, and publishing then produces the same tier sizes and set counts.
- Given `bin/rails test`, `bundle exec packwerk check`, `bin/rubocop` and `bundle exec i18n-tasks missing`, when run, then all pass.

## Implementation Notes

- Two queries: `DraftPreview` passes `Season.draft.select(:id)` to `SeasonRows.call` (which now takes an id or a relation selecting one), so the draft is read inside the rows query; the second query loads the English titles of the top and bottom ten. Only when the rows are empty does a second query (`Season.draft.exists?`) tell an empty draft (`empty_season`) from no draft (nil). The section heading takes the draft's number from `SeasonSummaries`. `DraftPreview.call(on:)` defaults to today's UTC date (tests pass it).
- `Preview` fields: `verdict`, `card_count`, `percentiles` (`{ 10, 50, 90, 99 }`), `min`, `max`, `tier_verdict`, `tiers` (`Tier(tier, card_count, threshold)`, gold first, steel's threshold nil), `dust` (count per level, shown as a share), `top`/`bottom` (`Entry(card_id, title, rating, prestige_score)`), `genres` (`Genre(genre, card_count, tome_count)`, most cards first, nil genre last and shown as `none`), `set_counts`. Verdict copy reuses `errors.catalog.{empty_season,empty_tier}`.
- The page: the preview (`app/views/back_office/seasons/_preview.html.erb`, keys `back_office.seasons.preview.*`) follows the seasons table; the publish form moved below it. "With the existing notice" was read as: while `Steam::UnfinishedImportRun` returns a run, the page shows the existing `back_office.seasons.publish.import_active` text above the publish form (the publish itself is still refused by the controller, unchanged).
- `Steam::RescoreCards` codes: `not_found`, `not_latest`, `not_completed`, `run_in_progress` (another run pending or running; an older failed run does not block, as it does not block publishing either). It resets `cards_written`/`cards_refused` to 0 so the counts describe the rescore, keeps the errors, and publishes `Steam::CardsRescoreStarted` (`{ import_run_id: }`). New query `Steam::LatestImportRun`. The run page shows "Rescore the cards" (with a Turbo confirmation) outside the polled frame, on the latest completed run only.

## Plan Change Log

## Review Triage Log

### Pass 1 (quick) — high 1, medium 0, low 4, false 0, maybe-false 0

| # | Verdict | Route | Finding | Evidence / action |
|---|---|---|---|---|
| 1 | high | patch | After publication the run is still the latest completed one, so a rescore re-upserted every card into a new draft season, breaking "a run never spans two seasons" | Confirmed (`UpsertDraftCard` opens a draft when none). `RescoreCards.refusal` adds `already_published` (no draft, or a season published at or after the run finished); the button uses the same guard; tests. |
| 2 | low | patch | Step durations measured from events are wrong after a rescore | README: record durations before rescoring; `CardsRescoreStarted` marks the boundary. |
| 3 | low | patch | A rescore refused for an unfinished run showed start/resume copy | Own message key; tested. |
| 4 | low | rejected | The rescore button reappears only on a full reload | Cosmetic; the run page is reloaded after a calibration anyway. |
| 5 | low | rejected | A genre literally named `none` shares the "no genre" row | Steam genre keys never produce `none`; the row is read by the author during calibration. |


## Verification

**Commands:**
- `bin/rails test` -- expected: all green.
- `bundle exec packwerk check && bin/rubocop && bundle exec i18n-tasks missing` -- expected: no offence.

**Manual checks (if no CLI):**
- hitl, after approval (`pending-approvals.md`), on the test server: run a full import; record each step's duration from the `Steam::ImportStepFinished` event timestamps (time spent failed noted apart), the catalog size and the tier sizes in the epic Notes; check `Steam::App.ready_by(run).where("review_count < 500 OR image_url IS NULL").count == 0` and that no draft card lacks an `en` or `fr` title; read the preview (first-genre distribution against the Indie risk), adjust the constants, rescore if the formula changed, publish season 1. Ticket 8's verify: "Season 1 is published with every card carrying a rarity, a release date, French and English text and its sets, no card under 500 reviews or without a vertical image, and the measured duration and tier sizes recorded in the epic's Notes."
