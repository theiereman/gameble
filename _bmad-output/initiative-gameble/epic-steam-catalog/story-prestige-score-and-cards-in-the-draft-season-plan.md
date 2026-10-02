---
title: 'Prestige score and cards in the draft season'
type: 'feature'
ticket: '5'
created: '2026-10-02'
status: 'built'
baseline_revision: '9c8b664073253c80e2ec9c4d94126dc838a85553'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
context: ['{project-root}/_bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md', '{project-root}/_bmad-output/initiative-gameble/spec-gameble/catalog-and-rarity.md', '{project-root}/_bmad-output/initiative-gameble/epic-steam-catalog/story-store-details-in-both-languages-plan.md', '{project-root}/_bmad-output/initiative-gameble/epic-steam-catalog/story-catalog-schema-and-draft-season-plan.md']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The import ends with Steam rows ready to become cards, but no card exists in `Catalog` and no game has a prestige score (epic 2, R4, R5).

**Approach:** A last step, `cards`, pages over `Steam::App.ready_by(run)` (story 2.4), computes each game's prestige score from its review score and review count only, and writes the card into the draft season through `Catalog::UpsertDraftCard`. Its last page completes the run. Starts only once story 2.4 is committed.

## Boundaries & Constraints

**Always:**
- `STEPS` ends with `cards`; story 2.3's step mechanics apply (cursor naming its step, guard, recovery); the run completes after `cards`.
- `Steam::PrestigeScore.call(percent_positive:, review_count:)`, the one place the formula lives, a pure function of those two inputs (R5; Metacritic never): the Wilson lower bound of the positive share at 95 % (`z = 1.96`, share `percent.fdiv(100)`, count as Float) plus `0.01 × log10(review_count)`. Domain: integer percent 0–100, count ≥ 1; anything else (nil included) raises `ArgumentError`. Acclaim dominates — (40 %, 10 M) ≈ 0.470 < (99 %, 600) ≈ 1.006; (95 %, 1,000) ≈ 0.965 — and the count only nudges, so a little-known game is never rare for being little known. Strictly increasing in each input over the domain, tested as a grid property. Starting formula; story 2.8 calibrates its weight.
- `Steam::CardMapping.call(app, tag_names:)` returns plain Ruby values only (String, Date, Integer, Float, Array, Hash) for `UpsertDraftCard`, or a refusal code when `review_percent_positive` or `review_count` is nil: `source_key` `"steam:<appid>"`; `texts` `en` from `name_en`/`short_description_en`, `fr` from `name_fr`/`short_description_fr`; `release_date` `release_on`; `image_url`; `store_url` `https://store.steampowered.com/` + `store_url_path.delete_prefix("/")`, or `app/<appid>/` when blank; `publisher` `publishers.first` (nil on `[]`); `credit`; `genres` blanks dropped; `tags` the names of `tag_ids` (from `tag_names`, unknown ids dropped) → `parameterize(separator: "_", locale: :en)`, blanks dropped, `uniq`, order kept; `prestige_score` the formula; `rating` `review_percent_positive`.
- `ImportCardsPage` (pages of ≤ 100 apps of `ready_by(run)` after the cursor, tag names loaded once per page) writes each card in its own savepoint: `ActiveRecord::Base.transaction(requires_new: true) { result = @upsert.call(**attrs); raise ActiveRecord::Rollback if result.failure? }`, `result` captured outside the block, never passed to `step` — the deliberate exception to `application_operation.rb`'s "only through `step`" rule, said in the class comment: the upsert's own `transaction` joins the page's, so without the savepoint a refusal raised inside it would keep its rows and event. Only Failures (`missing_text`, `invalid_card`, or the mapping's refusal) are refused per card; an exception fails the page as in the other steps. The upsert is injectable (`initialize(upsert: Catalog::UpsertDraftCard.new)`).
- Refusals are collected in memory as `"appid <id>: <code>"` and written once, after the loop, with the counts (`cards_written`, `cards_refused`) and the cursor (the page's highest appid, refused apps included, so they are not retried this run) in the page's transaction. The error append (`{ at, message }`, truncation, `.last(ERROR_LIMIT)`) moves out of `FailImport` into `ImportRun`, used by both; older errors falling off the limit is accepted, `cards_refused` keeps the total. Readers `cards_written`, `cards_refused`; the run page shows them once `reached?("cards")`; step label in `fr` and `en`.
- The page publishes `CardsPageImported` (`{ import_run_id:, last_appid: }`); each upsert publishes `Catalog::DraftCardUpserted`. The cards page holds the draft's `FOR SHARE` lock for its transaction, so a publish waits up to one page.
- A run is never split across two seasons: story 2.6's seasons page refuses to publish unless the latest import run is completed.

**Never:** no tier cut, publication or sets (stories 2.6–2.7); no Steam name in `Catalog`; no removal of draft cards whose game left the run; no Steam call in this step.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Genres done | last `genres` page committed | run on `cards`, cursor 0 | — |
| Page | 3 ready apps | 3 draft cards with every field, prestige score and rating | — |
| Re-run | same apps, scores changed | same cards; draft card-seasons updated in place | — |
| Published season exists | season 1 published with these cards | cards and texts updated, new draft card-seasons; season 1's card-seasons untouched | — |
| Refused card | the upsert double writes a row then returns `invalid_card` for one app | its row and event rolled back; the 2 others written; error recorded; `cards_refused` 1 | savepoint |
| No percent | ready app with nil `review_percent_positive` | refused without calling Catalog; page continues | — |
| Exception in a card | the upsert raises | page rolled back, job retries, run failed after retries | as other steps |
| Tags | unknown id; a name that parameterizes blank; `Co-op` and `Co op` | dropped; dropped; one `co_op` | — |
| Store path | `/app/1/X/`; blank | `…/app/1/X/`; `…/app/<appid>/` | — |
| Formula | (95, 1,000), (95, 10,000), (99, 1,000), (0, 500), (40, 10 M) vs (99, 600) | ≈ 0.965 < 0.986, < 1.012; ≈ 0.027; 0.470 < 1.006 | nil or out of domain → `ArgumentError` |
| Errors over the limit | 25 refusals | last 20 kept; `cards_refused` 25 | — |
| Stale job / last page | a `genres` job once on `cards`; no ready app left | does nothing; run completed | cursor guard |

</frozen-after-approval>

## Code Map

- `packs/catalog/app/operations/catalog/upsert_draft_card.rb` -- the contract (keywords, validations, failures).
- `lib/application_operation.rb` -- the `step` rule and why an inner Failure in a joined transaction keeps its rows.
- `packs/steam/app/operations/steam/import_reviews_page.rb` and story 2.4's `import_details_page.rb` / `import_genres_page.rb` -- page operations to copy.
- `packs/steam/app/operations/steam/fail_import.rb` -- the error append to extract into `ImportRun`.
- `packs/steam/app/models/steam/{app,import_run,tag}.rb` -- `ready_by`, steps, counts, `count_of`.
- `test/support/steam_api_stubs.rb` -- story 2.4's stubs for the full six-step run.
- `app/views/back_office/import_runs/show.html.erb`, `config/locales/{en,fr}.yml`.

## Tasks & Acceptance

**Execution:**
- [x] `packs/steam/app/models/steam/{prestige_score,card_mapping}.rb`.
- [x] `packs/steam/app/models/steam/import_run.rb`, `app/operations/steam/fail_import.rb` -- shared error append, readers.
- [x] `packs/steam/app/operations/steam/import_cards_page.rb`, `app/events/steam/cards_page_imported.rb`; `STEPS`, `STEP_OPERATIONS`.
- [x] back-office counts and labels.
- [x] `test/` -- every matrix row; the formula grid; the mapping's value classes; a full stubbed run of five games (one under 500 reviews, one without a vertical image, three ready) over all six steps; update tests that expect `genres` to complete the run.

**Acceptance Criteria:**
- Given that stubbed run, when it goes to the end, then the draft season holds three cards with every field and a prestige score, a second identical run leaves three cards, and the run page shows 3 written.
- Given `bin/rails test`, `bundle exec packwerk check`, `bin/rubocop` and `bundle exec i18n-tasks missing`, when run, then all pass.

## Implementation Notes

- `Steam::CardMapping.call` returns a dry-monads `Success(attributes)` or `Failure(:no_reviews)` (the refusal code). `Steam::PrestigeScore` raises on a non-Integer percent or count too (a Float `50.0` is out of domain).
- Tag keys: `parameterize(separator: "_")` keeps hyphens (`"Co-op"` → `co-op`), so the matrix's single `co_op` needs `.tr("-", "_")` (then squeezed and trimmed of `_`) after it. Genres are only stripped of blanks: story 2.4 already stored them as keys.
- `Steam::App#store_url` now does the store-URL rule itself (`delete_prefix("/")`, `app/<appid>/` when blank), and the mapping uses it.
- `ImportRun#append_errors(messages, at:)` (and `MESSAGE_LIMIT`, moved from `FailImport`) assigns without saving; `FailImport` and `ImportCardsPage` save it with their own `update!`.
- `ImportCardsPage` makes no remote call, so it selects its page inside the transaction, after locking the run and re-checking the cursor. Tag names are loaded once per page for the page's tag ids only.
- The FOR SHARE lock on the draft is taken by the upsert inside each card's savepoint; a released savepoint keeps it until the page commits. A savepoint rolled back on a refusal releases a lock taken inside it, but the next successful card takes it again; a page whose every card is refused writes nothing to the draft.
- Tests: `test/packs/steam/cards_test.rb` (formula values and grid property, mapping and its value classes, every page row of the matrix, the job retry, `append_errors`); the full five-game run, its identical second run and the run page in `test/controllers/back_office/import_runs_controller_test.rb`. Tests patching `Catalog::UpsertDraftCard` patch a private method, never `call`: dry-operation wraps every `call` defined on the class, and re-aliasing it recurses.
- The seasons page's refusal to publish while the latest run has not completed was already in place (story 2.6, `Steam::UnfinishedImportRun`); unchanged.

## Plan Change Log

## Review Triage Log

### Pass 1 (quick) — no finding

The reviewer checked the savepoint against dry-operation's ActiveRecord `transaction` source, the formula, the mapping and acceptance criterion 1; no unmet criterion, broken rule or bug. Noted, not a defect: the refused-card test uses a double that fails after a real upsert; no test makes the real upsert fail inside its own transaction (rejected as low: the path is covered by the double's rollback and the reading of the gem).


## Verification

**Commands:**
- `bin/rails test` -- expected: all green.
- `bundle exec packwerk check && bin/rubocop && bundle exec i18n-tasks missing` -- expected: no offence.
