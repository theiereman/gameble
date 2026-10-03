---
epic: epic-steam-catalog
date: 2026-10-03
verdict: rejected
criteria: declared
headless: true
---

# Retrospective: Steam catalog (epic 2)

## Epic summary

**Epic:** `epic-steam-catalog` (id 2), folder `_bmad-output/initiative-gameble/epic-steam-catalog/`. Done when is declared in `epic-steam-catalog.md` (five criteria), so the verdict is judged against declared criteria.

**Tickets** (from `tickets.py status`, in build order):

| Ref | Title | status | state | Plan baseline | Range (commits) |
|---|---|---|---|---|---|
| 2.1 | Import run tracer | built | review | `9475174` | `9475174..a9ee53a`: `f7f486c` (feat), `a9ee53a` (docs) |
| 2.2 | Catalog schema and draft season | built | review | `a9ee53a` | `a9ee53a..8828e60`: `2780581` (chore), `8828e60` (feat) |
| 2.3 | Review pass and the 500-review filter | built | review | `8828e60` | `8828e60..761439e`: `761439e` (feat) |
| 2.4 | Store details in both languages | built | review | `426adf4` | `426adf4..9c8b664`: `e9db769` (docs), `9c8b664` (feat) |
| 2.5 | Prestige score and cards in the draft season | built | review | `9c8b664` | `9c8b664..b33e0aa`: `b33e0aa` (feat) |
| 2.6 | Publish a season with its tiers | built | review | `761439e` | `761439e..426adf4`: `5bc83f0` (docs), `426adf4` (feat) |
| 2.7 | Sets of the season | built | review | `b33e0aa` | `b33e0aa..d69b583`: `d69b583` (feat) |
| 2.8 | First real import and calibration | built | review | `d69b583` | `d69b583..8d64754`: `8d64754` (feat) |
| 2.9 | Refactor sweep | built | review | `8d64754` | `8d64754..6891e36` (inferred, cut): `9a07c25` (epic 3 docs, not this epic), `6891e36` (refactor) |

- **Unfinished tickets (`pending_tickets`):** none. Every ticket is finished in the `tickets.py` sense (`status = built`).
- **Tickets still at `built`, not called done:** all nine (2.1 to 2.9). The owner has not marked any of them done.
- **Ticket 2.8 is `built` but its hitl part is not done:** the plan says "The build ends at `built`; ticket 8 stays open until the author has done the hitl part (`pending-approvals.md`) and written its results in the epic Notes" (`story-first-real-import-and-calibration-plan.md`, Intent, line 23). The full real import has not run (`pending-approvals.md`, entries "Full real Steam import in development" and "Deploy to the test LXC ... and run the first real import there"). The owner reports that a degraded local import of 1,000 games is running in the development database; this retrospective did not read that database.
- **Ranges.** Ordered by baseline ancestry, the builds started 2.1, 2.2, 2.3, **2.6**, 2.4, 2.5, 2.7, 2.8, 2.9. Story 2.6 was built before 2.4 and 2.5 even though `tickets.toml` declares `after = [5]` for it. The last range ends at HEAD's `6891e36` (the sweep commit), not at HEAD. Later commits belong to epics 3 and 4. No merges in the range (`merge_count` 0). Each story has exactly one `feat`/`refactor` commit, as the "one commit per story" rule asks.
- **Whole-epic range:** `9475174..6891e36`, 14 commits, 174 paths. The production diff (packs, app, config, db/migrate, lib, README, Procfile, Gemfile) is 101 files, +3,969/−8. Tests add 33 files, +4,713/−2.

**Evidence inventory**

| Evidence | Status |
|---|---|
| Epic file with Done when | present, `epic-steam-catalog.md` |
| Initiative requirements | present. `initiative-gameble.md` defers to the spec; the epic file carries its own R1 to R7. `spec-gameble/catalog-and-rarity.md` was read as the binding companion. |
| Ticket entries (`description`, `verify`, `covers`) | present, `tickets.toml` |
| Story files | none. No ticket was refined (`file: null` on every row); the plans carry the intent. |
| Plans | present for all nine, each with a baseline, Review Triage Log, Implementation Notes and Verification. One quick review pass per story (`lenses_ran: ['quick']`). |
| `git_evidence.py` output | run once per distinct range plus once over the whole epic; all succeeded |
| Previous retrospective | **none.** `epic-foundation-and-steam-sign-in/` has no `-retrospective.md` file. |
| Session logs | partly available: orchestrator session `~/.claude/projects/-home-teyermann-projets-gameble/16906cad-8d2e-44f7-b728-8e8e3d26e2ca.jsonl` (ends 2026-10-02 23:24). It was searched for sequencing decisions only, not read in full. The per-story implementer subagent transcripts were not located. |
| Behavior run | **not exercised**: see Behavior verification |

## Findings

Every finding cites its source. File references are at the epic's last commit `6891e36` unless noted. The packs and back-office controllers named here are unchanged between `6891e36` and HEAD. Dispositions are *fix now*, *defer* or *accept*, and each finding names the upstream lesson where one exists. The three review-lens reports came from sub-agents. They were re-checked against the source before routing: every finding below was confirmed in the code, and the ones that depend on real Steam behavior are marked unverified.

### Aggregate views

**A1. Architecture delta: clean.** The pack graph is what AD-2 asks: `packs/steam/package.yml` depends on `lib` and `packs/catalog`, and `packs/catalog/package.yml` on `lib` only. `git grep -niw steam 6891e36 -- packs/catalog` returns nothing, so R5 and Done-when 4 of story 2.2 hold. Some checks span packs: the import gate before publishing, and the rescore and resume refusals. They sit in the web layer (`app/controllers/back_office/seasons_controller.rb:22`, `import_runs_controller.rb:20-21`) because `Catalog` cannot ask `Steam`. That placement is correct, but it makes the publish guard non-atomic (see F2). *Accept.*

**A2. Duplication map.**
- The six `Import*Page` operations repeated the same run guards (`find_run`, `lock_run`, `require_on_step`, cursor checks). Story 2.9 extracted them into `Steam::PageSteps` (`packs/steam/app/operations/steam/page_steps.rb`; `story-refactor-sweep-plan.md` line 28). *Resolved within the epic.*
- `ReviewPolicy`, `DetailsPolicy` and `GenresPolicy` share one shape (a `Verdict` of the columns to write). That is a deliberate pattern, not duplication. *Accept.*
- **One divergent duplicate remains.** Genre keys and tag keys are normalized two different ways:
  - `GenresPolicy.genres` (`packs/steam/app/models/steam/genres_policy.rb:39-41`) calls `parameterize(separator: "_")`, which keeps hyphens and uses the ambient locale.
  - `CardMapping.tag_keys` (`card_mapping.rb:44-49`) forces `locale: :en`, turns `-` into `_`, and squeezes and trims.

  `UpsertDraftCard` refuses a whole card when one genre fails `Set::KEY_FORMAT` (added in story 2.7, review finding 3). A single odd genre string would therefore drop a game from the season. Reported by the edge-case (5) and adversarial (10) lenses; the input that triggers it is hypothetical. *Defer, to the next sweep.* Lesson: a key format that one story enforces (2.7) should be traced back to every producer of that key (2.4).

**A3. Size growth: none.** The largest production files after the epic are:

| File | Lines |
|---|---|
| `packs/catalog/app/operations/catalog/upsert_draft_card.rb` | 214 |
| `packs/steam/app/clients/steam/web_api.rb` | 152 |
| `packs/steam/app/models/steam/import_run.rb` | 146 |

Each was read and none mixes responsibilities. Churn is concentrated in tests: `test/controllers/back_office/import_runs_controller_test.rb` +465, `test/packs/steam/store_details_test.rb` +446. *Accept.*

**A4. Pattern divergence.**
- **Documented exceptions.** Each is stated in its class comment or plan, so *accept*:
  - `ImportStepJob` derives from `ActiveJob::Base`, not `ApplicationJob` (the pack cannot reach the root; story 2.1 Implementation Notes).
  - `ImportCardsPage` writes each card in its own savepoint outside `step` (story 2.5 Boundaries).
- **Comment drift.** `packs/steam/app/operations/steam/import_genres_page.rb:15-17` says "a rate limit that outlasts the client's retries raises `RateLimited`". The client does not retry 403 or 429 at all: `store_api.rb` `RETRY_STATUSES` is 5xx only, and `RATE_LIMIT_STATUSES` raise at once (story 2.4 review finding 1 changed this). The comment predates that fix and the sweep's comment pass missed it. Edge-case lens finding 8, verified. *Fix in the next sweep.*

**A5. Reconciling the spec with what was built.**
- **S1. Done-when 3, 4 and 5 are not demonstrated on the real catalog.**
  - **The evidence:** season 1 is not published. No real full import has run (`pending-approvals.md`; `deferred-work.md` entry "The first real Steam import and the calibration are not done"). The epic Notes hold no measured duration, catalog size or tier sizes, which ticket 2.8's `verify` requires (`tickets.toml` entry 8).
  - **What is demonstrated:** these criteria are met on stubs and fixtures only, by the full stubbed runs (`test/controllers/back_office/import_runs_controller_test.rb`) and by story 2.7's 150-card acceptance draft.
  - **Disposition:** *open; blocks acceptance* (see Acceptance verdict).
- **S2. French titles are not localized.** R4 and `spec-gameble/catalog-and-rarity.md` ("Card text … Translations come from Steam's own localized store text") expect a French title. The second probe found that `GetItems` "does not localize game names" (epic Notes, Finding 2026-10-02 second probe). Story 2.4 falls back to the English value when the French one is missing or blank (plan line 25). So the French title is Steam's single name, and only the short description is localized. *Accept the deviation; propose a spec reconciliation* (action item 7).
- **S3. Tags are stored as English keys only.** `import_tags_page.rb` names tags in English. The sweep's comment pass recorded that "no story plans other languages" (`story-refactor-sweep-plan.md` line 83). The spec only says tags are imported, so R4 is met. Whether the collection epic will show tags to French players is unplanned. *Open question.*
- **S4. Tome genre order is unverified.** The epic Notes flag a risk for story 2.8: non-genres such as `Indie`, `Free To Play` and `Early Access` can come first in `appdetails` `genres`. The adversarial lens (9) adds that Steam's order may not be a primary-genre ranking at all. The calibration preview shows cards per first genre (`DraftPreview`), so this is checkable, but only on the real import. *Defer to the 2.8 hitl run.*
- **S5. Build order did not follow `after`.**
  - **What happened:** story 2.6 (`after = [5]`) was built from `761439e` and committed as `426adf4`, before 2.4 (`9c8b664`) and 2.5 (`b33e0aa`).
  - **Why:** the orchestrator session shows a deliberate choice. 2.6 "touches only the `Catalog` pack and the back-office", and its implementation waited for 2.3's commit to keep locale changes separable (session `16906cad…jsonl`).
  - **Disposition:** *accept; it worked.* Story 2.5 found 2.6's guard already in place (plan line 166).
  - **Lesson:** nothing in `tickets.toml` or the plans records the re-sequencing, so the declared order and the real order disagree.
- **S6. A stale note in the sweep plan.** The story 2.9 plan says "Not committed: the sweep is left in the working tree for review" (line 84), but the sweep is commit `6891e36`. *Accept*; noted so later readers are not misled.

### Diff-scope review (bmad-review: adversarial, edge-case-hunter, verification-gap)

The review ran over the epic's production diff `9475174..6891e36`: packs, app, config, db/migrate, lib, README, Procfile and Gemfile, 4,712 lines. The lenses gave extra weight to the seams between stories. Each lens ran as an independent sub-agent; the edge-case lens also received the commit messages as claims.

**F1. The draft season is never pruned, so cards from an earlier run survive, are not rescored, and can be published.**
- **Reported by:** adversarial 1, edge-case 2 and 6, verification-gap 3. Verified.
- **The cause:** nothing in `packs/steam` or `packs/catalog` deletes a draft card-season (`git grep "destroy\|delete_all" 6891e36 -- packs/*/app` finds only the refusal callbacks).
- **When it bites:** `Steam::StartImport` does not refuse or clear an unpublished draft that already holds cards. A second run, or a fresh run after an abandoned one, writes into the same draft. The games it no longer keeps stay there with their old data and old scores: games below 500 reviews, unavailable or delisted, or no longer a game.
- **The rescore does not reach them:** `Steam::RescoreCards` rewrites only `App.ready_by(latest run)` (`rescore_cards.rb:1-7`, `import_cards_page.rb`). Its claim, "a change of `Steam::PrestigeScore` rewrites the draft's scores", is only true for the latest run's games.
- **What it breaks:** the calibration preview and the tier cut would mix two formulas. A leftover card would also break Done-when 4 ("No game is in the catalog with fewer than 500 Steam reviews").
- **Why no test caught it:** every re-run and rescore test reuses the same app set (`cards_test.rb:195`, `:215`; `rescore_cards_test.rb:52`).
- **Where it came from:** stories 2.2 (Never: "no removal of a card from the draft (a later operation, if 2.5 needs it)", plan line 154) and 2.5 (Never: "no removal of draft cards whose game left the run", plan line 123) each pushed the removal out of scope. No later ticket picked it up, and `deferred-work.md` has no entry for it.
- **Why it matters now:** the owner reports a degraded 1,000-game import filling the development draft. Any later run into that same draft inherits its cards.
- **Disposition:** *fix now*, before season 1 is published (action item 2).
- **Lesson:** a "Never … later" in a plan must leave a `deferred-work.md` entry or a ticket. Idempotency matrices need a "re-run over a *different* input set" row, not only "the same set again".

**F2. The publish guard is not atomic with a rescore.**
- **Reported by:** adversarial 2, edge-case 1 and 7. The code was verified; the race itself is inferred.
- **The cause:** the seasons controller checks `Steam::UnfinishedImportRun` (`seasons_controller.rb:22`) outside `PublishSeason`'s `FOR UPDATE` transaction. `RescoreCards.refusal` reads the draft and published seasons without the season lock (`rescore_cards.rb:38-45`).
- **What it breaks:** a rescore committed between the check and the lock lets a publication go through. Its later pages then find no draft and open draft N+1, and the run spans two seasons.
- **What is already tracked:** the same race with start and resume is in `deferred-work.md` (story 2.6 review finding 2, rejected as low because closing it would need a lock across packs, which AD-2 forbids). The rescore path widens that entry but is not recorded in it.
- **Disposition:** *defer.* There is one administrator, and the race needs two actions in the same instant. Record it (action item 6).

**F3. One bad app can fail the run on every resume, and a failed latest run blocks publishing.**
- **Reported by:** adversarial 3, edge-case 3 and 4. The code was verified; whether real Steam data triggers it is unknown.
- **Why it blocks:** `Steam::UnfinishedImportRun` blocks publishing while the latest run is failed (`unfinished_import_run.rb`), and there is no administrator path to abandon a run. A page that raises for the same input every time fails again on each resume, and a new run meets the same data.
- **Inputs that raise instead of being refused per app:**
  - **A review percent outside 0–100.** `ReviewPolicy` stores `percent_positive&.to_i` without a range check (`review_policy.rb:31`). `PrestigeScore` then raises `ArgumentError` out of domain (`card_mapping.rb:34`), which fails the whole cards page.
  - **A repeated appid within one `GetAppList` page.** `ImportAppListPage#upsert_apps` (`import_app_list_page.rb:56-61`) does not deduplicate, unlike the tags page, so Postgres raises "ON CONFLICT DO UPDATE cannot affect row a second time".
- **Disposition:** *fix now, before the full real run.* That run takes hours, and one deterministic failure late in it costs the run (action item 3).

**F4. Rate-limit resilience is unproven against real Steam.**
- **Reported by:** adversarial 4, 5 and 11; verification-gap 4. The code was verified; Steam's real throttling behavior is not.
- **Store API:** a throttle longer than about 6–7 minutes fails the run (`ImportStepJob::RATE_LIMIT_WAIT` 3 minutes × 3 attempts, `import_step_job.rb:34-42`). That is a manual resume during an unattended run of several hours.
- **Web API:** a 429 gets Faraday's four retries and then the job's short polynomial retries (`web_api.rb:25,140-145`), with no `RateLimited` path of its own.
- **Stall recovery:** it reads `updated_at`, which moves only when a page commits, so a slow page could get a duplicate job during a backoff. The cursor guard keeps the data safe.
- **What holds:** the 2-second store spacing gives about 150 requests per 5 minutes, under the measured limit of about 200.
- **Disposition:** *defer.* Observe during the real run and harden only if throttles appear (action item 5).

**F5. The AD-5 freeze is enforced only in models.**
- **Reported by:** adversarial 7. Verified: no trigger or check constraint exists in `db/migrate/20261002210000_create_catalog.rb` or later migrations.
- **What exists:** the freeze on published card-seasons, sets and memberships is `ActiveRecord` validations and `before_destroy` callbacks (`card_season.rb:29-39`, `set.rb:24-34`, `set_membership.rb:17-33`). `Catalog::Season` has no freeze of its own.
- **What holds within the epic:** the only bulk writes in `Catalog` are `PublishSeason`'s `update_all` and `insert_all!`, and they run on the locked draft before the flip. Verification-gap and edge-case lenses checked this independently.
- **The risk:** a later epic's bulk write could change rarities under owned cards without any error.
- **Disposition:** *defer.* Record it for later epics (action item 6).

**F6. Published sets can contradict the cards' live identity fields.**
- **Reported by:** adversarial 8. Verified; the behavior is documented as intended.
- **The cause:** card identity (publisher, genres, release date) is updated in place by later imports, published seasons included (story 2.2 Boundaries, plan line 148). Set memberships stay frozen.
- **What a player could see:** a card shown with publisher B inside publisher A's set.
- **Disposition:** *defer* to epic 4's set screens, which must render set context from `catalog_sets.params`, never from live card fields (action item 6, open question).

**F7. Refusals push real failures out of the run's error log.**
- **Reported by:** adversarial 6. Verified.
- **The cause:** the cards step appends one line per refused card to the run's error log, and the log is capped at the last 20 (`import_run.rb` `ERROR_LIMIT`; story 2.5 Boundaries accepted "older errors falling off the limit").
- **What it breaks:** on a real run with many refusals, the failure that triggered a resume falls off, and the author cannot list which games were refused during calibration.
- **Disposition:** *defer.* Revisit if the real run refuses more than a handful of cards.

**F8. Verification gaps: three invariants the suite does not pin.** All three were verified (verification-gap 1, 2 and 4).
- **Store spacing.** No test asserts the production default `Steam::StoreApi.interval` (2.0 s). Every test sets it to 0 or to 2.0 itself (`test/support/steam_api_stubs.rb:25`; `store_api_test.rb:78,98`).
- **Queue configuration.** No test asserts that `config/queue.yml` serves `default` or keeps its dispatcher. `queue_config_test.rb:19-28` only asserts what it must not serve. `RecoverStalledImportsJob` runs on `default`, and the import process relies on that dispatcher for scheduled retries.
- **Retry waits versus stall recovery.** No test ties `(ATTEMPTS − 1) × RATE_LIMIT_WAIT` to `StalledImportRuns::STALL_AFTER`, an invariant stated in `import_step_job.rb`'s comment.
- **Disposition:** *fix in the next sweep* (action item 4).

**Already tracked, not re-routed:** the rescore button shows only after a full reload (adversarial 12). It is already in `deferred-work.md` (story 2.8 review finding 4).

**Checked and clean** (reported by the lenses as verified with no issue):
- The `CardMapping` → `UpsertDraftCard` keyword contract and its value classes (`steam_import_step_job_test.rb:312`, `cards_test.rb:99-130`).
- Each page operation's cursor-moved guard after the `PageSteps` refactor.
- Deduplication by stall recovery (`steam_recover_stalled_imports_job_test.rb:58-94`).
- `DraftPreview` and `PublishSeason` give equal tier sizes and set counts (`draft_preview_test.rb:107-116`).
- The `ResumeImport` and `RescoreCards` refusal codes.
- `RateLimited` taking precedence in `retry_on`.

## Behavior verification

**Runtime behavior was not exercised by this retrospective.** The scope is narrowed at the owner's instruction: do not touch the development database, do not start an import, do not run the test suite. A degraded 1,000-game import is running in the development database. So the import, the seasons page, publishing and the rescore were not run end to end here. What the record shows instead:

- **Story 2.1:** a local manual check killed the import worker with SIGKILL. The job was then retried from Mission Control, and "the run finished from its cursor with no duplicate" (Implementation Notes). The automatic recovery (`RecoverStalledImportsJob`) was added afterwards and is covered by tests only.
- **Story 2.3:** `get_items` was probed once against the real API, with four appids (Implementation Notes). The full development run, with its kept count and duration, was not done.
- **Story 2.4:** "Manual check (real Steam) not done" (Implementation Notes).
- **Stories 2.5 to 2.8:** stubbed full runs and fixtures only, with no run against real Steam.
- **The degraded 1,000-game import** the owner reports is the first real exercise of the six-step chain. Its outcome is not recorded in the tree, and this run did not read it.

## Previous-retro follow-through

There is nothing to follow through. **No previous retrospective file exists:** `_bmad-output/initiative-gameble/epic-foundation-and-steam-sign-in/` contains no `epic-foundation-and-steam-sign-in-retrospective.md`. The previous epic (epic 1, status `done`) was never retrospected. This is a missing file, not a file with no outstanding items.

## Action items

Every item is **proposed, not applied.** This retrospective changed no code, ticket, plan, spec or `deferred-work.md`.

1. **Run the first real import and finish story 2.8's hitl part.** Owner: **the author (hitl)**.
   - Run the full real import (`pending-approvals.md`: in development, or on the test LXC after `bin/kamal deploy`).
   - Record in the epic Notes each step's duration (from the `Steam::ImportStepFinished` timestamps), the catalog size, and the tier sizes.
   - Check that no card has fewer than 500 reviews or lacks a vertical image, and check the first-genre distribution against the Indie risk (S4).
   - Calibrate `Steam::PrestigeScore::COUNT_WEIGHT`, `Catalog::RarityThresholds::SHARES` and `SetBuilder::TOME_SIZE`, rescore, and publish season 1.
   - Then re-run this retrospective. Done-when 3 to 5 decide the verdict.
2. **Make the draft hold exactly the latest run's cards (F1).** Owner: **dev loop, a remediation story before item 1's publish.** Proposed remediation:
   - A `Catalog` operation that discards the draft, or prunes the draft card-seasons whose source key the completing run did not write. It would be called when the cards step finishes, or `StartImport` would refuse while the draft holds cards from another run.
   - A cross-run test: run A on {10, 20}, run B on {20}, rescore B, then assert on `steam:10`.
   - Until the fix lands, the author should make sure the calibration run starts from an empty draft. This includes deciding what happens to the degraded 1,000-game draft in development.
3. **Harden the import against one bad app before the full real run (F3).** Owner: **dev loop.** Proposed remediation:
   - Refuse a card, rather than raise, when `review_percent_positive` is outside 0–100.
   - Deduplicate appids in `ImportAppListPage#upsert_apps`.
   - Normalize genres the way tags are normalized, and drop a genre that fails `KEY_FORMAT` rather than refusing the card (A2).
   - Decide whether an administrator can abandon a failed run, so a deterministic failure cannot block publishing indefinitely.
4. **Pin the unprotected invariants and fix the stale comment (F8, A4).** Owner: **dev loop, next refactor sweep.**
   - Tests for the `StoreApi.interval` default, for `config/queue.yml` serving `default` with a dispatcher, and for `(ATTEMPTS − 1) × RATE_LIMIT_WAIT` against `STALL_AFTER`.
   - Correct the rate-limit comment in `import_genres_page.rb:15-17`.
5. **Watch rate limits during the real run (F4).** Owner: **the author, during item 1; dev loop if needed.** Note any `RateLimited` failures and resumes. If store throttles outlast about 6 minutes, or Web API 429s fail the run, lengthen the waits or add a Web API `RateLimited` path with automatic resume.
6. **Record the deferred findings in `deferred-work.md`.** Owner: **dev loop, next sweep.** Proposed entries:
   - The rescore variant of the publish-lock race (F2), next to the existing 2.6 entry.
   - The AD-5 freeze enforced only in models, with a database trigger as the option (F5).
   - Set membership versus live card fields, for epic 4's set screens (F6).
   - The capped refusal log (F7).
7. **Reconcile the spec with Steam's untranslated titles and English-only tags (S2, S3).** Owner: **the author.** Proposed spec reconciliation for `spec-gameble/catalog-and-rarity.md` § Card identity:
   - Titles come from Steam's single store name, which `GetItems` does not localize. Only the short description is localized.
   - Tags are stored as English keys.
   - Decide whether French tag labels are needed before epic 4 shows tags.
8. **Process lessons for the orchestrator.** Owner: **the orchestrator, `bmad-build` / `bmad-ticket` use.**
   - (a) When a plan's Never defers work to "later", write a `deferred-work.md` entry or a ticket in the same commit (F1).
   - (b) Idempotency stories need a matrix row for re-running over a different input set (F1).
   - (c) Record a re-sequencing that departs from `tickets.toml` `after` (S5), in the plan's Plan Change Log or in `after` itself.
   - (d) Keep Implementation Notes current at commit time (S6).
   - (e) Run a retrospective when an epic is built. Epic 1 has none (Previous-retro follow-through).

## Acceptance verdict

**Machine verdict: `rejected`**, against **declared** criteria, with **no human decision.** This verdict means *not accepted*; it does not mean the code failed. All nine tickets are finished (`status = built`), so unfinished tickets did not force the verdict. It rests on the declared Done when:

| # | Criterion | Evidence | Met? |
|---|---|---|---|
| 1 | An administrator starts an import and sees its step, counts and errors while it runs | System test through the dashboard and the start button (story 2.1 review finding 5). The run page polls (`app/views/back_office/import_runs/show.html.erb`). | Met in tests. Not observed by this run. |
| 2 | An interrupted import resumes without restarting and without duplicate cards | Cursor guard tests per step, stall-recovery tests, a local SIGKILL check on the app-list step (story 2.1), and the unique `source_key` on cards | Met in tests and one local manual check |
| 3 | Publishing season 1 makes its cards visible at once, each with rarity, release date, FR and EN text, and its sets | Season 1 is not published. No real import has completed (`pending-approvals.md`). | **Not met** |
| 4 | No game in the catalog with fewer than 500 reviews or without a vertical image | Filters exist (`ReviewPolicy`, `DetailsPolicy`, `ready_by`), proven on stubs only. No real catalog exists. F1 shows the draft can keep an earlier run's games, which would break this criterion. | **Not demonstrated**; F1 is a blocking finding |
| 5 | The published season contains publisher sets, tomes and best-of-year sets | Story 2.7's 150-card acceptance draft (1 / 4 / 3) on fixtures. No real season 1. | **Not demonstrated** on season 1 |

**What lifts it:**
- The author completes action item 1: real import, calibration, season 1 published, measurements recorded in the epic Notes.
- Action item 2 (F1) lands before that publication, or the calibration run is shown to start from an empty draft.
- Action item 3 is strongly advised before the full run.

With those done, the expected verdict is `accepted-with-open-items`, carrying F2 and F4 to F8 as deferred items. The code side of the epic is complete and well tested. Every story has its own commit, a quick review pass with triaged findings, and the architecture boundaries hold (A1).

## Open questions

- **The degraded 1,000-game import.** Is it meant to become season 1, or to be discarded before the full import? Which database will season 1 be published in: development, or the test LXC? Because of F1, the answer decides whether action item 2 must land before the next import.
- **French titles.** Is Steam's single store name acceptable as the French title (S2)? If not, a French source must be found, since `GetItems` does not provide one.
- **French tag labels.** Does epic 4, or the card detail in story 4.3, show tags to French players? If so, French tag labels need a story (S3).
- **First-listed genres.** Are `appdetails` genres in an order that makes the first one a real primary genre? Only the real import's preview can answer (S4).
- **Throttling.** How long do Steam's store throttles last on a run of several hours (F4)?
- **Epic 1.** Should epic 1 get its own retrospective, so later retrospectives have a chain to follow through?

## Assumptions

Headless run (`-H epic-steam-catalog`). Every choice below was made without the user.

- **Epic resolution:** `epic-steam-catalog` matched the slug of epic id 2 in `tickets.py status`. The folder is `_bmad-output/initiative-gameble/epic-steam-catalog/`.
- **`pending_tickets`:** empty. Every row is `status = built` (`state = review`), so nothing was retrospected over unfinished tickets.
- **The verdict:** the machine verdict `rejected` was rendered without a human decision, on criteria 3 to 5 and the blocking finding F1. A human decision overrides it.
- **The owner's statements** (relayed by the calling agent) were taken as context, not as evidence: the 2.8 hitl part is not done, and a degraded 1,000-game import is running in development. Only the first is backed by the tree (`pending-approvals.md`, `deferred-work.md`).
- **Narrowed scope:**
  - Runtime behavior was not exercised; the reasons are under Behavior verification.
  - The development database was not read.
  - The test suite was not run.
  - The orchestrator session log was searched for sequencing decisions only; the implementer sub-agent transcripts were not located.
- **Ranges:**
  - The last range was cut at `6891e36` (the sweep commit), because later commits belong to epics 3 and 4.
  - `9a07c25` falls inside 2.9's range but is epic 3 slicing; it was ignored.
  - The review diff was limited to production paths (tests excluded, plus `db/schema.rb`, `db/queue_schema.rb` and `Gemfile.lock`). Tests were read by the verification-gap lens.
- **Aggregate views** were computed inline, from `git_evidence.py` change volume, `wc -l` at HEAD and `git grep`. No dependency-graph tool was run; the pack graph comes from `package.yml`.
- **Every action item is proposed**, owned as stated, and not applied.
- **Team discussion (Phase 3)** did not run (headless).
