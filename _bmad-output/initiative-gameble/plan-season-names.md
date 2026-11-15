---
title: 'Name each published season in French and English'
type: 'feature'
ticket: ''
created: '2026-11-15'
status: 'built'
baseline_revision: '4505ac530e82caca0bc3d8c59e9f7105a3a2cb5d'
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

**Problem:** Every season shows the fixed label "Grand catalogue" on the capsule screen and the landing page; the author cannot give a season its own name.

**Approach:** A season carries a French and an English name, typed by the administrator in the publish form and renamable afterwards from the season's back-office page; the current season's name, in the reader's locale, replaces "Grand catalogue" everywhere it shows, and a season without a name keeps "Grand catalogue".

## Boundaries & Constraints

**Always:** Both names required together, squished, 1–60 characters, checked in the operations (publish and rename), not only the form. Names live on `catalog_seasons` as nullable `name_en` / `name_fr` (existing seasons have none). Writes go through operations that publish one event. Every new string in `en.yml` and `fr.yml`, including `errors.catalog.invalid_season_name`.

**Never:** No rename of a draft (a draft is named when published). No name on screens that show only "Saison N" today (library, profiles, card pages). No change to the rake task `number_published`. No database id in the forms (season number is the param, as today).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Publish named | draft 2, `name_fr: "Printemps"`, `name_en: "Spring"` | season 2 published with both names; capsule title reads "Printemps" in fr, "Spring" in en | — |
| Publish unnamed | blank or missing name, or name over 60 chars | nothing published, draft unchanged | alert `invalid_season_name` |
| Rename published | season 1 (no name) renamed to "Hiver"/"Winter" | names stored; `SeasonRenamed` event; notice; current-season screens show it | — |
| Rename refused | blank name, or season number of a draft / unknown | nothing written | alert `invalid_season_name`, or `no_published_season`; unknown number 404 |
| No name | published season without names | "Grand catalogue" / "Season 1 · Grand catalogue" exactly as today | — |
| No season | no published season | unchanged plain labels | — |

</frozen-after-approval>

## Code Map

- `app/domains/catalog/app/models/catalog/season.rb` -- add `NAME_LENGTH = 60`, length validation `allow_nil`, `name(locale)` returning `name_fr` for `:fr`, else `name_en`.
- `app/domains/catalog/app/operations/catalog/publish_season.rb` -- `call(number:, name_en:, name_fr:)`; validate names first (reuse `Catalog::ThemeNaming.clean` with the season length), store them in `flip`.
- `app/domains/catalog/app/operations/catalog/rename_theme.rb` + `theme_editing.rb` -- pattern to copy for `RenameSeason` (lock, update, publish event on `Season.stream_name(id)`).
- `app/domains/catalog/app/events/catalog/season_published.rb` -- pattern for new `SeasonRenamed`.
- `app/controllers/back_office/seasons_controller.rb` -- `publish` passes names; new `update` (PATCH `back-office/seasons/:number`) calls `RenameSeason`, `redirect_refused` on failure (see `ApplicationController#redirect_refused`); `rate_limit` covers it.
- `config/routes.rb:244` -- add `:update` to `only:`.
- `app/policies/back_office/seasons_policy.rb` -- `update? = administrator?`.
- `app/domains/catalog/app/queries/catalog/season_summaries.rb`, `season_scores.rb` -- expose `name_en`, `name_fr` on their Data rows.
- `app/views/back_office/seasons/index.html.erb` -- the publish `ButtonComponent` becomes a `form_with` (POST, `number` hidden, two `text_field_tag`s like `back_office/themes/index.html.erb:135-138`, submit `ButtonComponent` with `confirm`); add a name column to the ledger.
- `app/views/back_office/seasons/show.html.erb` -- for a published season, a rename form (PATCH) pre-filled with the names.
- `app/helpers/boosters_helper.rb` -- new `season_title(season)` = `season&.name(I18n.locale).presence || t("booster.title")` (could live in `ApplicationHelper` since the landing uses it too); `booster_canister_label` passes `name:`; `booster_root_data` adds `booster_season_name_value`.
- `app/views/boosters/_info.html.erb:6`, `_canister.html.erb:17`, `_strip.html.erb:4` -- use `season_title(season)`; strip uses `t("booster.strip_title", number:, name:)`; drop now-unused `strip_title_plain` (use `t("booster.title")`).
- `app/frontend/controllers/booster_controller.ts` (392 lines, limit 400), `app/frontend/lib/booster_render_host.ts`, `app/frontend/lib/booster_render.ts:167` -- carry `seasonName` and pass `name` to `canisterLabel`.
- `app/domains/game/app/queries/game/landing_season_facts.rb` -- add `season_name: season&.name(locale)` (already cached per locale); `app/views/landings/_live.html.erb:29` and `app/models/landing_markdown.rb:48` interpolate `name:` with the `booster.title` fallback.
- `config/locales/{en,fr}.yml` -- `booster.strip_title`, `booster.strings.canister_label`, `landings.show.live.season_name` take `%{name}`; back-office labels (name column, field labels, rename button, `updated` notice); `errors.catalog.invalid_season_name`.
- `db/seeds.rb:66`, `test/support/catalog_seeds.rb:72,104,127` and ~25 test call sites of `PublishSeason.new.call(number:)` -- add names.
- Tests: `test/domains/catalog/publish_season_test.rb`, `test/domains/catalog/theme_operations_test.rb` (pattern), `test/controllers/back_office/seasons_controller_test.rb`, `test/controllers/boosters_controller_test.rb:122,130,246`, `test/controllers/landing_page_test.rb:280,290`, `test/domains/game/landing_queries_test.rb`.

## Tasks & Acceptance

**Execution:**
- [ ] `db/migrate/<ts>_add_names_to_catalog_seasons.rb` -- add nullable `name_en`, `name_fr` strings; regenerate `db/schema.rb` the CI way -- storage.
- [ ] `catalog/season.rb`, `catalog/events/season_renamed.rb`, `catalog/operations/publish_season.rb`, new `catalog/operations/rename_season.rb` -- names on the model; publish requires names; rename for published seasons only -- write path.
- [ ] `seasons_controller.rb`, `routes.rb`, `seasons_policy.rb`, `season_summaries.rb`, `season_scores.rb`, back-office season views -- publish form with names, rename form, name column -- admin UI.
- [ ] booster helper/views/TS, landing facts/view/markdown -- show the name with fallback -- player UI.
- [ ] `en.yml`, `fr.yml` -- strings and error key -- i18n.
- [ ] seeds and test call sites; new tests for each I/O row (operation tests, controller tests for publish/rename/refusals, booster + landing showing a named season in both locales and the fallback) -- coverage.

**Acceptance Criteria:**
- Given an administrator on the seasons page with a draft, when they look at the publish form, then it shows required French and English name fields before the publish button.
- Given a named current season, when a player opens the capsule screen in French, then the panel title, canister line, strip title and canister aria label carry the French name; in English, the English name.
- Given a named current season, when a visitor opens the landing (HTML and markdown), then the season line reads "Saison N · <name>".

## Design Notes

`name(locale)` on the model keeps locale choice in one place; views call `season_title(season)` so the fallback lives in one helper. The landing facts hash is cached per locale, so the name it carries is already the right language; a rename shows there within the one-minute cache.

## Verification

**Commands:**
- `bin/rails test test/domains/catalog test/controllers/back_office/seasons_controller_test.rb test/controllers/boosters_controller_test.rb test/controllers/landing_page_test.rb test/domains/game` -- pass
- `bin/rails test` -- pass (call sites changed across the suite)
- `npm run test:js && npm run format:check && npm run lint:css` -- pass
- `bin/ci`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bundle exec i18n-tasks health`, `script/check_file_sizes`, `script/check_planning_references` -- pass
- `bin/rails test test/system/<booster system test> -n /canister|title/` -- pass, if one asserts the label

## Implementation Notes

- Name check and published-season lock live in `Catalog::SeasonEditing`, shared by `PublishSeason` and `RenameSeason`; `ThemeNaming.valid?` takes a `length:`.
- `SeasonTitle.call(name)` holds the "Grand catalogue" fallback; `ApplicationHelper#season_title(season)` wraps it.
- The publish confirmation moved to the form (`data-turbo-confirm`), since `ButtonComponent` takes `confirm:` only with `method:`.
- `test/controllers/library_controller_test.rb:119` fails on the baseline too (rarity legend lost its "All seasons" column in f22bf3b7); untouched here.

## Plan Change Log

## Review Triage Log

Pass 1 (quick): high 0 · medium 1 · low 2 · false 0 · maybe-false 0.

| Finding | Verdict | Route | Evidence / action |
|---|---|---|---|
| Unnamed season's canister aria label turns "grand catalogue" into "Grand catalogue" (server + TS), contrary to the "No name" matrix row | low | patch | `canister_label` now interpolates `SeasonTitle` = `booster.title`; fallback to the lower-case wording and restore the old assertion |
| Back-office intros still say a published season never changes / nothing is written, beside the new rename form | low | patch | `back_office.seasons.index.intro`, `show.published_intro` in both locales; reword so only the name can change |
| A long name overflows the canister body over the hazard band and LEDs | medium | patch | `.booster-canister__line--title` at `top: 47px`, 120px wide, 26px VT323 upper-case, no clipping; hazard at `top: 180px`; clamp to 4 lines with ellipsis |
