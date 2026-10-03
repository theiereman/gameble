---
title: 'Import hardening before season 1'
type: 'feature'
ticket: '11'
created: '2026-10-03'
status: 'built'
baseline_revision: '2d908769f2ae88d557d8d4bc6f233800f4627629'
route: 'full'
route_source: 'auto'
review: 'thorough'
review_source: 'pinned'
lenses_ran: ['blind-hunter', 'edge-case-hunter', 'verification-gap', 'intent-alignment']
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: ['oversized']
deferred:
  - summary: >-
      A NUL byte in a Steam tag name still makes the tags upsert raise and fails the tags step.
    evidence: |-
      `WebApi#get_tag_list` keeps `tag["name"]` as is, while every other Steam string now goes through `Steam::RawValue.string`; Postgres refuses "\u0000" in a text column. Pre-existing (the tags step is not an app and was not changed by this story), and Valve's curated tag names are unlikely to hold one.
    location: >-
      packs/steam/app/clients/steam/web_api.rb (get_tag_list)
    severity: low
---

<intent-contract>

## Intent

**Problem:** Three retrospective findings block the first real import (`epic-steam-catalog-retrospective.md` F1, F3). F1: nothing ever removes a card from the draft season, so cards from an earlier run, which a newer run no longer keeps, stay in it with old scores and can be published. F3: one malformed app makes a page raise. Examples are a review percent outside 0–100 (`PrestigeScore` raises `ArgumentError`) and an appid listed twice in one `GetAppList` page (Postgres "ON CONFLICT DO UPDATE cannot affect row a second time"). The run then fails again on every resume, and a failed latest run blocks publishing, because no administrator can abandon it.

**Approach:**
- At the end of each cards pass (the last, empty cards page), the draft keeps only the cards that this pass wrote. `Steam` records which run wrote each app's card, and a new `Catalog` operation removes every other draft card-season.
- Malformed Steam values are read defensively. A malformed app is excluded with a reason (a review exclusion, a card refusal or an app-list error line) and the page goes on.
- A new `Steam::AbandonImport` operation lets an administrator abandon the latest failed run. An abandoned run blocks neither a publication nor a new run.

## Boundaries & Constraints

**Always:**
- AD-2/AD-4: `Catalog` never learns about runs or Steam. `Catalog::PruneDraft.call(keep_source_keys: [String])` removes the draft card-seasons whose card's `source_key` is not in the list.
  - It locks the draft `FOR SHARE`, like the upsert does.
  - It passes the list as one Postgres array bind (`= ANY(?::text[])` with a PG array literal), never as N binds. There can be about 20k keys.
  - It deletes in bulk inside the draft only. A published season's card-seasons and sets are never touched (AD-5). Cards and texts stay (identity, stable slugs).
  - With no draft it returns `Success(0)` and publishes no event. Otherwise it publishes `Catalog::DraftPruned` `{ season_id:, removed: n }` on the season stream and returns `Success(n)`.
- AD-3: every write is an operation, inside its transaction, publishing one event: `Steam::ImportRunAbandoned` `{ import_run_id: }`.
- `steam_apps.carded_run_id` (bigint, FK to `steam_import_runs`, indexed) records the run whose cards step last wrote the app's card.
  - It is set for the written apps only (not the refused ones) in the same page transaction.
  - `RescoreCards#reopen` clears it for that run (`carded_run_id = NULL`) and resets `cards_removed` with the other card counts. A rescore therefore also drops a card it now refuses.
- The last cards page prunes the draft, sets the run count `cards_removed`, then calls `FinishImportStep`, all in one transaction. The keep list is `"steam:<appid>"` (via `CardMapping`) for `App.where(carded_run_id: run.id)`.
- Malformed input never raises out of a page. Values are read through a new `Steam::RawValue` helper:
  - `integer(value, min:, max:)` accepts an Integer, or a String of digits, within the range; anything else gives nil. Floats give nil.
  - `string(value)` returns a String with NUL bytes removed, otherwise nil.
  - `hash(value)` returns a Hash or `{}`.
  - `scrub(value)` removes NUL bytes from every string of a deep value, before it is stored in a jsonb column.
  - Bounds: int4 for `review_count` and `tag_ids`, `1..2**31-1` for appids, timestamps `0..253_402_300_799` (year 9999).
- `ReviewPolicy` gains the exclusion `malformed_reviews`, with a migration that replaces the check constraint.
  - A count present but not an integer in range gives `malformed_reviews`. A missing count is 0 (too few, as now).
  - A count of at least 500 with a percent that is not an integer from 0 to 100 gives `malformed_reviews`.
  - Columns store only valid values, otherwise NULL.
- `CardMapping` refuses `:invalid_reviews` when the percent is outside 0–100 or the count is below 1. This covers rows stored before this story. It never lets `PrestigeScore` raise.
- `ImportAppListPage` handles repeated and malformed entries:
  - It keeps the first entry of a repeated appid and appends `"appid <id>: repeated_in_page"`.
  - `WebApi#get_app_list` drops entries without a valid appid (a non-Hash entry, a missing appid, a non-integer appid or one out of range) and counts them in a new `AppListPage#malformed` member. The page then appends `"app list after appid <cursor>: <n> malformed_entries"`.
  - `apps_listed` counts the unique valid apps.
- `DetailsPolicy` and `WebApi#get_items` never call `dig` through a value that is not a Hash.
  - A bad field degrades into the existing exclusions (`no_title`, `no_vertical_image`, `no_release_date`) or is dropped (a malformed tag).
  - An item whose appid is not an integer is skipped.
- `ImportRun` status gains `abandoned` (enum and check constraint). `Steam::AbandonImport.refusal(run)` returns `:not_abandonable` unless the run failed, `:not_latest` unless it is the latest run, and `:cards_written` when it is on `cards` with `last_appid > 0` (the draft holds part of its pass).
  - The status becomes `abandoned`; `finished_at` and the errors are kept.
  - `UnfinishedImportRun` treats abandoned like completed.
  - `ResumeImport` and `RescoreCards` refuse an abandoned run (existing codes).
- Back-office (`/back-office/import-runs/:token`):
  - `post :abandon`, an administrator-only policy, rate-limited like resume.
  - An "Abandon this run" button outside the polled frame, with a confirmation, shown only when `refusal` is nil.
  - When the refusal is `:cards_written`, a note in place of the button.
  - The `cards_removed` count once the run reached `cards`, and the `abandoned` status label.
  - Copy in en and fr (AD-18), in the Brotherhood tone of the neighbouring keys.
- Migrations are strong_migrations-safe and follow the repo pattern: constraints and the FK are added `validate: false` and validated in the next migration, and the index is added concurrently in its own migration.
- Migrations run on the test database only. `db/schema.rb` follows them.

**Never:**
- No change to `PrestigeScore`, the tiers, `SetBuilder`, the steps or the Steam requests.
- No removal of `Catalog::Card` rows.
- No pruning at `StartImport` or in the middle of a pass. While a run is unfinished, the draft still holds the previous pass's cards, and publishing stays refused.
- No abandon of a run that wrote cards in its current pass.
- No retry or rate-limit changes (F4) and no error-log cap change (F7).
- No database trigger for the AD-5 freeze (F5).
- No real Steam call, no development database, no import run, no push or deploy.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Cross-run prune | Run A carded {10, 20}; run B over {20, 30} completes | The draft holds steam:20 and steam:30 with B's scores; steam:10's draft card-season is gone, its card row kept; B `cards_removed` 1 | — |
| Published untouched | steam:10 is also in a published season | Its published card-season, sets and memberships are unchanged | — |
| Rescore drops a refusal | Latest completed run; app 10 now has a percent of 150 | The rescore refuses it (`invalid_reviews`) and steam:10 leaves the draft | — |
| Nothing written | The pass wrote 0 cards, a draft exists | The draft is emptied (`empty_season` in the preview) | — |
| Repeated appid | A GetAppList page `[10, 20, 20]` | One app 20, `apps_listed` +2, error `appid 20: repeated_in_page`, cursor moves | — |
| Malformed list entry | `{}`, `{"appid":"x"}`, `{"appid":-3}`, `"junk"`, `{"appid":2**40}` | Skipped, `malformed` 5, one error line | — |
| Bad review values | percent 150, -1, "abc" or nil with 900 reviews; count `[1]`, "12x" or 2**40 | `malformed_reviews`, invalid values stored as NULL | — |
| Bad details shape | basic_info a String, assets an Array, release a Hash or after year 9999, a tag weight `[1]`, tagid 2**40, NUL in a description | No raise; `no_vertical_image` / `no_release_date` / bad tag dropped / NUL removed | — |
| Abandon | The latest run failed on `details` | `abandoned`, event, publish allowed, a new run starts | — |
| Abandon refused | Running or completed / not latest / failed on cards with `last_appid` > 0 / unknown token | `not_abandonable` / `not_latest` / `cards_written` / 404 | Alert flash, no change |

</intent-contract>

## Code Map

- `packs/steam/app/models/steam/{review_policy,details_policy,card_mapping,app,import_run}.rb` -- policies (`ReviewPolicy.verdict` at lines 24–39; `DetailsPolicy.verdict`, `release_on`, `tag_ids` and its digs at lines 38–91), the `CardMapping.call` guard (line 21), the App scopes (add `carded_by`, `belongs_to :carded_run` optional), and the `ImportRun` status enum, `cards_removed` and comments.
- `packs/steam/app/clients/steam/web_api.rb` -- `get_app_list`, `normalize_app` (line 149 `Integer(app.fetch("appid"))` raises), `get_items` (line 81 `.to_i` on the item id), `AppListPage` (add `malformed`).
- `packs/steam/app/operations/steam/import_app_list_page.rb` -- `upsert_apps` (no dedup), `advance`. `import_tags_page.rb#upsert_tags` already dedups and is the model to follow.
- `packs/steam/app/operations/steam/import_cards_page.rb` -- `write_cards`/`write_card` (mark the written apps), the `apps.empty?` branch (prune, then finish).
- `packs/steam/app/operations/steam/{rescore_cards,resume_import}.rb`, `queries/steam/unfinished_import_run.rb` -- reopen clearing, abandoned semantics, comments. New: `operations/steam/abandon_import.rb` (model it on `ResumeImport`, including `self.refusal`), `events/steam/import_run_abandoned.rb`, `models/steam/raw_value.rb`.
- `packs/catalog/app/operations/catalog/prune_draft.rb`, `events/catalog/draft_pruned.rb` -- new; follow `upsert_draft_card.rb` (`find_draft_season` lock) and `publish_season.rb` (bulk writes on the locked draft).
- `app/controllers/back_office/import_runs_controller.rb`, `app/policies/back_office/import_runs_policy.rb`, `config/routes.rb` (lines 52–55), `app/views/back_office/import_runs/show.html.erb` (rescore block, lines 70–76) -- abandon.
- `config/locales/{en,fr}.yml` -- `back_office.import_runs.{statuses,show,abandon}`, `errors.steam.{not_abandonable,cards_written,not_latest}`, `back_office.seasons.publish.import_active` (mention abandoning), `index.intro` if it names the statuses.
- `db/migrate/2026100305000{0,1,2}_*.rb`, `db/schema.rb` -- follow `20261002220000/1/2` (add without validation, validate, then the concurrent index).
- `README.md` § Steam import -- abandon, prune at the end of a pass, malformed apps.
- Tests:
  - `test/packs/steam/{review_pass,web_api,import_operations,store_details,cards,rescore_cards}_test.rb`
  - new `test/packs/steam/raw_value_test.rb` and `test/packs/catalog/prune_draft_test.rb`
  - `test/jobs/steam_import_step_job_test.rb` (full stubbed runs at lines 278–325, helpers in `test/support/steam_api_stubs.rb`)
  - `test/controllers/back_office/{import_runs,seasons}_controller_test.rb` (the role and visitor loops over actions at lines ~422–458)

## Tasks & Acceptance

**Execution:**
- [x] `db/migrate/20261003050000_harden_the_steam_import.rb`, `...050001_validate_the_steam_import_hardening.rb`, `...050002_index_steam_apps_carded_by_run.rb`, `db/schema.rb` -- the `carded_run_id` column, its FK and index; the `review_exclusion` check with `malformed_reviews`; the status check with `abandoned`.
- [x] `packs/steam/app/models/steam/raw_value.rb` and the policies, `web_api.rb` -- defensive reading (matrix rows 5–8).
- [x] `import_app_list_page.rb` -- dedup, error lines, count.
- [x] `card_mapping.rb`, `import_cards_page.rb`, `rescore_cards.rb`, `app.rb`, `import_run.rb` -- carded marks, `invalid_reviews`, the prune at the end of a pass, `cards_removed`.
- [x] `packs/catalog/.../prune_draft.rb`, `draft_pruned.rb` -- the Catalog prune.
- [x] `abandon_import.rb`, `import_run_abandoned.rb`, `unfinished_import_run.rb`, controller, policy, route, view, locales -- abandon.
- [x] Tests for every matrix row, plus each new operation's success and every failure (AD-22), plus the DB checks (accepted and unknown values).
- [x] `README.md`; `_bmad-output/initiative-gameble/deferred-work.md` (residuals: a title long enough to break the slug index, about 2.7 kB, still fails a page; a whole answer that is not valid JSON still fails the page).

**Acceptance Criteria:**
- Given recorded Steam answers for two imports started with `Steam::StartImport` over different games (A: 10 and 20; B: 20 and 30), with `PrestigeScore::COUNT_WEIGHT` changed between them, when both run through the job chain, then the draft holds exactly steam:20 and steam:30, each scored with B's weight, and B's run page shows 1 card removed.
- Given a recorded app-list page that repeats an appid, and a review answer with a percent of 150, when a full stubbed run goes through the job chain, then it completes; the repeated app exists once; the malformed app is excluded `malformed_reviews` and has no card; and the run's errors name `repeated_in_page`.
- Given a latest run that failed before its cards, when an administrator abandons it from its page, then the page shows it abandoned without resume, rescore or abandon; the seasons page publishes the draft; and starting an import succeeds.
- Given a latest run that failed on the cards step with `last_appid > 0`, when its page is shown, then it offers resume and the `cards_written` note, no abandon button, and a POST to abandon is refused with that message.

## Implementation Notes

- `db/schema.rb` was dumped by `RAILS_ENV=test bin/rails db:migrate` (test database only). The re-dump reformatted the untouched `details_exclusion` check; that line was reverted by hand, so the diff holds only this story's objects. The development database was not migrated.
- `Catalog::PruneDraft` sends the keep list as one PG array literal (`PG::TextEncoder::Array`, `= ANY(?::text[])`). A 20,000-key test checks that the delete uses at most 2 binds and takes the draft lock `FOR SHARE`.
- `ImportCardsPage` takes the prune as an injectable collaborator (`prune:`), as it already did for the upsert, so a test can make the end of the pass raise and check that it rolls back.
- `ReviewPolicy` now treats a count of at least 500 with a missing percent as `malformed_reviews`. Before, such an app was kept, then refused `no_reviews` at the cards step. Floats are refused wherever `.to_i` accepted them before, so a float release timestamp now gives `no_release_date`.
- Retrospective action 3's genre normalization (A2) has no work left: story 2.10 replaced store genres with the fixed keys of `Steam::GenreTags`.
- Files: the three migrations and `db/schema.rb`; new `Steam::RawValue`, `Steam::AbandonImport`, `Steam::ImportRunAbandoned`, `Catalog::PruneDraft` and `Catalog::DraftPruned`; `web_api.rb`, `review_policy.rb`, `details_policy.rb`, `card_mapping.rb`, `app.rb`, `import_run.rb`, `import_app_list_page.rb`, `import_cards_page.rb`, `rescore_cards.rb`, `resume_import.rb` and `unfinished_import_run.rb`; the import runs controller, policy, route and show view; the en and fr locales; `README.md` and `deferred-work.md`; tests (new `raw_value_test.rb` and `prune_draft_test.rb`, and ten test files extended).

## Plan Change Log

## Review Triage Log

### 2026-10-03 — Review pass
- verdicts: 32 findings — high 0, medium 5, low 19, false 8, maybe-false 0
- findings:
  - `[medium]` `[patch]` (verification-gap) No prune test covers a cards pass that spans several pages, or one that fails and is resumed (`ResumeImport`); a regression that drops earlier pages' marks would strip the pass's own cards — pre-verified gap; test added: page_size 2 over 10/20/30, failed, resumed, finished; draft keeps all three, only an earlier run's card is removed.
  - `[low]` `[patch]` (verification-gap, other) `carded_run_id` is not backfilled, so a run on its cards step at deploy prunes the cards it wrote before the migration — real only for a run left on `cards` while migrating (development's latest run is completed); a "migrate with no run on its cards step, or rescore after" note added to the pending-approvals entry for migrating development. Grouped with blind 1 and edge 2.
  - `[low]` `[reject]` (intent) The `cards_written` carve-out leaves the F3 deadlock for an input that fails the cards step every time (the deferred title of about 2.7 kB) — a Steam title of that length is not met in practice. Closing it needs a per-card rescue of database errors (a new branch); the residual stays in `deferred-work.md`.
  - `[false]` `[reject]` (intent) The "a new run starts after abandon" check passes whether or not the run was abandoned — a failed run never blocked `StartImport`, before or after this story, so the assertion states a true behavior. No defect.
  - `[low]` `[patch]` (intent) The job-level V2 test puts the repeated appid and the malformed percent on the same app (20) — test split: 10 is repeated and gets one app and a card; 20 is `malformed_reviews` without a card.
  - `[false]` `[reject]` (intent) The draft is mixed while a run is unfinished (reading A2 against A1) — publishing is refused while the latest non-abandoned run is unfinished (`UnfinishedImportRun`, tightened by the edge 1 patch), so a mixed draft can never be published; the plan chose A1 on purpose.
  - `[false]` `[reject]` (intent) The prune also removes non-Steam draft cards — the intent asks that the draft hold only the latest completed run's cards. Only `ImportCardsPage` writes the draft (`db/seeds.rb` seeds development only), and Catalog stays source-agnostic (AD-4). Grouped with edge 4 and blind 8.
  - `[low]` `[reject]` (intent) V1 is checked at job level, not on the seasons preview, and "recorded" pages are synthetic stubs — the preview reads the same draft rows (`SeasonRows`). Faraday stubs are the repo's recorded answers, and real Steam calls are forbidden.
  - `[low]` `[patch]` (intent) After an abandon, the previous completed run can no longer be rescored (`not_latest`) — confirmed. It is kept on purpose: the abandoned run may have moved `reviewed_run_id`/`details_run_id`, so a rescore of the older run would shrink its ready set. README "Calibrating a season" now says that a new run is needed. Grouped with edge 7 and blind 4.
  - `[medium]` `[patch]` (edge) Run B fails on cards after writing (it cannot be abandoned), then a later run C fails before its cards and is abandoned. The latest run is then abandoned, so a draft that mixes the previous run's cards with B's partial pass becomes publishable — confirmed in `UnfinishedImportRun`. It now reads the latest non-abandoned run; tests added (seasons publish refused, the query returns B).
  - `[low]` `[patch]` (edge) No backfill of `carded_run_id` for a run on cards at deploy — grouped with verification-gap other; pending-approvals note.
  - `[false]` `[reject]` (edge) An empty keep list removes every draft card-season — that is the matrix row "Nothing written" (the draft holds only the latest pass's cards), asserted on purpose.
  - `[false]` `[reject]` (edge) The prune deletes other sources' draft cards — grouped with intent 5.
  - `[medium]` `[patch]` (edge) A GetAppList page that is entirely malformed, says `have_more_results` and gives no valid `last_appid` ends the app_list step silently: the catalog is truncated and then pruned to that list. Before this story it raised. `WebApi#get_app_list` now raises `WebApi::Error` for that page, and a test was added. Grouped with blind 7.
  - `[low]` `[patch]` (edge) `cards_written` refused the abandon of a run on cards past appid 0 whose every card was refused, although the draft was untouched — the refusal now reads `run.cards_written.positive?`; tests, comments and README updated.
  - `[low]` `[patch]` (edge) A rescore of the draft's run is refused after a later run is abandoned — grouped with intent 7 (README).
  - `[false]` `[reject]` (edge) `AbandonImport` checks the latest run without a lock, so a racing `StartImport` lets it abandon a run that is no longer the latest — an abandoned failed run gates nothing, and the new run is the latest non-abandoned one, so no bad outcome follows. Grouped with blind 9.
  - `[medium]` `[patch]` (edge, claim) The abandon's refusal checks only the run's own cursor, not whether an earlier failed run dirtied the draft — grouped with edge 1 (the `UnfinishedImportRun` patch).
  - `[low]` `[patch]` (blind) No `carded_run_id` backfill — grouped with verification-gap other.
  - `[low]` `[patch]` (blind) No pending approval for migrating development — added as a separate `docs:` commit (`pending-approvals.md`).
  - `[low]` `[reject]` (blind) Nothing guards the prune from emptying the draft when a format change sends every app to an exclusion — the run page shows the exclusion counts. Publishing is manual: the preview, and the confirmation that names the card count, come first, and an empty draft is refused (`empty_season`). A threshold guard adds complexity for an unlikely event.
  - `[low]` `[patch]` (blind) Abandoning leaves the previous completed run unrescorable — grouped with intent 7 (README).
  - `[low]` `[patch]` (blind) The abandon confirmation and flash promise a draft "ready to be published", which is false with no completed run, a published draft or an earlier failed run — the copy is now neutral in en and fr.
  - `[low]` `[reject]` (blind) Pruned cards are not named anywhere, only counted — naming thousands of cards in a 20-line error log, or in an event, adds surface for little use. The count and the preview are enough.
  - `[medium]` `[patch]` (blind) A page made only of malformed entries truncates the app list silently — grouped with edge 5.
  - `[false]` `[reject]` (blind) `PruneDraft` deletes cards from every source — grouped with intent 5.
  - `[false]` `[reject]` (blind) `AbandonImport` checks the latest run without a lock — grouped with edge 8.
  - `[low]` `[patch]` (blind) `RawValue.hash` overrides `Object#hash` on the module and needs a sentinel — renamed to `RawValue.object`, with the sentinel and its test removed.
  - `[low]` `[reject]` (blind) The plan file shows unchecked tasks and empty notes — the fix is an edit to this build's plan. The bookkeeping is filled in at finalize.
  - `[low]` `[patch]` (blind) README "Calibrating a season" omits abandoned runs, the rescore dropping newly refused cards, and the rescore after an abandon — the existing steps were updated.
  - `[low]` `[reject]` (blind) The `carded_run_id` index could be partial — a bigint index over a table of a few hundred thousand rows; the gain is negligible.
  - `[low]` `[patch]` (blind) "Cards struck from the draft" shows 0 before the end-of-pass prune has run — the row now shows only for a completed run.

### 2026-10-03 — Review pass (follow-up)
- verdicts: 29 findings — high 0, medium 2, low 23, false 4, maybe-false 0
- findings:
  - `[low]` `[patch]` (blind) A failed rescore that wrote no card can be abandoned; the run whose full pass is the draft becomes abandoned, the gate falls back to an older run, and the `UnfinishedImportRun` comment ("an abandoned run wrote no card") is wrong for it — confirmed. The comment now says "no card in its last pass". With the edge 3 patch an older run that wrote no card can be abandoned in turn; the remaining case (an older run that failed after writing cards, whose cards the rescored run's completion already pruned) keeps publishing refused until a new run completes. It needs a partial run, then a completed run, then a rescore failing on its first page; telling a rescore apart needs a new column, so it is recorded in `pending-approvals.md`. Grouped with edge 4.
  - `[low]` `[reject]` (blind) The abandon button and the `cards_written` note sit outside the polled frame, so they appear only after a reload — the plan places them there on purpose (a confirmed POST button); a stale button is refused by the operation with an alert, so nothing goes wrong. Moving them into the frame changes the page's structure for a cosmetic gain.
  - `[low]` `[patch]` (blind) `import_active` says "abandon it if it halted", wrong for a run that wrote cards or an older blocking run — the en and fr copy now say "a Steam import", offer resuming, and limit abandoning to a run that halted before writing cards.
  - `[low]` `[defer]` (blind) `get_tag_list` keeps tag names without removing NUL bytes — pre-existing (the tags step was not changed by this story, and a tag is not an app); added to `deferred`.
  - `[low]` `[reject]` (blind) A store item with a malformed appid is dropped silently and the game ends up `unavailable`; `appid || id` lets a malformed appid hide a valid id — the plan's rule ("an item whose appid is not an integer is skipped"); `unavailable` is a recorded reason. Counting and logging these adds surface for a Steam answer never seen.
  - `[low]` `[reject]` (blind) Malformed entries can be counted twice across pages when `last_appid` is malformed — needs a malformed cursor and malformed entries on the same page; only the error-line count is off. Not worth a new branch.
  - `[low]` `[patch]` (blind) The `ResumeImport` comment says the gate "reads the latest run only" — now "the latest run that was not abandoned".
  - `[low]` `[patch]` (blind) `cards_written_note` says "over those of the last completed run", wrong with no earlier completed run or for a rescore — now "over the cards it held" / "par-dessus celles que le brouillon tenait".
  - `[low]` `[patch]` (blind) `abandon_confirm` and the abandon flash say "keeps the cards it holds", an unclear pronoun in en and fr — now "the draft season is left as it stands" / "reste telle quelle".
  - `[low]` `[patch]` (blind) A controller comment line was not rewrapped — rewrapped.
  - `[low]` `[patch]` (edge) A Steam string holding an invalid UTF-8 byte (JSON 3.0.2 parses it) makes `RawValue.string`/`scrub` raise `ArgumentError` in `String#delete` — confirmed in the bundle. Both now drop invalid bytes (`scrub("")`) before removing NULs; test added. Grouped with edge 8.
  - `[low]` `[reject]` (edge) An all-malformed page with `have_more_results` and a valid `last_appid` at or below the request cursor ends the app_list step — `more_pages?` already ends the step for any page whose cursor does not move, before this story too; Steam answering a non-advancing cursor is not met in practice, and the fix is another guard branch.
  - `[medium]` `[patch]` (edge) An older failed run that wrote no card, then a newer run started and abandoned: the gate reads the older run, which can be neither resumed nor abandoned (`not_latest`), so publishing stays blocked until a full new run completes — confirmed; a regression of the previous pass's gate patch. `AbandonImport.refusal` now reads "latest" as the latest run that was not abandoned, as the gate does, so that run can be abandoned in turn; a run that wrote cards in its pass still cannot (`cards_written`). Tests added for both; README and pending-approvals updated. Grouped with verification-gap other 1.
  - `[low]` `[patch]` (edge) A completed run reopened by a rescore that fails before its first page can be abandoned, and the gate then reads an older run — grouped with blind 1.
  - `[low]` `[reject]` (edge) More than 20 repeated appids in one page push the other errors out of the 20 kept — Steam repeating that many appids in one page is not met in practice; collapsing the lines adds a branch.
  - `[false]` `[reject]` (edge) Rolling back the first migration while rows hold `abandoned` or `malformed_reviews` aborts midway — Postgres runs the migration's DDL in a transaction, so the rollback fails whole and leaves the schema as it was; a loud failure on data the old schema cannot hold is correct.
  - `[low]` `[reject]` (edge) Two jsonb keys that differ only by NUL bytes collide after `scrub` — such keys are not met in Steam answers; detecting the collision adds a branch.
  - `[low]` `[patch]` (edge, claim) `RawValue` claims it never raises, but invalid UTF-8 makes it raise — grouped with edge 1.
  - `[low]` `[reject]` (edge, claim) AC 4 says a run on cards with `last_appid > 0` offers no abandon button, while the code refuses only on `cards_written > 0` — the previous pass changed this on purpose (a pass whose every card was refused never touched the draft); the AC's Given implies cards were written. The fix would edit this build's plan.
  - `[medium]` `[patch]` (verification-gap, other) A run fails before its cards, a new run completes, its rescore fails before writing a card and is abandoned: the gate reads the first run, which cannot be abandoned or resumed, so only a new import unblocks publishing — confirmed; grouped with edge 3, whose patch makes that run abandonable.
  - `[false]` `[reject]` (intent) The draft is mixed while a pass runs or after a run fails partway — carried: publishing is refused while that run is the latest non-abandoned unfinished one, and the abandon is refused (`cards_written`), so a mixed draft cannot be published.
  - `[low]` `[reject]` (intent) The two-run test uses overlapping games ([10, 20] then [20, 30]) rather than wholly different ones — the overlap checks the dropped card and the rescored shared card at once; a disjoint pair would check strictly less.
  - `[false]` `[reject]` (intent) A repeated appid is kept and carded rather than excluded — the malformed thing is the repeated entry, which is dropped with the reason `repeated_in_page`; the game itself is valid. Recorded in `pending-approvals.md` for confirmation.
  - `[low]` `[reject]` (intent) `malformed_reviews` shows only as a count on the run page, not per app — the reason is stored per app; listing excluded apps is not asked by the intent and adds a page.
  - `[low]` `[reject]` (intent) No captured real Steam payloads; malformed input is checked with hand-built stubs — carried: real Steam calls are forbidden, and Faraday stubs are the repo's recorded answers.
  - `[low]` `[reject]` (intent) The two deferred inputs (a title of about 2.7 kB, a body that is not valid JSON) still fail the run — carried: recorded in `deferred-work.md`.
  - `[low]` `[reject]` (intent) The `cards_written` carve-out keeps the F3 deadlock for an input that fails the cards step every time — carried.
  - `[false]` `[reject]` (intent) "A new run is not blocked" was already true before the story — carried: the assertion states a true behavior.
  - `[low]` `[reject]` (intent) Abandon then publish is tested only with a run that failed on details, not one on cards that wrote nothing — the gate does not read the step; the operation tests abandon a cards-step run that wrote nothing, and the gate tests read the run after an abandon.

## Design Notes

**Why prune at the end of a pass, and why `carded_run_id`.** Pruning at `StartImport` would empty the draft for hours, and a failed run would lose the previous cards. Pruning at the end keeps the invariant at the moment it matters: when no run is unfinished, the draft is exactly the latest completed pass. Steam already records its per-step run ids (`reviewed_run_id`, `details_run_id`), so `carded_run_id` follows that pattern. Clearing it on a rescore makes the keep list "this pass", not "this run". Catalog stays source-agnostic: it receives only opaque keys.

**Why `cards_written` refuses an abandon.** A pass that has written cards overwrote the previous pass's cards in place, so they cannot be restored. Abandoning it would leave a draft scored by two passes, which could then be published. The way out is a resume, or a new run, since a failed run never blocks `StartImport`. The new run's completion prunes the draft. This is recorded as a pending approval.

## Verification

**Commands:**
- `RAILS_ENV=test bin/rails db:migrate` -- the schema dump changes only the three migrations' objects (test database only).
- `bin/rails test && bin/rails test:system` -- all green.
- `bundle exec packwerk check && bin/rubocop && bundle exec i18n-tasks missing && bundle exec i18n-tasks unused` -- no offence.

## Auto Run Result

**Summary**

Three fixes ahead of the first real import, from retrospective findings F1 and F3:
- **The draft keeps only the latest pass's cards.** At the end of each cards pass (an import or a rescore), the draft season keeps only the cards that pass wrote.
  - `Steam` marks each written app with `carded_run_id`.
  - The new `Catalog::PruneDraft` removes every other draft card-season, in one statement with one array bind. The card rows stay, and a published season is never touched.
  - The run counts these as `cards_removed`.
- **A malformed app no longer fails the run.** `Steam::RawValue` reads Steam's values defensively:
  - a bad review count or percent is excluded as `malformed_reviews`;
  - a stored score out of range is refused at the cards step as `invalid_reviews`;
  - an app repeated in one app-list page is kept once and logged as `repeated_in_page`;
  - an entry without a valid appid is skipped and counted;
  - a malformed store field falls into its existing exclusion or is dropped;
  - NUL bytes are removed before anything is stored.
  - A page whose every entry is malformed, with no cursor and more results to come, raises instead of cutting the list short.
- **An administrator can abandon a failed run.** `Steam::AbandonImport` abandons the latest failed run from its back-office page.
  - It is refused (`cards_written`) once the run has written cards in its current pass.
  - The publish gate (`UnfinishedImportRun`) reads the latest run that was not abandoned.

**Files**

- `db/migrate/20261003050000_harden_the_steam_import.rb`, `…050001_validate_the_steam_import_hardening.rb`, `…050002_index_steam_apps_carded_by_run.rb`, `db/schema.rb`: the `carded_run_id` column with its FK and index, and the review-exclusion and run-status checks.
- `packs/steam/app/models/steam/raw_value.rb` (new): defensive readers (`integer`, `string`, `object`, `scrub`).
- `packs/steam/app/models/steam/{review_policy,details_policy,card_mapping,app,import_run}.rb`: `malformed_reviews`, defensive details, `invalid_reviews` and `source_key`, `carded_by`, the `abandoned` status and `cards_removed`.
- `packs/steam/app/clients/steam/web_api.rb`: malformed app-list entries dropped and counted; the raise for an all-malformed page with no cursor; item appids read defensively.
- `packs/steam/app/operations/steam/import_app_list_page.rb`: dedup, error lines, unique count.
- `packs/steam/app/operations/steam/import_cards_page.rb`: card marks; prune, count and finish at the end of the pass.
- `packs/steam/app/operations/steam/rescore_cards.rb`: clears the marks and resets `cards_removed`.
- `packs/steam/app/operations/steam/resume_import.rb`: comment only.
- `packs/steam/app/operations/steam/abandon_import.rb` and `events/steam/import_run_abandoned.rb` (new): the abandon.
- `packs/steam/app/queries/steam/unfinished_import_run.rb`: the latest run that was not abandoned.
- `packs/catalog/app/operations/catalog/prune_draft.rb` and `events/catalog/draft_pruned.rb` (new): the draft prune.
- `app/controllers/back_office/import_runs_controller.rb`, `app/policies/back_office/import_runs_policy.rb`, `config/routes.rb`, `app/views/back_office/import_runs/show.html.erb`: the abandon action, button and note; the struck-cards row on completed runs.
- `config/locales/{en,fr}.yml`: the abandon copy, the `abandoned` status, the new failure codes, `import_active`.
- `README.md`: § Steam import and § Calibrating a season.
- `_bmad-output/initiative-gameble/deferred-work.md`: the residuals.
- Tests:
  - new: `test/packs/steam/raw_value_test.rb`, `test/packs/catalog/prune_draft_test.rb`;
  - extended: `review_pass`, `web_api`, `import_operations`, `store_details`, `cards`, `rescore_cards`, `steam_import_step_job`, the `import_runs` and `seasons` controller tests, and the `import_runs` policy test.
- `_bmad-output/initiative-gameble/pending-approvals.md`: committed apart (`docs:`).

**Review**

One thorough pass with four lenses (blind hunter, edge-case hunter, verification gap, intent alignment) gave 32 findings: high 0, medium 5, low 19, false 8.
- **Patched:** 3 medium entries and 7 low entries, 19 finding rows in all:
  - medium: the publish gate now skips abandoned runs, the app-list raise for an all-malformed page with no cursor, and the test of a pass spread over several pages that fails and resumes;
  - low: the `cards_written` refusal now reads `cards_written`; `RawValue.hash` became `RawValue.object`; neutral abandon copy; the struck-cards row only on completed runs; README calibration steps; the step-job test split; the pending-approvals notes for migrating development without a run on its cards step.
- **Deferred:** none.
- **Rejected, with their reasons in the triage log:**
  - the F3 deadlock for a title of about 2.7 kB (unlikely; it stays in `deferred-work.md`);
  - the prune guard against an emptied draft;
  - naming pruned cards in the run's errors;
  - a partial `carded_run_id` index;
  - the job-level surface for V1;
  - the unchecked plan boxes (a plan edit);
  - false: the "new run" assertion, the mixed draft during a run (gated), non-Steam draft cards (×3), the empty keep list (by design), the unlocked latest-run check (×2, no bad outcome).

**Follow-up review: recommended.**
- Patched counts: high 0, medium 3 (entries), low 7 (entries).
- **Risk not re-checked by any lens:** the post-review publish gate (`UnfinishedImportRun` skipping abandoned runs) changes when publishing unblocks. A run that failed after writing cards, followed only by abandoned runs, now keeps publishing blocked until a new run completes. How that rule interacts with `ResumeImport`, `RescoreCards` and the abandon refusals was only checked by the implementer's new tests. The app-list raise also changes behavior on Steam answers no test records from reality.

**Follow-up review (2026-10-03)**

A fresh thorough pass, focused on the publish gate (commit 21e511c) and the interplay of abandon, rescore, draft pruning and publish. Four lenses gave 29 findings: high 0, medium 2, low 23, false 4.
- **Patched:** 1 medium entry and 7 low entries (16 finding rows):
  - medium: an older failed run that wrote no card, left behind an abandoned latest run (directly, or after a failed rescore), blocked publishing with no way out but a new import. `Steam::AbandonImport.refusal` now reads "latest" as the latest run that was not abandoned, as `Steam::UnfinishedImportRun` does, so it can be abandoned in turn; a run that wrote cards in its pass still cannot;
  - low: `RawValue` drops invalid UTF-8 bytes instead of raising; the gate and resume comments; the `import_active`, `cards_written_note`, `abandon_confirm` and abandon flash copy in en and fr; a comment rewrap.
- **Deferred:** a NUL byte in a Steam tag name (pre-existing).
- **Rejected,** with reasons in the triage log: the button outside the polled frame, silent malformed store items, double-counted malformed entries, a non-advancing cursor on an all-malformed page, more than 20 repeated appids, NUL key collisions, the AC 4 wording, the overlapping two-run test, per-app reason pages, a step-specific abandon-then-publish test, and the carried rows; false: the migration rollback, the mixed draft mid-pass, the repeated appid kept, the "new run" assertion.
- Files: `abandon_import.rb`, `unfinished_import_run.rb`, `resume_import.rb`, `raw_value.rb`, `import_runs_controller.rb`, `config/locales/{en,fr}.yml`, `README.md`, `test/packs/steam/{import_operations,raw_value}_test.rb`, `pending-approvals.md`.
- Patched counts: high 0, medium 1 (entry), low 7 (entries). **Follow-up review: not recommended**: no high was patched, so the work has converged.
- Verification after the patches: `bin/rails test` 925 runs, 0 failures; `bin/rails test:system` 46 runs, 0 failures; packwerk, rubocop, `i18n-tasks missing` and `unused` clean. No migration changed. No Steam call, no import, test database only.
- Residual: a failed rescore that wrote no card can still be abandoned. If the run before it failed after writing cards, publishing stays refused until a new run completes (`pending-approvals.md`).

**Verification**

- `RAILS_ENV=test bin/rails db:migrate` was run on the test database only. The development database was not touched.
- After the patches:
  - `bin/rails test`: 922 runs, 0 failures, 0 errors, 0 skips.
  - `bin/rails test:system`: 46 runs, 0 failures.
  - `bundle exec packwerk check`, `bin/rubocop`, `i18n-tasks missing` and `i18n-tasks unused` are clean.
- **Matrix audit:** every row is covered by a test that ran and passed (`prune_draft_test`, `cards_test`, `rescore_cards_test`, `import_operations_test`, `web_api_test`, `review_pass_test`, `store_details_test`, the controller tests).
- No real Steam call was made, and no import was run.

**Residual risks**

- `carded_run_id` is not backfilled. A run left on its cards step across the migration would strike the cards it wrote before it, so migrate with no run on cards (`pending-approvals.md`).
- A store title long enough to break the slug index (about 2.7 kB), or a whole answer that is not valid JSON, still fails a page (`deferred-work.md`).
- After an abandon, the previous completed run cannot be rescored, so a formula change needs a new run (README, `pending-approvals.md`).
- A pass that keeps no card (for example, a Steam format change that excludes everything) empties the draft. Publishing still refuses an empty draft.
