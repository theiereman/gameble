---
epic: epic-steam-catalog
date: 2026-10-06
verdict: accepted-with-open-items
criteria: declared
headless: true
---

# Retrospective: Steam catalog (epic 2), third run

This run replaces the two earlier ones: 2026-10-03, verdict `rejected`, and the morning of 2026-10-06 (`200521d`), also `rejected`. The second run said the code side was complete and the verdict was rejected only because no Steam season had been published from a real import. Current evidence wins. Since then, one thing changed:
- `d3a768f` (docs) records that the author deployed staging (gameble.dotsncircles.com) and ran the first full real import there on 2026-10-06, then published season 1.

No code changed after the second run (`git log 200521d..HEAD` holds only `d3a768f`).

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
- **Ticket 2.8's hitl part has now run (author's report).** Commit `d3a768f` adds two Measurement lines to the epic Notes (`epic-steam-catalog.md`, last two Notes) and moves the two real-import entries of `pending-approvals.md` to a "Staging deployed and the first full real import run there" line. What is still open of 2.8:
  - the author has not reported checking the names of the 124 Légendaire cards, so the calibration approval rests on "Calibration kept the starting values" alone;
  - `deferred-work.md` line 52, "The first real Steam import and the calibration are not done", is still open.
- **Ranges.**
  - The 2.10 and 2.11 ranges have no merges. Each story has one main commit, with its docs committed apart.
  - 2.11's range was cut at `da3c974`, the last commit naming story 2.11. Later commits belong to epics 4, 8 and 10.
  - Commits after that cut touch this epic's packs:
    - `d1a1cdb`: five more tome genres, 25 in all.
    - `a1e4e44`: story 8.3, tier codes common…legendary and card numbers at publication.
    - `b8bae72`: story 8.7, `dust_tier` dropped.
    - `d968377`: the Kamal staging and production destinations.

    They were read as later context, not as this epic's work. `d3a768f` (docs) carries this epic's real-import evidence.
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
| Previous retrospective | the second run of this same file (2026-10-06, `200521d`), followed through below |
| `pending-approvals.md`, `deferred-work.md` | read at HEAD `d3a768f` |
| Staging measurements | **author-reported** from the back-office, recorded in the epic Notes by `d3a768f`. No staging database or host was reachable from this run, so they were checked for internal consistency (below), not against the data. |
| Development database | read only, in the 2026-10-06 morning run (N2, N3). Not re-read in this run. |
| Session logs | not read in this re-run. Process lessons rest on the plans and commits. |
| Test suite | 505 runs, 0 failures in the earlier run of the day. Not re-run: `d3a768f` changes only docs. |

## Findings

Earlier findings keep their ids. Each shows its status at HEAD `d3a768f`.

### The real import on staging (new evidence)

- **R1. The figures recorded in the Notes are internally consistent** (epic Notes, Measurement lines of 2026-10-06; checked by arithmetic in this run).
  - Listed 190,718 − kept 12,326 = 178,392 set aside. The Notes give 178,392.
  - Kept 12,326 − 19 set aside at the store page = 12,307 cards written. 0 refused at the cards step.
  - Tiers: 7,384 + 3,076 + 1,231 + 492 + 124 = 12,307. That is 60.0 / 25.0 / 10.0 / 4.0 / 1.0 %, which matches `Catalog::RarityThresholds::SHARES = {5=>100, 4=>400, 3=>1000, 2=>2500}` per mille (`packs/catalog/app/models/catalog/rarity_thresholds.rb:16`).
  - 406 tomes fits `SetBuilder::TOME_SIZE = 30` over the 25 genres of `Steam::GenreTags`. Rounding volumes of `(n + 15) / 30` gives about 410 for 12,307 cards, fewer when cards fall outside every genre.
  - The 55-minute duration matches what was expected after story 2.10 removed `appdetails` ("minutes rather than hours", `pending-approvals.md` before `d3a768f`).

  *Accept.* This is consistent with the code. It is the author's report, not data read by this run.
- **R2. The 19 games set aside at the store page are what the details step should do.** `Steam::DetailsPolicy::EXCLUSIONS` are `unavailable`, `not_a_game`, `no_title`, `no_vertical_image` and `no_release_date` (`packs/steam/app/models/steam/details_policy.rb:21-26`). The Notes do not break the 19 down by reason. *Accept.*
- **R3. The import ran without two preconditions the author had set.**
  - The neighbouring-genre fold was "to work out before the real import". `pending-approvals.md` still lists it as open.
  - The backlog story `story-import-staging-and-rollback.md` has not landed.

  Season 1 is frozen (AD-5), so each change now applies from season 2 (epic Notes: "a change applies from season 2"). Season 1's 406 tomes are cut on the unfolded genres. *Accept as the author's choice.* The fold carries over to season 2 (open question 2).
- **R4. Calibration kept its starting values without a recorded review.**
  - The Notes say the starting values were kept: `COUNT_WEIGHT = 0.01` (`prestige_score.rb:17`), the tier shares, and `TOME_SIZE = 30` (`set_builder.rb:13`).
  - 2.8's hitl part names "the author's approval of the calibration" (`deferred-work.md` line 52). The author has not yet reported checking the 124 Légendaire names, the sanity check that the top tier holds the games it should.

  Season 1 cannot be recalibrated. *Defer:* the review informs season 2 (action item 1).
- **R5. `pending-approvals.md` no longer tells the truth about its own state.**
  - Its header still says "Nothing here has been run", yet the file now records the staging deploy and the real import.
  - The "Traefik route for staging" and "First staging deploy" items are still listed as pending.
  - The test-LXC operations (`catalog:number_seasons`, the `dust_tier` contract migration, `game:backfill_player_states`) do not say whether they are moot on a fresh staging database.

  *Fix now, as doc hygiene* (action item 3).

### Resolved since 2026-10-03

- **F1. The draft was never pruned.** *Resolved by story 2.11* (`21e511c`, `Catalog::PruneDraft`). The real run struck 0 cards from the draft, as expected on a first run (Notes).
- **F3. One bad app could fail every resume, and a failed run blocked publishing.** *Resolved by story 2.11* (`21e511c`, `2286751`). The real run over 190,718 apps completed with 0 refused and no reported failure. **Residuals,** in `deferred-work.md`:
  - a store title of about 2.7 kB, or a Steam answer that is not valid JSON, still fails its page;
  - a NUL byte in a tag name still fails the tags step.
- **A2, A4.** *Moot* after story 2.10.
- **S4. Tome genres in Steam's order.** *Superseded* by 2.10's most-voted genre tag. The 2.8 risk of hundreds of `indie` volumes no longer applies: Indie is not one of the 25 genres.
- **F6.** *Resolved by epic 4* (story 4.6).
- **F8.** *Resolved or moot* (`queue_config_test.rb`, `steam_import_step_job_test.rb:162`).
- **N4. Calibration still at its starting values.** *Closed as a finding.* The values were kept on purpose after the real run. The open review moves to R4.
- **N3. The development draft met the inclusion rules.** All 498 draft cards had at least 500 reviews, a vertical image, a release date, French and English texts, and a genre (second run, read only). *Carried as supporting evidence for Done when 4.*
- **N2. "Season 1" in development is the seed season.** *Settled by the evidence.* The first Steam season is season 1 on staging, so Done when 3's wording holds there. Development's seed season stays a local matter (open question 4).

### Still open (deferred, tracked)

- **F2.** The rescore variant of the publish-lock race (`deferred-work.md` line 37). *Defer.*
- **F4. Web API rate limits.** No 429 is reported and the run completed in 55 minutes, but the run's error log has not been reported here. *Defer.* Downgraded: the run did not fail.
- **F5.** The AD-5 freeze is enforced only in models (`deferred-work.md` line 40). Now that a real published season exists, this guards owned cards. *Defer.*
- **F7.** The refusal log is capped at 20 lines (`deferred-work.md` line 43). The real run refused 0 cards, so the cap did not bite. *Defer, lowered.*
- **N1. Epic R6 no longer matches the code.** R6 still names the steel … gold tiers and a dust tier from the game's age.
  - Story 8.3 (`a1e4e44`) renamed the tiers `common … legendary`. The back-office shows them as Commune … Légendaire (Notes).
  - Story 8.7 (`b8bae72`) dropped `dust_tier`.
  - Publication now numbers the cards (AD-28).

  *Accept the deviation; reconcile R6* (action item 4).
- **N5. Author preconditions still open:**
  - the genre fold (R3);
  - the import staging and rollback story;
  - seven unconfirmed 2.11 edge-case rules in `pending-approvals.md`.

  None blocks season 1, but all of them shape season 2.

### Diff-scope review

**Narrowed, unchanged from the second run.** `bmad-review` was not re-run. Stories 2.10 and 2.11 carry their own review passes (2.11: two thorough four-lens passes, ending "follow-up review: not recommended"). The seams were checked inline in the second run. No code has changed since (`200521d..HEAD` is docs only).

## Behavior verification

- **Exercised by this run:** nothing new. The tests (505 runs, 0 failures) and the read-only development database reads come from the second run of the day, and no code changed after them.
- **Reported by the author, on staging** (`d3a768f`, epic Notes), not observed by this run:
  - a full real import started from the back-office, all steps through to cards;
  - Steam season 1 published, with tiers and the three kinds of set.
- **Not exercised or not reported:**
  - an interrupted real run resuming. Story 2.1's manual kill-and-restart check was meant for the same real run (`deferred-work.md` line 52), and the Notes do not mention one;
  - players seeing the published cards, and the per-card fields, on staging;
  - the abandon flow in a browser;
  - the Légendaire names (R4).

## Previous-retro follow-through

Action items of the second run (2026-10-06, `200521d`):

1. **Run the real import, calibrate, and publish the first Steam season** (the author). **Landed, author-reported:** `d3a768f`, epic Notes Measurement lines.
   - Sub-step 1, settle the preconditions: **not landed.** The import ran without them (R3, N5).
   - Sub-step 2, choose the database: staging. **Landed.**
   - Sub-step 3, watch for 429s: none reported (F4).
   - Sub-step 4, record the counts: **landed** for listed, kept and refused counts and tier and tome sizes. Per-step durations were not recorded, only the total of 55 minutes.
   - Sub-step 5, calibrate: the starting values were kept. The review is not reported (R4).
   - Sub-step 6, re-run this retrospective: this run.
2. **Close ticket 2.8 and mark the epic's tickets done** (the author, through `bmad-ticket`). **Not landed:** `tickets.py status` shows all eleven tickets `built` / `review`. `deferred-work.md` line 52 is still open.
3. **Revisit F7** (conditional). **Condition not met:** 0 cards refused.
4. **Harden the Web API rate-limit path** (conditional). **Condition not met:** the run did not fail.
5. **Reconcile R6 and Done when 3** (the author). **Partly moot:** Done when 3's "season 1" now holds on staging. **R6 not landed:** `epic-steam-catalog.md` R6 still names steel … gold and the dust tier.
6. **Run epic 1's retrospective** (the orchestrator). **Not landed:** `epic-foundation-and-steam-sign-in/` has no retrospective file.

## Action items

All items are **proposed, not applied.** This run wrote only this file.

1. **Review the calibration on season 1's real data, for season 2** (R4). Owner: **the author (hitl)**. Check the 124 Légendaire names and the 492 Épique, the tome sizes after the genre fold (R3), and, if needed, change `COUNT_WEIGHT`, `SHARES` or `TOME_SIZE` before season 2's import. Record the approval, or the changes, in the epic Notes.
2. **Close 2.8 and the epic** once item 1 is recorded, or now if the author judges season 1's calibration accepted as is. Owner: **the author, through `bmad-ticket`**. Steps:
   1. Mark the eleven tickets done.
   2. Close the `deferred-work.md` line 52 entry. Its remaining part, story 2.1's real kill-and-restart check, is either moved to a new entry or dropped explicitly.
3. **Bring `pending-approvals.md` up to date** (R5). Owner: **the orchestrator, with the author's confirmation**. Steps:
   1. Fix the header.
   2. Settle or remove the Traefik and first-staging-deploy items.
   3. Say which test-LXC operations (`number_seasons`, the `dust_tier` contract migration, the player-state backfill) are moot on staging's fresh database.
4. **Reconcile R6 with the as-built** (N1). This is a spec reconciliation. Owner: **the author**. R6 should name tier codes `common … legendary` (AD-28, story 8.3), drop the dust tier (story 8.7), and add card numbers at publication.
5. **Run epic 1's retrospective**, carried from the 2026-10-03 run's item 8(e). Owner: **the orchestrator**.
6. **Keep the deferred items tracked:**
   - F2, F5 and F7;
   - F4, rechecked against the staging run's error log if the author can read it;
   - the 2.11 residuals;
   - N5's preconditions, which apply before season 2.

   Owner: **dev loop and the author**. Nothing new to file: each one already has its `deferred-work.md` or `pending-approvals.md` entry.

## Acceptance verdict

**Machine verdict: `accepted-with-open-items`**, against **declared** criteria, with **no human decision.** No ticket is unfinished (`pending_tickets` empty). Every Done-when criterion is now met, on the author's report of the staging run read with the code. No blocking finding stands. The open items are tracked (above).

| # | Criterion | Evidence now | Status |
|---|---|---|---|
| 1 | Start an import from the back-office and see its step, counts and errors | System and controller tests (green). Development run 4. The staging run's counts were read by the author from the back-office (Notes). | **Met** |
| 2 | An interrupted import resumes without restarting and without duplicate cards | Cursor guards, stall recovery and the resume tests, including 2.11's multi-page fail/resume prune test. Story 2.1's local kill check. Unique `source_key`. The real run was not interrupted, so there is no real-run evidence. | **Met** (tests and one local manual check) |
| 3 | Publishing season 1 makes its cards visible at once, each with a tier, a release date, FR/EN title and description, and its sets | Season 1 published on staging at 15:02:33 UTC with 12,307 cards, every card in one of the five tiers (the counts sum to 12,307) (Notes). Each written card has a release date and a title by construction (`DetailsPolicy` excludes `no_title` and `no_release_date`). French falls back to English where Steam gives none (`details_policy.rb`, verdict). Player-side visibility on staging is not reported. | **Met** (author-reported; per-card fields by construction) |
| 4 | No game in the catalog with fewer than 500 reviews or without a vertical image | Kept means 500 reviews or more (Notes). `DetailsPolicy` excludes `no_vertical_image` before a card is written. The 19 games set aside at the store page are this filter at work (R2). The development draft had 0 of 498 cards in breach (N3). | **Met** (by construction, with a consistent real-run report) |
| 5 | The published season contains publisher sets, tomes and best-of-year sets | 380 publisher sets, 406 tomes and 37 best-of-year sets in staging season 1 (Notes). | **Met** |

**Why not `accepted`:**
- R4: the calibration review has not been reported.
- R5: `pending-approvals.md` is out of date.
- N1: R6's wording is out of date.
- Epic 1's retrospective is missing.
- F2, F4, F5, F7 and the 2.11 residuals are deferred.
- The real-run evidence is the author's report. This run could not read the staging database.

A human decision overrides this verdict.

## Open questions

1. **Is season 1's calibration accepted as published?** The author has not reported the Légendaire check (R4). The answer decides whether item 1 is a season 2 task or a formality.
2. **The neighbouring-genre fold:** which tags fold into which, now for season 2 (R3)?
3. **Must the import staging and rollback story land before season 2's import?** It changes AD-5 and AD-19.
4. **Development's seed season 1:** keep it, or align development with staging? This is a local matter only.
5. **The 2.11 edge-case rules** in `pending-approvals.md` still await confirmation.
6. **French tag labels:** still open in the spec.
7. **Did the staging run log any errors** (429s, page failures that resumed)? This would settle F4 and F7.

## Assumptions

Headless run (`-H _bmad-output/initiative-gameble/epic-steam-catalog`). Every choice below was made without the user.

- **Epic resolution:** the folder was given. `tickets.py status` returned 11 rows, all `built` / `review`. `pending_tickets` is empty.
- **Resumed run:** the existing file (second run, `200521d`) was loaded. Its findings were reconciled against `d3a768f`, and the file was rewritten in place. Ids carry over. Development-database and test-suite results are carried from the second run, because no code changed since.
- **The staging figures were taken as evidence on the author's report.** The caller relayed them, and `d3a768f` records them in the epic Notes. This run had no access to the staging database or host and verified them only for internal consistency and against the code (R1, R2). If they prove wrong, the verdict falls back to `rejected`.
- **The verdict:** `accepted-with-open-items` was rendered from the evidence alone. No human decision was taken.
- **Criterion 2** is judged met on tests and the local check, as in earlier runs. The real run's lack of an interruption is not counted against it.
- **Criterion 3's "visible at once"** is judged on the publication being reported and on `PublishSeason` making a season visible in one step (tested). Player-side visibility on staging was not reported.
- **The missing Légendaire check** was treated as a calibration review (2.8's hitl approval), not a Done-when criterion, so it is an open item rather than a blocker.
- **Narrowed scope:**
  - no `bmad-review` re-run;
  - no test re-run;
  - no session logs;
  - no staging access.
- **Every action item is proposed and owned as stated.** None was applied. No ticket, plan, epic file or code was changed.
- **Team discussion (Phase 3)** did not run (headless).
