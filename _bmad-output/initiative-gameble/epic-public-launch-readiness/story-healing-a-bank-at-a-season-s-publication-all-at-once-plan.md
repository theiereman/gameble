---
title: 'Healing a bank at a season''s publication, all at once'
type: 'feature'
ticket: '6'
created: '2026-10-07'
status: done
baseline_revision: 'e419296bcc721682f3ba0eafef14b228311cacf9'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: [oversized]
deferred:
  - summary: >-
      AD-7 says Game::OpenPack tops the bank back up to ten; since story 7.6 an opening replaces only the opened pack and a short bank waits for the next publication, so AD-7's wording holds only for a full bank.
    evidence: |-
      packs/game/app/models/game/top_up_bank.rb (call replaces one pack, heal fills to ten); architecture-gameble.md AD-7, the OpenPack rule. The architecture document is the author's; this lane does not edit it.
    location: >-
      _bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md AD-7
    severity: low
---

<intent-contract>

## Intent

**Problem:** Commit `2dfebe0` already makes `Game::HealBank` (run by `Game::HealBanksJob` on `Catalog::SeasonPublished`) give every missing pack available now. But an opening still tops a short bank back up to ten (`Game::OpenPack` → `Game::TopUpBank`, every missing pack scheduled ten minutes apart), so a bank is still healed outside a publication, against the author's decision of 2026-10-07 ("a player short of packs outside that moment waits for the next publication"). The publication path is not tested end to end for "available now" and "full bank untouched", and the epic 3 retrospective's B2 cross-operation races (open, register, bonus, heal) are untested.

**Approach:** An opening replaces only the pack it opened (one pack, scheduled as AD-7 says), so a full bank behaves exactly as before and a short bank stays short until the next publication. Healing (all missing packs, available now) stays the only fill of a short bank, reached only from the publication's job. Add the publication-level test and thread race tests.

## Boundaries & Constraints

**Always:** every bank write under `Game::BankLock` inside its transaction; a full bank's opening keeps AD-7's schedule (ten minutes after the latest time in the bank, or after the opening); bonus and reward packs neither count nor move the schedule; with no published season nothing is inserted.

**Never:** no retry of failed heals, no fill on use, no new trigger for healing; keep `Game::CollectDailyBonus`'s fill of a player who never had a pack (the author's one exception); do not change `Game::FillBank`, the job's batching or its two-query cost; do not edit the architecture or epic documents.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Publication, bankless player | no pack ever, season published | 10 regular packs, all `available_at` = publication time, `BankFilled` | a failing player is reported, others served |
| Publication, short bank | 2 unopened (1 available, 1 scheduled) | 8 new packs available at publication time; the 2 untouched; `BankToppedUp` packs: 8 | same |
| Publication, full bank | 10 unopened | no pack inserted, ids and times unchanged, no operation called | — |
| Opening a full bank | 10 unopened | 1 replacement, ten minutes after the later of now and the latest time | — |
| Opening a short bank | 3 unopened, season published | 1 replacement only; bank stays 3 | — |
| Daily bonus / sign-in of a short bank | 3 unopened | bank stays 3 (bonus pack added for the bonus) | — |
| Race heal × open, short bank of 3 | both at once | bank 10, 1 opened, one `BankToppedUp` of 7 | — |
| Race heal × heal | short bank, two heals at once | bank 10, one `BankToppedUp` | — |
| Race register × heal job | new sign-in while the job runs | new player 10 packs, one `BankFilled`, no `BankToppedUp` | — |
| Race bonus × heal | bankless, or short bank with no pack available | 10 regular + 1 bonus, one claim | — |
| Race open × bonus | 9 available + 1 scheduled | both succeed, bank 10, 1 bonus pack | — |

</intent-contract>

## Code Map

- `packs/game/app/models/game/top_up_bank.rb` -- `TopUpBank.call(player_id:, now:, random:, immediate:)`; today inserts every missing pack. Becomes `call` (opening: at most one replacement, scheduled `Pack::INTERVAL` after max(now, latest `available_at`)) and `heal` (every missing pack at `now`); shared private insert reads `DrawPool.current` (nil → 0) and `Pack.row` + `Draw.pack(odds: DrawOdds::REGULAR, size: Pack::SIZE, …)`.
- `packs/game/app/operations/game/open_pack.rb:55` -- calls `TopUpBank.call` for a regular pack; comment lines 8-10 say "tops the bank back up to ten".
- `packs/game/app/operations/game/heal_bank.rb:31` -- calls `TopUpBank.call(..., immediate: true)`; switch to `TopUpBank.heal`.
- `packs/game/app/jobs/game/heal_banks_job.rb`, `packs/game/app/handlers/game/handlers/season_published.rb`, `packs/game/app/events/game/bank_topped_up.rb` -- comments only (healing happens only at publication, all at once).
- `packs/game/lib/tasks/game.rake` -- `game:top_up_banks`, development-only manual run of the job; kept.
- `test/packs/game/top_up_bank_test.rb:83` -- asserts the fill-on-use being removed; rewrite.
- `test/packs/game/heal_banks_job_test.rb` -- add the publication-level test (`Catalog::PublishSeason` + `perform_enqueued_jobs`, `seed_card_seasons(distinct_scores(150))` from `test/support/catalog_seeds.rb`).
- `test/packs/game/open_pack_concurrency_test.rb` -- pattern for non-transactional thread tests and their teardown (packs, holdings, feed entries, weekly contributions, event streams).
- `Accounts::SignIn.new.call(steam_id:)` -- registers a player and fills the bank synchronously (`Game::Handlers::PlayerRegistered`), also creating `Game::PlayerState` and `Game::FriendCode` rows.

## Tasks & Acceptance

**Execution:**
- [ ] `packs/game/app/models/game/top_up_bank.rb` -- split into `call` (one replacement) and `heal` (all missing, now); drop `immediate:` -- an opening never fills a short bank.
- [ ] `packs/game/app/operations/game/heal_bank.rb`, `open_pack.rb` -- use `heal` / reword comments -- the single healing path.
- [ ] `packs/game/app/jobs/game/heal_banks_job.rb`, `handlers/game/handlers/season_published.rb`, `events/game/bank_topped_up.rb` -- comments -- state the rule.
- [ ] `test/packs/game/top_up_bank_test.rb` -- replace the short-bank opening test; add "outside a publication nothing heals" (open, daily bonus, sign-in) -- verify's last clause.
- [ ] `test/packs/game/heal_banks_job_test.rb` -- publication test of the matrix's three publication rows.
- [ ] `test/packs/game/bank_races_test.rb` -- new non-transactional thread tests of the matrix's race rows.

**Acceptance Criteria:**
- Given a bankless player, a short bank and a full bank, when a season is published and its job runs, then the bankless player has ten packs and the short bank its missing packs, all available at the publication time, and the full bank is unchanged.
- Given a short bank and a published season, when the player opens a pack, collects a daily bonus or signs in, then the bank holds no more regular packs than before.
- Given two bank operations of different stories started at once on one player, when both finish, then the bank holds exactly ten regular unopened packs (or the expected count) and each fill event is published once.

## Implementation Notes

- Subagents unavailable, done in-session (the lane's brief allows it when no subagent tool is offered).
- Already on develop before this run: commit `2dfebe0` (the author's) made `Game::HealBank` give every missing pack available now. This run completes the story: the opening's fill of a short bank is removed, the publication is tested end to end, and the cross-story races are tested.
- `Game::TopUpBank`: `call` (opening) now inserts at most one pack, the opened one's replacement; `heal` inserts every missing pack at `now`; the `immediate:` keyword is gone (its only caller was `HealBank`). A full bank's openings keep the exact schedule of before (every existing replacement test unchanged and green).
- `test/packs/game/top_up_bank_test.rb`: the test that asserted a short bank topped up to ten on opening now asserts the opposite (one replacement, the bank stays at three, no `BankToppedUp`); a new test runs an opening, a daily bonus and a sign-in on a short bank and finds it still short.
- `test/packs/game/bank_races_test.rb`: thread races slow `Game::DrawPool.current` (read by every bank write after its reads) so the two transactions overlap. Checked by mutation: without `BankLock` in `HealBank`, "two heals at once" fails; without it in `FillBank`, "daily bonus and fill" fails. Heal × open stays at ten even without the heal's lock, since an opening now adds exactly what it takes.
- The daily bonus raced against the publication's fill for a bankless player has two outcomes by order (the fill first makes ten packs available, so the bonus is refused `reserve_full`, unclaimed); the test accepts both and checks each is whole.
- `game:top_up_banks` kept: development only (refuses production), it runs the publication's job.
- Not changed: `architecture-gameble.md` AD-7 still says an opening "tops the bank back up to ten"; with this change that holds only for a full bank (recorded in `deferred`).

## Plan Change Log

## Review Triage Log

### 2026-10-07 — Review pass
- Quick lens run in-session (no subagent tool in this lane), against the plan's acceptance criteria and the diff since the baseline; no AGENTS.md or CLAUDE.md in the worktree.
- verdicts: 3 findings — high 0, medium 0, low 1, false 2, maybe-false 0
- findings:
  - `[low]` `[defer]` AD-7 in the architecture still says an opening tops the bank back up to ten — real wording drift, harmless at run time; the document is the author's, recorded in `deferred`.
  - `[false]` `[reject]` The heal × open race test does not fail when `HealBank` loses its lock — true, but no bad outcome follows: an opening now adds exactly the pack it takes, so the bank ends at ten in every interleaving; the heal's own lock is caught by "two heals at once" (mutation-checked).
  - `[false]` `[reject]` `TopUpBank.call` could under-replace when the opened pack is not in the bank — refuted: `call` runs only for a regular pack (`open_pack.rb:55`), and the bank is every unopened regular pack, so the opened pack was in it and the count is at most nine afterwards.

## Design Notes

Two orderings of heal × open on a bank of three both end with a `BankToppedUp` of 7 (open first: 3→2+1=3, heal +7; heal first: +7=10, open 9+1=10), so race assertions stay order-independent. For bonus × heal on a short bank, its packs are scheduled in the future so the reserve cannot be full in either order.

## Verification

**Commands:**
- `bin/rails test test/packs/game` (lane env, PARALLEL_WORKERS=2) -- expected: green
- `bin/rails test` (non-system) -- expected: green
- `bin/rubocop` on changed Ruby files -- expected: no offenses

## Auto Run Result

- **Summary:** a bank is now healed only at a season's publication. An opening replaces only the pack it opened (`Game::TopUpBank.call`), so a full bank keeps AD-7's schedule and a short bank stays short until the next publication. The publication's job fills a player with no pack and heals a short bank with every missing pack available at once (`Game::TopUpBank.heal`, through `Game::HealBank`; the at-once part came with the author's commit `2dfebe0`). The publication is tested end to end, and the bank operations of different stories are raced in thread tests.
- **Files changed:**
  - `packs/game/app/models/game/top_up_bank.rb`: `call` (one replacement after an opening) and `heal` (every missing pack, available now); `immediate:` removed.
  - `packs/game/app/operations/game/heal_bank.rb`: uses `TopUpBank.heal`; comment states the only-at-publication rule.
  - `packs/game/app/operations/game/open_pack.rb`, `packs/game/app/jobs/game/heal_banks_job.rb`, `packs/game/app/handlers/game/handlers/season_published.rb`, `packs/game/app/events/game/bank_topped_up.rb`: comments only.
  - `test/packs/game/top_up_bank_test.rb`: the fill-on-use test is reversed; a new test checks that an opening, a daily bonus and a sign-in leave a short bank short.
  - `test/packs/game/heal_banks_job_test.rb`: a test publishes a season with a bankless player, a short bank and a full bank.
  - `test/packs/game/bank_races_test.rb` (new): seven non-transactional races (heal × open, heal × heal, fill × heal, sign-up × job, bonus × fill, bonus × heal, open × bonus), with a slowed draw pool so the transactions overlap.
- **Review:** quick lens, in-session. 0 patches applied; 1 item deferred (AD-7 wording, low); 2 findings rejected as false (see the Review Triage Log).
- **Follow-up review recommended:** false. No patches were applied (high 0, medium 0, low 0).
- **Verification:**
  - `bin/rails test` (non-system, PARALLEL_WORKERS=2): 1437 runs, 0 failures.
  - `bin/rails test test/packs/game/bank_races_test.rb`: green 5 times in a row.
  - Mutation checks: removing `BankLock` from `HealBank` or from `FillBank` makes a race test fail.
  - System tests `countdown_test.rb`, `booster_test.rb`, `hub_test.rb` and `daily_bonus_test.rb` (PARALLEL_WORKERS=1): 53 runs, 0 failures.
  - `bin/rubocop` on the 9 changed Ruby files: no offenses.
- **Residual risks:** a player who is short of packs, banned during a publication, or whose heal failed waits for the next publication. This follows the author's decision: no retry and no fill on use. AD-7's text needs reconciling (deferred).
