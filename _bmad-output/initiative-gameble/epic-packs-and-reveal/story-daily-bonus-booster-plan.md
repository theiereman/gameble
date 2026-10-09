---
title: 'Daily bonus booster'
type: 'feature'
ticket: '7'
created: '2026-10-02'
status: done
baseline_revision: '4ddebaf7a8d5c4b6a3dbfa3c69c53496a8e77270'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
context: ['{project-root}/_bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md', '{project-root}/_bmad-output/initiative-gameble/epic-packs-and-reveal/story-replacement-packs-and-the-timer-plan.md']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A returning player has no reason to come back each day (CAP-16; epic 3, R8, R9).

**Approach:** Once per UTC day a signed-in player collects a small bonus booster from a panel in the attic: a `bonus` pack of three cards drawn with better odds, added to the bank outside the cap of ten and opened like any pack, in arrival order (after the packs already available). One claim row per player and UTC day, unique in the database, makes a second collection impossible whatever the client does.

## Boundaries & Constraints

**Always:**
- `game_daily_bonus_claims`: player (FK), `day` (date, UTC), `pack_id` (FK to `game_packs`, indexed), timestamps; unique `(player_id, day)` (AD-9). `DailyBonusClaim.day_of(now) = now.utc.to_date`, shared by the operation and `BankSummary`.
- `Game::DrawOdds::BONUS = { 2 => 7_000, 3 => 2_400, 4 => 500, 5 => 100 }` and `Game::Pack::BONUS_SIZE = 3`, the single source in code of the assumption already recorded in the epic Notes and `pending-approvals.md`. Tests assert the literal hash, its keys 2–5 (no steel, by key) and its sum; the odds are tested at `Draw` level (`Draw.pack(odds: BONUS, size: 100_000, random: Random.new(seed), pool:)` on a seeded 150-card season, tiers within 4 σ).
- `Game::CollectDailyBonus.new(random: SecureRandom).call(player:)`, under the bank lock, with `now` taken once: (1) a claim for `day_of(now)` exists → `Failure(:already_collected)`; (2) no published season → `Failure(:no_season)` (no claim, so the player can collect later that day); (3) `step FillBank.new.call(player:)` (the lock is re-entrant), so a player without a bank gets their ten packs and guarantee first; (4) insert a `bonus` pack of `BONUS_SIZE` cards drawn with `BONUS`, available `now`; (5) insert the claim; (6) publish `Game::DailyBonusCollected` (`{ player_id:, pack_id: }`, the player's stream). No savepoint: the lock serialises a player's collections, and the unique index is the database's guarantee. Returns the pack.
- It relies on story 3.2: the bank is unopened `regular` packs; opening a bonus tops nothing up; `next_available_at` ignores bonus packs.
- `Game::BankSummary` adds `bonus_collectable`: `Catalog::PublishedSeason.call.present?` and no claim for `day_of(now)` (the same two checks; never loads the draw pool).
- Web: `resource :daily_bonus, path: "daily-bonus", only: :create` in the locale scope; `DailyBonusesController#create` authorizes `:daily_bonus, :create?` (`DailyBonusPolicy#create?` a signed-in player; a visitor is refused through `ApplicationController#refuse` with `authorization.sign_in_required` — the Steam redirect is story 3.8's), rate limit 5 a minute by player with its own throttled message, and redirects to the attic with `:see_other` and a notice, or with `Game::CollectDailyBonus.failure_message` for `already_collected`, `no_season` and `player_required`. The attic shows the panel (text plate and button) through a `bonus_panel` local so story 3.8 only widens its condition; hidden once collected until a page load after midnight UTC. The packs result page titles a `bonus` pack "Your daily bonus" and lists its three cards. Copy in `fr` and `en`.
- The reveal (3.6) takes its card count from the pack; the epic Notes say so.

**Never:** no streak or other reward; no change to the regular odds or the bank of ten; no client-side day; no live push of the panel at midnight.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Collect | full bank, no claim today | one claim, a bonus pack of 3 available now, one event; `available` 11; `next_available_at` nil | — |
| No bank yet | season published, player without packs | ten regular packs (with the guarantee) plus the bonus | — |
| Twice / double submit | claim today | nothing written, no event; second request redirected with the message | `Failure(:already_collected)` |
| Race | two threads collect at once (non-transactional test) | one success, one `already_collected`; one claim, one bonus pack | bank lock |
| Duplicate row | a direct insert of the same `(player_id, day)` | refused | `RecordNotUnique` |
| Day boundary | claimed at 23:59:59 UTC, collect at 00:00:01; inside `Time.use_zone("Pacific/Kiritimati")` | collected; claim day is the UTC date | — |
| Not full | 8 available + 2 scheduled, collect | `next_available_at` unchanged | — |
| Opening order | 3 regular available, then collect | the bonus opens fourth; opening it inserts no regular pack | — |
| Pile-up | bonuses of several days unopened | `available` above 10; countdown unaffected | — |
| No season | nothing published | no claim, no pack; collect later that day works | `Failure(:no_season)` |
| Banned | banned player | nothing written | `Failure(:player_required)` |
| Panel | collectable / collected / visitor | shown / hidden / absent (asserted, 3.8 changes it) | — |
| Visitor POST | signed out | refused with sign-in message; nothing written | policy |
| Result page | an opened bonus pack | "Your daily bonus", three cards | — |

</frozen-after-approval>

## Code Map

- `packs/game/app/operations/game/{open_pack,fill_bank}.rb`, `app/models/game/{pack,draw,draw_odds,bank_lock}.rb`, `app/queries/game/bank_summary.rb`.
- `app/controllers/packs_controller.rb`, `app/policies/pack_policy.rb` -- controller, rate-limit and policy pattern.
- `app/views/pages/home.html.erb`, `app/frontend/styles/attic.css`, `config/locales/{en,fr}.yml`, `config/routes.rb`.
- `test/packs/game/*`, `test/support/game_packs.rb`, `test/controllers/packs_controller_test.rb`.

## Tasks & Acceptance

**Execution:**
- [x] `db/migrate/*` -- the claims table.
- [x] `packs/game/app/models/game/{daily_bonus_claim,draw_odds,pack}.rb`, `app/operations/game/collect_daily_bonus.rb`, `app/events/game/daily_bonus_collected.rb`, `app/queries/game/bank_summary.rb`.
- [x] `app/controllers/daily_bonuses_controller.rb`, `app/policies/daily_bonus_policy.rb`, route, attic panel, CSS, locales.
- [x] `test/` -- every matrix row.

**Acceptance Criteria:**
- Given a signed-in player with the bonus collectable, when they collect it from the attic, then the chest count rises by one, the panel disappears, a second collection the same UTC day is refused, and the next UTC day the panel is back.
- Given `bin/rails test`, `bin/rails test:system`, `bundle exec packwerk check`, `bin/rubocop` and `bundle exec i18n-tasks missing`, when run, then all pass.

## Implementation Notes

- `config/initializers/inflections.rb` gains `irregular "bonus", "bonuses"`: Rails pluralised `daily_bonus` to itself, so `resource :daily_bonus` routed to a `DailyBonusController`.
- `CollectDailyBonus` checks the season through `DrawPool.current` (nil when nothing is published), which also hands it the pool; `BankSummary` reads `Catalog::PublishedSeason` only. The bonus pack is inserted with `Pack.create!` (its id goes in the claim); `FillBank` receives the operation's `random`.
- The panel (`.attic__bonus`, `bonus_panel = @bank.present? && @bank[:bonus_collectable]`) sits on the floor between the lectern and the chest, above the chest's button row (mockups/attic.html places it there).
- Tests: `test/packs/game/collect_daily_bonus{,_concurrency}_test.rb`, the odds in `draw_test.rb`, `test/controllers/daily_bonuses_controller_test.rb`, `test/policies/daily_bonus_policy_test.rb`, `test/system/daily_bonus_test.rb`; the bank summary's hash in `queries_test.rb`/`top_up_bank_test.rb` follows the new key.

## Plan Change Log

## Review Triage Log

### Pass 1 (quick) — high 0, medium 1, low 0, false 0, maybe-false 0

| # | Verdict | Route | Finding | Evidence / action |
|---|---|---|---|---|
| 1 | medium | patch | For a player without a bank, `FillBank` read its own `Time.current`, later than the bonus's `now`, so the bonus opened before the ten regular packs; the frozen-time test hid it | Confirmed. `FillBank#call(player:, now:)` takes the operation's `now` (tie broken by id, bank first); a real-clock test asserts the bonus opens last. |


## Verification

**Commands:**
- `bin/rails test && bin/rails test:system` -- expected: all green.
- `bundle exec packwerk check && bin/rubocop && bundle exec i18n-tasks missing` -- expected: no offence.
