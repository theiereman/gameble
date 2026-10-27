---
epic: epic-screen-walkthrough
date: 2026-10-27
verdict: accepted-with-open-items
criteria: declared
headless: true
---

# Retrospective: Every screen walked through before the release (epic 16, release 0.4.0)

## Epic summary

`tickets.py status`: 35 tickets, 35 done, `pending_tickets` empty. Three groups:

- Profile rebuild before the walkthrough (Done when 5): 16.2 designed, 16.3 profile, 16.8 automatic showcase, 16.4 showcase from the card detail, 16.5 showcase order, 16.6 friendship action, 16.7 another player's collection, 16.9 card-count cap and staff banned play.
- The walkthrough itself: 16.1, whose record is `walkthrough-findings.md` (25 findings, session closed 2026-10-23).
- 26 tickets raised from it (16.10 to 16.36): bugs 16.10 to 16.13, 16.16, 16.17, 16.18, 16.20, 16.21; stories and the design study 16.14, 16.15, 16.19, 16.22 to 16.32, 16.34 to 16.36. Ticket 16.33 (tribute card for the six beta testers) left the epic on 2026-10-27 for a new epic of its own (`1944c192`: "Move the exotic card out of the 0.4.0 release into its own 1.2.0 epic"; the epic-22 reference is the coordinator's brief, the commit message says 1.2.0). Tickets still at `built` with tracker `done`: all except 16.2, 16.3, 16.8 (plan `status: done`).

Range narrowing: plans were built in parallel worktrees and cherry-picked, interleaved with other epics (the same pattern the card-catalog retrospective records as F-P1). Per-plan baseline ranges would mix other epics' work, so ticket attribution below rests on plans and commit subjects, not on `git_evidence.py` ranges. Evidence available: epic file, 32 plans, `walkthrough-findings.md`, `tickets.toml`, commits 2026-10-15 to 2026-10-27. Missing: session logs, so process lessons rest on plans and commits only; no diff was reviewed by `bmad-review`.

## Findings

### Done when versus the record
1. **The walkthrough did not cover every screen (blocking for Done when 1 and 2).** `walkthrough-findings.md` Screens table leaves Seasonal allocation, Card picker, Public card page, Public profile, Full collection, Steam sign-in and Plus (phone) with no mark, marks most others "partial" (desktop, player), and notes "phone, staff, FR/EN to see" on a dozen rows. The Session close (2026-10-23) says the author ended it with "the phone, the other language and the signed-out views not walked" since "the findings already raised cover what matters". Disposition: accept as the author's call, but the criterion as written is not met.
2. **Every finding is decided (Done when 3 holds).** 25 findings, each with a decision (21 tickets 16.12 to 16.32, a note on 21.3, one `keep`, one `deferred` to epic-back-office-ux, finding 11 left as an existing request). Finding 11 points to GitHub issue #67 ("Standardise the return button"), which is still OPEN, and 16.11 was built as a "defensive guard, decided by the author without a reproduction" (`bug-switch-through-collections-menu-...-plan.md:26`), so the issue is not shown to be closed by it.
3. **Profile before the walkthrough (Done when 5) holds.** 16.2 to 16.9 are done; plans show reviews with findings patched (16.3: 3, 16.6: 8 rows, 16.7: 6).

### Aggregate and cross-ticket
4. **Reviews are uneven.** 30 of 32 plans ran a `quick` review, one `thorough` (16.36: 30 findings, 5 patched, 2 deferred; `...iris...-plan.md` Review Triage Log). Plans with no recorded verdict or an empty Review Triage Log: 16.16 (reduced animations, `Verification` and `Auto Run Result` only), 16.31 (feed tabs), 16.19 reports a "Quick lens ran from the coordinating session after the unattended run halted on no subagents" (its Auto Run Result), 16.10 lists three one-line rows with no verdict summary. Not "reviewed clean" versus "not reviewed" is distinguishable only for 16.16 and 16.31.
5. **Two recommended follow-up reviews have no record of running.** 16.23 (`story-filters-on-a-set-album-plan.md:82`, unverified: stale cached album after Back and Forward following TOUT EFFACER) and 16.29 (`story-the-friend-profile-dialog-...-plan.md:72`, unverified: views' focus and pressed look). Their later commits are `4e44831c` (a fix: the dialog's views stack on the phone, 2026-10-25) and `b9400094` (a fix: clearing an album's filters keeps Back where the album was opened). Both look like the very risks flagged. No dedicated follow-up review is recorded; treat as defect-after-review evidence, not proof of a miss.
6. **The top bar chip needed three fixes.** 16.20: `a46282e0` (height) and `3c2f9801` (avatar fits) on 2026-10-24, then `43761d43` on 2026-10-26 ("the player chip and the rarity counter sit on the capsules chip's top edge. Their wrappers were blocks whose line box lifted the chip; as flex boxes they center like the capsules chip"), edited `test/system/shell_test.rb`. The ticket's verify was "three chips measure the same height" (`bug-the-top-bar-...-plan.md`); equal height passed while vertical alignment failed. Closed by `8b54f740` on 2026-10-27 with the friends fix. Prevent: a visual-alignment verify names position as well as size.
7. **A CI break from a date-dependent fixture.** `8f8337d2` (2026-10-26, "Keep CI green: an empty game has no discoveries, crass 1.0.8"): "The fixture's discoveries date two weeks back from today, so from 2026-10-26 they fell inside the test's fixed week." A time-bomb test, which AGENTS.md treats as a defect (random failure). The same commit bumps `crass` to 1.0.8, which the message does not explain further; not investigated.
8. **Parallel builds on a loaded host.** 16.31 records a full-suite failure "whose details were lost to a truncated log on a host at load ~28 shared by nine builds", cleared on rerun (`story-the-feed-s-tabs-...-plan.md` Results). This is the pattern AGENTS.md calls a defect to fix, not retry; no follow-up recorded.
9. **Planning drift on the set-tile line.** 16.34 (two-faced tiles, `b061d802`, 2026-10-26) was followed the next day by 16.36, whose Problem opens "The author's staging review (2026-10-27) found the set tile's turn too fast and ugly with a transparent gap halfway, the tier counts overflowing their squares, and the full EN COURS list heavy" (`...iris...-plan.md:25`). The first tile build needed a full redesign loop (five mock-ups, `40d5a6fa`, `5975cb15`, `05ea3097`), and the thorough review on 16.36 deferred paging and back-navigation edge cases (offset paging can repeat or skip; loaded pages lost on Back). Recorded in the plan only; check that they reached `deferred-work.md` (not found by grep on this epic's folder name).
10. **Two contradictions of other epics' decisions by this epic's tickets.** 16.26 (`4f85578e`) reverses the 2026-10-20 rule that the card detail never greys a card (epic-card-catalog Done when 3); 16.24 changes set albums' missing slots that epic-card-catalog Done when 1 says "still show". Both are recorded in `tickets.toml` as author decisions, but epic-card-catalog's text is stale (see its retrospective's reconciliation).
11. **Assumptions awaiting the author.** 16.35 "Assumed by the agent on 2026-10-26, to confirm with the author on staging: the section is titled COMPLÉTÉS / COMPLETED; ordered by the latest card gained in the set ... hidden when empty." The ticket was closed (`a4da225c`) with no recorded confirmation. 16.36's two assumptions were settled by `1fd10da9`.
12. **Policy wins.** Per the plans: `quick` reviews patched real defects (16.6 let staff invite a private profile's owner; 16.24 had a high finding; 16.32 fixed tilt losing to reduced-motion CSS); 16.15 and 16.4 and 16.5 and 16.3 carry the `oversized` warning. The planning-id rule appears respected in the plans' patches (16.3 etc.); not audited for the epic's code.

## Behavior verification

Not exercised by this run (no app or test run). Secondary evidence: the 16.36 plan records `bin/rails test` 3213 runs green, vitest 585, packwerk and zeitwerk clean, and screenshots at four widths in both locales. The iris's real hover path "cannot run in headless Chrome", so only pointer-origin and focus are tested (its Residual risks). The author's own staging review of 2026-10-27 is cited in the 16.36 plan and the closure commits `d2c20c99`, `8b54f740`, `a4da225c`, but the review text itself is in the author's hands, not in a retained file I could read; the triage logs hold no author staging-review block besides 16.5's (`### 2026-10-20 - Rework: drag and drop`, plan lines 101+) and 16.36's Problem.

## Previous-retro follow-through

The previous epic in this release is `epic-card-catalog`, whose retrospective was reconciled on 2026-10-27. Its items that depend on this epic: the card detail rule (16.26 contradicts R2 and Done when 3) and the album slots (16.24); both are flagged there. Its process items 4 to 6 (develop hash in plan `commit`, sweep ordering, own test database) show no evidence of landing here: plan `commit` fields were not examined, and finding 8 above describes shared-host test load again.

## Action items

1. Author: either accept the walkthrough's coverage in the epic file (amend Done when 1 and 2 to say screens marked "partial" are accepted, or add a ticket to finish: Seasonal allocation, Card picker, Public card page, Public profile, Full collection, Steam sign-in, Plus, phone, staff, EN). `epic-screen-walkthrough.md` and `walkthrough-findings.md`.
2. Author: decide whether 16.11 resolves issue #67 (still open); close or keep it.
3. Author: confirm the COMPLÉTÉS section's title and ordering (16.35 assumption) on staging and record it in the ticket notes.
4. Dev loop: a ticket for the two unrun follow-up reviews (16.23 stale album after Back and Forward; 16.29 view focus and pressed look), or a note accepting the later fixes as the follow-up.
5. Dev loop: record the 16.36 deferrals (offset paging can repeat or skip, loaded pages lost on Back) in `deferred-work.md` if not already there.
6. Dev loop: remove other date-relative fixtures like the one in `8f8337d2` (grep test fixtures for `ago`/`weeks.ago` against fixed weeks); then close the AGENTS.md "flaky" class for this pattern.
7. Process (author, in bmad-ticket guidance): a visual-alignment verify must name position as well as size (finding 6); a walkthrough's Done when should say how a partial screen is closed (finding 1).
8. Author: epic-card-catalog text still carries the superseded detail rule; see its retrospective, action item 1.

## Acceptance verdict

**accepted-with-open-items**, criteria declared (epic Done when), a machine verdict with no human decision on the epic as a whole (issue #106 stays open until the 0.4.0 milestone closes).

1. Done when 1 (every screen walked, marked): not met as written (finding 1); the author closed the session and the findings cover what he judged to matter.
2. Done when 2 (each screen as visitor, player, staff, FR/EN, phone and desktop): not met (finding 1); staff and phone are mostly unseen.
3. Done when 3 (each finding decided): met, with finding 11 pointing to open issue #67.
4. Done when 4 (tickets in the tree, ordered before epic 12): the 26 tickets are in the tree and all done; ordering not rechecked here.
5. Done when 5 (profile matches design before the walkthrough): met on the plans (16.2 to 16.9 done, reviewed).

This is a substantive gap on criteria 1 and 2, so the verdict is a judgment: it holds because the epic's Outcome ("a findings list with no item left undecided") is met, every ticket is finished, and the author chose the session's scope. A stricter reader would reject on criteria 1 and 2; the author should decide.

## Open questions

- Does the author consider the walkthrough complete, or should the unseen screens (phone, staff, EN, the seven blank rows) be walked after the release?
- Does 16.11's guard close #67?
- Where were the staging reviews of 2026-10-26 and 2026-10-27 recorded beyond closure commits? The brief names triage logs; I found them only in plan Problems.

## Assumptions

- Epic resolved from the folder path; `pending_tickets` was empty.
- 16.33's move is read from `1944c192` and the brief; the commit message names a 1.2.0 epic, the brief says epic 22.
- Attribution by plan and commit subject, not by baseline ranges (interleaved worktree builds).
- Review counts come from each plan's `verdicts` line; plans without it are listed in finding 4.
- All routing of findings and action items is mine and unconfirmed by the author.
