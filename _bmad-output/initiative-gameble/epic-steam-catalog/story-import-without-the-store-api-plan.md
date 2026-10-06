---
title: 'Import without the store API'
type: 'refactor'
ticket: '10'
created: '2026-10-03'
status: done
baseline_revision: '4b1dfe4854fc1932f91358685fb7cf2310f8ffca'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context: ['{project-root}/_bmad-output/initiative-gameble/spec-gameble/catalog-and-rarity.md']
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The import's `genres` step calls the keyless store API (`appdetails`, ~200 requests per 5 minutes) once per game, only for genres and the legal notice; it took 17 of the 17 minutes of a 1,000-game local import, and a full import would last hours. The author decided (2026-10-03) to drop it.

**Approach:** Remove the `genres` step and `Steam::StoreApi`. The cards step derives a card's genres from the weighted tags the details step already stores: the tags of a curated list of 20 Steam genre tags (by tag id, kept in `Steam`), most-voted first, so the tome (first genre) is the most-voted listed one; none, no tome. The per-game credit is no longer imported or shown; the card detail shows the publisher and a generic ownership notice in French and English. Columns are kept (ignored) for a later contract migration.

## Boundaries & Constraints

**Always:**
- Steps become `app_list reviews tags details cards`; details hands over to cards. `ImportStepJob` keeps one `retry_on StandardError` (no store-specific retry, no `RATE_LIMIT_WAIT`).
- `Steam::GenreTags` (new, `packs/steam/app/models/steam/genre_tags.rb`) holds `GENRES = { tagid => key }` for exactly these 20 tags (ids read from `steam_tags`, GetTagList): 1663 fps, 1625 platformer, 1628 metroidvania, 1664 puzzle, 1667 horror, 1716 roguelike, 29482 souls_like, 1646 hack_and_slash, 1743 fighting, 699 racing, 701 sports, 9 strategy, 122 rpg, 1662 survival, 599 simulation, 4328 city_builder, 3810 sandbox, 3799 visual_novel, 1698 point_and_click, 1666 card_game. `GenreTags.call(tag_ids)` returns the listed keys in `tag_ids` order (already heaviest first, ties by tagid — `DetailsPolicy.tag_ids`).
- `CardMapping` passes `genres: GenreTags.call(app.tag_ids)` and no `credit`. `App.ready_by(run)` = kept and detailed by the run without exclusion (no genres condition); `detailed_by` goes.
- Catalog stays Steam-free (AD-4): `SetBuilder`'s "first genre" rule and `catalog_cards.genres` are unchanged. `UpsertDraftCard` loses its `credit:` keyword; `CardDetail::Detail` loses `credit`.
- Expand/contract: no column dropped. `Steam::App.ignored_columns` = `genres credit app_details genres_run_id genres_exclusion`; `Catalog::Card.ignored_columns` = `credit`. One data-only migration moves any run whose `step` is `genres` to `cards` with cursor `{"step":"cards","last_appid":0}` (irreversible down is a no-op); `db/schema.rb` gets only its version bumped. The migration is never run on the development database.
- `Steam::GenresPageImported` stays (comment: no longer published, kept so earlier runs' events load).
- Card detail (`app/views/cards/_detail.html.erb`): publisher row as now; credit row gone; after the fields, always, `card_details.notice`: en "This game and its image belong to their respective owners. gameble is not affiliated with Valve or Steam." / fr "Ce jeu et son image appartiennent à leurs propriétaires respectifs. gameble n'est affilié ni à Valve ni à Steam." Styled muted, label size (reuse the old `.card-detail__credit` rule as `.card-detail__notice`, without `pre-line`).
- `catalog.genres.*` gains the 20 keys in fr and en; the old store-genre labels stay (seasons published before this story name tomes with them); its comment is updated.
- Tests use the test database and Faraday stubs only; no real Steam call, no import run on development.

**Never:** no new step, no change to reviews, details requests (`include_tag_count: 20` stays), prestige, tiers or `SetBuilder`; no column or table dropped; no change to the development database; no push or deploy.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Genre order | tag_ids `[492 Indie, 1664 Puzzle, 1663 FPS]` | genres `["puzzle", "fps"]`, tome puzzle | — |
| No listed tag | tag_ids `[19, 492]` or `[]` / nil | genres `[]`, no tome | — |
| Unknown tagid | tag_ids `[999999, 122]` | `["rpg"]` | — |
| Full run | recorded GetItems answers | steps details → cards; no `/api/appdetails` request; cards carry derived genres, credit nil | — |
| Legacy run | a failed run with step `genres` | migration moves it to `cards`, cursor 0; resume writes its cards | — |
| Card detail | card with / without publisher, en and fr | publisher row when present; notice always, in the page's language | — |

</intent-contract>

## Code Map

- `packs/steam/app/clients/steam/store_api.rb`, `models/steam/genres_policy.rb`, `operations/steam/import_genres_page.rb` -- delete; tests `test/packs/steam/store_api_test.rb` and the genres tests of `store_details_test.rb` (~288–420) go too.
- `packs/steam/app/models/steam/import_run.rb` -- `STEPS`, `apps_genred`/`apps_excluded_genres` (remove), step comment.
- `packs/steam/app/jobs/steam/import_step_job.rb` -- `STEP_OPERATIONS`, the RateLimited `retry_on`, `RATE_LIMIT_WAIT`, comment.
- `packs/steam/app/models/steam/{app,card_mapping}.rb`, `operations/steam/{import_details_page,import_cards_page,page_steps}.rb` -- scopes, mapping, comments naming the genres step.
- `packs/catalog/app/operations/catalog/upsert_draft_card.rb`, `queries/catalog/card_detail.rb`, `models/catalog/card.rb` -- credit out.
- `app/views/cards/_detail.html.erb`, `app/frontend/styles/card-detail.css` (~126), `app/views/back_office/import_runs/show.html.erb` (~36–41).
- `config/locales/{en,fr}.yml` -- `steam.import_runs.steps.genres`, `show.apps_genred`, `show.apps_excluded_genres`, `index.intro` ("and their genres"), `card_details.credit` → `card_details.notice`, `catalog.genres`.
- `test/support/steam_api_stubs.rb` (store stubs, `store_sleeps`, `stub_app_details`, `app_details_entry`), `test/test_helper.rb:16`.
- Tests touching genres/credit: `test/jobs/steam_import_step_job_test.rb` (~246–330), `test/packs/steam/{cards,rescore_cards,store_details}_test.rb`, `test/controllers/back_office/import_runs_controller_test.rb` (~114–260), `test/packs/catalog/{upsert_draft_card,card_detail}_test.rb`, `test/controllers/cards_controller_test.rb` (~63–110), `test/system/card_detail_test.rb` (~38–53, 107).
- `db/seeds.rb:28` (genres action → fps), `README.md` import section, `_bmad-output/initiative-gameble/deferred-work.md`.

## Tasks & Acceptance

**Execution:**
- [x] `packs/steam/app/models/steam/genre_tags.rb` -- new list and `call` -- the curated genre tags.
- [x] Steam pack files above -- remove the step, store client, policy; rewire mapping, scopes, job, ignored columns, comments.
- [x] `db/migrate/20261003040000_move_import_runs_off_the_genres_step.rb`, `db/schema.rb` version -- data safety for a run left on `genres`.
- [x] Catalog files above -- drop `credit` from upsert and detail; ignore the column.
- [x] Views, CSS, locales -- card detail notice, run page counts, genre labels.
- [x] Tests -- remove store/genres tests; add `test/packs/steam/genre_tags_test.rb` (matrix rows 1–3), a full stubbed run asserting no appdetails request and derived genres, the migration on a legacy run, the detail notice in en and fr.
- [x] `db/seeds.rb`, `README.md`, `deferred-work.md` (contract migration owed: drop `steam_apps.{genres,credit,app_details,genres_run_id,genres_exclusion}` with its check and FK, and `catalog_cards.credit`).

**Acceptance Criteria:**
- Given recorded GetItems answers, when a run goes through every step, then it completes with steps app_list → reviews → tags → details → cards, makes no store API request, and each card's tome after publish is its most-voted listed genre tag (none without one).
- Given a published card, when its detail is shown in en and in fr, then it shows the publisher (when known) and the ownership notice in that language, and no credit.
- Given `grep -rn "StoreApi\|GenresPolicy\|ImportGenresPage\|appdetails" app packs config test`, when run, then nothing remains but the kept event class and comments about history.

## Implementation Notes

- The migration wraps its `execute` in `safety_assured` (strong_migrations refuses a bare `execute`); it is a data-only UPDATE of the runs on `genres`. Run on the test database only (schema load), never on development.
- `Steam::App.detailed_by` is gone; the details tests that read it now read `ready_by` (same rows: kept and detailed without exclusion).
- `test/components/set_label_test.rb` (not in the Code Map) lists every `catalog.genres` key: it now expects the old store genres plus `Steam::GenreTags::GENRES`.
- The notice is a `<p class="card-detail__notice">` right after the fields' `<dl>` (so before the copies, share and store link), with `margin: 0` like its neighbours.
- New tests: `test/packs/steam/genre_tags_test.rb` (matrix rows 1–3, 20 valid keys, labels in both locales), `test/packs/steam/genres_step_migration_test.rb` (legacy run moved, other runs untouched, resume writes cards), and in `test/jobs/steam_import_step_job_test.rb` a 21-game stubbed run checking the finished steps, no request outside the GetAppList/GetTagList/GetItems stubs (an unstubbed request would fail the run), and the tomes after publish.

## Plan Change Log

## Review Triage Log

### 2026-10-03 — Review pass
- verdicts: 5 findings — high 0, medium 0, low 4, false 1, maybe-false 0
- findings:
  - `[false]` `[reject]` The ownership notice names Valve and Steam, against `brotherhood-tone.md` / spec "the copy never names a real company" — the author's 2026-10-03 decision (memlog) explicitly asks for a notice of no affiliation to Steam or Valve, which supersedes the tone rule for this legal line; the conflict is recorded in the notice's `pending-approvals.md` entry so the spec can carry the exception.
  - `[low]` `[patch]` `packs/catalog/app/models/catalog/card.rb` comment named "the Steam legal notice", the only Steam mention in Catalog (AD-4) — reworded "the source's legal notice".
  - `[low]` `[patch]` `rescore_cards.rb` header and `rescore_confirm` (en, fr) said a rescore only re-applies the prestige formula, and the README said a genre-list change always takes effect on a rescore (refused once the draft is published) — both texts and the comment now name the genre list; README says "while the run's draft is unpublished, otherwise on the next import".
  - `[low]` `[patch]` Rescoring a run completed before this story also writes the apps the old genres step had set aside as unavailable (`ready_by` no longer reads the ignored genres columns), undocumented — confirmed real and consistent with the new rules (those apps pass every remaining filter); documented in the "Migrate development" entry of `pending-approvals.md`.
  - `[low]` `[patch]` A run still running on `genres` at migration time waits for `RecoverStalledImportsJob` (its queued job's cursor no longer matches), undocumented — confirmed (`require_expected_cursor` → `cursor_moved`, stall after 10 min); the migration's comment now says so. Not tested: the recovery path itself is covered by existing stall tests.

## Design Notes

Passing every listed genre, most-voted first, keeps Catalog's rule ("a card sits in the tome of its first genre") and the draft preview untouched; the choice of tome lives where the Steam data lives. A rescore of the latest completed run (`Steam::RescoreCards`) recomputes genres from the stored `tag_ids` without calling Steam, so the development draft can be re-sorted without a new import.

## Verification

**Commands:**
- `bin/rails test && bin/rails test:system` -- expected: all green (test database only).
- `bundle exec packwerk check && bin/rubocop && bundle exec i18n-tasks missing && bundle exec i18n-tasks unused` -- expected: no offence.

**Manual checks (if no CLI):**
- The 1,000-game degraded import timing ("finishes in minutes") is the author's to run; recorded in `pending-approvals.md`.

## Auto Run Result

- **Change:** the import no longer calls the keyless store API. The `genres` step, `Steam::StoreApi`, `Steam::GenresPolicy` and `Steam::ImportGenresPage` are removed (with their tests, stubs and the store rate-limit retry of `ImportStepJob`); steps are `app_list reviews tags details cards`. A card's genres are its tags among the 20 genre tags of `Steam::GenreTags`, most-voted first, so its tome is its most-voted listed tag (none without one). The credit is no longer imported or shown; the card detail shows the publisher and a generic ownership notice in en and fr. Columns are kept and ignored (contract migration recorded in `deferred-work.md`); a data-only migration moves runs left on `genres` to `cards`.
- **Files:** `packs/steam/app/models/steam/genre_tags.rb` (new list); `import_run.rb`, `import_step_job.rb`, `app.rb`, `card_mapping.rb`, `import_details_page.rb`, `page_steps.rb`, `rescore_cards.rb`, `genres_page_imported.rb` (step removed, mapping, comments); `store_api.rb`, `genres_policy.rb`, `import_genres_page.rb` (deleted); `packs/catalog/.../card.rb`, `upsert_draft_card.rb`, `card_detail.rb` (credit out); `app/views/cards/_detail.html.erb`, `card-detail.css`, `back_office/import_runs/show.html.erb` (notice, counts); `config/locales/{en,fr}.yml`; `db/migrate/20261003040000_move_import_runs_off_the_genres_step.rb`, `db/schema.rb` (version), `db/seeds.rb`; `README.md`, `deferred-work.md`; tests (new `genre_tags_test.rb`, `genres_step_migration_test.rb`, full-run test in `steam_import_step_job_test.rb`; store tests removed; card detail and Steam tests updated).
- **Review:** 1 quick pass, 5 findings: 4 low patched (comments, confirmation texts, README, pending-approval notes), 0 deferred, 1 rejected as false (notice naming Valve/Steam: the author's decision asks for it; the tone-rule conflict is noted in `pending-approvals.md`).
- **Follow-up review:** not recommended (patched: high 0, medium 0, low 4).
- **Verification:** after the patches, `bin/rails test` 866 runs 0 failures; `bin/rails test:system` 46 runs 0 failures (test database, Faraday stubs only); `packwerk check`, `rubocop`, `i18n-tasks missing` and `unused` clean; the acceptance grep finds no `StoreApi`, `GenresPolicy`, `ImportGenresPage` or `appdetails` in app, packs, config or test. The development database was only read (tag ids, read-only transaction); no import was run.
- **Residual risks:** the "1,000 games in minutes" clause of Verify is not measured (author's manual check, `pending-approvals.md`); the genre list and the notice wording await the author's confirmation; only a game's 20 heaviest tags are imported, so a listed genre tag ranked lower is not seen; the ignored columns stay until the contract migration.
