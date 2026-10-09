---
title: 'Replacement packs and the timer'
type: 'feature'
ticket: '2'
created: '2026-10-02'
status: done
baseline_revision: '9afcebe82e50137213c26121aeaccfcf8659914a'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
context: ['{project-root}/_bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md', '{project-root}/_bmad-output/initiative-gameble/epic-packs-and-reveal/story-open-a-pack-end-to-end-plan.md']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** An opened pack is never replaced, so a player's bank empties for good, and the attic cannot say when the next pack comes (epic 3, R1, R4, R9; CAP-4: one pack every ten minutes, up to ten banked, accruing while away).

**Approach:** Keep, for every player with a bank, exactly ten unopened regular packs, some available now and some scheduled. Opening a regular pack tops the bank back up to ten in the same transaction: each new pack is drawn at once from the in-memory pool and scheduled ten minutes after the later of the opening time and the latest scheduled time in the bank. The attic shows a countdown to the next pack, hidden when all ten are available.

## Boundaries & Constraints

**Always:**
- "The bank" for the cap and the schedule is the player's unopened `regular` packs; bonus and reward packs never count and never move the schedule (R1, story 3.7).
- `Game::TopUpBank` (private step shared by `OpenPack`, under the bank lock, after the pack is marked opened): while the bank holds fewer than ten packs, insert a `regular` pack drawn now (regular odds, current pool, the season published now) with `available_at = max(opened_at, latest available_at in the bank) + 10 minutes`, recomputed after each insert. With ten packs before an opening this equals the spec's rule — ten minutes after the latest time in the bank, or after the opening when the bank was full — and it heals a bank left short by earlier builds. Opening a `bonus` or `reward` pack tops up nothing. No published season: nothing inserted, the opening still succeeds.
- Decision (recorded as a deviation from AD-7's "enqueues a job that draws the replacement", in `pending-approvals.md`): the replacement is drawn inline — five picks from the per-process in-memory pool, microseconds — instead of by a job, removing undrawn packs, their nullable season, the job and its race. Story 3.9 warms the pool at boot so a cold load never lands in an opening.
- A player whose bank was emptied by 3.1's build (all opened, no replacement) is healed by `bin/rails game:top_up_banks` (idempotent, under the bank lock, development data only; no production data exists yet), scheduling the missing packs from now.
- `Game::BankSummary` adds `next_available_at`: the earliest future `available_at` in the bank, nil when every bank pack is available or the player has no bank. `available` keeps counting every kind available now.
- Attic: under the chest, when `next_available_at` is set, a countdown in mm:ss (at most ten minutes away): the server renders `seconds_remaining`; a Stimulus `countdown` controller counts down against a `performance.now()` deadline, keeps the ticking text `aria-hidden` beside a static visually hidden "Next pack at HH:MM (UTC)", and at zero plus one second refreshes the page with a Turbo morph (`turbo_refreshes_with method: :morph, scroll: :preserve`; `Turbo.visit(location.href, { action: "replace" })`) so the attic keeps its scroll; the attic page is `data-turbo-cache="false"`. Not shown to a visitor. Copy in `fr` and `en`.
- Times in UTC; tests use `travel_to`; the concurrency test of 3.1 gains two concurrent openings of a full bank.

**Never:** no task per player on a schedule; no undrawn pack; no change to the first fill; no bonus pack (3.7).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Full bank opened | 10 available, open at T | replacement drawn, at T + 10; 9 available, countdown 10:00 | — |
| Scheduled packs | 8 available + T + 4 and T + 14, open at T | replacement at T + 24 | — |
| Accrual while away | ten openings at T, back at T + 35 min | 3 available (T + 10, + 20, + 30), 7 scheduled; countdown to T + 40 | — |
| Concurrent openings | two threads open a full bank at T | replacements at T + 10 and T + 20 | bank lock |
| Invariant | 30 openings at varied times | always 10 regular unopened; never more than 10 regular available | — |
| Short legacy bank | 3 unopened regular, open one | bank topped up to 10, scheduled 10 min apart from max(now, latest) | — |
| Emptied legacy bank | 0 unopened; `game:top_up_banks` | 10 packs scheduled from now; a second run adds nothing | — |
| No season | bank opened, nothing published | opening succeeds, nothing inserted | — |
| Bonus present | a bonus pack opened; bonus packs available while the bank is full | no top-up; countdown hidden | — |
| Empty now | 0 available, scheduled packs | chest "No pack" disabled, countdown shown | — |
| Visitor | signed out | no countdown | — |
| Countdown | a pack scheduled at now + 3 s (real clock, system test) | count rises after the morph refresh; scroll kept | — |

</frozen-after-approval>

## Code Map

- `packs/game/app/operations/game/{open_pack,fill_bank}.rb`, `app/models/game/{pack,draw,draw_odds,draw_pool,bank_lock}.rb`, `app/queries/game/bank_summary.rb`.
- `test/packs/game/{open_pack_test,open_pack_concurrency_test}.rb`, `test/support/game_packs.rb`.
- `lib/tasks/` -- the rake task.
- `app/views/pages/home.html.erb`, `app/views/layouts/application.html.erb` (morph meta), `app/frontend/controllers/` (glob-registered), `app/frontend/styles/attic.css`, `config/locales/{en,fr}.yml`.
- `_bmad-output/initiative-gameble/pending-approvals.md` -- the AD-7 deviation.

## Tasks & Acceptance

**Execution:**
- [x] `packs/game/app/operations/game/open_pack.rb` -- top-up; `app/queries/game/bank_summary.rb`.
- [x] `lib/tasks/game.rake` -- `game:top_up_banks`.
- [x] attic countdown: view, `countdown_controller.ts`, CSS, layout meta, locales.
- [x] `pending-approvals.md` entry.
- [x] `test/` -- every matrix row.

**Acceptance Criteria:**
- Given a player who opened all ten packs at T, when they come back at T + 35 minutes, then the chest shows 3 packs and the countdown points to T + 40 minutes.
- Given `bin/rails test`, `bin/rails test:system`, `npm run typecheck`, `bundle exec packwerk check`, `bin/rubocop` and `bundle exec i18n-tasks missing`, when run, then all pass.

## Implementation Notes

- `Game::TopUpBank` is a module step (`packs/game/app/models/game/top_up_bank.rb`, like `BankLock`), called under the bank lock by `OpenPack` (regular packs only) and `HealBank`; it inserts all missing packs in one `insert_all!`, the k-th at `max(now, latest) + k × 10 min` (same as recomputing after each insert). `Pack::BANK_SIZE`, `Pack::INTERVAL` and the `Pack.bank(player_id)` scope (unopened regular) added; `FillBank::BANK_SIZE` now points at `Pack::BANK_SIZE`. `OpenPack.new(random:)` takes a seeded random like `FillBank`.
- The rake task calls a new operation, `Game::HealBank` (AD-3; a player who never had a pack is left to `FillBank`), which publishes `Game::BankToppedUp` (`{ player_id:, packs: }`) when it inserts (AD-10). The task lives in `packs/game/lib/tasks/game.rake` (packs-rails loads it): from `lib/tasks` the `lib` package could not reference `Game`/`Accounts` (packwerk). It refuses to run in production.
- Morph and cache metas come from the attic view (`turbo_refreshes_with`, `turbo_exempts_page_from_cache`, both through the layout's existing `yield :head`), so only the attic refreshes by morph; the layout is unchanged. "Not cached" is the `turbo-cache-control: no-cache` meta.
- The countdown sits beside the chest's button (a plate like the objects' names): under it, the room has no height left. `seconds_remaining` is computed in `PagesController` (ceil), with the static time `HH:MM` UTC.
- A morph would strip the attic's JS-set `tabindex`; `attic#keepTabStop` cancels that attribute's `turbo:before-morph-attribute`. The pan (`scrollLeft`) survives the morph since the element is kept.
- The countdown controller reaches Turbo through `window.Turbo` (the npm package has no types).
- Review fixes: the countdown starts or resumes in `connect()`, and after a refresh it tries again every 5 s until the value changes or it disconnects. It does not refresh from `turbo:submit-start` until the next `turbo:load`, or until a failed `turbo:submit-end`, so an "Open a pack" in flight is never cancelled. `FillEmptyBanksJob`, run on every season publication, now heals banks short of ten (`HealBank`) as well as filling never-banked players (`FillBank`), so a bank emptied while no season was published is refilled. `game:top_up_banks` reuses that job's walker: each player is rescued and reported, and the run goes on.

## Plan Change Log

## Review Triage Log

### Pass 1 (quick) — high 0, medium 3, low 1, false 0, maybe-false 0

| # | Verdict | Route | Finding | Evidence / action |
|---|---|---|---|---|
| 1 | medium | patch | The countdown's `Turbo.visit` could cancel an opening in flight (Turbo stops the pending form submission) | Confirmed in Turbo 8's Navigator. The controller holds refreshes from `turbo:submit-start` to the next load; system test with a delayed POST. |
| 2 | medium | patch | The countdown froze at 00:00 when a refresh failed or returned the same value | Confirmed (timer only armed on value change). Resumed on `connect()`; retries every 5 s; system test with a frozen server clock. |
| 3 | medium | patch | A bank emptied while no season was published was never refilled in production | Confirmed (`FillEmptyBanksJob` skipped players who had packs; the rake task refuses production). The job on `SeasonPublished` now heals short banks too; test. |
| 4 | low | patch | `game:top_up_banks` aborted on one failing player | The task runs the job's per-player walker. |


## Verification

**Commands:**
- `bin/rails test && bin/rails test:system` -- expected: all green.
- `npm run typecheck && bundle exec packwerk check && bin/rubocop && bundle exec i18n-tasks missing` -- expected: no offence.
