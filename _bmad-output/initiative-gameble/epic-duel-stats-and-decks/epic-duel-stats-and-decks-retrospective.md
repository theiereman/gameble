---
epic: epic-duel-stats-and-decks
date: 2026-11-17
verdict: accepted-with-open-items
criteria: declared
headless: true
---

# Retrospective: epic-duel-stats-and-decks (epic 42)

## Epic summary

Seven stories, all `status: built`, all `state: review`, none `done` or `dropped`. `pending_tickets` is empty (`tickets.py status`), so the machine verdict is not forced to rejected. No ticket is closed: closing is `bmad-ticket`'s.

| Ref | Ticket | Review that ran (plan frontmatter) | Follow-up recommended |
|---|---|---|---|
| 42.1 | Duel profile on the card detail, recomputed each Monday | thorough (4 lenses) plus a second thorough follow-up pass | no, after the second pass |
| 42.3 | Deck editor, twelve-card decks | thorough | no |
| 42.6 | Monday feed entry | thorough | no |
| 42.5 | Deck copies named and freed on trade, sale, entrust | thorough | **yes, no record that it ran** |
| 42.2 | DUELS tab, Duels screen, ÉCHANGES sub-tabs | quick | **yes, no record that it ran** |
| 42.4 | Deck editor sort, moves, gap fill | quick, one loop (`review_loop_iteration: 1`) | no |
| 42.7 | Refactor sweep | quick | no |

Tickets still at `built` and not `done`: all seven.

Commits (branch `feature/duels`, head d23a6ed1, not on origin), contiguous, parent 75e6e558 (a develop commit): 18b972c7 (42.1), 2cd02f61 (42.3), 426feeee (42.1 follow-up fix), 366f5045 (42.6), 3017ee70 (42.2), e56e580b (42.5), ae8b7b6b (42.4), acd2d751 (42.7). `git diff --shortstat 75e6e558 acd2d751`: 270 files, +10405 / -292, which includes the seven plan files.

Plan ranges (each plan's `baseline_revision`): 42.1 a41c6f96 (a develop commit, ancestor); 42.3 and 42.6 ad7a35b8 and 42.2 and 42.5 50909e25 (both exist in the object store with the epic's subjects but are pre-rebase commits, not ancestors of the branch; they are the old hashes of 18b972c7 and 366f5045); 42.4 d067ac33 (not in the repository; the plan's Implementation Notes say the branch was rebased and name 94752424 as the rebased baseline); 42.7 ae8b7b6b (ancestor, the 42.4 commit). So per-plan ranges could not be derived mechanically for five of seven plans; the single contiguous commit range above was used instead, and `git_evidence.py` was not run (the harness refused the command form). Attribution is by commit subject and plan, not by `stories` tags.

Evidence inventory. Available: epic file with Done when, `tickets.toml`, seven plans with Review Triage Logs and Auto Run Results (42.4 has no Auto Run Result), `deferred-work.md`, RELEASING.md, the branch commits, the run brief's final-review findings. Missing: session logs (process-lesson analysis is skipped; the "why" of each rework is only what the plans record), a previous retrospective (epic 41's folder holds none), a staging deployment (see Behavior verification). The initiative's requirements are the epic file's own R1 to R17.

Where the review depth the brief describes applies: in this epic all seven tickets got a per-ticket review (the unreviewed tickets are 43.8 onward and epic 44, outside this folder). One whole-duel-diff review ran at the end; its findings, as the run brief states them, are cited below as "final review (run brief)" and were not re-verified here beyond the commit d23a6ed1.

## Findings

Disposition key: fix now / defer / accept. Upstream lesson follows each.

### F1. Mid-week season publication breaks the "previous weekly run" baseline (spec-to-implementation mismatch)

R3 says only the first and weekly runs rotate the last weekly percentiles; R6 and R11 compare with "the previous weekly run". `Game::DuelStatRows#weekly_percentiles` (`app/domains/game/app/models/game/duel_stat_rows.rb:50,59`) copies the row's current percentiles, which a season run has already replaced, so after a season publication between two Mondays the next Monday's feed entry and the deck editor's arrows compare with the season run, not last Monday. Surfaced by three lenses in 42.6's triage (`[medium] [defer]` three rows) and in 42.1's (blind-hunter, intent, orchestrator rows), and recorded twice in `deferred-work.md` (lines 649 and 665, no `resolved:` line). The deferral stands on 42.1's reasoning that seasons are published a few times a year and the fix needs a second stored percentile set or a season run that keeps ranked rows, "an author's choice". 42.4 (arrows) shipped on the same base.
Disposition: defer, needs the author's choice before release; the Monday entry in Done when 4 is correct on every Monday without a season publication in the week.
Upstream: when a requirement names a comparison base, the story that stores it owns a test that a season run does not move that base; here the story that wrote the rotation (42.1) knew the consumer (42.6) would read it and deferred instead of asking.

### F2. Contract boundary with epic 43: a nullable stat value reached a consumer that assumed a number (final review, commit d23a6ed1)

`game_duel_stats.popularity_value` is nullable (`db/migrate/20261115100000_create_game_duel_stats.rb:7`, with a check that value and percentile are null together at line 25), and 42.1's follow-up pass added a test that a reviewless edition renders "No value". The epic's Notes state the stats query is the contract `AcceptChallenge` copies, but name no nullability rule. 43's rating tie-break compared `[rating, popularity value]` pairs; a nil raised and would strand a duel (`d23a6ed1`: `.to_i` added, test added; a95fa2be had introduced the tie-break). Confirmed crash, fixed on the branch.
Disposition: fixed (d23a6ed1).
Upstream: a contract note for a table read by another epic lists which columns can be null and what each consumer does with null; R2 already said "an edition nobody has pulled has no discovery or circulation value" but not that a reviewless edition has no popularity.

### F3. Three smaller 43/44 gaps from the final review (run brief), two touching this epic's objects

Release of a deleted player's pending challenge publishes no event; a stale deck token lapses a challenge; a distinct-opponents metric drops when an opponent deletes their account. Being fixed on another branch per the brief. The stale deck token concerns 42.3's decks (tokens, deletion), so the 42 to 43 boundary of "deck exists and is complete at challenge time" was verified from the challenge side only. Not re-verified here.
Disposition: fix now (in progress elsewhere). Upstream: none beyond F2.

### F4. Native tab code never compiled (42.2), still unverified

42.2 changed `mobile/ios/Gameble/Tabs.swift`, `mobile/android/.../Tabs.kt`, `activity_main.xml` and strings with no Swift or Kotlin toolchain; its review patched a medium bug there (`atRoot` reported `/trades` and `/market` as tab 3's root) and recommended a follow-up review naming the native code as the unverified risk (plan `## Auto Run Result`, "Follow-up review recommended: true"). No follow-up review is recorded; the item sits in `deferred-work.md` (native tabs, "a build of both apps must check…"). The epic file already puts submitting the apps outside the epic.
Disposition: defer to the author's next app build; the five-tab layout and `tab-duels` icon are release-blocking for the apps only, not the web.

### F5. 42.5's recommended follow-up review has no record; its named risk is untested

42.5 patched five medium findings on a thorough pass and set `followup_review_recommended: true`, naming one risk: after "Retirer" the trade board reloads and relies on the localStorage draft restore, and no test removes a card with lines already placed (plan Auto Run Result). There is no follow-up section in the plan, unlike 42.1. The final whole-diff review may have covered it; the brief does not say.
Disposition: defer; ask the author whether the final review covered it, otherwise one system test of removal with placed lines on a draft board and a counter board.
Upstream: a plan with `followup_review_recommended: true` should not reach the next ticket's baseline without either the follow-up or an explicit "waived by author" line.

### F6. A plan contradicted the design system, caught only by the quick review (42.4)

The plan's Code Map prescribed `<select>`s for sort and trump filter; the review found them and the 22px hand-made gap button against `docs/design-system.md` ("Same job, same component"; `ButtonComponent` for every button) and the 44px phone target, routed `bad_plan`, and the ticket was rebuilt once (Plan Change Log, review loop 1; triage rows 7, 8, 10). A medium contrast failure (3.58:1) was also patched. A re-derivation was needed rather than a patch, so this was the epic's most expensive rework. AGENTS.md already says to read the design system before touching a view; the plan author did not.
Disposition: accept (fixed). Upstream: the ticket-planning step for any UI story checks the Code Map against `docs/design-system.md` before approval.

### F7. Verification not recorded in two plans

42.4's `## Verification` lists commands with "-- green" as expectations and the plan has no Auto Run Result. 42.7 states its build ran no test (suites were "run by the coordinator after integration"); its Verification records expectations only, though its Implementation Notes do say what it did run. This is the process rule previous retros already asked for ("a plan's Verification records the results of the commands it lists", `deferred-work.md` line 321 and 336), still not enforced for these two.
Disposition: defer (cannot be reconstructed without the sessions). Upstream: the closing step refuses `built` without recorded results (also `deferred-work.md` line 349).

### F8. Baselines not traceable

Five of seven plan baselines are not ancestors of the branch and one (d067ac33 for 42.4) does not exist in the repository; commit subjects carry no ticket ref (`feat(duels): …`). The same rule was raised in earlier retros (`deferred-work.md` lines 321, 349, 375). Cause here is a rebase onto develop mid-epic; the 42.4 plan notes it but did not update `baseline_revision`.
Disposition: accept for this epic; carried item. Upstream: rewrite `baseline_revision` when a rebase changes it (the plan's Implementation Notes recorded the new hash instead of the frontmatter).

### F9. Repeated and cosmetic duplications deferred, not built (aggregate view: duplication map)

The progress-bar CSS is now copied a fourth time and the day-format rule a fifth (42.1 triage, `[low] [reject]` rows; `deferred-work.md` line 686); `TradeSuggestions.still_spared` keeps a second spare rule beside `Game::SpareCopies`, differing only on unrated editions (42.5 triage, 42.7 Implementation Notes, `deferred-work.md` line 683); a failed or throttled deck deletion and a removal with no referer land on the new-deck editor rather than Duels, the deletion's two paths asserted by no test (42.7 deferred entry). Each was weighed three times and rejected for scope; the third consecutive epic-level rejection is the signal.
Disposition: defer. Upstream: one scheduled cleanup ticket for the shared bar, day-format helper and spare rule, instead of re-weighing per epic.

### F10. First-deploy cost and the entrypoint (risk, mitigated)

The first duel computation runs in the boot entrypoint, under Kamal's 30-second default. 42.1's follow-up timed it (about 4 s and 50 MB per season of 12,500 card-seasons on a development machine; 8.5 s for two seasons) and RELEASING.md line 66 and the acceptance list (line 84) now state the cost and ask to note the staging boot time. Not measured on the staging host.
Disposition: accept; the author notes the boot time on the first release (RELEASING.md line 84).

### F11. Feed previews show the Monday line, against a strict reading of R6

R6: the entry shows "under TOUS and the TOUT filter only, never in the ticker". 42.6's plan decision shows the line in the previews (hub feed block, LIVE strip, landing), reported to the author as a plan decision (triage `[low] [reject]` intent row; Auto Run Result residual risk).
Disposition: open, author decides (see Open questions).

### Strengths worth keeping (confirmed by the evidence)

- The two heaviest tickets got two thorough passes and one follow-up respectively (42.1: 39 and 31 findings; 42.3: 38; 42.6: 33; 42.5: 33), producing no high findings and medium patches that are mostly missing-test gaps (concurrency probe, no-value branch, requester-only deck block, sale page stream).
- Lock order (bank lock, deck, deck cards, holdings) is tested for add, remove and delete (42.3 triage), and 42.5 repeated it for `RemoveFromDecks`.
- 42.7 swept the epic's added comments, one `of_player` scope and one `Profile#stat`, with no test change; its one review finding was a wrong evidence line, corrected.

## Behavior verification

Runtime behavior was not exercised in this run: it is a headless documentation run with no staging and no browser. The evidence of execution is what each plan records: 42.1 system tests green (9 runs), 42.3 `deck_editor_test` green, 42.2 `duels_test` and four more (17 runs), 42.5 41 system runs green, 42.6 6 system runs green; suite results per plan end with the known `library_controller_test.rb:119` failure (resolved by f62dd90d per `deferred-work.md`). 42.4 and 42.7 record no results (F7). Every Done when item is stated "on staging"; none could be checked here.

## Previous-retro follow-through

Nothing to follow through on: no previous retrospective file exists in the previous epic's folder (`epic-prices-economy-health-and-opening` holds none), so this is a missing file, not an empty action list.

## Action items

All are proposed, none applied. Owners are roles, since the epic has no assignee.

1. (author, before release) Choose the fix for F1: a second stored percentile set, or a season run that keeps ranked rows. Remediation, story-shaped, owner: author decides, dev loop builds.
2. (author, before release) On staging, check each Done when: the DUEL block as player and visitor, a 12-card deck with refusals, the copy block on a trade, a listing and an entrust, the first Monday entry, the sub-tab memory and the old market links; and note the first boot time (RELEASING.md line 84). Owner: author.
3. (dev loop) Add a nullability note to the stats contract (F2): which `game_duel_stats` values may be null and that a reviewless edition has a null popularity value; check any other consumer in epics 43 and 44 that orders by a raw value (`Game::DuelRules` `exact_value`) for the same pattern. Spec reconciliation for the epic's Notes, applied by the author.
4. (dev loop) Run the follow-up review 42.5 recommended, or one system test of "Retirer" with trade lines placed (F5), and ask whether the final review already did.
5. (author) Build and run both native apps with the five tabs and `tab-duels` before any store submission (F4).
6. (process, owner: bmad-ticket) Refuse `built` while a plan has `followup_review_recommended: true` with no follow-up record or waiver; refuse it without recorded verification results; rewrite `baseline_revision` when a rebase changes it (F5, F7, F8; already open in `deferred-work.md` lines 321, 349, 375).
7. (process, owner: planning) Check a UI story's Code Map against `docs/design-system.md` at plan approval (F6).
8. (dev loop) One cleanup ticket for the shared progress-bar class, the day-format helper and `still_spared` (F9).
9. (dev loop) Confirm the three final-review gaps (F3) land with tests on the fix branch, including the stale deck token case against the deck operations of this epic.

## Acceptance verdict

Accepted-with-open-items, criteria declared (the epic's Done when 1 to 5). Basis: all seven tickets are built and reviewed; no high finding at any review; one confirmed crash found by the final review and fixed (d23a6ed1) in epic 43 code, caused at the boundary this epic defines (F2); named findings deferred and tracked (F1, F4, F5, F9). Done when 1 to 5 are staging checks that nothing in the record shows as run, so "criteria met" rests on the tests the plans record, and the author's staging pass (action item 2) is the real gate. F1 is a requirement mismatch (R3, R6, R11) rather than a defect found by a test; it should not be accepted silently. Proposed for the author: accept with the open items above; the human decision overrides this proposal.

## Open questions

- F1: second percentile set or ranked-rows-kept, or accept the gap?
- F11: may the Monday line show in the previews, or is the strict reading (TOUS and TOUT only) intended?
- F5: did the final whole-diff review cover 42.5's trade board draft restore after "Retirer"?
- Whether the final review covered 42.2's native tab code at all (it cannot have compiled it).

## Assumptions

- The epic reference resolved from the folder path given in the invocation; `status` on that folder returned seven tickets and an empty `pending_tickets`.
- The branch `feature/duels` was used as the diff source, as instructed; ranges were derived from its contiguous commits because the plans' baselines are not usable (Epic summary). `git_evidence.py` could not be run in this environment.
- The final review's findings come from the run brief, not from a file in the repository; only d23a6ed1 was checked against the code.
- Session logs and a staging deployment were unavailable; no process lesson that needs them is claimed.
- The machine verdict is proposed as accepted-with-open-items because no ticket is unfinished and no blocking finding stands; the human verdict is pending.
- No ticket was created, no plan frontmatter, frozen block or `pending-approvals.md` was edited.
