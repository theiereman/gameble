---
epic: epic-duel-capsule-record-and-achievements
date: 2026-11-17
verdict: rejected
criteria: declared
headless: true
---

# Retrospective: Duel capsule, record and achievements (epic 44)

Machine verdict `rejected` because ticket 44.5 is unfinished (rule: any unfinished ticket forces it). 44.5 is the author's release 1.4.0 and is pending by design, not a failure. The proposed human decision is in Acceptance verdict.

## Epic summary

Tickets (`tickets.py status`, build order):

| Ticket | Title | status / state | Plan baseline | Commit |
|---|---|---|---|---|
| 44.1 | First real win of the day gives a duel capsule | built / review | `852d5a6f` | `5f7eca45` |
| 44.2 | Profile and Duels screen show the record and last duels | built / review | `5f7eca45` | `7250f668` |
| 44.3 | Ten duel achievements and the Duelliste back | built / review | `940317c6` | `8f3226dd` |
| 44.4 | Refactor sweep | built / review | `7250f668` | `eef84890` |
| 44.5 | The author ships release 1.4.0 | (none) / planned, HITL | none | none |

- Tickets still at `built`: 44.1 to 44.4. Unfinished (`pending_tickets`): 44.5.
- Branch under review: `feature/duels` at `d23a6ed1`, not on origin. The head commit is the review's fix to epic 43's rules (`game/duel_rules.rb`), not an epic 44 ticket.
- Ranges by plan baseline, oldest first: 44.3 `940317c6..852d5a6f`; 44.1 `852d5a6f..5f7eca45`; 44.2 `5f7eca45..7250f668`; 44.4 `7250f668..d23a6ed1` (inferred end; the last commit is the review fix). `git_evidence.py` was run on the 44.3 range: it mixes in epic 43 commits (`4bf2fd3b`, `c4e6479f`, `852d5a6f`) because the builds interleaved, so ticket-level volume below comes from each ticket's own commit (`git show --stat`) instead.
- Ticket volume: 44.1 38 files, +660/-19 (4 tests, 3 migrations, 4 pixel assets); 44.2 23 files, +613/-17; 44.3 33 files, +518/-28; 44.4 12 files, +156/-18.
- Evidence available: epic file, four plans, `tickets.toml`, branch commits, `deferred-work.md` (sections of 2026-11-17), the committed code, and the review's findings as given in the run brief (not a file in the tree). Missing: session logs (process lessons are limited to what plans and commits record), staging or production observations, and any previous retrospective (see follow-through).
- Review facts as plans record them: only 44.3 ran a review (`review: quick`, `lenses_ran: ['quick']`, a Review Triage Log of 5 findings, 3 patches applied). 44.1, 44.2 and 44.4 are `review: none`, each plan saying the author reviews the whole duel diff at the end.

## Findings

Each finding has a source and two dispositions: this instance / what would prevent the next.

### Aggregate views

F1. **Distinct-opponents metric loses progress when an opponent deletes their account.** `OPPONENTS_SQL` counts `DISTINCT other.player_id` over the other seat (`app/domains/game/app/queries/game/duel_achievement_metrics.rb:10-14`), and `game_duel_seats.player_id` is nullable (`db/schema.rb:489`), so a deleted opponent's seat stops counting. The metric was written in `8f3226dd` before the deleted-seat rule landed in `852d5a6f` (43.8), the dependency 44.3 skipped (see F6); the order is consistent with the gap, the code line proves it. Review found it; a fix is in flight on another branch. Disposition: fix now (in flight) / the achievement ticket should have read the removed-seat rule of the epic it waits on.

F2. **Record figures reuse the achievement metrics' SQL.** `DuelRecord::WINS_SQL` is `DuelAchievementMetrics::SQL.fetch(:duels_won)` and `ProfileActivity` embeds it (`duel_record.rb:6`, `profile_activity.rb:11-13`; sweep item 2 of 44.4). One definition of a win is good, but a change to the achievement metric now changes the profile figure, a coupling the sweep made on purpose and no test names. Disposition: accept, with F3's test as its guard.

F3. **No test covers the friends-only case of the record figures.** `public_profiles_controller_test.rb:527-546` asserts the figures for a public owner and the not-found page for a private owner; the friends-only visibility tests (`:548`, `:577`) do not assert the Duels figures. Disposition: fix now / a privacy-rule story lists each visibility value in its verify, not only the private one.

F4. **Flavours of R6 not delivered.** The epic's R6 and the 44.3 ticket call for a flavour per achievement; the locale structure has name and condition only, so none were added (`deferred-work.md:730-731`, plan 44.3 Triage Log, finding marked false and recorded). Spec and implementation disagree: the spec text names a field the product does not have for the 30 earlier achievements. Disposition: spec reconciliation for the author (drop flavours from rows 24 to 33 or add the field for all 40); not applied here / have a ticket's description checked against the data model when it is refined.

F5. **No finding on repeated code left open.** Duplicates the sweep found (N+1 on opponents, SQL copy, spoken-result helper) were fixed in 44.4; the plan lists the remaining drawings of crossed blades as accepted (`deferred-work.md:752-753`). Disposition: accept.

### Process and boundaries between tickets

F6. **44.3 was built ahead of 44.1 against its declared dependency (`after = [1]`).** Its baseline `940317c6` precedes 44.1's `852d5a6f`. Cost seen in the record: two deferred lines about the Duelliste back that contradicted each other ("may reuse the grid" against a later `resolved` line) until 44.4 stated the actual reason (`story-refactor-sweep-plan.md`, Implementation Notes). No code defect traces to the order except F1, by inference. Disposition: accept for the docs; the lesson is that an out-of-order build needs its plan to name what it could not see (here the removed-seat rule) / process change in Action items.

F7. **44.2 and 43.10 ran in parallel and shared `answer_round.rb`.** 44.1 changed it (`5f7eca45`), then the epic 43 sweep `d1cddee3` rewrote 9 lines of it before 44.2's baseline moved on. No conflict or regression is recorded, and 44.4's full suite passed, so this is "checked, clean" on the available evidence. Disposition: accept.

F8. **Eleven fr.yml strings failed `FrenchTypographyTest`; they came from 44.2, not 44.3.** The strings are the record line and Comment ça marche's duels section (`config/locales/fr.yml`, `7250f668` added them with a plain space before `:` and `;`; `eef84890` fixed them). 44.2's plan lists only targeted tests, with no full `bin/rails test`; 44.4 found the failure "by the full suite" (sweep plan, item 5). 44.1 ran the full suite, 44.3 its own suites. Disposition: fixed in 44.4 / prevention: a no-review build must run the whole Ruby suite once, or the plan must say it did not.

F9. **The known red test carried through the epic.** `test/integration/error_pages_test.rb` fails on `public/errors/starfield.svg` drift on the base (plans 44.1, 44.3, 44.4). Every verification section says "one known unrelated failure", which trains readers to skim a red run. Disposition: defer, someone should own it / prevention: a known failure gets a ticket or a quarantine, not a sentence in each plan.

F10. **Three of four tickets shipped with no review, by the author's choice.** Findings the single whole-diff review then surfaced (F1, F3 and the epic 43 nil tie-break crash fixed in `d23a6ed1`) were all findable per ticket. The cost was bounded because the review ran before release, but F1 would have reached production behind an author who had not read the diff. Disposition: accept as a trade; see Action items for the rule.

### Reviewed and judged sound (checked, clean)

- `Game::DuelCapsule.award` (`duel_capsule.rb`): runs inside the finishing move, takes the winner's bank lock, inserts with the unique index as the final guard (`unique_by: INDEX`, `.rows.any?`), skips draws, removed winners and automatic moves of the winner. The `nil` return for nobody-won, removed winner and missing pool is recorded as deferred (`deferred-work.md:754`).
- Migrations `20261117100000` to `100002`: checks swapped as added-not-valid, validated in their own migration, the unique index concurrent in its own migration, per the project's expand/contract rule; the review judged them sound. They have not run on real data (see Action items).
- The profile's privacy rules for the record: a private owner's page is not found and shows no figure (test above); only the friends-only case is untested (F3).

### Known gaps carried as deferred by the build (not new findings)

- Winner's top-bar capsule chips do not update on the duel's closing push; they update on the next page load (`deferred-work.md:736`, plan 44.1).
- A published season with an empty tier makes `Game::DrawPool.current` raise inside the finishing move, so a duel could not finish until the season is repaired (`deferred-work.md:738`, plan 44.1). A season cannot be published with an empty tier, which bounds it.

## Behavior verification

Runtime behavior was not exercised in this run: the retrospective only reads the record and the code, and the run brief forbids touching code. What the plans report instead, not independently re-run here: 44.4's `bin/rails test` (6000 runs, one known unrelated failure), the three system test files (`duel_capsule_test.rb`, `duel_record_test.rb`, `duel_achievements_test.rb`) one at a time, vitest, zeitwerk, packwerk, format, CSS lint, planning references, file sizes, `i18n-tasks`, rubocop and `node script/pixel_art/export.mjs --check`. Nothing was exercised on staging, on a phone or on production data.

## Previous-retro follow-through

No previous retrospective file exists for epic 43 (`epic-live-friend-duels/`) or for the epics 38 to 42 folders checked; this is "no file", so there are no outstanding items to follow through on. Not a statement that none were outstanding.

## Action items

All proposed; none is applied or ticketed here. Owners are roles, the author owns the release.

Before the author ships 1.4.0:

1. **Real-phone checks (author).** On a phone with two accounts: the result panel in its three cases (CAPSULE DE DUEL GAGNÉE linking to the capsule screen, "Pas de capsule : un de vos coups a été joué automatiquement.", "Capsule de duel déjà gagnée aujourd'hui."); the duel capsule in the special reserve, the blue-steel canister on the capsule screen and its "EN OUVERTURE" line (`booster_render.ts`, `booster-canister.css`, `booster-capsule.css`, `duel-reveal.css` all changed in 44.1); the Duels screen with the record and ten DERNIERS DUELS rows wrapping at phone width (`duels.css` +72 lines), the desktop left column; the profile's Duels figures; the achievement toasts after a duel's end; the Duelliste back in the picker at 50 wins, both locales. Source: 44.1 to 44.3 verify sections, Done when 1 to 3, no staging evidence in the tree.
2. **Migrations on real data (author, with the dev loop).** Run `20261117100000` to `100002` on a copy of production data: time the validation of the four swapped checks on the real `game_packs` and `game_fortunes` rows, confirm the concurrent partial unique index builds and the CI schema-drift job is green. Source: plan 44.1 Residual risks ("the migrations run on production data only at deploy"), epic High-risk checks.
3. **Production-like capsule economy (author).** With production-like data, check how a pair of cooperating friends could mint: the grant is one per player per UTC day, so two accounts can each take one by beating each other once a day with no automatic move; confirm that this is within the intended economy, that the Flukeometer counts `duel_packs`, and that the daily snapshot and the economy health page read them (44.1 made `Game::Fortune::PACK_COLUMNS` drive the board's sum and the backfill's tally check). Confirm the live season has every rarity tier so `Game::DrawPool.current` cannot raise in the finishing move (deferred line above).
4. **Fix the distinct-opponents metric (dev loop, in flight on another branch).** Count the seat's opponent by identity that survives account deletion or state the intended behavior; add the deleted-opponent test. After it lands, re-run the whole duel diff's tests.
5. **Add the friends-only test (dev loop).** Cover the Duels figures for a friends-only owner as a friend and as a stranger, next to `public_profiles_controller_test.rb:527`.
6. **Spec reconciliation for flavours (author).** Decide whether R6 and EXPERIENCE rows 24 to 33 keep flavours; if they do, a flavour field must exist for all 40 achievements.
7. **Own the red error-pages test (author or dev loop).** `test/integration/error_pages_test.rb` and `public/errors/starfield.svg` drift, carried in every plan.
8. **Decide the chips deferral (author).** The top-bar capsule chips update only on the next page load after a duel win; accept or ticket after the phone check (item 1).

Process lessons (for the ticket skills' owner, proposals only):

9. A ticket built out of order records in its plan the epics and tickets it could not see and the rules that landed after it (F1, F6).
10. A build with no review still runs the whole Ruby suite once (F8, 44.2), and a privacy or visibility rule lists every visibility value in its verify (F3).
11. When the author reviews the whole diff at the end, give that review the boundary list this retro found (removed seat against achievement metric, record against achievement SQL) so it checks the same places (F1, F2, F10).

## Acceptance verdict

Machine verdict: **rejected**, criteria **declared**. Evidence: `pending_tickets` is `["44.5"]`. Against the epic's Done when:

1. Capsule on the first win, none on the second or after an automatic move, the result saying why: built and covered by tests and one system test (plan 44.1); not exercised on staging.
2. Profile record and the Duels screen's record and last ten results: built and covered (plan 44.2); not exercised on staging.
3. Ten duel achievements unlock from real duels, 50 wins unlock the Duelliste back: built (plan 44.3), with F1 (opponent metric, fix in flight) and F4 (flavours) open.
4. Release 1.4.0 in production: not done, 44.5 is the author's.

Proposed human decision, for the author to take or reject: **accepted-with-open-items for 44.1 to 44.4**, 44.5 left pending to the author. Conditions to hold the release until met: item 4 (the metric fix) merged, items 1 to 3 done (phone, migrations on real data, capsule economy). F3 and the flavours decision (items 5 and 6) can ride with the release or follow it. No human decision is recorded here; the frontmatter stays the machine verdict.

## Open questions

- Is a pair of friends each taking one capsule a day by beating each other the intended economy, or should the grant depend on something else (for example a distinct opponent per day)? Only the author can say; the spec's text on this was not re-read in this run.
- Should the closing push update the top-bar chips for the winner (item 8)?
- Should `Game::DuelCapsule.award` return a named value for "nothing won"? The build judged it not worth a constant (`deferred-work.md:754`).

## Assumptions

- The epic reference was an explicit folder; it resolved to `epic-duel-capsule-record-and-achievements`.
- `pending_tickets` is `["44.5"]`; I proceeded without a confirmation (headless) and the machine verdict is `rejected` as the rule requires. The reading of 44.5 as pending by design, and the proposed `accepted-with-open-items` decision, come from the run brief, not from the tree.
- The review's findings (nil review count tie-break fixed in `d23a6ed1`, three gaps being fixed elsewhere, DuelCapsule.award, the migrations and the privacy rules judged sound, F3, F1) come from the run brief; F1, F3 and the sound-code claims were re-checked against the code and tests I read, the review's own text was not available to me.
- The brief attributes the eleven French strings to 44.3; the commit history shows `7250f668` (44.2) introduced them, and the document follows the commits.
- The `bmad-review` lenses were not invoked: the whole-duel-diff review had already run, and reading the code was limited to the boundaries named in the brief. Scope narrowed, not "checked and clean" outside the files cited above.
- Every action item is a proposal; no ticket, plan, `pending-approvals.md` or frozen block was touched.

## Author decisions (2026-11-17)

- Capsule economy: one duel capsule per player per day stays as built; a pair of friends may each take one.
- Flavours: dropped. R6 of the epic no longer names them; EXPERIENCE.md already says no flavor text on achievements.
- Distinct opponents: opponents who deleted their account count as one opponent together.
- Top-bar chips after a duel win: accepted, they update on the next page load.
