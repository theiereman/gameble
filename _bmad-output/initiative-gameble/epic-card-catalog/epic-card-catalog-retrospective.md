---
epic: epic-card-catalog
date: 2026-10-20
verdict: accepted
criteria: declared
headless: true
---

# Retrospective: Every card of the game, browsable and searchable

## Epic summary

Epic `epic-card-catalog` (14), retro run headless on the folder `_bmad-output/initiative-gameble/epic-card-catalog`. `tickets.py status` returns nine rows, all finished (`pending_tickets` is empty): eight `done`, one `dropped`.

| Ref | Ticket | State | Commit on develop |
|-----|--------|-------|-------------------|
| 14.1 | A card not owned and the visitor's catalog designed (hitl) | done | c3fd9943 (docs(ux)) |
| 14.2 | A card not owned shows its face in the grid | done | afe6d9b3 |
| 14.3 | The card detail shows the face of a card not owned | done | 7649120e |
| 14.4 | A visitor browses every card with no ownership data | done | 7a8b899e |
| 14.5 | A visitor's way in to every card (hitl) | done | 3feb5033 |
| 14.7 | A visitor's collection entry suggests sets to discover | dropped (built, then removed by 14.8) | 3278d2c3 |
| 14.6 | Refactor sweep | done | 82fabc5b |
| 14.8 | A visitor reaches only the landing, the catalog and the shared pages | done | f87b3f56, 42c9d71c |
| 14.9 | A visitor reads the feed and has a tab bar of their own | done | b67cd2eb |

Out-of-ticket commit in the epic's window: 3d03a251 (the draw pool reset before every test, a flaky-test fix found while building this epic). Staging: v0.1.4-rc.1 carried 14.2–14.7 (author's review 63c56fa8: 14.2–14.6 done, 14.7 dropped, 14.8 opened); v0.1.5-rc.1 carried 14.8–14.9 (author's review 1de08482: both done).

**Ranges.** The builds ran in parallel worktrees and were cherry-picked onto develop, interleaved with other epics' commits (35 commits in c3fd9943^..1de08482, of which the ten above are this epic's). The plans' `baseline_revision` values are develop commits, but each plan's `commit` field names the worktree commit, not the develop one (see F-P1), so the per-plan baseline-to-baseline range would mix in other epics' work. The ranges used are therefore one commit each, the develop cherry-picks listed above, matched by subject; `git_evidence.py` was run once over c3fd9943^..1de08482 (35 commits, 0 merges) for the window, and per-file churn was summed over the ten commits only.

**Evidence inventory.**
- Available: the epic file, `tickets.toml`, eight story files, nine plans (14.1's is a stub with no build), the ten commits, the two staging review commits, EXPERIENCE.md and the spec.
- Missing: session logs (the process lessons below rest on plans, commit messages and ticket notes only); a follow-up review for 14.8, which its plan recommended (F-P3); any browser observation by an agent.

## Findings

Each finding has a source and two dispositions: what to do now, and what would prevent the next one.

### Spec-to-implementation reconciliation

- **F-S1. The spec still describes the signed-out hub that 14.8 removed.** `spec-gameble/spec-gameble.md:149` (CAP-18: "Signed out, a visitor can open the hub, the feed, public profiles, card details and the sets with their empty slots"), `:34` ("The signed-out hub stays reachable from the landing and the public card page") and `:187` (the landing's sign-in actions "open the Steam sign-in panel" and "Embarquer sur le pont opens the signed-out hub"). As built (f87b3f56, b67cd2eb), a visitor reaches only the landing, Toutes les cartes and its detail, the public card page, public profiles and albums, the feed read-only and Comment ça marche; the sign-in panel is gone and "Embarquer sur le pont" posts to Steam. EXPERIENCE.md was brought in line by 14.9 (`ux-gameble/EXPERIENCE.md:64`); the spec was not, and no ticket asked for it. *Now:* fix (spec reconciliation, the author's). *Prevent:* a ticket that changes what a capability allows names the spec lines it supersedes.
- **F-S2. The epic file does not record the scope that 14.7–14.9 added.** The epic's Boundaries (`epic-card-catalog.md:42`) cover the grid, the detail and "the visitor's way in to it"; R4 (`:31`) and Done when 4 (`:39`) speak of the grid and the detail only. 14.8 closed the hub, the collection entry, set albums outside a profile and every other page to visitors, and 14.9 reopened the feed. Those decisions live only in `tickets.toml:100` and `:112`; the epic's Notes end at entry 1's design decision (`epic-card-catalog.md:77`). *Now:* fix (add the two decisions to the epic's Notes). *Prevent:* nothing beyond the item.
- **F-S3. R2's wording is superseded by the author's decision on the detail.** R2 (`epic-card-catalog.md:29`) says the detail shows a card not owned "set apart as in the grid". The author decided the detail always shows the real card (`tickets.toml:40`, `epic-card-catalog.md:77`), and 7649120e built that. Done when 3 ("shows the card's face, owned or not") holds. *Now:* accept as-is (recorded so later runs stop flagging it); reword R2 if the author wants the record clean.

### Architecture delta

- **F-A1. The feed, now open to visitors, is not under the public-read throttle.** `config/initializers/rack_attack.rb:26` lists `cards brothers library landing`; `feed` is absent. 14.9's plan says so deliberately (`story-a-visitor-reads-the-feed-and-has-a-tab-bar-of-their-own-plan.md:98`: "not added to `PublicRead`'s throttle (it was not before 14.8 either)"). R4's throttling clause names only the grid and the detail, so this is not a criteria miss. The feed is the one visitor page with no per-IP read cap. *Now:* defer, a decision for the author (one word in `PAGES` plus a rate-limit test). *Prevent:* when a page opens to visitors, its ticket states its throttle.
- **F-A2. `LibraryController` keeps `PublicRead` on two actions that are now player-only.** `app/controllers/library_controller.rb:14` includes `PublicRead`; `show` and `set` authorize `play?` (`:21`, `:43`). Rejected in 14.8's review (`story-a-visitor-reaches-only-the-landing-the-catalog-and-the-share-plan.md:117`): the only effect is that old browsers skip the modern-browser check on those two GETs before being redirected. *Now:* accept as-is.
- No new pack dependency. `bundle exec packwerk check`: no offenses.

### Duplication map

- Nothing found. 14.8 removed the visitor forms that 14.5 and 14.7 had added to the set row and album header (f87b3f56: `app/views/library/_set_progress_row.html.erb`, `_album.html.erb`, `set_board_loading.rb#load_discover`), so no dead visitor branch is left. `set_label_sentence` (`app/helpers/set_rows_helper.rb:13`) is still used by `set_progress_sentence` (`:18`).

### God-class / size growth

- Nothing found. Over the ten commits the largest code churn is `app/controllers/library_controller.rb` (+35/−27, 111 lines now) and `app/controllers/cards_controller.rb` (+16/−21). Several files shrank (`card-detail.css` −92 net). The largest single change is f87b3f56 (92 files, +779/−810), flagged `oversized` in its plan (`…share-plan.md:16`); 14.5 and 14.9 carry the same warning.

### Pattern divergence

- **F-D1. Planning ids remain in files that 14.8 and 14.9 touched after the sweep.** For example `app/controllers/application_controller.rb:17,47,60,78,120` (AD-14, AD-11, AD-18, AD-21), `app/controllers/concerns/public_read.rb:1` (CAP-9, CAP-18), `app/views/cards/_public.html.erb:2` ("story 10.3"), `test/integration/shell_test.rb:5` ("story 8.1"), and `app/frontend/styles/shell.css`. All predate this epic (git blame: 2026-10-02 to 2026-10-07). The sweep's own files are clean, as it claimed (`story-refactor-sweep-plan.md:69`), but it ran before 14.8 and 14.9. *Now:* defer to epic-human-readable-codebase, whose envelope covers planning ids. *Prevent:* see F-P2.

### Diff-scope review (narrowed)

`bmad-review` was not invoked: this headless run reviewed the epic's cross-ticket seams inline, which narrows the scope. Checked:
- 14.4's ownership-free visitor grid against 14.6's skipped figures (`library_controller.rb:36` `load_summary if current_player`). Consistent.
- 14.5's and 14.7's visitor branches against 14.8's closing of `/library` and set albums. Removed cleanly, as above.
- 14.8's visitor redirect against 14.9's reopened feed (`app/controllers/feeds_controller.rb:17-19`: `show?` with the Friends tab for a player only) and the visitor tab bar (`app/views/shell/_tab_bar.html.erb:19-23`). Consistent.

Not checked line by line: the 92 files of f87b3f56, beyond its four-lens thorough review (25 findings, 6 patched).

- **F-R1. A visitor has no link to Comment ça marche.** 14.8 leaves it open to visitors, but the only links to it are the hub menu (`app/views/pages/_menu_how_it_works.html.erb:4`) and PLUS (`app/views/pages/more.html.erb:42`), both player-only now; the landing does not link it. 14.9 records the same thing as residual risk (`…tab-bar-of-their-own-plan.md:113`). *Now:* open question for the author.

### Process

- **F-P1. Plans record worktree commits that develop does not hold.** Each plan's `commit:` (for example `story-a-card-not-owned-shows-its-face-in-the-grid-plan.md:15` → 1590fd0e) is reachable only from a `worktree-agent-*` branch. The develop commit is the cherry-pick (afe6d9b3), so a plan's provenance breaks once the worktree branch is pruned. *Now:* fix forward, in the orchestration process. *Prevent:* after the cherry-pick, the plan's `commit` records the develop hash.
- **F-P2. The refactor sweep ran before the epic's last two tickets.** 14.6 (82fabc5b) depends on 1–5 and 7 (`tickets.toml:74`); 14.8 and 14.9 were added afterwards from staging review, and their rejected and residual items (F-A1, F-A2, F-D1, F-R1) were never swept. *Now:* accept; this retro carries them. *Prevent:* when tickets are added after the sweep, either re-point the sweep or note that the retro sweeps them.
- **F-P3. 14.8's recommended follow-up review never ran.** `…share-plan.md:14` `followup_review_recommended: true` (`:152`: a high entry patched, the terms and privacy line restored beside four sign-in buttons, "checked from markup only"). The only later commits on it are a test fix (42c9d71c) and the plan record (35753fd5). The author's staging validation of v0.1.5-rc.1 (1de08482) covered the screens. *Now:* accept, with the staging review as the mitigation. *Prevent:* the build loop either runs the recommended follow-up or records why the staging review replaces it.
- **F-P4. Built work was thrown away when visitor scope was decided after the builds.** 14.5's visitor set rows and album header and 14.7's À DÉCOUVRIR (3278d2c3) were removed by 14.8 the same day (`tickets.toml:100`: "a signed-out visitor has no reason to be on the hub or the collection"). 14.1 settled the not-owned treatment but not which pages a visitor reaches. The detail design was overridden the same day too (`tickets.toml:40`). The cost was rework, not defects: both rounds passed the full suite. *Prevent:* a design ticket for a visitor-facing change settles the visitor's reachable surface along with how things look.
- **F-P5. Shared test databases produced false failures.** 14.4's verification records "one run showed 1 error not reproduced in three later full runs, likely a concurrent use of the test database" (`story-a-visitor-browses-every-card-with-no-ownership-data-plan.md:102`). The worktree lanes used their own databases (`gameble_test_w14`, `_w14_5`, … `_w14_9`), but another session ran on the same one. *Prevent:* every session, not only worktree lanes, names its own `DATABASE_URL` test database.
- **Win. A real flaky test fixed at its root.** 3d03a251 resets the per-process draw pool before every test, replacing the per-file resets (25 test files touched); the diagnosis is in its message (a cached snapshot of rolled-back card-seasons). This retro's full parallel run passed on it.
- **Win. The staging gate did its job.** The author's two staging reviews caught a product-level mismatch (14.7) that no automated check could, and turned it into two scoped tickets the same day.

## Behavior verification

This run exercised nothing end to end in a browser, and neither did any build agent: every plan's residual risk says layouts were "checked from the markup/CSS only" (system tests are disabled by project policy). The end-to-end evidence is the author's own staging review: 14.2–14.6 on v0.1.4-rc.1 (63c56fa8) and 14.8–14.9 on v0.1.5-rc.1 (1de08482).

Run once by this retro on develop at 1de08482, on its own test database `gameble_test_retro`:
- `PARALLEL_WORKERS=4 bin/rails test`: 2941 runs, 0 failures.
- `npm run test:js`: 45 files, 492 tests passed.
- `bundle exec packwerk check`: no offenses.

## Previous-retro follow-through

In the `status` epic order, the previous epic is `epic-season-preparation` (11). It has no retrospective file, so there was nothing to follow through on. The reason is that the file is missing, not that it has no outstanding items. The most recent retrospective written is `epic-recognizable-sets`; it was not checked here.

## Action items

All items are proposed, not applied; the author decides what runs.

1. **Spec reconciliation (author).** Rewrite CAP-18 (`spec-gameble.md:149`), CAP-1's signed-out line (`:34`) and CAP-24's landing line (`:187`) to the visitor surface as built (F-S1).
2. **Epic record (author, via bmad-ticket).** Add the 14.7 → 14.8 and 14.9 decisions to the epic file's Notes, and reword R2 if wanted (F-S2, F-S3).
3. **Remediation, if the author agrees (dev loop).** Add `feed` to `PublicReadThrottle::PAGES` with a rate-limit test (F-A1).
4. **Process (orchestrator).** After cherry-picking a worktree build onto develop, record the develop hash in the plan's `commit` (F-P1).
5. **Process (orchestrator).** When tickets join an epic after its sweep, re-point the sweep to depend on them or hand their residuals to the retro explicitly; run or explicitly waive a recommended follow-up review (F-P2, F-P3).
6. **Process (orchestrator).** Every session running the Ruby suite uses its own test database URL (F-P5).
7. **Deferred (epic-human-readable-codebase).** The planning ids listed in F-D1.

## Acceptance verdict

**Verdict: accepted** (author, 2026-10-20). The machine verdict was accepted-with-open-items (criteria declared in the epic file's Done when); the author accepted the epic and settled the open items below.

1. Every card shows its face, not-owned set apart for a player, copies shown, albums keep missing slots: afe6d9b3, `library_controller_test.rb`, author-validated on v0.1.4-rc.1. Met.
2. Search, rarity and set filters for a player and a visitor; empty result: unchanged grid filters, 7a8b899e tests. Met.
3. The detail shows the face, owned or not: 7649120e (the real card, by the author's decision). Met.
4. A visitor sees no ownership data, is throttled, cache private, no id, and enters from the author's choice (the landing link `app/views/landings/_concept.html.erb:33`, the visitor tab bar): 7a8b899e, 3feb5033, b67cd2eb, `rate_limit_test.rb`. Met.
5. French and English, phone and desktop: locale tests, with the layouts seen only by the author on staging. Met on the author's review.

All tickets are finished. Open items: F-S1 (the spec contradicts the as-built), F-A1 (unthrottled visitor feed), F-R1 (no visitor path to Comment ça marche), F-P1 to F-P5 (process). None blocks the Done when. The author's acceptance of 14.8 and 14.9 on staging is a human decision on those tickets; no human decision on the epic as a whole is recorded yet.

## Open questions

- Should the feed join the public-read throttle now that it is a visitor page (F-A1)? **Answer (author, 2026-10-20): yes.**
- Comment ça marche is open to visitors, but nothing links them to it. Should the landing link it, or should it close to visitors like the hub (F-R1)? **Answer (author, 2026-10-20): a link from the landing.**
- Should CAP-18 in the spec now read as the visitor surface as built (F-S1)? **Answer (author, 2026-10-20): yes, the spec and the epic file are reconciled, done in the follow-up below.**
- 14.5's open question (`story-a-visitor-s-way-in-to-every-card-plan.md:111`) on the landing link's place and words ("Voir toutes les cartes", module 01 · Concept): the author's staging review accepted the ticket; is the wording final? **Answer: already approved by the author on 2026-10-20.**

## Assumptions

- The epic resolved from the folder argument `_bmad-output/initiative-gameble/epic-card-catalog`; `pending_tickets` was empty, so no verdict was forced.
- The author had no going-in concerns (stated by the caller); none were weighted.
- Each ticket was attributed to its develop commit by subject, as the plans' `commit` fields name worktree commits (F-P1).
- `bmad-review` was not invoked; the cross-ticket review was done inline over a narrowed scope (above).
- No end-to-end browser check was run; the author's staging reviews stand in for it.
- The machine verdict **accepted-with-open-items** was rendered without a human decision on the epic.
- Each action item above is a proposal made without the author.

## Follow-up applied

Applied on 2026-10-20 from the author's answers above, in two commits:

- **Code, a20caeef** (feat(visitor)): `feed` joins `PublicReadThrottle::PAGES` (`config/initializers/rack_attack.rb`), with a rate-limit test that the 121st read of /fr/feed from one address within a minute gets 429 and the feed paths counted as shared pages (F-A1, action item 3). The landing footer links "Comment ça marche" / "How it works", before "Mentions légales", with a request test that a visitor follows it (F-R1). EXPERIENCE.md's Information Architecture row for Comment ça marche, its landing footer copy and behaviour rows, and DESIGN.md's landing footer name the link.
- **Docs, the commit that records this section** (docs(card-catalog)): the spec's CAP-1, CAP-18, CAP-24 and the legal line now describe the visitor surface as built, marked "(author, 2026-10-20)" (F-S1, action item 1); the epic file's R2, Done when 3, Boundaries and Notes record the real card on the detail and the 14.7, 14.8 and 14.9 decisions (F-S2, F-S3, action item 2); each plan's `commit` names its develop commit (afe6d9b3, 7649120e, 7a8b899e, 3feb5033, 82fabc5b, 3278d2c3, f87b3f56, b67cd2eb) instead of the worktree one (F-P1, for this epic); this file's verdict and answers.

Not applied here: the process items 4 to 6 (orchestrator) and item 7 (epic-human-readable-codebase).

## Reconciliation, 2026-10-27 (headless re-run, release 0.4.0)

This file already existed (commits `fcb6c2a1`, `d14bebcd`, `0c77b4b6`, 2026-10-20), so the run loaded it and checked its state against the current tree instead of rewriting it. The ticket state is unchanged: nine rows, eight `done` and one `dropped` (14.7), `pending_tickets` empty. The verdict `accepted` is the author's decision of 2026-10-20 and stands. Epic issue #105 is still open and closes with the 0.4.0 milestone.

**Follow-through of this file's action items.**
1. Spec reconciliation of CAP-1, CAP-18, CAP-24: recorded as applied in "Follow-up applied" (docs commit after `0c77b4b6`). Not re-read line by line here.
2. Epic record (Notes, R2, Done when 3): applied, `epic-card-catalog.md` lines 38 and 81 carry the new wording.
3. Feed under the public throttle: landed, `config/initializers/rack_attack.rb:26` lists `feed` in `PAGES` (commit `a20caeef` exists).
4. The landing link to Comment ça marche: landed, `app/views/landings/_footer.html.erb:5`.
5. Plan `commit` fields: checked on 14.2, which names develop's `afe6d9b3`.
6. Orchestrator items 4 to 6 (sweep re-pointing, own test database per session) are process rules with no file to point at: no evidence found either way.
7. Planning ids (F-D1) deferred to epic-human-readable-codebase: `grep -rEl '(AD|CAP)-[0-9]+'` over app, packs, lib, config and test still matches 194 files, so the deferral is still open (no retrospective in that epic's folder).

**What changed after acceptance and bears on the Done when.** Two later tickets of epic-screen-walkthrough reverse parts of what this epic settled, both by the author after the 2026-10-23 staging walkthrough:
- 16.26 (`4f85578e`, 2026-10-25) greys and locks a card the player does not own on its detail too (a visitor and the public card page keep the plain face). Done when 3 and R2 still say "the real card's face, owned or not, the same for every viewer", and the entry in `tickets.toml` for 16.26 states that it "reverses the 2026-10-20 call". The criterion no longer holds for a signed-in player; it holds for a visitor.
- Ticket 24 of that epic's `tickets.toml` (16.x, "A set album's missing cards look like the not-owned cards of the catalog", walkthrough finding of 2026-10-23) changes the album's missing slots, which Done when 1 says "still show". I did not verify its state or build here: no evidence found.
- The grid itself later gained infinite scroll (`fd1e8136`) and set tiles (`b061d802`, `22cb1cdd`); no criterion contradicts them.

**Action items (new).**
1. Author, via bmad-ticket: amend `epic-card-catalog.md` Done when 3 and R2 to say the detail shows a card not owned greyed and locked to a signed-in player and plain to a visitor, citing 16.26, and Done when 1 if the album change is built. The 2026-10-20 epic text is otherwise stale against the code.
2. Author: close #105 with the 0.4.0 milestone; no work of this epic is open.
3. Author: the planning-ids sweep (F-D1) is still unscheduled; confirm which release carries epic-human-readable-codebase.

Verdict after reconciliation: **accepted** (unchanged, human decision). Open items: the three above.
