---
epic: epic-steam-catalog
date: 2026-10-06
verdict: rejected
criteria: declared
headless: true
---

# Retrospective: Steam catalog (epic 2), re-run

This is a re-run of the 2026-10-03 retrospective (verdict `rejected`), which this file replaces. Current evidence wins over the earlier record. Since then, three things changed:
- Stories 2.10 and 2.11 were built.
- The remediation items from the earlier run landed.
- Later epics changed code this epic owns: 25 tome genres, tiers renamed in story 8.3, `dust_tier` dropped in story 8.7, and the Kamal staging destination.

## Epic summary

**Epic:** `epic-steam-catalog` (id 2), folder `_bmad-output/initiative-gameble/epic-steam-catalog/`. Done when is declared in `epic-steam-catalog.md` (five criteria).

**Tickets** (from `tickets.py status`, in build order):

| Ref | Title | status | state | Plan baseline | Range (commits) |
|---|---|---|---|---|---|
| 2.1 | Import run tracer | built | review | `9475174` | `9475174..a9ee53a`: `f7f486c`, `a9ee53a` |
| 2.2 | Catalog schema and draft season | built | review | `a9ee53a` | `a9ee53a..8828e60`: `2780581`, `8828e60` |
| 2.3 | Review pass and the 500-review filter | built | review | `8828e60` | `8828e60..761439e`: `761439e` |
| 2.4 | Store details in both languages | built | review | `426adf4` | `426adf4..9c8b664`: `e9db769`, `9c8b664` |
| 2.5 | Prestige score and cards in the draft season | built | review | `9c8b664` | `9c8b664..b33e0aa`: `b33e0aa` |
| 2.6 | Publish a season with its tiers | built | review | `761439e` | `761439e..426adf4`: `5bc83f0`, `426adf4` |
| 2.7 | Sets of the season | built | review | `b33e0aa` | `b33e0aa..d69b583`: `d69b583` |
| 2.8 | First real import and calibration | built | review | `d69b583` | `d69b583..8d64754`: `8d64754` |
| 2.9 | Refactor sweep | built | review | `8d64754` | `8d64754..6891e36`: `6891e36` (plus epic 3 docs `9a07c25`, ignored) |
| 2.10 | Import without the store API | built | review | `4b1dfe4` | `4b1dfe4..2d90876`: `5540b45` (refactor), `2d90876` (docs) |
| 2.11 | Import hardening before season 1 | built | review | `2d90876` | `2d90876..da3c974` (cut, inferred): `21e511c` (feat), `c1427ac` (docs), `2286751` (follow-up fix), `da3c974` (docs) |

- **Unfinished tickets (`pending_tickets`):** none. All eleven are `status = built`.
- **Tickets still at `built`, not called done:** all eleven. The owner has marked none of them done.
- **Ticket 2.8 is `built`, but its hitl part is still not done.**
  - `pending-approvals.md` still lists "Full real Steam import in development" and "Deploy to the test LXC … and run the first real import there", each marked not run.
  - `deferred-work.md` still holds the open entry "The first real Steam import and the calibration are not done".
  - The epic Notes record no measured full run, catalog size or tier sizes.
- **Ranges.**
  - The 2.10 and 2.11 ranges have no merges. Each story has one main commit, with its docs committed apart.
  - 2.11's range was cut at `da3c974`, the last commit naming story 2.11. Later commits belong to epics 4, 8 and 10.
  - Commits after that cut touch this epic's packs:
    - `d1a1cdb`: five more tome genres, 25 in all.
    - `a1e4e44`: story 8.3, tier codes common…legendary and card numbers at publication.
    - `b8bae72`: story 8.7, `dust_tier` dropped.
    - `d968377`: the Kamal staging and production destinations.

    They were read as later context, not as this epic's work.
- **2.10 (`4b1dfe4..2d90876`):** 43 paths, +492/−738. The `genres` step, `Steam::StoreApi`, `GenresPolicy` and `ImportGenresPage` were removed, and `Steam::GenreTags` was added.
- **2.11 (`2d90876..da3c974`):** 42 paths, +1,740/−123. It added `Catalog::PruneDraft`, `Steam::RawValue`, `Steam::AbandonImport` and `carded_run_id`. Most of the churn is tests and the plan.

**Evidence inventory**

| Evidence | Status |
|---|---|
| Epic file with Done when | present |
| Initiative requirements | the epic carries its own R1–R7. `spec-gameble/catalog-and-rarity.md` was read as the binding companion. |
| Ticket entries | present, `tickets.toml` |
| Story files | none (no ticket refined) |
| Plans | all eleven. 2.10: one quick review pass. 2.11: a thorough four-lens pass plus a thorough follow-up pass. |
| `git_evidence.py` | run on the 2.10 and 2.11 ranges. The 2.1–2.9 ranges come from the 2026-10-03 run, and their commits are unchanged. |
| Previous retrospective | the 2026-10-03 run of this same file, followed through below |
| `pending-approvals.md`, `deferred-work.md` | read at HEAD `d968377` |
| Development database | **read only**, in a read-only transaction, for seasons, runs and draft contents. Nothing was written. |
| Session logs | not read in this re-run. Process lessons rest on the plans and commits. |
| Test suite | `test/packs/steam test/packs/catalog test/jobs test/controllers/back_office`: 505 runs, 0 failures (test database) |

## Findings

Earlier findings keep their ids. Each shows its status at HEAD.

### Resolved since 2026-10-03

- **F1. The draft was never pruned.** *Resolved by story 2.11* (`21e511c`).
  - At the end of each cards pass, `Catalog::PruneDraft` keeps only the draft card-seasons whose source key the pass wrote (`steam_apps.carded_run_id`).
  - A rescore clears the marks, so a card the rescore now refuses leaves the draft.
  - Tested across runs: A {10, 20}, then B {20, 30} with a changed weight. Also tested over several pages with a failure and a resume (2.11 Review Triage Log, verification-gap medium).
- **F3. One bad app could fail every resume, and a failed run blocked publishing.** *Resolved by story 2.11* (`21e511c`, `2286751`).
  - `Steam::RawValue` reads Steam's values defensively.
  - Bad review values are excluded as `malformed_reviews`. A stored score out of range is refused as `invalid_reviews`, and `CardMapping` no longer lets `PrestigeScore` raise.
  - An appid repeated within one page is kept once and logged as `repeated_in_page`.
  - An administrator can abandon a failed run (`Steam::AbandonImport`), except one that wrote cards in its current pass.
  - **Residuals,** in `deferred-work.md`:
    - a store title of about 2.7 kB, or a Steam answer that is not valid JSON, still fails its page;
    - a NUL byte in a tag name still fails the tags step (2.11 plan, `deferred`).
- **A2. Genre keys normalized two ways.** *Moot.* Story 2.10 replaced the store genres with the fixed keys of `Steam::GenreTags` (2.11 Implementation Notes).
- **A4. The stale rate-limit comment.** *Moot.* `import_genres_page.rb` was deleted by story 2.10.
- **S4. Tome genres in Steam's order.** *Superseded.* A card's tome is now its most-voted listed genre tag (2.10). In the development draft (498 cards), every card has a genre. The largest tomes are fps (104), strategy (101) and rpg (66); no card falls back to "Indie" (read from `catalog_cards.genres` of draft season 2).
- **F6. Set membership versus live card fields.** *Resolved by epic 4* (`deferred-work.md`, resolved by story 4.6).
- **F8. Verification gaps.** *Resolved or moot.*
  - The queue configuration is tested in `test/config/queue_config_test.rb`.
  - Retries versus stall timing is tested at `test/jobs/steam_import_step_job_test.rb:162`.
  - The store-spacing test went away with `StoreApi`.

### Still open (deferred, tracked)

- **F2.** The rescore variant of the publish-lock race (`deferred-work.md`, line 37). *Defer.*
- **F4. Rate-limit resilience against real Steam is unproven.** The store-API half is gone: since 2.10 the run makes no `appdetails` calls. Web API 429 handling is still unexercised against real Steam. *Defer to the real run.*
- **F5.** The AD-5 freeze is enforced only in models (`deferred-work.md`, line 40). *Defer.*
- **F7.** The refusal log is capped at 20 lines (`deferred-work.md`, line 43). This waits on the real run's refusal count. *Defer.*

### New in this run

- **N1. Epic R6 no longer matches the code.** R6 still says `PublishSeason` "sets each card-season's dust tier from the game's age" and names the tiers "steel, emerald, sapphire, amethyst, gold".
  - Story 8.3 (`a1e4e44`) renamed the tier codes to `common … legendary` (`packs/catalog/app/models/catalog/rarity.rb`).
  - Story 8.7 (`b8bae72`) dropped `dust_tier` and `Catalog::Dust`.
  - Publishing now also numbers each card (AD-28).
  - Done when does not mention dust, so the verdict is unaffected. *Accept the deviation (epic 8 owns it); propose reconciling R6* (action item 5).
- **N2. In development, "season 1" is the seed season, not a Steam season.**
  - Read from the development database: season 1 is `published` (2026-10-02 18:42) and holds 60 cards whose source keys are `seed:*` (`db/seeds.rb`: "a small published season of generic cards").
  - Season 2 is the `draft`: 498 `steam:*` cards from run 4 (1,000 listed games, 502 kept), with no rarities.
  - So a Steam publication in development would be season 2. Done when 3 names "season 1" (open question).
- **N3. The development draft meets the inclusion rules.** All 498 draft cards have:
  - a Steam app with at least 500 reviews (none below);
  - a `library_600x900` image URL;
  - a release date;
  - French and English texts;
  - a genre.

  This is positive evidence for Done when 4, on a degraded 1,000-game draft only.
- **N4. Calibration is still at its starting values.**
  - `Steam::PrestigeScore::COUNT_WEIGHT = 0.01`.
  - `Catalog::RarityThresholds::SHARES = {5=>100, 4=>400, 3=>1000, 2=>2500}` ("Starting values, to be calibrated on the first real import", `rarity_thresholds.rb`).
  - `SetBuilder::TOME_SIZE = 30`.

  Expected, since 2.8's hitl part has not run.
- **N5. Open preconditions the author has set for the real import.** These live in `pending-approvals.md` and are not code defects:
  - "Tome genres: fold neighbours … to work out before the real import";
  - the backlog story `_bmad-output/backlog/story-import-staging-and-rollback.md` (import into a separate draft with rollback; changes AD-5/AD-19);
  - seven unconfirmed edge-case rules for story 2.11;
  - the first staging deploy (a Traefik route mismatch to fix first).

  None is a Done-when criterion, but the first two decide *when* the real import is worth running.

### Diff-scope review

**Narrowed.** `bmad-review` was not re-run on the 2.10 and 2.11 diffs. Story 2.11 already had two thorough four-lens passes: 32 findings, then 29, ending with "follow-up review: not recommended", no high finding, and every medium finding patched. Story 2.10 had one quick pass with 4 low findings, all patched. This run checked the seams between stories inline:
- Prune (2.11) against numbering at publication (8.3): numbers are given only at publication, on the draft that remains, so they do not interact.
- 8.7's single Steam edit (`details_policy.rb`) is a comment.
- The genre-list change (`d1a1cdb`) is applied through a rescore of run 4, which recorded 498 cards written and none refused (`pending-approvals.md`, settled 2026-10-05; consistent with run 4's counts in the database).

No new defect was found. The two story-level reviews are the review record.

## Behavior verification

- **Exercised:** the Steam, Catalog, job and back-office tests (505 runs, 0 failures). They include the stubbed full runs, the cross-run prune, abandonment and the publish gates.
- **Observed in the development database (read only):**
  - run 4 completed all five steps on 1,000 real listed apps (`cards_written` 498, `cards_refused` 0);
  - the draft contents are as in N3;
  - no Steam season has been published.
- **Not exercised:**
  - a full real import (about 190k listed apps);
  - publishing a Steam season;
  - the abandon flow in a browser;
  - staging. The pending items say the first staging deploy has not run, and nothing in the tree shows it did.

## Previous-retro follow-through

Action items of the 2026-10-03 run:

1. **Run the first real import and finish 2.8's hitl part** (the author). **Not landed.** `pending-approvals.md` still lists both runs as "Nothing here has been run". The epic Notes hold only the degraded 1,000-game import. Development has no published Steam season (N2).
2. **The draft holds exactly the latest run's cards** (dev loop). **Landed:** story 2.11, `21e511c`, `Catalog::PruneDraft`, and `test/packs/catalog/prune_draft_test.rb` with the cross-run test in `cards_test.rb`.
3. **Harden the import against one bad app** (dev loop). **Landed:** 2.11, `21e511c` and `2286751`. The bad-percent refusal, the dedup and abandonment are all in. The genre-normalization part is moot after 2.10.
4. **Pin the invariants and fix the stale comment** (dev loop). **Landed:** story 4.6, per `deferred-work.md` line 97 (`queue_config_test.rb`, `steam_import_step_job_test.rb:162`). The store spacing and the comment are moot after 2.10.
5. **Watch rate limits during the real run** (the author). **Not landed:** no real run yet. The store half is moot after 2.10.
6. **Record the deferred findings** (dev loop). **Landed:** `deferred-work.md` lines 37 (F2), 40 (F5), 43 (F7) and 95–97 (F6, resolved).
7. **Reconcile the spec on titles and tags** (the author). **Landed:** `spec-gameble/catalog-and-rarity.md` lines 8 and 11 now say the title is Steam's single name and tags are English keys, with French labels open. The French tag labels question is still open in the spec.
8. **Process lessons** (orchestrator):
   - (a) A Never "later" leaves a `deferred-work.md` entry: **landed**. The 2.10 and 2.11 residuals are in `deferred-work.md` (lines 103 and 106).
   - (b) An idempotency matrix row for a different input set: **landed** (2.11 matrix, "Cross-run prune").
   - (c) Record a re-sequencing: no re-sequencing occurred, so **not tested**. `tickets.py` reports 2.10's `after = "4.3"` as an `order_conflict`/`undeclared_after` across epics.
   - (d) Implementation Notes current at commit: **landed** for 2.10 and 2.11.
   - (e) A retrospective for epic 1: **not landed**. `epic-foundation-and-steam-sign-in/` still has no retrospective file.

## Action items

All items are **proposed, not applied.** This run wrote only this file.

1. **Run the real import, calibrate, and publish the first Steam season** (finish 2.8's hitl part). Owner: **the author (hitl)**. In order:
   1. Settle the preconditions the author set:
      - the neighbouring-genre fold for `Steam::GenreTags`;
      - whether `story-import-staging-and-rollback` must land first;
      - the 2.11 edge-case rules in `pending-approvals.md`.
   2. Choose the database (open question 1). Either development: decide what to do with seed season 1. Or staging: fix the Traefik route, run `bin/kamal deploy -d staging` with the `import` role, and apply the pending migrations and backfills.
   3. Run the full real import and watch for Web API 429s (F4).
   4. Record each step's duration, the listed, kept and refused counts, and the tier and tome sizes in the epic Notes.
   5. Calibrate `COUNT_WEIGHT`, `RarityThresholds::SHARES` and `TOME_SIZE`, rescore, check the preview, and publish.
   6. Re-run this retrospective.
2. **Close ticket 2.8 and mark the epic's tickets done** once item 1 is recorded. Owner: **the author, through `bmad-ticket`**. Also close the `deferred-work.md` entry "The first real Steam import and the calibration are not done".
3. **Revisit F7** (the capped refusal log) if the real run refuses more than a handful of cards. Owner: **dev loop**, conditional on item 1.
4. **Harden the Web API rate-limit path** only if item 1 shows 429s fail the run (F4). Owner: **dev loop**, conditional.
5. **Reconcile R6 and Done when 3 with the as-built** (N1, N2). This is a spec reconciliation. Owner: **the author**.
   - R6: tier codes `common … legendary` (AD-28, story 8.3), no dust tier (story 8.7), and card numbers at publication.
   - Done when 3: say "the first Steam season" (or name the database) rather than "season 1", if development's seed season keeps number 1.
6. **Run epic 1's retrospective**, carried from 8(e). Owner: **the orchestrator**.

## Acceptance verdict

**Machine verdict: `rejected` (not accepted)**, against **declared** criteria, with **no human decision.** No ticket is unfinished, so the verdict rests on the criteria. The code side of the epic is complete and the two earlier blocking findings (F1, F3) are resolved. What is missing is the epic's own goal: a Steam season published from a real import.

| # | Criterion | Evidence now | Status |
|---|---|---|---|
| 1 | Start an import from the back-office and see its step, counts and errors | System and controller tests (green). Run 4 in development completed from the back-office with full counts recorded. | **Met** |
| 2 | An interrupted import resumes without restarting and without duplicates | Cursor guards, stall recovery and the resume tests (green). The multi-page fail/resume prune test (2.11). Story 2.1's local SIGKILL check. Unique `source_key`. | **Met** (tests and one local manual check) |
| 3 | Publishing season 1 makes its cards visible at once with tier, release date, FR/EN text and sets | No Steam season is published anywhere on record. Development's published season 1 is the 60-card seed (N2). The draft's 498 cards carry date and FR/EN texts but no tier. | **Not met** |
| 4 | No game in the catalog under 500 reviews or without a vertical image | Filters exist and are tested, and F1 is fixed. The development draft has 0 of 498 cards in breach (N3). There is no published Steam catalog to judge, and the draft covers only the first 1,000 appids. | **Met on the degraded draft; not demonstrated on a published season** |
| 5 | The published season has publisher sets, tomes and best-of-year sets | `SetBuilder` is tested (2.7's acceptance draft). Development's seed season 1 has 6 publisher, 3 tome and 35 best-of-year sets, but from seed data, not Steam. | **Not demonstrated** on a Steam season |

**What lifts it:** action item 1, which is a real import, calibration and publication, with the measurements in the epic Notes. With that done, the expected verdict is `accepted-with-open-items`, carrying F2, F4, F5, F7, the 2.11 residuals and N1 as tracked items. No code change is required to lift the verdict.

## Open questions

1. **Which database holds the first Steam season?** In development it would be season 2, behind seed season 1. On staging it would be season 1, but staging has not been deployed. The answer decides how Done when 3 should read (action item 5).
2. **Must the import staging and rollback story land before the real import?** The author asked for it, and it changes AD-5 and AD-19. It would also change how a bad real run is thrown away.
3. **The neighbouring-genre fold:** which tags fold into which? The author marked it "to work out before the real import".
4. **The 2.11 edge-case rules** in `pending-approvals.md` await confirmation. They are seven items, including whether a failed rescore may be abandoned.
5. **French tag labels:** still open in the spec (S3 carried).
6. **Real Web API throttling** over about 1,900 `GetItems` calls is unknown (F4).

## Assumptions

Headless run (`-H _bmad-output/initiative-gameble/epic-steam-catalog`). Every choice below was made without the user.

- **Epic resolution:** the folder was given. `tickets.py status` returned 11 rows, all `built` / `review`.
- **`pending_tickets`:** empty. The verdict is not forced by unfinished tickets.
- **The verdict:** `rejected` was rendered from the evidence alone, on Done when 3 and 5, and 4 for a published season. No human decision was taken. A human decision overrides it.
- **This file was rewritten in place.** The earlier run's findings are carried by id with their current status, and its action items are followed through above.
- **The caller's context was taken as context, not as evidence.** It said the real import and the season 1 publication had not been done, and that staging was configured but not known to be deployed. Each point was checked against `pending-approvals.md`, `deferred-work.md` and the development database. Nothing in them contradicts it.
- **The development database was read** in a read-only transaction: seasons, import runs, draft contents and set counts. It was not written. The test LXC and staging were not contacted.
- **Narrowed scope:**
  - `bmad-review` was not re-run (see Diff-scope review).
  - The aggregate views for 2.10 and 2.11 come from `git_evidence.py` change volume and from reading the plans, without a dependency-graph tool.
  - Session logs were not read.
  - The full suite and the system tests were not run, only the four relevant test directories.
- **Range cut:** 2.11's range ends at `da3c974`. The later commits that touch `packs/steam` and `packs/catalog` (`d1a1cdb`, `a1e4e44`, `b8bae72`) were read as context for N1 and N4.
- **Every action item is proposed and owned as stated.** None was applied.
- **Team discussion (Phase 3)** did not run (headless).
