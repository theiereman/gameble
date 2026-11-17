---
epic: epic-live-friend-duels
date: 2026-11-17
verdict: accepted-with-open-items
criteria: declared
headless: true
---

# Retrospective: Live duels between friends (epic 43)

## Epic summary

Branch read: `feature/duels` at `d23a6ed1` (not on origin), retro branch `retro/43` cut from it. Epic 43 sits in a branch that also carries epics 42 and 44; only epic 43's commits and tickets are judged here, except where a boundary with epic 44 is the finding.

Tickets (`tickets.py status`): all ten have `status: built`, `state: review`; `pending_tickets` is empty. None is yet `done`; closing the epic is `bmad-ticket`'s, confirmed by the author.

| Ticket | Build route and review (plan frontmatter) | Landing commit | Size of that commit |
|---|---|---|---|
| 43.1 rules, view, tables | full, quick review | `f33c0fd4` (+ fix `a95fa2be`) | 49 files, +1402 over its range |
| 43.2 whole duel, plain screen | full, quick | `92e5851f` (+ fix `93328100`) | 65 files, +2514 |
| 43.3 reachable friend | full, quick | `237206a3` (+ fix `c7988f21`) | 29 files, +610 |
| 43.6 server clock | full, quick | `53c290e1` (+ fix `36b2bf67`) | 35 files, +810 |
| 43.4 challenge sheet and dialog | full, quick | `9b5849e7` (+ fix `1ec34832`) | 54 files, +1372 |
| 43.5 phone duel screen | full, quick | `940317c6` | 45 files, +2111 |
| 43.7 dropped connection, reload | full, thorough (four lenses) | `4bf2fd3b` | 52 files, +1208 |
| 43.8 removed players | full, review pinned `none` | `852d5a6f` | 17 files, +565 |
| 43.9 desktop layout | oneshot, quick | `c4e6479f` | 8 files, +362 |
| 43.10 refactor sweep | oneshot, review pinned `none` | `d1cddee3` | 15 files, +109 -30 |

After the tickets: one confirmed crash fix, `d23a6ed1` (rating tie-break, `Game::DuelRules`).

Plan ranges (baseline to next baseline, oldest first; recorded `baseline_revision` of each plan): 43.1 `ae8b7b6b..f33c0fd4`; 43.2 `f33c0fd4..93328100`; 43.3 `93328100..c7988f21`; 43.6 `c7988f21..36b2bf67`; 43.4 `36b2bf67..1ec34832`; 43.5 `1ec34832..940317c6`; 43.7 `940317c6..4bf2fd3b`; 43.8 `4bf2fd3b..852d5a6f`; 43.9 recorded baseline `940317c6` (the same as 43.7's), landed `c4e6479f`; 43.10 recorded baseline `5f7eca45`, so its range also spans epic 44's capsule commit. Ranges were measured with `git show --shortstat` per commit and `git diff --shortstat` per range; `git_evidence.py` was not run (the worktree's git guard refuses its invocation form), so per-file churn and a duplication map were not derived.

Evidence inventory:
- Available: epic file, ten plans (frontmatter, triage logs, verification, auto run results), `tickets.toml`, commit log `develop..feature/duels`, `deferred-work.md`, the code at `d23a6ed1`.
- Missing: the final whole-diff review's report is not in the repository; its findings come from the retro request and each was re-checked in the code below (the three gaps and the crash). The session logs of the builds were not available, so process lessons rest on plan records only. No previous retrospective (see follow-through). The mockups ("Écrans des Duels") are outside the repository, which the plans of 43.5 and 43.9 record.

## Findings

Disposition notation: this instance / what would prevent the next.

### A. Defects that escaped the per-ticket reviews

**F1. Rating tie-break raised on a nil review count (fixed).** `a95fa2be` made equal ratings compare `[value, popularity]` pairs; with a nil popularity the pair comparison returns nil and `.zero?` raises, stranding the duel. Fixed by `d23a6ed1` (`.to_i`, with a test). Provenance: 43.1's review log rejected "the rating tie ignores the review count" as low (plan `story-the-duel-s-rules...-plan.md`, Review Triage Log); the author's later fix `a95fa2be` added the very branch that then crashed, and its test (`duel_rules_test.rb`) used non-nil review counts only. The pure object already treats a missing percentile as strength -1 (`DuelRules.strength`), so missing stat data was a known case. Fixed / a fix to a rejected-as-rare review finding needs the missing-data case in the same commit. Residual: `by_value` still compares `value` as given; the new test covers only a nil review count, not a nil rating value.

**F2. `ReleaseDuelSeats` lapses a challenge and publishes nothing.** `app/domains/game/app/operations/game/release_duel_seats.rb` (`lapse_received_challenge`) sets the duel `lapsed`, leaves both seats and raises `move_number`, with no event. The duel stream hears only duel events (43.8 plan deferred entry, `app/models/duel_stream.rb`), so the waiting challenger's page never refreshes; the project rule that an operation publishes one event is also broken. Provenance: 43.8 had no review (`review: none`). Fix now (in progress on another branch per the request; not verified here).

**F3. A stale or unknown deck token lapses the whole challenge.** `accept_challenge.rb` computes `ready_deck(player.id, deck_token)` and, when it fails, `lapse(...)`: the challenger loses the challenge because the acceptor's form was stale. Provenance: 43.2's review rejected exactly this ("an unreadable `deck` param on accept lapses the challenge", low). The failure of the challenger's own deck lapses correctly per the epic's requirement; the acceptor's bad token should refuse inline. Fix now (in progress on another branch; not verified here).

**F4. The distinct-opponents achievement metric drops when an opponent deletes their account.** `app/domains/game/app/queries/game/duel_achievement_metrics.rb` (`OPPONENTS_SQL`, `COUNT(DISTINCT other.player_id)`); a deleted player's seat is nulled by `ReleaseDuelSeats` (`UPDATE ... player_id = NULL`), and `COUNT(DISTINCT)` ignores nulls, so the count falls and a granted-or-near achievement can regress. Boundary of 43.8 and epic 44 (the achievements ticket was built in parallel with 43.8, commits `8f3226dd` and `852d5a6f` share a minute). Fix now (in progress on another branch).

Common pattern for F2 to F4: none of them was visible to a ticket in isolation; F2 is a 43.8 gap with no review, F3 and F4 are interactions with seat nulling and with the token model, found only by a whole-diff read. Prevention: the epic's own high-risk note says secrecy and removed-player flows get a whole-epic review (epic Notes, High-risk checks); it did, and it worked, but for the parallel tickets it was the only review.

### B. Boundaries between tickets

**F5. The sweep missed a third hand-rolled copy of the closing steps.** 43.10 extracted `DuelSteps#close_seats` (leave seats, publish, release deleted seats) as "the shared ending of `end_challenge` and `AnswerRound#finish`" (sweep plan, Cleanups 2). `ReleaseDuelSeats#lapse_received_challenge` (landed earlier, `852d5a6f`, inside the sweep's baseline range) repeats the same lapse by hand and is the one without the event (F2). The sweep's "checked and found clean" list does not name `ReleaseDuelSeats`. Fix with F2 by closing through the shared step / prevent: a sweep after a parallel merge searches every writer of the same state transition, not only the files a plan lists.

**F6. 43.9 was built on the pre-43.7 tree.** 43.9 declares `after: [7]` (`tickets.toml`), but its plan baseline is `940317c6`, the same commit as 43.7's, i.e. built in parallel and cherry-picked (`c4e6479f` landed after `4bf2fd3b`). `duel-desktop.css` does not mention the connection slot or the own-connection banner that 43.7 added (`app/views/duels/play.html.erb` lines 11 to 16, `duel-connection.css`). Neither the desktop system test (`duel_desktop_test.rb`) nor any plan records a run against the merged tree. Whether the desktop board lays out correctly with the connection slot and a lost-connection banner is not checked. Defer, verify in the author's desktop play on staging; prevent: a ticket that `after`-depends on another and is built beside it reruns its own test file after the cherry-pick.

**F7. The Duels-screen deferral is split across three owners.** 43.3's deferred DÉFIER anchor (`#duel-challenge` when the form is absent) was meant to be owned by 43.4; 43.4's plan has the disabled-state rows (Sheet, no complete deck) and the plan's own deferrals say nothing on the anchor. Not confirmed closed. Sourced only from the two plans; check in the author's play (low).

### C. Spec to implementation reconciliation

**F8. "Newly private" contradicts the Done when.** Done when 5 and R11 say a banned, deleted or newly private opponent's duel finishes by automatic play. The 43.8 plan records (frontmatter, deferred) that a player who goes private mid-duel keeps playing their moves and only a removed player's lease stops being renewed, because R5 lets later moves act for a seat made private. The text conflicts inside the epic. Not applied: spec reconciliation, the author decides which sentence stands.

**F9. A ban or deletion pushes no board to the other seat** (43.8 plan, deferred; `duel_stream.rb` hears only duel events). The other seat reads "anonyme" at the next board, at most a minute, and on any load. Accept as-is until the author weighs it; low.

**F10. A refusal reads "no complete deck".** `app/models/duel_update.rb:21` turns a `refused` outcome into `no_deck` when the friend has no complete deck at render time. The epic's Open question (when the sheet says it) was to be settled with the author when 43.4 starts; the 43.4 matrix (State, "Sheet, declined / lapsed") records the render-time reading, with no author answer on file. A friend who refuses deliberately and happens to hold no complete deck reads as deckless, and a friend whose deck state changes after refusing changes the line. Deferred in 43.4's plan (low). Ask the author.

### D. Verification gaps

**F11. Staging play and every hitl check are not done.** Done when 1 (two devices on staging, phones then desktops), 2, 3 and 5 (author bans and deletes a test opponent mid-duel) are author checks (epic Notes, High-risk checks). The plans record: 43.5 not verified on a real phone, a screen reader, or against mockup boards 4 to 7; 43.9 "not seen in a real desktop browser", "not compared with boards 11 and 12 (not in the repository)"; 43.7 not verified on a real flaky network or a real 20 s lease expiry in a browser. Mockup boards are not comparable from the repository. The request also reports the desktop hand sitting below the fold at 1180px; no file in the repository records it, so it is carried as an open question, not a finding.

**F12. The secrecy proof is complete at the view and thin at the stream.** `duel_view_test.rb` walks "every call and answer of a whole duel" for each seat (line 89) and the not-started state (line 124). At the broadcast level `duel_stream_job_test.rb` covers a call push and the form naming (lines 40, 82); no test pushes every duel event (challenge, accept, lapse, finish, absence slot) through `DuelStreamJob` and scans the rendered HTML. Done when 4 asks for every broadcast. Defer: add the sweep over events (medium; the epic names this the high-risk check).

**F13. Several builds were integrated without a recorded suite run.** 43.1, 43.2, 43.3, 43.4 and 43.6 plans state "suites run by the coordinator after integration" and "nothing ran under Rails"; no plan records the result. 43.5, 43.7 and 43.9 record real runs (4204 Ruby runs and 1483 vitest for 43.7). The crash F1 is a test-level gap of the same kind. Accept for this epic since later commits ran green suites; prevention in item P2.

### E. Deferred items the plans left (carried, not reopened)

Sourced from plan frontmatter and `deferred-work.md` (lines 689 to 721):
- Native apps: tab or top-bar destination does not count as a disconnection, and the DUELS badge is not wired (43.7; no Swift or Kotlin toolchain). Defer; needs its own native-capable run.
- Closing push: the winner's top-bar capsule chips update on the next load, not on the push (epic 44 ticket, deferred-work).
- 43.4: an away challenger gets no outcome or landing; no way to challenge again after an outcome without a reload; the no-deck outcome read at render time (F10).
- 43.6: late accept between a challenge's 60 s and the 2 to 12 s job or sweep; displayed deadline versus the shortened lease deadline; stale server time on a delayed push. The first deferral (lease never written) was resolved by 43.7.
- 43.5: "Joué" may clip on a 22 to 26 px thumbnail; rematch availability read at render time.
- 43.9: Tab order follows hand, stat, direction, button while the hand sits at the foot on desktop.
- 43.7: connection slot rendered on every board push and re-pushed every 10 s while a seat is away; button keeps the sending label after the timer ran out; resume line on the duel's own page.
- 43.10: `CallRound` and `AnswerRound` share a four-step opening; `guard`, `keepOpen`, `TICK_MS` repeated between Stimulus controllers.

### F. Load, noted by the final review

**F14. Three periodic writers are unmeasured.** (a) `PlayerStreamChannel` writes the reachability lease on subscribe and every 30 s per connection, on every page (`app/channels/player_stream_channel.rb`, `RENEWAL = 30.seconds`), as the epic's R2 specifies. (b) `DuelSeatChannel` writes presence every 10 s per duel connection (`duel_seat_channel.rb`, `periodically :note_presence, every: 10.seconds`). (c) `DuelAbsenceJob` every 10 s re-pushes the connection slot of duels with an absent seat (`config/recurring.yml`, `sweep_duel_absence`), beside the 10 s deadline sweep. All three are by spec; the epic marks live duel load as Unknown and keeps Solid Cable until measured (epic Notes). Accept for 1.4 volumes; measure before the signal is read (action item A6).

## Behavior verification

Not exercised. This run is documentation only: no code was touched, no server was started, and the whole system suite is not run locally. The findings above rest on reading code and plans at `d23a6ed1`; the three gap fixes on the other branch were not read.

## Previous-retro follow-through

Nothing to follow through on: the previous epic, `epic-duel-stats-and-decks` (epic 42), has no `epic-duel-stats-and-decks-retrospective.md` in its folder. This is a missing file, not an empty list of outstanding items.

## Action items

All are proposed; none is applied, and no ticket is created.

| # | Item | Owner | Kind |
|---|---|---|---|
| A1 | Land the three gap fixes (F2 event on the seat-release lapse through the shared closing step, F3 a bad acceptor token refuses inline without lapsing, F4 the distinct-opponents count survives nulled seats), each with a test, and re-read them against this document. | dev loop | remediation |
| A2 | Add the nil-rating-value case beside the nil review count in the rules test, and confirm `by_value` cannot compare an array containing nil against a number. | dev loop | remediation |
| A3 | Add a broadcast-level secrecy test that pushes every duel event through `DuelStreamJob` and scans each seat's HTML for the other hand, an unrevealed call and a draw order (F12). | dev loop | remediation |
| A4 | Play the epic on staging: two phones then two desktops, a refused, cancelled and lapsed challenge, a timer run out, a reload and a drop within 60 s, a ban and a deletion of a test opponent mid-duel; check the desktop hand at 1180px and the desktop board with a lost-connection banner (F6, F11). Add the real phone and screen-reader pass of 43.5. | author | verification |
| A5 | Decide the spec: does a player who goes private mid-duel keep playing, or does the duel close their seat (Done when 5 versus R5, F8); and when the sheet says "no complete deck" (F10). Reconcile `epic-live-friend-duels.md` after the answer. | author | spec reconciliation |
| A6 | Count writes of the three periodic writers during the staging play (F14) before reading the release signal. | author | measurement |
| A7 | Decide whether the native-apps work (tab and top-bar disconnection, DUELS badge) and the 43.4 sheet follow-ups become tickets. | author | triage |
| P1 | Process: a review finding rejected as "rare" in a high-risk epic gets a test of the case, or a deferral with evidence, not a bare rejection; F1 and F3 both began as rejected low findings. | author, retro process | process |
| P2 | Process: record the post-integration suite run of a ticket built without running suites (F13), and rerun a ticket's own test files after a cherry-pick when it declares `after` on a ticket built beside it (F6). | coordinator | process |
| P3 | Process: a refactor sweep that extracts a step searches every writer of the same state transition, including those landed in parallel (F5). | sweep author | process |
| P4 | Process: two tickets of this epic (43.8, 43.10) and all of epic 44 were built with no per-ticket review and the whole-diff review found four defects; for the next epic keep a short per-ticket review on any ticket that writes a state transition. | author | process |

## Acceptance verdict

Proposed: **accepted-with-open-items** (criteria declared in the epic's Done when).

Evidence: every ticket is built and none is unfinished, so the machine rule for **rejected** does not apply. The built behaviour matches each Done when on the record: whole duel, timer, reload and drop, removed player and secrecy have tests (`test/system/duel_play_test.rb`, `duel_deadline_test.rb`, `duel_connection_test.rb`, `duel_removed_player_test.rb`; `duel_view_test.rb`). The final review found one crash (fixed) and three gaps (fix in progress elsewhere); no high-severity finding stands open on `feature/duels` once those land. What is not shown in the evidence is Done when 1, 3 and 5 on staging and the hitl checks (F11), which the epic assigns to the author. The acceptance is conditional on those: if the staging play fails any of them, or if the three gap fixes do not land before the release, this reads as **rejected**. A human decision overrides.

## Open questions

- Does the desktop hand sit below the fold at 1180px (reported in the request, no file records it), and is that acceptable against board 12?
- Which sentence stands for a newly private player: Done when 5 or R5 (F8)?
- Should a ban or deletion push a board to the other seat (F9)?
- Has the three-gap fix branch also added the missing event, or does the sweep rule (P3) need a second change?

## Assumptions

- The epic reference resolved to the folder named in the request, `_bmad-output/initiative-gameble/epic-live-friend-duels`; ticket order is `tickets.py` build order (43.1, 43.2, 43.3, 43.6, 43.4, 43.5, 43.7, 43.8, 43.9, 43.10).
- `pending_tickets` is empty; "built" tickets still at `state: review` count as finished by the build.
- The request's description of the final review (one crash, three gaps, three noted points) is taken as given where the repository holds no copy; each was re-verified against the code and a plan before being written as a finding, except the desktop-fold report, which stayed an open question.
- The machine verdict was rendered from the evidence alone with no human decision; the proposed verdict is the author's to accept or override.
- Epic 44's tickets were not retro'd; F4 appears because it sits on the seat-nulling boundary of 43.8.
- `git_evidence.py` was not run (invocation refused by the worktree git guard); sizes come from `git show --shortstat`.

## Author decisions (2026-11-17)

- F8: a player who goes private mid-duel keeps playing; nothing is changed, the case is not expected to happen.
- F9: accepted. A ban or deletion pushes no board to the other seat.
- F10: accepted. A refusal reads "no complete deck" at render time.
- F14: accepted for release 1.4 volumes.
