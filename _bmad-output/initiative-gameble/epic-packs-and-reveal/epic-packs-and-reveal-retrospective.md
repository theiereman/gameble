---
epic: epic-packs-and-reveal
date: 2026-10-03
verdict: accepted-with-open-items
criteria: declared
headless: true
---

# Retrospective: Packs and reveal (epic 3)

## Epic summary

**Epic:** `epic-packs-and-reveal` (id 3), `_bmad-output/initiative-gameble/epic-packs-and-reveal/epic-packs-and-reveal.md`. Covers CAP-4, CAP-5, CAP-16; requirements R1–R9; six Done-when criteria.

**Tickets** (from `tickets.py status`, in build order): every ticket has `status = built` and `state = review`. `pending_tickets` is empty. None is marked done; the author has not closed them.

| Ref | Title | Status | Plan baseline | Own commit (from subject) |
|---|---|---|---|---|
| 3.1 | Open a pack, end to end | built | `6891e36` | `3577e96` |
| 3.2 | Replacement packs and the timer | built | `9afcebe` | `4ddebaf` |
| 3.3 | First-session guarantee | built | `3577e96` | `55ca9d3` |
| 3.4 | Pixel-art image filter package | built | `6891e36` | `6ff154f` |
| 3.5 | Card component | built | `55ca9d3` | `e5f9e6b` (+ `9afcebe` docs) |
| 3.6 | Pack reveal island | built | `f922b42` | `de6247a` |
| 3.7 | Daily bonus booster | built | `4ddebaf` | `f922b42` |
| 3.8 | Signed-out attic | built | `de6247a` | `32d3beb` |
| 3.9 | Pack opening at 200 ms | built | `4ddebaf` | `1b36aaf` |
| 3.10 | Refactor sweep | built | `32d3beb` | `9a85700` |

**Ranges.** These are derived from the plans' `baseline_revision`, oldest first, each running to the next baseline. `git_evidence.py` was run once per distinct range.

| Range | Tickets | Commits in range |
|---|---|---|
| `6891e36..3577e96` | 3.1, 3.4 (shared baseline) | `6ff154f`, `3577e96` |
| `3577e96..55ca9d3` | 3.3 | `55ca9d3` |
| `55ca9d3..9afcebe` | 3.5 | `e5f9e6b`, `9afcebe` |
| `9afcebe..4ddebaf` | 3.2 | `4ddebaf` |
| `4ddebaf..f922b42` | 3.7, 3.9 (shared baseline) | `f922b42` |
| `f922b42..de6247a` | 3.6 | `1b36aaf` (3.9's commit), `de6247a` |
| `de6247a..32d3beb` | 3.8 | `32d3beb` |
| `32d3beb..9a85700` | 3.10 | `9a85700` (cut: HEAD has since moved on with epic 4 commits `9fcb676`…`b818a88`) |

Across the whole epic (`6891e36..9a85700`): 11 commits, no merges (`merge_count 0`), 156 files, +8,911 / −288 lines, including plans and generated SVG assets. The mechanical ranges misattribute work: 3.9 has an empty range of its own, and its commit sits in 3.6's range. Each commit was therefore attributed by its subject, as shown in the first table (finding P2).

**Evidence inventory.**

- Available:
  - the epic file and the initiative file;
  - `tickets.toml`;
  - ten plans, each with a Review Triage Log (no plan has dated `### <date>` Code Review blocks);
  - `deferred-work.md`;
  - `pending-approvals.md`;
  - the architecture spine;
  - git history;
  - session log `~/.claude/projects/-home-teyermann-projets-gameble/16906cad-8d2e-44f7-b728-8e8e3d26e2ca.jsonl`, the orchestrator session that built epics 2–4 on 2026-10-02.
- Missing:
  - story files: no ticket was refined, and `file = null` for all;
  - a previous retrospective (see Previous-retro follow-through);
  - transcripts of the subagents that built each story (only their hand-back reports exist in the orchestrator log).

The process analysis is therefore narrowed to what the orchestrator log and the plans show.

**Working-tree note.** At retro time, the working tree holds uncommitted work from another agent (story 4.3) and today's uncommitted document edits:

- the AD-7 amendment in `architecture-gameble.md`;
- the confirmed bonus odds in `spec-gameble.md`.

Code was read at `9a85700` (`git show`), not from the working tree.

## Findings

Dispositions: **fix now** (becomes an action item), **defer** (tracked with enough context), **accept** (recorded so later runs stop re-flagging it). Lens findings come from `bmad-review`, run on the code diff `6891e36..9a85700` (plans, generated `app/frontend/images/` assets and `package-lock.json` excluded) with three lenses: adversarial (ADV), edge-case-hunter (EC) and verification-gap (VG). Each finding used in an action item was re-checked against the source at `9a85700`.

### Aggregate view: architecture delta

- **A1. The pack boundaries held (positive).**
  - `packs/game/package.yml` declares `Game → lib, Accounts, Catalog` (AD-2), unchanged by the epic.
  - Game reads Catalog only through queries: `Catalog::PublishedSeason`, `PublishedCardSeasonsByTier` in `draw_pool.rb`.
  - It reads Accounts only through `PlayerById` and the new `PlayersInBatches`.
  - No model association crosses packs (`pack.rb` header).
  - The rake tasks moved into `packs/game/lib/tasks/` because `lib/` may not reference Game (3.2 Implementation Notes).
  - No cycle was introduced.
  - Scope note: packwerk was not re-run by this retro; the plans' Verification sections record it green.
  - Disposition: accept.
- **A2. A third React island exists that AD-16 does not allow.**
  - AD-16 (`architecture-gameble.md:164`) allows React "for the pack reveal and the trade board only".
  - Story 3.5 registered a back-office `CardPreview` island and recorded the exception only in its plan (`story-card-component-plan.md:143`).
  - Disposition: defer, as a spec reconciliation (action item 5).
- **A3. AD-7 was amended to the as-built design.**
  - Replacement packs are drawn inline by `Game::TopUpBank` (`packs/game/app/models/game/top_up_bank.rb`), with no job.
  - The author approved this today. The AD-7 amendment is present in the working tree (`architecture-gameble.md:94`) but not yet committed.
  - Disposition: accept (approved). Committing it is part of action item 5.

### Aggregate view: duplication map

- **D1. The pack-row hash is built in three places.**
  - `FillBank#insert_packs` (`fill_bank.rb:42-45`) and `TopUpBank.call` (`top_up_bank.rb:27-31`) build `{ player_id, token: Pack.generate_unique_secure_token, kind, season_id, card_season_ids, available_at }`.
  - `CollectDailyBonus` (`collect_daily_bonus.rb:37-38`) builds the same through `Pack.create!`.
  - These are small and consistent today. The epic-6 reward packs will add a fourth writer.
  - Disposition: defer, until a fourth writer is added.
- **D2. Duplication removed during the epic (positive).**
  - The rate-limit counting workaround was folded into `test/support/counting_rate_limit.rb` (3.10).
  - `DailyBonusClaim.day_of` is shared by the operation and `BankSummary` (3.7).
  - `CardSeasonLabels` was retired once `CardViews` replaced it (3.6 Implementation Notes).
  - Disposition: accept.

### Aggregate view: size growth

- **S1. No god-class (positive).** The largest code files the epic produced are:
  - `app/frontend/styles/card.css` (334 lines);
  - `packs/game/lib/tasks/game_benchmark.rake` (331 lines, a self-contained benchmark class by design, per 3.9 Implementation Notes);
  - `reveal.css` (285);
  - `PackReveal.tsx` (258).

  The most-touched code files are `fill_bank.rb` (5 commits, net +55), `home.html.erb` (4 commits, +45) and `pack.rb` (3 commits, +40), all still small. Disposition: accept.

### Aggregate view: pattern divergence

- **PD1. Write steps live as modules in `app/models/game/`.**
  - `TopUpBank`, `BankLock`, `FirstSessionGuarantee` and `DrawPool` sit there, while the entry points are operations.
  - AD-3 ("written only through the operations") still holds, because these steps are only called under an operation's lock and transaction.
  - The pattern is consistent within the epic.
  - Disposition: accept.

### Aggregate view: spec-to-implementation reconciliation

- **R-1. The epic's own text lags today's decisions.**
  - `epic-packs-and-reveal.md` R4 still says `Game::OpenPack` "enqueues the draw of the replacement".
  - Its Notes still list "Open question: odds of the daily bonus booster … Assumption until the author decides".
  - The author confirmed the odds today, and the spec now states them (`spec-gameble.md:106`). They match `Game::DrawOdds::BONUS`: emerald 70 %, sapphire 24 %, amethyst 5 %, gold 1 %, 3 cards.
  - Disposition: defer, as a spec reconciliation (action item 5).
- **R-2. The other documents also lag those decisions.**
  - The initiative Notes still list the booster odds as an open question (`initiative-gameble.md`, Notes).
  - The architecture's Deferred section still lists "booster odds" (`architecture-gameble.md:365`).
  - `pending-approvals.md` still lists five epic-3 items as awaiting a decision:
    - the bonus odds;
    - the AD-7 deviation;
    - the large card back;
    - the tier cues on a dusty back;
    - the reveal phone breakpoint.

    The author settled all five today: two approved, three deferred to the bmad-ux redesign.
  - Disposition: defer, as a spec reconciliation (action item 5).
- **R-3. The boot warm-up of the draw pool was dropped (resolved).**
  - Story 3.2 assumed "story 3.9 warms the pool at boot". 3.9 measured the cold build at 25–34 ms, under its 50 ms bar, and dropped the warm-up.
  - This is recorded in the 3.9 Implementation Notes and the epic Notes.
  - Disposition: accept.
- **R-4. Visitor button wording differs from the plan (resolved).**
  - Story 3.8's visitor buttons read "Enlist through Steam to …", not the plan's literal wording.
  - This is recorded in that plan's Change Log.
  - Disposition: accept.

### Diff-scope review: cross-story boundaries

The three-lens pass found these. The per-story "quick" reviews did not.

- **B1. On a phone, "flip all" hides most of the pack** (ADV 6, ADV 7). *Verified.*
  - Location: `app/frontend/components/PackReveal.tsx:138-148,181-184,224`.
  - In the phone layout, `runFlipAll` moves the view only to gold cards (`onStep`), and then to the last card (`onEnd: setCurrent(last)`).
  - There is no "previous" control, and "next" shows only while `current < last`. The non-gold cards that flip all turned are therefore never shown in the island.
  - `setCurrent` there also does not set `focusShown`, so the focused card's `<li>` unmounts and focus falls to `<body>`.
  - Effect: a phone player who taps flip all sees one or two of their cards, and must reload the pack page (faces) to see the rest. This weakens Done-when 3 "on phone".
  - Disposition: **fix now** (action item 1).
- **B2. Bank operations from different stories are never raced against each other in a test** (VG 1).
  - All four bank operations take `Game::BankLock`: `OpenPack`/`TopUpBank` (3.2), `FillBank` (3.1/3.3), `CollectDailyBonus` (3.7) and `HealBank` (3.2/3.10).
  - The only concurrency tests race an operation against itself: `open_pack_concurrency_test.rb:31` and `collect_daily_bonus_concurrency_test.rb:28-34`.
  - A regression in lock placement in `HealBank` or `FillBank` could double a bank during a season publication, and no test would fail.
  - Disposition: **fix now**, test only (action item 2).
- **B3. The reveal's failure path is untested** (VG 2).
  - `RevealErrorBoundary` (`RevealErrorBoundary.tsx:13-28`) is never triggered by a test.
  - The `:has()` rule that hides the server fallback once the island draws (`reveal.css:269`) is never asserted. The only test asserts that the fallback is present (`packs_controller_test.rb:75`).
  - Disposition: **fix now**, test only (action item 2).
- **B4. Some players can be left with no bank until the next publication** (ADV 2, EC 4).
  - Banks are filled only:
    - on sign-up (`player_registered.rb`);
    - on `SeasonPublished` (`HealBanksJob`);
    - before a daily bonus.
  - Three cases slip through:
    - a sign-up whose fill read "no season" but which committed after `HealBanksJob` read its batch;
    - a player banned at publication and later unbanned (`PlayersInBatches` skips banned players);
    - accounts created before epic 3 is deployed, against an already-published season.
  - Such a player sees a disabled chest with no countdown.
  - Disposition: defer to before the first deploy (action item 6).
- **B5. `HealBanksJob` reports per-player failures but never retries them** (ADV 1).
  - The job rescues each player's `StandardError`, reports it and moves on (`heal_banks_job.rb:16-19`).
  - The manual path, `game:top_up_banks`, refuses production (3.2 Implementation Notes).
  - A transient error during a publication therefore leaves that player without a bank.
  - Disposition: defer, with B4 (action item 6).
- **B6. Healing an emptied bank schedules every pack in the future** (ADV 11). *Verified.*
  - `HealBank` schedules the missing packs at now + 10, +20 … +100 min (`top_up_bank.rb:26-31`, `start = max(now, latest)`).
  - A never-banked player in the same job gets ten packs available at once (`FillBank`).
  - This is a product rule nobody decided.
  - Disposition: defer, for an author decision (action item 6).
- **B7. The countdown is keyed on its integer seconds value** (EC 1–2, ADV 8; overlapping lenses).
  - After the zero refresh, a morph that brings the same value (the 598–599 cluster that 10-minute spacing produces) does not fire `secondsValueChanged`.
  - The clock then sits at 00:00 for the 5 s retry, with one extra refresh (`countdown_controller.ts:53-58`).
  - Related gaps:
    - nothing resumes the countdown after the device sleeps (EC 3);
    - `submitting` clears only on `turbo:load`, or on a failed `turbo:submit-end`, so a future turbo-stream or frame form on the same page would freeze it (ADV 9);
    - no test covers a failed submission resetting it (VG 3).
  - Disposition: defer. The attic's countdown placement is part of the UX redesign (action item 4).
- **B8. Screen-reader users get an absolute UTC time, not a relative countdown** (ADV 13).
  - `home.html.erb:48` and `en.yml` give "Next pack at %{time} (UTC)", while sighted users see a relative countdown.
  - The audience is mostly French, at UTC+1/+2.
  - Disposition: defer to the UX redesign (action item 4).

### Diff-scope review: other findings

- **O1. CI never builds the Docker image** (VG 4).
  - The npm-workspace `COPY packages/pixel-art-filter/package.json` in `Dockerfile:56-58` is verified by reading only, as 3.4's Verification says. No CI job builds the image (`.github/workflows/ci.yml`).
  - Disposition: defer, with the deployment work already in `deferred-work.md` (action item 7).
- **O2. `card_season_ids` has no database check on length or kind** (ADV 4).
  - The column is a bare `bigint[]`.
  - A bad row at the head of the queue would make every later `OpenPack` for that player fail on the same pack.
  - Only the operations write it today.
  - Disposition: defer, until a new writer is added (the epic-6 reward packs).
- **O3. A failing fill blocks sign-up** (ADV 3).
  - The fill runs synchronously inside the sign-up transaction and rolls it back on failure. `SessionsController` rescues any `StandardError` into "sign-in failed".
  - This is deliberate per 3.1's Boundaries: "a player is never created without a bank while a season is published".
  - Disposition: accept, but revisit together with B4. The broad rescue also masks Accounts bugs as a user message.
- **O4. Two tabs share one reveal flash slot** (ADV 10).
  - Openings in two tabs share `flash[:reveal]`, so one of the two reveals is lost.
  - This overlaps 3.6 review row 7, already accepted and recorded in `deferred-work.md`.
  - Disposition: accept.
- **O5. `HealBanksJob` walks every player on each publication** (ADV 12).
  - Each player costs about six queries, even for a full bank.
  - Disposition: defer, to measure before launch scale.
- **O6. Unreachable 500 on the result page** (ADV 5).
  - `PacksController#show` raises on a card without a view in the URL's locale (`views.fetch`).
  - This cannot happen: `Catalog::UpsertDraftCard` writes a text in every locale (`upsert_draft_card.rb:80`), and publication cuts every card.
  - Disposition: accept.
- **O7. A raising draw pool returns 500** (EC 7).
  - `DrawPool::EmptyTier` cannot happen, because `Catalog::PublishSeason` refuses an empty tier (`Failure(:empty_tier)`).
  - The remaining "season kept changing" raise needs three publications in one draw.
  - Disposition: accept.
- **O8. Smaller edge cases.**
  - A three-digit season number would overflow the season seal (EC 6).
  - A player banned mid-job is reported as an error (EC 5).
  - Disposition: accept / defer (low).
- **Dropped.** EC 8 claimed that the first-session guarantee contradicts its commit message. This is false: the plan's Boundaries say the tenth pack is left alone when it already holds a tier-3+ card, and the code does exactly that.

### Process lessons (orchestrator log and plans)

- **P1. Every story ran a single "quick" review, pinned.**
  - All ten plans have `review: 'quick'`, `review_source: 'pinned'` and `lenses_ran: ['quick']`, including risk-high stories 3.1 and 3.6.
  - The session log shows one "Quick review of story 3.x" subagent per story.
  - The quick reviews caught in-story defects well: 26 patched findings across the triage logs. But the boundary defects B1–B3 and B7 only surfaced under the three-lens pass here.
  - Disposition: process change (action item 8).
- **P2. Plan baselines do not delimit a story's work.**
  - 3.1 and 3.4 share baseline `6891e36`, and 3.7 and 3.9 share `4ddebaf` (parallel lanes).
  - 3.9's commit `1b36aaf` lands inside 3.6's baseline range.
  - Commits had to be attributed by subject. No plan records its own commit.
  - Disposition: process change (action item 8).
- **P3. An unattended build left decisions waiting, and the documents unreconciled.**
  - The epic was built while the author was away. The session log at 2026-10-02T17:30Z says: "ne fais pas les opérations qui pourraient être sensibles en mon absence".
  - Five product and visual assumptions were therefore queued in `pending-approvals.md`. That worked as intended.
  - But once they were decided, the epic, initiative, architecture and approvals files were not reconciled (R-1, R-2).
  - Disposition: process change (action items 5 and 8).
- **P4. No story was marked hitl, though some checks need a person.**
  - Every ticket has `hitl = false`. Yet some checks can only be done by a person:
    - the touch slide on a real phone (3.6 matrix row "Touch slide", "manual check");
    - card art from a real Steam image (tests use a bundled sample; 3.4 checked Steam's CORS header by hand on 2026-10-02).
  - Neither check is recorded as done.
  - Disposition: process change, plus manual checks (action items 8 and 9).
- **P5. What worked (positive).**
  - Every deviation was recorded where a reader would find it: 3.2 AD-7, 3.8 wording, 3.9 rate-limit store order.
  - The refactor sweep (3.10) cleared the deferred benchmark re-run and logged every rejected or deferred finding in `deferred-work.md`.
  - The 200 ms gate has a repeatable benchmark with a large margin.

## Behavior verification

**Not exercised by this retrospective.**

- The caller's constraints for this run forbid running the test suite, and another agent is building story 4.3 on `main`.
- The working tree mixes this epic's code with uncommitted 4.3 changes (for example `app/views/packs/show.html.erb` and `config/routes.rb`). Running the app would not exercise the epic's state alone.
- The benchmark was not re-run either: it needs the test build, and it was measured as distorted by a concurrent suite (epic Notes, 3.9).

Recorded evidence from the build, not re-observed here:

- The benchmark figures in the epic Notes:
  - POST `/en/packs` worst p95 9.3 ms (3.9), then 8.8 ms after the reveal (3.10);
  - result-page GET p95 7.5–8.1 ms.
- Each plan's Verification commands, recorded as green by its build.
- The system tests for the reveal (`test/system/pack_reveal_test.rb`, including a 390 × 844 phone window), the countdown, the daily bonus and the signed-out attic.

The phone flip-all defect (B1) is an example of what end-to-end use would have shown and the existing system test does not assert: the phone test asserts that gold cards are held, not that every card can be seen.

## Previous-retro follow-through

**Nothing to follow through on: no previous retrospective exists.**

- The previous epic in the `epics` order is `epic-steam-catalog` (id 2). Its folder holds no `epic-steam-catalog-retrospective.md`.
- Epic 1 has none either.

This is a missing file, not "no outstanding items". Epic 2's rejected and deferred findings are tracked only in `deferred-work.md`.

## Action items

Remediation items are proposed for the normal dev loop. Spec reconciliations are proposed for the author to apply. Nothing was applied by this retrospective.

1. **Phone reveal: let the player see every card after flip all, and keep focus** (B1). Proposed remediation.
   - In `PackReveal.tsx`, either:
     - step the view through every card during flip all, still holding each gold card its full length; or
     - add a "previous" control or selectable progress positions.
   - Set `focusShown` before each `setCurrent` that flip all makes.
   - Extend the phone system test to assert that every card is shown.
   - Owner: dev loop (`bmad-build`), as a small story, or folded into the epic-4 refactor sweep (4.6) if the author prefers.
2. **Add the missing boundary tests** (B2, B3). Proposed remediation, tests only.
   - Non-transactional thread tests: `HealBank` × `OpenPack` on a short bank, and `FillBank` × `CollectDailyBonus` for a bankless player. Assert ten regular packs and unique scheduled times.
   - Reveal system tests: the fallback is hidden once the island draws, and a forced island failure shows the error boundary with its link to the faces.
   - Owner: dev loop.
3. **Commit today's AD-7 amendment.** It is currently uncommitted in the working tree (`architecture-gameble.md:94`). Do this once story 4.3's agent has finished. Owner: author.
4. **Hand the countdown and the attic-specific findings to the UX redesign** (B7, B8; the three deferred visual decisions). Proposed input to the `bmad-ux` session.
   - The countdown should key on the target instant, not the seconds left.
   - It should resume after sleep or visibility changes.
   - Its accessible text should be relative or in the viewer's zone, not UTC.
   - The redesign also absorbs:
     - the large card back;
     - the tier cues on a dusty back;
     - the reveal phone breakpoint;
     - the signed-out chest and panel (3.8), whose attic-object form the menus will replace.
   - Owner: author (bmad-ux), then the dev loop.
5. **Reconcile the documents with today's decisions** (R-1, R-2, A2). Proposed spec reconciliation.
   - Epic file: R4 should say the replacement is drawn inline by `Game::TopUpBank`. The Notes' booster-odds open question becomes a decision dated 2026-10-03.
   - `initiative-gameble.md` Notes: close the booster-odds half of the open question (the weekly-goal rare pack odds stay open).
   - `architecture-gameble.md` Deferred: remove "booster odds".
   - AD-16: record the back-office `CardPreview` island as an allowed exception, or forbid it.
   - `pending-approvals.md`:
     - mark the bonus odds and the AD-7 deviation as approved;
     - move the large back, the dusty-back tier cues and the phone breakpoint under the UX redesign;
     - mark the epic-3 breakdown as reviewed, if it was.
   - Owner: author, or the orchestrator with the author's go-ahead.
6. **Make bank healing robust before the first deploy** (B4, B5, B6, O3). Proposed remediation, plus one author decision.
   - Self-heal at the point of use: `OpenPack` or the attic fills a bankless player while a season is published.
   - Re-enqueue the players whose fill failed (per-player job with `retry_on` for deadlock or lock timeout).
   - Decide whether a healed, emptied bank starts with one pack available now, and record the rule in AD-7.
   - Owner: author (B6 decision), then the dev loop.
7. **Build the Docker image in CI, or as a pre-deploy check** (O1). Add this to the existing Kamal/deploy deferred work. Owner: dev loop, with the deploy story.
8. **Process changes for the next epics** (P1–P4). Proposed.
   - Run the full lens set (adversarial, edge-case, verification-gap) for `risk = "high"` stories instead of the pinned quick review, and run one cross-story lens pass before the refactor sweep.
   - Record each story's own commit in its plan (for example a `built_revision`), so retros can attribute work without guessing.
   - Set `hitl = true` on stories whose Verify needs a real device or a real external service.
   - After the author settles a `pending-approvals.md` item, reconcile every document that cites it in the same change.
   - Owner: author (bmad configuration) and orchestrator.
9. **Manual checks still owed** (P4). Owner: author.
   - The touch slide (wipe by finger) on a real phone.
   - One card face drawn from a real Steam vertical image in development.
   - The pack-opening p95 in production once deployed. Initiative Done-when 3: the epic's figure is an in-process dev-machine lower bound.

Also proposed, for whoever next edits `deferred-work.md`: record the deferred findings B4–B8, D1, O2 and O5 there, so the epic-4 sweep sees them. This retrospective does not edit that file.

## Acceptance verdict

**Machine verdict: accepted-with-open-items.** The criteria are declared, from the epic file's Done when. Every ticket is finished (`built`), and `pending_tickets` is empty.

| # | Done when | Evidence | Met |
|---|---|---|---|
| 1 | Ten packs at sign-up, sapphire or better by the tenth | `FillBank` (`fill_bank.rb`), `FirstSessionGuarantee`; 3.3 plan: a 2,000-fill test plus a stubbed all-steel draw asserting the forced card in pack 10 | Yes |
| 2 | Five pre-drawn cards credited; opening without a pack refused | `OpenPack` (`open_pack.rb`); `Failure(:no_pack_available)`; 3.1 matrix rows "No pack / future pack", "Race on the last" | Yes |
| 3 | Dust by age, seal on wipe, game on flip, desktop and phone; flip all never skips a legendary | 3.6: `reveal.ts` scheduler (Vitest), `pack_reveal_test.rb` incl. 390 × 844 | Yes, with an open item: B1 (phone flip all hides non-gold cards); touch slide unchecked on a real phone |
| 4 | Vertical Steam image, pixelated, 16 colours in the browser | `packages/pixel-art-filter`; `card_art.ts`; card preview system test (bundled sample) | Yes, with an open item: never exercised on a real Steam image |
| 5 | Daily bonus once per UTC day, second attempt refused | `CollectDailyBonus`, unique `(player_id, day)`; 3.7 tests incl. concurrency and day boundary | Yes |
| 6 | Opening within 200 ms p95 | Epic Notes: worst POST p95 9.3 ms, then 8.8 ms (15,000-card season) | Yes, on a dev-machine lower bound; production unmeasured |

No blocking finding stands. B1 is a real defect against criterion 3 on a phone, but the cards are credited and shown face up on the pack page. The remaining items are tracked above.

No human decision was taken on this verdict in this headless run. The author may override it. Closing the epic (marking the tickets done) is `bmad-ticket`'s job, with the author's confirmation; this run changed no status.

## Open questions

- **B6.** Should a bank that is healed after being emptied start with a pack available at once, like a new player's, or wait ten minutes?
- **B1.** Should the phone reveal offer free navigation between cards (previous and next), or only step through every card during flip all? The UX redesign may decide this.
- **A2.** Should back-office React islands (the card preview) be allowed by AD-16?
- **Ticket closure.** Does the author want epic 3's tickets marked done now, with action items 1–2 as new work, or held at `built` until item 1 lands?

## Assumptions

Made without the user in this headless run:

- The epic reference `epic-packs-and-reveal` resolved by slug to `_bmad-output/initiative-gameble/epic-packs-and-reveal/` (`tickets.py status`, epic id 3).
- `pending_tickets` was empty: all ten tickets are `built`. No unfinished ticket forced the verdict.
- The machine verdict **accepted-with-open-items** was rendered with no human decision.
- Ranges came from plan baselines, cut at `9a85700` (the epic-3 refactor sweep). Later commits are epic 4's. Commits were attributed to stories by their subjects where the baselines overlap.
- The diff review excluded plans, generated `app/frontend/images/` assets and `package-lock.json`. Code was read at `9a85700`, not from the working tree, which holds another agent's uncommitted 4.3 work.
- The author's statements relayed for this run were treated as decisions already taken: the AD-7 deviation approved and amended, the bonus odds confirmed, and three visual decisions deferred to a bmad-ux redesign. The routing of B7, B8 and the attic-specific items to that redesign follows from the last of these.
- No behavior check was run, under the run's constraints (no test suite; a concurrent agent on `main`).
- Every action item is a proposal; none was applied. This document is the only file written.
