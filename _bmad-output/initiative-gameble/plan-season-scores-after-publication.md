---
title: 'Any season''s prestige scores can be read in the back-office, published or not'
type: 'feature'
ticket: ''
created: '2026-10-09'
status: 'built'
baseline_revision: '4b05ce7e1f05164758e066752e00fafb17fddd55'
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

**Problem:** The seasons page shows the prestige score panel (percentiles, tiers with their lowest score, ten highest and lowest cards, genres, sets) only for the draft. Once a season is published, an administrator can no longer read how it was scored and cut, although every score, version, rating and rarity is kept on its card-seasons. The staging incident (season 2 published with two score scales) could only be read from the console.

**Approach:** A read-only page per season, `/<locale>/back-office/seasons/<number>`, linked from each row of the seasons table, shows the same panel. For a published season, tiers come from the rarities stored at publication and sets from the stored sets, never from a new cut. The page also states which formula versions scored the season.

## Boundaries & Constraints

**Always:** GET only, no write, no migration. Administrators only, same as the seasons list (Pundit `show?`); a moderator gets 403, a visitor or player the back-office 404. The season is found by its number (`\d+` constraint), never a database id; an unknown number is a 404. One panel partial serves the draft preview on the list and both kinds of season on the new page. Every new string in `en.yml` and `fr.yml`.

**Never:** Recompute a published season's tiers with `RarityThresholds`. Change the draft preview's numbers, the publish button or `PublishSeason`. Add a link from the published season to the player-facing screens.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Published season | number of a published season | card count, percentiles, min/max, each tier's stored count and lowest stored score (common: no threshold), top/bottom 10, genres with tome counts from stored tome sets, set counts from stored sets, versions present | No error expected |
| Season scored before versions | every card-season version nil | versions line says none was recorded | No error expected |
| Mixed versions published | versions {nil, 2} | versions line lists both | No error expected |
| Draft | number of the draft | same panel as the list's preview (cut computed now), including the mixed-versions verdict; no publish button here | No error expected |
| Empty draft | draft with no card-season | empty_season verdict | No error expected |
| Unknown number | `/back-office/seasons/99` or non-numeric | 404 | routing / not found |

</frozen-after-approval>

## Code Map

- `packs/catalog/app/queries/catalog/draft_preview.rb` -- builds `Preview` from `SeasonRows`; split so the shared part (percentiles, extremes with titles, genres, set counts) takes rows plus tiers, tome counts and set counts; `DraftPreview.call` keeps its exact output.
- `packs/catalog/app/queries/catalog/season_rows.rb` -- rows of any season; reuse unchanged (`Row` has no rarity: published tiers read `CardSeason.where(season_id:).group(:rarity)` with `minimum(:prestige_score)`, or add a query beside it).
- `packs/catalog/app/queries/catalog/season_summaries.rb` -- pattern for stored tier and set counts (`CardSeason.rarities`, `Set.kinds`).
- `packs/catalog/app/models/catalog/set.rb` -- `kind` enum; tome sets carry `params["genre"]`.
- `app/controllers/back_office/seasons_controller.rb`, `app/policies/back_office/seasons_policy.rb` -- add `show` / `show?`.
- `config/routes.rb` (~line 115) -- `resources :seasons, only: %i[index show], param: :number` with a `\d+` constraint; keep `post :publish, on: :collection`.
- `app/views/back_office/seasons/index.html.erb` -- number cell links to the season page.
- `app/views/back_office/seasons/_preview.html.erb` -- the panel; its heading/intro are the draft's ("si elle était publiée maintenant"): pass heading and intro in, or move them to the callers.
- `config/locales/{en,fr}.yml` `back_office.seasons` (~fr line 388) -- new `show` keys.
- Tests: `test/packs/catalog/draft_preview_test.rb` (must stay green unchanged), `test/controllers/back_office/seasons_controller_test.rb` (access tests at lines 279–323 to extend), `test/support/catalog_seeds.rb` (`seed_sets_draft`).

## Tasks & Acceptance

**Execution:**
- [x] `packs/catalog/app/queries/catalog/` -- a query returning the panel for one season by number (nil when none): draft through the existing rule, published from stored rarities and sets; plus `score_versions` (sorted, nil kept) -- one reading of a season for both states
- [x] `packs/catalog/app/queries/catalog/draft_preview.rb` -- extract the shared builder, output unchanged -- no second copy of the panel's maths
- [x] `config/routes.rb`, `app/controllers/back_office/seasons_controller.rb`, `app/policies/back_office/seasons_policy.rb` -- `show` by number, administrators only, 404 on unknown -- the page
- [x] `app/views/back_office/seasons/show.html.erb`, `_preview.html.erb`, `index.html.erb` -- season heading with status and publication date, versions line, the panel; link from the list -- reachable and readable
- [x] `config/locales/en.yml`, `config/locales/fr.yml` -- show page strings, French officer voice like the rest of the back-office
- [x] `test/packs/catalog/` -- cover each matrix row on the query, notably that a published season's tiers equal its stored rarities even when a new cut would differ
- [x] `test/controllers/back_office/seasons_controller_test.rb` -- show for published and draft, link from the list, 403 moderator, 404 visitor/player/unknown number

**Acceptance Criteria:**
- Given seasons 1 to 3 published, when an administrator opens the list and follows season 2, then the page shows that season's stored tier counts, which match the list's row.
- Given a published season, when its page is loaded, then nothing is written (the GET runs on the reading role).

## Design Notes

Published tiers: count and `minimum(:prestige_score)` per stored rarity, legendary first, common's threshold nil, so the table reads like the draft's. Tome count per genre: stored `tome` sets grouped by `params->>'genre'`.

## Verification

**Commands:**
- `bin/rails test test/packs/catalog test/controllers/back_office` -- expected: green
- `bin/rails test` -- expected: green
- `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `bundle exec i18n-tasks health`, `bin/rubocop` -- expected: clean (i18n-tasks: no new issue against baseline)

## Implementation Notes

- The panel's maths moved to `Catalog::ScorePanel` (`packs/catalog/app/queries/catalog/score_panel.rb`): `build(rows, tiers:, tome_counts:, set_counts:, score_version_verdict:)` and `empty_season`; it owns `Panel`/`Tier`/`Entry`/`Genre`, `PERCENTILES` and `EXTREMES`. `DraftPreview.call` keeps its output and its two queries (an empty draft included); `DraftPreview.of(rows)` is the draft's cut for any rows. `draft_preview_test.rb` is unchanged and green.
- `Catalog::SeasonScores.call(number)` (`season_scores.rb`) returns `Scores(number, status, published_at, score_versions, panel)` or nil. Draft: `DraftPreview.of(rows)`. Published: tiers from one grouped pluck of stored rarity, `COUNT(*)`, `MIN(prestige_score)` (common's threshold nil, a missing rarity shows 0); sets from one `Set` count grouped by kind and `params ->> 'genre'`, giving both the set counts and the tome count per genre. A published season costs 5 queries (season, rows, tiers, sets, titles).
- A published season's panel never carries `score_version_verdict` or `tier_verdict`: their messages speak of publishing the draft. Mixed versions show on the versions line instead (`none recorded (scored before versions), version 2`), with `data-season-score-versions="none 2"`.
- Route: `resources :seasons, only: %i[index show], param: :number, constraints: { number: /\d+/ }`; the constraint lands on the show route only, so `GET /seasons/publish` and `/seasons/abc` are routing 404s and `POST /seasons/publish` is unchanged. An unknown number raises `RecordNotFound` after `authorize`, so only an administrator learns a number is unknown.
- The `_preview` partial now takes `panel:`, `heading:` and `intro:`; the list passes the draft's existing heading and intro, the show page passes them for a draft and new `show.published_heading`/`published_intro` for a published season. The `data-preview*` hooks are kept so the list's tests stay unchanged; the section's DOM id became `score-panel`. The hidden scores caption now says "of the season" instead of "of the draft" (en and fr).
- Policy test: `show?` moved from the "nothing else" list to the administrator-only actions.
- Known limit: a published season's genre card counts and its top/bottom titles read the cards' current first genre and English title, not a snapshot from publication (no such snapshot is stored); the intro says the genres are today's.
- Verification (isolated DB `gameble_test_wseasons`): `bin/rails test` 2147 runs, 0 failures; `bin/rails test:system` 175 runs, 0 failures; `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `bin/rubocop` clean; `bundle exec i18n-tasks health`: no missing or unused keys; its inconsistent interpolation (`fr back_office.seasons.index.confirm.one`) and normalization report (also listing the untouched pagy files) predate this change.

- After review: the genre table also lists each stored tome's genre that no card of the season now leads with, at 0 cards, so its tomes add up to the Sets table. The comments added or rewritten by this change were removed, except the `DraftPreview` header (rewritten only to drop planning ids) and the field list above `ScorePanel::Panel` (moved from `DraftPreview::Preview`).

## Plan Change Log

## Review Triage Log

Pass 1 (quick lens): 0 high, 0 medium, 2 low, 0 false, 0 maybe-false.

| Finding | Verdict | Route | Evidence |
|---|---|---|---|
| A published season's stored tome drops out of the genre table once no card of the season leads with its genre | low | patch | Real: `ScorePanel.genres_of` groups the rows by their live first genre and reads `tome_counts` only for those, while `set_counts["tome"]` counts every stored tome; imports refresh the shared cards' genres. Patched: genres from `tome_counts` with no leading card are listed with 0 cards; test added. |
| New and rewritten comments break the AGENTS.md rule to comment only external constraints | low | patch | Real: none of the added comments states an external constraint. Patched: the comments the diff added or rewrote were deleted. |
