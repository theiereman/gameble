---
title: 'Store details in both languages'
type: 'feature'
ticket: '4'
created: '2026-10-02'
status: done
baseline_revision: '426adf4c8edc3739efb795fa4b0dd7147728c9af'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
context: ['{project-root}/_bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md', '{project-root}/_bmad-output/initiative-gameble/spec-gameble/catalog-and-rarity.md', '{project-root}/_bmad-output/initiative-gameble/epic-steam-catalog/story-review-pass-and-the-500-review-filter-plan.md']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The games kept by the review pass have no text, image, tags, release date, publisher, credit or genre yet, and the games without a vertical image are still in (epic 2, R3, R4).

**Approach:** Three more steps after `reviews`, each paging over the run's apps and resuming from its cursor: `tags` names Steam's tags; `details` asks `GetItems` in English and French for each kept game's names, short descriptions, release date, publishers, tags, store path and library image, and excludes what cannot become a card; `genres` asks the store's `appdetails`, one game per call under the store rate limit, for its genres and legal notice. The result, `Steam::App.ready_by(run)`, holds every field `Catalog::UpsertDraftCard` requires.

## Boundaries & Constraints

**Always:**
- `STEPS` becomes `app_list reviews tags details genres`; story 2.3's step mechanics (cursor naming its step, `FinishImportStep`, guard, recovery) apply unchanged. Each step's last page finishes it without calling Steam when no app is left.
- `tags`: one page, one `WebApi#get_tag_list(language: "english")` (`IStoreService/GetTagList`; raise on a malformed or empty answer), upserted into `steam_tags` (tagid unique, `name`). Tag labels in other languages are a later story's.
- `details`: pages of ≤ 100 apps of `Steam::App.kept_by(run)` after the cursor; two `get_items` calls (context `english`/`US`, then `french`/`US`; `include_basic_info`, `include_assets`, `include_release`, `include_tag_count: 20`), outside the transaction. Availability and type come from the English answer only; a French item missing, unsuccessful, or with a blank field falls back to the English value. Per app on `steam_apps`: `name_en`, `name_fr`, `short_description_en`, `short_description_fr` (plain text), `publishers` string[] (`basic_info.publishers[].name`, blanks dropped), `release_on` (the earliest non-zero of `release.original_release_date`, `original_steam_release_date`, `steam_release_date`, each `Time.at(ts).utc.to_date`; pre-Steam dates are intended, the dust uses them), `tag_ids` integer[] (`tags` by weight descending, ties by tagid), `store_url_path`, `image_url` (`Steam::Cdn::ASSET_BASE` = `https://shared.akamai.steamstatic.com/store_item_assets/` + `asset_url_format` with `${FILENAME}` replaced by `assets.library_capsule`), the raw `details` jsonb (the English item plus the French `name` and `short_description`), `details_run_id`, and `details_exclusion`, first match wins: `unavailable` (absent from the English answer or `success` ≠ 1), `not_a_game` (`type` absent or ≠ 0), `no_title` (blank English name), `no_vertical_image` (no `library_capsule`), `no_release_date` (no non-zero date), else NULL.
- `Steam::PlainText.call(html)` (in the pack): Nokogiri HTML5 fragment, `<br>` and block ends become spaces, `.text`, squished; entities decoded.
- `genres`: pages of ≤ 5 apps of `Steam::App.detailed_by(run)` (kept by the run, `details_run_id = run.id`, `details_exclusion IS NULL`); one `Steam::StoreApi#app_details(appid)` per app: `https://store.steampowered.com/api/appdetails?appids=<id>&cc=us&l=english&filters=basic,genres`. The client spaces requests itself: it sleeps until `StoreApi.interval` (2 s, configurable for story 2.8, 0 in tests) has passed since its last request, per process, on a monotonic clock, retries included; the sleeper is an injectable `class_attribute` for tests. A 429 or 403 raises `Steam::StoreApi::RateLimited`; `ImportStepJob` retries it with `wait: 3.minutes, attempts: 3` (declared after the generic `retry_on`, so it takes precedence; the 9 minutes stay under the 10-minute stall recovery), then the run fails and can be resumed. A body that is `null`, lacks the appid key, or is not JSON raises `Steam::StoreApi::Error`. Per app: `genres` string[] (each `description` parameterized with `_`, e.g. `free_to_play`, Steam's order kept; `[]` when none — such a card gets no tome), `credit` (`legal_notice` through `PlainText`, truncated to 1,000 characters at a word boundary, NULL when blank), the raw `app_details` jsonb (`data`), `genres_run_id`, and `genres_exclusion`: `unavailable` when `success` is false or `data.steam_appid` differs from the appid asked, else NULL.
- `Steam::App.ready_by(run)` = `detailed_by(run)` + `genres_run_id = run.id` + `genres_exclusion IS NULL`. Its rows give story 2.5 every required `UpsertDraftCard` field: English title, `release_on`, `image_url`, store URL (`https://store.steampowered.com/` + `store_url_path`). Story 2.5 passes the first publisher, and tag keys: the English tag name parameterized with `_`, unknown tag ids dropped.
- Migrations follow story 2.3's strong_migrations pattern (constraints `validate: false` then validated; indexes concurrently), with a partial index serving `detailed_by`.
- Counts gain `tags_named`, `apps_detailed`, `apps_excluded_details`, `apps_genred`, `apps_excluded_genres`; the run page shows them once the step is reached; step labels in `fr` and `en`.

**Never:** no `Catalog` write and no prestige score (2.5); no French `appdetails` call; no image download; no real Steam call in tests.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Tags | GetTagList answer | `steam_tags` upserted; run on `details` | malformed or empty → raise |
| Kept game | type 0, capsule, both languages | every field stored; not excluded | — |
| Hashed capsule | `ab12…/library_capsule.jpg` | URL from the format with that file | — |
| Exclusions | absent; `success` 2; type 1; type missing; blank name; no capsule; all dates 0 | `unavailable`, `unavailable`, `not_a_game`, `not_a_game`, `no_title`, `no_vertical_image`, `no_release_date` | — |
| Precedence | type 1 without capsule | `not_a_game` | — |
| French fallback | French item missing, or blank description | English values | — |
| HTML | `<b>Fun</b> &amp; games`, `Valve<br>All`, `&quot;x&quot;` | `Fun & games`, `Valve All`, `"x"` | — |
| Genres | appdetails success | `genres` keys in order, `credit` stored | — |
| No genre / blank or long notice | `genres` absent; `legal_notice` blank or 3,000 chars | `[]`; NULL or ≤ 1,000 chars at a word | — |
| Store refuses | `success: false`, or `steam_appid` differs | `genres_exclusion: unavailable` | — |
| Malformed | `null`, missing key, not JSON | job retry, then run failed | `StoreApi::Error` |
| Rate limited | 429 or 403 for longer than Faraday's retries | job waits 3 min and retries; failed after 3 | `RateLimited` |
| Spacing | two calls in a row | the second waits `interval` since the first | sleeper |
| Last page / stale job | no app left; a `reviews` job once on `tags` | step finishes without Steam; stale job does nothing | cursor guard |
| Re-run | app detailed by an earlier run, not kept by this one | not in `ready_by(run)` | — |

</frozen-after-approval>

## Code Map

- `packs/steam/app/operations/steam/import_reviews_page.rb` -- golden example of a page over the run's apps (selection before the call, update only, cursor guard).
- `packs/steam/app/models/steam/{app,import_run,review_policy}.rb` -- `kept_by`, `STEPS`, `cursor_for`, `reached?`, counts.
- `packs/steam/app/operations/steam/finish_import_step.rb`, `app/jobs/steam/import_step_job.rb` -- step machinery, `STEP_OPERATIONS`, `retry_on`.
- `packs/steam/app/clients/steam/web_api.rb` -- `get_items`; add `get_tag_list`. New `store_api.rb` (no key).
- `db/migrate/20261002220000*`–`*220002*` -- the migration pattern to copy.
- `app/views/back_office/import_runs/show.html.erb`, `config/locales/{en,fr}.yml`.
- `test/support/steam_api_stubs.rb` -- `stub_get_items` ignores the language: add `stub_get_items_by_language("english" => …, "french" => …)`, a GetTagList stub and an appdetails stub, built from the real answers in the epic's Notes.

## Tasks & Acceptance

**Execution:**
- [x] `db/migrate/*` -- `steam_tags`; the `steam_apps` columns, constraints and index.
- [x] `packs/steam/app/clients/steam/{web_api,store_api,cdn}.rb`.
- [x] `packs/steam/app/models/steam/{tag,app,import_run,plain_text,details_policy}.rb` -- scopes, steps, counts, exclusion order.
- [x] `packs/steam/app/operations/steam/{import_tags_page,import_details_page,import_genres_page}.rb` and events (`{ import_run_id:, last_appid: }`).
- [x] job dispatch and `RateLimited` retry; back-office counts and labels.
- [x] `test/` -- every matrix row; the clients (params incl. `cc`, malformed answers, spacing, rate limit); a full stubbed run over the five steps; update tests that expect `reviews` to complete the run.

**Acceptance Criteria:**
- Given a stubbed run whose kept games include a DLC-typed item, a game without a vertical image and a normal game, when the run ends, then only the normal game is `ready_by(run)`, with French and English text, tags, release date, publisher, credit, genres, store path and image URL.
- Given `bin/rails test`, `bundle exec packwerk check`, `bin/rubocop` and `bundle exec i18n-tasks missing`, when run, then all pass.

## Implementation Notes

- Migrations `20261002230000` (`steam_tags`), `230001` (the `steam_apps` columns, two FKs and two check constraints with `validate: false`), `230002` (validates them), `230003` (partial index `index_steam_apps_detailed_by_run` on `(details_run_id, appid) WHERE details_exclusion IS NULL`, concurrently). Rolled back and re-applied: identical `db/schema.rb`. Array columns (`publishers`, `tag_ids`, `genres`) are nullable without default: NULL means "not fetched yet".
- `Steam::DetailsPolicy` and a new `Steam::GenresPolicy` (same shape as `ReviewPolicy`) turn the answers into a `Verdict` whose `attributes` are the columns to write. Two small additions beyond the plan's letter, to keep `ready_by` complete: a missing `asset_url_format` (no URL can be built) counts as `no_vertical_image`, and a missing `store_url_path` falls back to `app/<appid>/`. `Steam::App#store_url` builds the store URL.
- The credit is truncated with `truncate(1000, separator: " ", omission: "…")`, so a cut credit ends with "…" and stays ≤ 1,000 characters.
- `Steam::StoreApi`: faraday-retry retries 5xx only (4 retries); a 403 or 429 raises `RateLimited < Error` at once (review fix: a Retry-After obeyed inside Faraday could stretch three job attempts past the 10-minute stall recovery), so the job's 3-minute waits govern; anything else → `Error`. Spacing is a Faraday middleware placed inside the retry, so every attempt is spaced; the spacing state is a per-process class-level monotonic timestamp behind a mutex; `interval`, `sleeper`, `retry_interval` and `adapter` are class attributes.
- An unavailable game in the genres step keeps `genres`, `credit` and `app_details` NULL (not fetched); `tags_named` counts the tags upserted after de-duplication by tagid.
- `ImportStepJob`: both `retry_on` share one `FAIL_RUN` block; `RateLimited` is declared last (`wait: 3.minutes`, 3 attempts; ActiveJob adds its default jitter of up to 15 %).
- `ImportTagsPage` publishes `TagsPageImported` with `{ import_run_id:, last_appid: }` (always 0, the step has no appid cursor) to keep the events uniform, then finishes the step in the same transaction.
- Existing full-run tests now also stub GetTagList; their review-only items carry no `type`, so the details step excludes them as `not_a_game` and the genres step finishes without a store call.
- Manual check (real Steam) not done: the genres step costs one store call per detailed game, about 2 s each.

## Plan Change Log

## Review Triage Log

### Pass 1 (quick) — high 0, medium 1, low 3, false 1, maybe-false 0

| # | Verdict | Route | Finding | Evidence / action |
|---|---|---|---|---|
| 1 | medium | patch | faraday-retry obeys `Retry-After` on 429/403 up to 60 s, so three job attempts could exceed the 10-minute stall recovery and duplicate page jobs would hammer a throttling store | Confirmed. `StoreApi` retries 5xx only; a 429/403 raises `RateLimited` at once and the job's two 3-minute waits govern (about 6 min + jitter). Tests adjusted. |
| 2 | low | patch | `tags_named` counted tags before de-duplication | Confirmed. Counts the upserted rows; test with a repeated tagid. |
| 3 | low | patch | An unavailable game stored `genres: []` ("no genre") instead of NULL ("not fetched") | Confirmed. NULL genres, credit and raw answer, as the details policy does; tested. |
| 4 | low | patch | The cursor-moved-under-lock path untested for the tags and genres pages (AD-22) | Tests added for both, plus the tags page whose run moved on. |
| 5 | false | rejected | A later run's exclusion leaves an earlier run's genre data and makes `ready_by(earlier_run)` lose the app | Rows hold the latest run's results by design (`*_run_id` columns); `ready_by(run)` is only read for the run in progress. |


## Verification

**Commands:**
- `bin/rails test` -- expected: all green.
- `bundle exec packwerk check && bin/rubocop && bundle exec i18n-tasks missing` -- expected: no offence.
