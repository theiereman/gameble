---
title: 'Open a pack, end to end'
type: 'feature'
ticket: '1'
created: '2026-10-02'
status: 'built'
baseline_revision: '6891e36fd0789b9e1669df9165148b3f79693c9d'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
context: ['{project-root}/_bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md', '{project-root}/_bmad-output/initiative-gameble/spec-gameble/catalog-and-rarity.md', '{project-root}/_bmad-output/initiative-gameble/epic-packs-and-reveal/epic-packs-and-reveal.md']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Players exist and a season can be published, but nothing gives a player packs, draws cards, or records what a player owns (epic 3, R1–R4, R9).

**Approach:** The thinnest path through every layer: `Game` tables for packs and holdings; a draw from the published season by tier odds; filling a player's bank with ten available packs (at sign-up, and for players left without a bank when a season is published); `Game::OpenPack` under a per-player bank lock; and an attic chest that shows the count, opens one pack, and lists its cards on a result page. No reveal, timer, replacement or guarantee yet (stories 3.2, 3.3, 3.6).

## Boundaries & Constraints

**Always:**
- Tables: `game_packs` — player (FK), `token` (unique, `has_secure_token`, AD-15), `kind` string enum `regular`/`bonus`/`reward` with a check constraint, `season_id` (FK to `catalog_seasons`), `card_season_ids bigint[]` NOT NULL (the pack's cards in order, one row per pack so opening reads one row), `available_at`, `opened_at` nullable; partial index `(player_id, available_at, id) WHERE opened_at IS NULL`. `game_holdings` — player (FK), card-season (FK), `quantity` and `reserved` integer NOT NULL default 0, check `quantity >= reserved AND reserved >= 0`, unique player + card-season (AD-6). `Game` models declare no association to `Catalog::*`; the database keys suffice; Catalog is read only through Catalog queries.
- The bank lock: every operation that changes a player's bank first takes `pg_advisory_xact_lock(<Game namespace int>, player_id)` (`Game::BankLock`), so openings, fills and later replacements (3.2) and bonuses (3.7) are serialised per player. Lock order: bank, then holdings in ascending card-season.
- `Game::DrawOdds` holds named tables in parts per ten thousand keyed by `Rarity` tier: `REGULAR = { 1 => 7_600, 2 => 1_900, 3 => 430, 4 => 65, 5 => 5 }` (sums tested). `Game::Draw.card(tier:, random:)` and `Game::Draw.pack(odds:, size:, random:)` (default `random: SecureRandom`): pick a tier with `random.random_number(10_000)` against the cumulative odds, then a card-season uniformly within the tier with `random.random_number(size_of_tier)`. `Game::DrawPool` holds a frozen per-process snapshot of `Catalog::PublishedCardSeasonsByTier` keyed by `[season_id, published_at]`, checked against `Catalog::PublishedSeason` on each use and swapped behind a Mutex; it raises on a season with an empty tier; `Game::DrawPool.reset!` for tests.
- `Game::FillBank.new.call(player:)` (idempotent: does nothing if the player has ever had a pack, or if no season is published, and then publishes nothing): under the bank lock, inserts ten `regular` packs available now with five drawn cards each in one `insert_all`, and publishes `Game::BankFilled` (`{ player_id: }`, stream `"Game::Player$<id>"`). Called (1) by `Game::Handlers::PlayerRegistered`, subscribed synchronously inside the existing `to_prepare` block of the event-store initializer, loading the player with `Accounts::PlayerById` and calling `.value!` so a failure raises and rolls the sign-up back; `SessionsController#create` rescues that error, reports it (`Rails.error.report`) and answers like a failed sign-in (`errors.accounts.sign_in_failed`); and (2) by `Game::FillEmptyBanksJob`, enqueued after commit by a handler on `Catalog::SeasonPublished`, for players who never had a pack.
- `Game::OpenPack.new.call(player:)`: under the bank lock, reads the player's oldest available pack of any kind (`available_at <= now`, not opened, ordered `available_at, id`), marks it opened, credits its cards with one `INSERT … ON CONFLICT (player_id, card_season_id) DO UPDATE SET quantity = game_holdings.quantity + excluded.quantity` (grouped, ascending card-season), publishes `Game::PackOpened` (`{ player_id:, pack_id: }`, stream `"Game::Player$<id>"`), returns the pack. Fails `player_required` (base class) or `no_pack_available`.
- Queries: `Game::BankSummary.call(player)` → `{ available: }` counting `regular` and other kinds available now; `Game::OpenedPackByToken.call(player, token)` → the player's opened pack or nil; `Catalog::CardSeasonLabels.call(ids, locale:)` → `{ id => { title:, rarity: } }`.
- Web: `PackPolicy` — `create?` a signed-in player (a visitor is sent to sign in, CAP-18), `show?` the owner of an opened pack. The attic chest shows "Open a pack (n)" as a form posting to `/<locale>/packs` (rate limit 30 a minute by player, `with:` redirecting to the attic with an alert); "No pack" disabled at zero. Success redirects (`see_other`) to `/<locale>/packs/<token>` listing the pack's cards (title in the URL's locale, rarity name; plain list until 3.6); `no_pack_available` redirects to the attic with `errors.game.no_pack_available`; an unknown, unopened or foreign token is a 404. Copy in `fr` and `en`.
- Fixtures: the published fixture season gains one card-season per tier so a draw works in every test; tests that count catalog rows are adjusted.
- Development seed (`db/seeds.rb`, `Rails.env.development?` only, only when no season exists at all, idempotent): 60 generic cards with distinct prestige scores and texts in both locales through `Catalog::UpsertDraftCard`, published with `Catalog::PublishSeason.new.call(number:)` — whose `SeasonPublished` fills the banks of existing players.

**Never:** no reveal, timer, replacement draws, guarantee or daily bonus (later stories); no association from `Game` to `Catalog` models; no internal id in a URL.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Sign-up | first sign-in, a published season | ten available packs of five cards; `BankFilled` | — |
| Returning sign-in | player with a bank | no new pack | — |
| Sign-up, no season | fixture season set to draft (`update_columns`) | no pack; sign-in succeeds; no event | — |
| Fill fails | the handler raises | no player created; failed sign-in shown; error reported | rollback |
| Season published later | player without any pack, then a publish | `FillEmptyBanksJob` gives ten packs | — |
| Open | ten packs | oldest (by `available_at`, `id`) opened, its cards credited, nine left, `PackOpened` | — |
| Duplicates / second copy | a card twice in a pack; a card already held | quantity +2; incremented, no new row | — |
| No pack / future pack | all opened; only a pack with `available_at` tomorrow (built in the test) | nothing changes | `Failure(:no_pack_available)` |
| Two openings at once | ≥ 2 packs, two threads with their own connections, non-transactional test | both succeed on different packs | bank lock |
| Race on the last | one pack, two threads | one succeeds, one refused | bank lock |
| Odds | 200,000 draws with `Random.new(seed)` over a season with every tier | each tier within 4 σ (drawn ids mapped back to their rarity); within one small tier every card drawn, counts within 4 σ | — |
| Pool | season republished; `db:reset` reusing an id | pool reloads | key `[season_id, published_at]` |
| Visitor | POST to open | sent to sign in; nothing changes | policy |
| Result page | owner / other player / unopened or unknown token | cards with titles in `fr` or `en` / 404 / 404 | policy, query |
| Kinds | a `bonus` pack in the bank | counted and opened in order like the others | — |

</frozen-after-approval>

## Code Map

- `packs/game/app/operations/game/operation.rb` -- base of Game operations (`player:`, `require_player`).
- `lib/application_operation.rb`; `packs/accounts/app/operations/accounts/sign_in.rb`, `app/controllers/sessions_controller.rb`, `packs/accounts/app/queries/accounts/player_by_id.rb`; `config/initializers/event_store.rb` (`to_prepare`).
- `packs/catalog/app/queries/catalog/{published_card_seasons_by_tier,published_season}.rb`, `app/events/catalog/season_published.rb`, `app/operations/catalog/{upsert_draft_card,publish_season}.rb`.
- `test/fixtures/catalog/*.yml`, `test/support/catalog_seeds.rb`, `test/integration/rate_limit_test.rb` (swapping the cache store for rate-limit tests).
- `app/views/pages/home.html.erb`, `app/controllers/pages_controller.rb`, `app/policies/*`, `config/routes.rb`.

## Tasks & Acceptance

**Execution:**
- [x] `db/migrate/*` -- `game_packs`, `game_holdings`.
- [x] `packs/game/app/models/game/{pack,holding,draw_odds,draw,draw_pool,bank_lock}.rb`.
- [x] `packs/game/app/operations/game/{fill_bank,open_pack}.rb`, events, handlers, `app/jobs/game/fill_empty_banks_job.rb`, subscriptions; `SessionsController` rescue.
- [x] `packs/game/app/queries/game/{bank_summary,opened_pack_by_token}.rb`, `packs/catalog/app/queries/catalog/card_season_labels.rb`.
- [x] `app/controllers/packs_controller.rb`, `app/policies/pack_policy.rb`, routes, attic chest, result view, locales.
- [x] fixtures; `db/seeds.rb`.
- [x] `test/` -- every matrix row.

**Acceptance Criteria:**
- Given a published season, when a new player signs in and opens a pack from the attic chest, then the result page lists five cards with their rarity and the chest shows nine packs.
- Given `bin/rails test`, `bundle exec packwerk check`, `bin/rubocop` and `bundle exec i18n-tasks missing`, when run, then all pass.

## Implementation Notes

- Migration timestamp `20261003010000`: Rails refuses a timestamp more than a day ahead.
- `Game::Draw.tier(odds:, random:)` added as the tier step; `Draw.card`/`Draw.pack` take an optional `pool:` (default `DrawPool.current`) so a pack reads the pool once. `DrawPool` retries (3 tries) when a season is published between its two reads; raises `DrawPool::EmptyTier`.
- `Game::BankLock` key: namespace `0x47414D45` ("GAME"); a player id beyond int4 wraps around (two such players may share a lock, which only serialises them).
- `Game::Operation.stream_name(player_id)` gives `"Game::Player$<id>"` for both events.
- `FillBank` returns `Success(10)` or `Success(0)` (nothing done).
- Added `Accounts::PlayersInBatches` (players not banned, in batches): `FillEmptyBanksJob` must walk players, and reads go through the owning pack's queries (AD-3). The job rescues and reports (`Rails.error.report`) a player's failed fill and goes on with the others.
- `SessionsController#create` rescues any `StandardError` from `Accounts::SignIn`, reports it and answers `errors.accounts.sign_in_failed`.
- `PacksController#show` authorizes with `policy_class: PackPolicy` (the record is `Game::Pack`). A visitor sees the chest button "Open a pack" (no count); pressing it is refused with the sign-in alert.
- The chest button hangs under the chest's name (absolute), the chest raised from `bottom: 30px` to `40px`, so the chest keeps its place under the visitor invitation.
- Rate-limit test: the controller's `rate_limit` captures the (null) test cache store at load; the test overrides that store's `increment` with a MemoryStore for its duration.
- Seed guard: development and no published season; reruns resume the existing draft (upserts idempotent by source key), then publish it.
- README and `lib/application_operation.rb` examples now cite the real `OpenPack` (`:no_pack_available`, `Game::Operation.stream_name`).

## Plan Change Log

## Review Triage Log

### Pass 1 (quick) — high 0, medium 0, low 3, false 0, maybe-false 0, rejected 1

| # | Verdict | Route | Finding | Evidence / action |
|---|---|---|---|---|
| 1 | low | patch | A seed run failing midway left a draft and was never retried (`Season.none?` guard) | Confirmed. Guard is "no published season"; an existing draft is reused and published by its number. |
| 2 | low | patch | `FillEmptyBanksJob` stopped at the first failing player | Confirmed. Per-player rescue with `Rails.error.report`; test. |
| 3 | low | patch | README and `ApplicationOperation` examples cited a hypothetical `OpenPack` (`:no_pack`, `Game::Pack$` stream) | Updated to the real code. |
| 4 | low | rejected | A signed-out owner gets a 404 on their own pack link instead of a sign-in prompt | Deliberate and in the matrix (unknown, foreign or unopened → 404); the result page is reached right after an opening, while signed in. |


## Verification

**Commands:**
- `bin/rails test` -- expected: all green.
- `bundle exec packwerk check && bin/rubocop && bundle exec i18n-tasks missing` -- expected: no offence.

**Manual checks (if no CLI):**
- `bin/rails db:seed` in development, sign in, open a pack from the chest.
