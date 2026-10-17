---
title: 'A season is never published with cards scored by two prestige formulas'
type: 'bugfix'
ticket: 'bug-a-season-is-never-published-with-cards-scored-by-two-prestig'
created: '2026-10-09'
status: 'done'
baseline_revision: 'a3230dcdfb0565a540d1b9c76abe84b81129ebc7'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** On staging, the deploy that changed `Steam::PrestigeScore` landed in the middle of an import's cards step, so season 2 was published with 3,400 of its 12,329 card-seasons on the old scale (≤ ~1.04) and the rest on the new one (5–10). The percentile cut put every old-scale card in common, RimWorld included. Nothing stopped that publication.

**Approach:** Stamp every card-season with the version of the formula that scored it, and make `Catalog::PublishSeason` refuse a draft whose card-seasons carry more than one version, with a message telling the administrator to rescore the latest import. The calibration preview shows the same verdict before the button is pressed.

## Boundaries & Constraints

**Always:** Catalog stays source-neutral: the version is an opaque positive integer the caller passes to `Catalog::UpsertDraftCard`; only Steam knows what it means. Every writer of `UpsertDraftCard` passes it (required keyword). A card-season with no version (written before this change) counts as a version of its own, so null mixed with any version is refused; a draft entirely null still publishes. The column is added nullable, no default, in its own migration; `db/schema.rb` regenerated, never hand-edited. Both `en.yml` and `fr.yml` get the new `errors.catalog.<code>` key by hand.

**Never:** Touch a published season's card-seasons (no backfill of the column, no republication of season 2). No change to the formula, the tier shares or the draw odds. No NOT NULL contract step in this change.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Uniform draft | every draft card-season has version 2 | publishes as today | No error expected |
| Legacy draft | every draft card-season has version null | publishes as today | No error expected |
| Mixed draft | versions {null, 2} or {1, 2} | nothing written, season stays draft | `Failure(:mixed_score_versions)`, back-office alert with the localized message |
| Preview of a mixed draft | same | preview shows the mixed-versions verdict | tiers still shown, so the admin sees the skew |
| Bad version | `prestige_score_version:` 0, -1, 1.5, "2", nil | card not written | `Failure(:invalid_card)` |
| Rescore after mix | rescore pass completes on the latest run | every draft card-season rewritten with the current version | publication then succeeds |

</frozen-after-approval>

## Code Map

- `packs/steam/app/models/steam/prestige_score.rb` -- add `VERSION = 2` (the formula in this file; the one it replaced is 1). A future formula change bumps it.
- `packs/steam/app/models/steam/card_mapping.rb` -- add `prestige_score_version: PrestigeScore::VERSION` next to `prestige_score:` in the mapped hash.
- `packs/catalog/app/operations/catalog/upsert_draft_card.rb` -- new required keyword `prestige_score_version:`; validate it in `validate_scores` (an `Integer`, ≥ 1) and carry it in the `scores` hash, which `upsert_card_season` already writes on create and update. Update the header example.
- `packs/catalog/app/queries/catalog/season_rows.rb` -- add `prestige_score_version` to `Row` and the pluck; both `PublishSeason` and `DraftPreview` read rows from here.
- `packs/catalog/app/operations/catalog/publish_season.rb` -- new step after `rows_of`, before `cut`: more than one distinct `prestige_score_version` among rows (nil distinct) → `Failure(:mixed_score_versions)`. Add the code to the header's Failure list. `failure_message` already resolves `errors.catalog.<code>`.
- `packs/catalog/app/queries/catalog/draft_preview.rb` -- add a `score_version_verdict` field (`:mixed_score_versions` or nil) to `Preview`, from the same rule; extract the rule once (e.g. a `Catalog::ScoreVersions.mixed?(rows)` or a class method on `PublishSeason`) so both read one definition.
- `app/views/back_office/seasons/_preview.html.erb` -- when the verdict is set, a `PanelComponent` with `<span data-preview-verdict="mixed_score_versions">` and `Catalog::PublishSeason.failure_message(:mixed_score_versions)`, above the tiers table, same pattern as `empty_tier`.
- `config/locales/en.yml`, `config/locales/fr.yml` -- `errors.catalog.mixed_score_versions`, in the officer voice next to `empty_tier`, naming the "Rescore the cards" / "Recalculer les cartes" button.
- `db/migrate/<ts>_add_prestige_score_version_to_catalog_card_seasons.rb` -- `add_column :catalog_card_seasons, :prestige_score_version, :integer, limit: 2` (nullable).
- `db/seeds.rb` -- its `UpsertDraftCard` call passes `prestige_score_version: Steam::PrestigeScore::VERSION` (or 2 if seeds avoid Steam).
- Tests to extend: `test/packs/catalog/upsert_draft_card_test.rb`, `publish_season_test.rb`, `draft_preview_test.rb`, `test/packs/steam/cards_test.rb`, `test/packs/steam/rescore_cards_test.rb` (rescore stamps the current version), `test/controllers/back_office/seasons_controller_test.rb`. Every existing `UpsertDraftCard` call in tests gains the keyword. `test/support/catalog_seeds.rb` and `test/fixtures/catalog/card_seasons.yml` insert rows directly and may stay null.
- Do not change: `RarityThresholds`, `Rarity`, `RescoreCards` logic, `PruneDraft`, `game_benchmark.rake` (writes rows directly).

## Tasks & Acceptance

**Execution:**
- [ ] `db/migrate/…_add_prestige_score_version_to_catalog_card_seasons.rb` -- add the nullable column -- record which formula scored each card-season
- [ ] `packs/steam/app/models/steam/prestige_score.rb`, `packs/steam/app/models/steam/card_mapping.rb` -- expose and pass the version -- Steam owns its meaning
- [ ] `packs/catalog/app/operations/catalog/upsert_draft_card.rb` -- require, validate, store -- every draft card-season is stamped
- [ ] `packs/catalog/app/queries/catalog/season_rows.rb`, `publish_season.rb`, `draft_preview.rb` -- one mixed-versions rule, refused at publish, shown in the preview -- the guard
- [ ] `app/views/back_office/seasons/_preview.html.erb`, `config/locales/en.yml`, `config/locales/fr.yml` -- verdict and message -- the admin knows to rescore
- [ ] `db/seeds.rb` and every test calling `UpsertDraftCard` -- pass the keyword -- required keyword
- [ ] tests listed in the Code Map -- cover each matrix row, the preview verdict, and the publish alert on the seasons page -- regression guard
- [ ] `db/schema.rb` -- regenerate with `RAILS_ENV=test bin/rails db:drop db:create db:migrate`
- [ ] `_bmad-output/initiative-gameble/spec-gameble/catalog-and-rarity.md` -- one line under Rarity: a season's cards are all scored by one formula; a draft that mixes them is not published until rescored

**Acceptance Criteria:**
- Given a draft mixing versions, when the administrator opens the seasons page, then the preview shows the mixed-versions message, and pressing publish leaves the season a draft with the same message as alert.
- Given that draft, when the latest import is rescored and its pass completes, then publication succeeds.

## Design Notes

The guard sits in `PublishSeason`, not in the import, because the mix comes from code changing under a running import, which the import cannot see. Reading the versions from `SeasonRows` costs no extra query: publication already plucks every row.

## Verification

**Commands:**
- `bin/rails test test/packs/catalog test/packs/steam test/controllers/back_office` -- expected: green
- `bin/rails test` and `bin/rails test:system test/system` for the back-office season screens touched -- expected: green
- `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `bundle exec i18n-tasks health`, `bin/rubocop` -- expected: clean
- `git diff --stat db/schema.rb` -- expected: only the new column

## Implementation Notes

- Implemented in worktree `.claude/worktrees/agent-aa105026df711a2ff` (another session was editing the main checkout); the implementer stopped before committing when the machine crashed, and the orchestrator verified and finished from the files on disk.
- The mixed-versions rule lives once in `Catalog::ScoreVersions.mixed?(rows)`, read by `PublishSeason` and `DraftPreview`.
- `prestige_score_version` joined `CardSeason::SEASON_DATA`, so it freezes with the season like the score.
- `UpsertDraftCard` accepts versions 1..32,767 (smallint column).
- Verified: migration on a fresh test DB gives the same `db/schema.rb` (one column); `bin/rails test` 1,898 runs, 0 failures; packwerk, zeitwerk, rubocop clean; `i18n-tasks health` reports the same inconsistent interpolation (`back_office.seasons.index.confirm.one`) and normalization as the baseline, nothing new. No system test covers the back-office seasons screen; the controller test covers the preview verdict and the publish alert.

## Plan Change Log

- 2026-10-09, after the fact: the cause stated in the intent was wrong. No deploy landed during the import. Two containers deployed on 2026-10-06 without `-d staging` (`gameble-web-d5227c7…`, `gameble-import-d5227c7…`) were still running the old formula against the staging database and took pages of the `import` queue. Every staging import since was partly written by them; a rescore was right only when the current worker took every page. Those old workers do not know `prestige_score_version`, so an update by them kept version 2 beside an old-scale score and the guard could not see the mix. The author stopped both containers; import run 4 then wrote all 12,336 cards of draft season 3 on the new scale (3.32 to 10.40) without a rescore. The README now says to always name the destination.

## Review Triage Log

Pass 1 (quick lens): 0 high, 0 medium, 3 low, 0 false, 0 maybe-false.

| Finding | Verdict | Route | Evidence |
|---|---|---|---|
| `errors.catalog.mixed_score_versions` says "two formulas" while `ScoreVersions.mixed?` fires on any count above one | low | patch | Real: a draft holding {nil, 1, 2} trips it. Patched: "more than one prestige formula" / "plusieurs formules de prestige"; affected tests rerun green. |
| No system test covers the back-office seasons screen, so the publish alert is checked only at request level | low | rejected | Real, but no system test exists for that screen and the controller test asserts the preview verdict, the alert and the untouched draft; a new system test is added complexity for a rarely met gap. |
| `prestige_score_version` has no model validation or DB check, unlike `prestige_score`, `rating`, `number` | low | rejected | Real inconsistency; the only production writer (`UpsertDraftCard`) validates 1..32,767; a check needs an add/validate migration pair, added complexity for a writer that does not exist. |
