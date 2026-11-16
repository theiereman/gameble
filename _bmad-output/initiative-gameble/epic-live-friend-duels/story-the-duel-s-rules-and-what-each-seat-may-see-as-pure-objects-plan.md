---
title: "The duel's rules and what each seat may see, as pure objects over the duel tables"
type: 'feature'
ticket: '1'
created: '2026-11-16'
status: 'built'
baseline_revision: 'ae8b7b6be8607bee5b39ca472c56e4b0e339321c'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/AGENTS.md'
  - '{project-root}/_bmad-output/initiative-gameble/spec-gameble/duel-rules.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Live duels need their storage and their rules settled before any operation or screen exists: three tables complete for every later duel story (none migrates them again), one pure rules object, and one view object that is the only way a duel reaches a player, so the other seat's hand, an unrevealed call and the draw orders can never leak.

**Approach:** One migration creates `game_duels`, `game_duel_seats` and `game_duel_rounds` with their checks and partial unique indexes; `Game::DuelSnapshot` copies a deck into frozen `Game::DuelCard`s through `Game::DuelProfiles`; `Game::DuelRules` computes everything from a duel row and its round rows without touching the database; `Game::DuelView.for(duel, seat)` builds plain data for one seat. Exhaustive unit tests, model tests for the checks.

## Boundaries & Constraints

**Always:**
- Obey `AGENTS.md`: no planning ids (AD-n, R-n, story/epic numbers) anywhere in code, tests, migrations or locales; English repo text; no comments except an external constraint; Ruby files under 400 lines (tests exempt); never name a model in a test class body (constants included), only inside methods.
- `DuelRules`, `DuelCard` and `DuelView` never query or write; the only reads are `DuelSnapshot` (deck, catalog, `DuelProfiles`) and `DuelView.for` loading `duel.rounds`.
- `DuelView` holds only plain data (Data objects, symbols, numbers, strings, dates): never an ActiveRecord object, never a draw order, never the other seat's unplayed drawn cards outside the two decks, never an unrevealed call's stat or direction for the answerer; while the duel is not started (`challenged`, `cancelled`, `refused`, `lapsed`) it holds no card at all, even if the snapshot columns were filled.
- Stats are `Game::DuelStat::STATS` in that order (popularity, rating, release, discovery, circulation); directions `:high`/`:low`; roles `:challenger`/`:opponent`. Rules and view speak symbols; rows store strings.
- The migration lists its own values (as `CreateGameDuelStats` does); checks are OR-joined equalities like the existing ones.

**Never:**
- No operation, event, job, channel, controller, route, policy, view template or stream (later stories).
- Do not run tests, rubocop, packwerk, zeitwerk, i18n-tasks, vitest or `bin/ci`: the suites are run by the coordinator after integration. Only the schema regeneration in Verification runs.
- Do not hand-edit `db/schema.rb`; do not touch `develop` or `main`; run git only as `/usr/bin/git`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Call order | first caller challenger, then opponent | rounds 1–10 called by A B A B A B A B B A; 5 calls each | — |
| Stats left | revealed calls of a player; a locked unrevealed call | its called stats removed; the locked call's stat still listed | — |
| Hand | draw order, played cards, round r | the first r+2 drawn minus played, 3 cards (2 after the caller locks); round 10 = deck minus the 9 played | — |
| Outcome by percentile | high: 80 vs 60; low: 30 vs 60 | caller wins both, margin 20 and 30 | — |
| Outcome on exact value | equal percentiles, values differ | the better value in the direction wins (discovery: earlier is the high side), `decided_on_value`, margin 0 | — |
| No point | equal percentiles and values | winner nil, no score | — |
| Missing value | one card has no percentile on the stat | it loses in either direction; both missing: no point | — |
| Result | 10 revealed rounds | higher score; equal scores → larger margin; still equal → `:draw`; nil before round 10 is revealed | — |
| Automatic call | caller's hand, stats left | max strength; then larger median distance; then stat order; then earlier card in the fixed order; never a called stat | — |
| Automatic answer | shown card, caller's stats left | the shown card's most extreme stat and side (same tie-breaks), then the answerer's hand card strongest there (median distance, then fixed order) | — |
| View secrecy | every state, each phase of a scripted 10-round duel, both seats | nothing listed under Always leaks; `calls left` from revealed rounds only | — |
| Wrong seat | a seat of another duel | — | `ArgumentError` |
| Checks | bad state/status/role/stat/direction/number/result, second `seated` or `invited` seat of a player | refused by the database | `ActiveRecord::CheckViolation` / `RecordNotUnique` |
| Snapshot | a 12-card deck over two seasons | cards ordered by season number then card number, values equal to `DuelProfiles`; survives the jsonb round trip | — |

</intent-contract>

## Code Map

- `db/migrate/20261115100000_create_game_duel_stats.rb`, `db/migrate/20261115120100_create_game_decks.rb` -- migration style to follow (references, checks, `[8.1]`).
- `app/domains/game/app/models/game/duel_stat.rb` -- `DuelStat::STATS`.
- `app/domains/game/app/queries/game/duel_profiles.rb` -- `DuelProfiles.call(ids)` → `{ id => Profile }`, `Profile#stats` (Stat: `name value percentile median_distance`); values: popularity Integer, rating Integer, release Date, discovery TimeWithZone, circulation Integer; percentile BigDecimal (nil with its value), median_distance Float.
- `app/domains/game/app/models/game/duel_stat_rows.rb` -- discovery's percentile ranks the earliest highest (`key: -discovered_at`); every other stat ranks the larger value higher.
- `app/domains/game/app/models/game/deck.rb`, `deck_card.rb` -- `game_deck_cards(deck_id, card_season_id, card_id, slot)`; catalog: `catalog_card_seasons(number, rarity int 1–5, season_id)`, `catalog_seasons(number)`.
- `app/models/set_album_filters.rb` -- precedent for `class X < Data.define(...)`.
- `accounts_players.stream_key` (`db/schema.rb`) -- precedent for `t.uuid … default: -> { "gen_random_uuid()" }`.
- `test/models/game/deck_test.rb` -- model-check test style (`refused` helper with `requires_new`).
- `test/support/decks.rb` -- `ranked_cards(player, count)` (a new published season per call, common rarity), `set_percentiles`.
- `test/controllers/accounts_controller_test.rb` + `accounts.dialog.kept` in `config/locales/{en,fr}.yml` -- every table with a foreign key to `accounts_players` must be listed; `game_duel_seats` will be.

## Tasks & Acceptance

**Execution:**
- [x] `db/migrate/20261116100000_create_game_duels.rb` -- create the three tables of Design Notes, then regenerate `db/schema.rb` (Verification).
- [x] `app/domains/game/app/models/game/duel.rb`, `duel_seat.rb`, `duel_round.rb` -- models (tables `game_duels`, …); `Duel`: `has_secure_token :token, length: 24`, `has_many :seats`, `has_many :rounds, -> { order(:number) }`, `started?` (active or finished), `cards(role)` (parsed `DuelCard`s, `[]` when nil), `draw_order(role)` (`[]` when nil).
- [x] `app/domains/game/app/models/game/duel_card.rb` -- frozen card, snapshot (de)serialisation.
- [x] `app/domains/game/app/queries/game/duel_snapshot.rb` -- `DuelSnapshot.call(deck)` → `[DuelCard]` in the fixed order.
- [x] `app/domains/game/app/models/game/duel_rules.rb` -- the rules.
- [x] `app/domains/game/app/models/game/duel_view.rb` -- the seat's view.
- [x] `config/locales/en.yml`, `config/locales/fr.yml` -- `accounts.dialog.kept`: "your past trades, your past duels, …" / "vos échanges passés, vos duels passés, …".
- [x] `test/controllers/accounts_controller_test.rb` -- `KEPT` gains `"game_duel_seats" => { fr: [ "vos duels passés" ], en: [ "your past duels" ] }`.
- [x] `test/support/duels.rb` -- in-memory builders: a `DuelCard` with given percentiles/values/distances, two 12-card decks with distinct id ranges (e.g. 1001–1012, 2001–2012), an unsaved active `Game::Duel`, a locked call (`duel.rounds.build`) and its answer.
- [x] `test/domains/game/duel_rules_test.rb`, `duel_view_test.rb`, `duel_snapshot_test.rb`, `test/models/game/duel_test.rb` -- every matrix row; the view test walks a whole duel played by `automatic_call`/`automatic_answer`, checking both seats after each call and each answer, plus each unstarted state and a finished duel.

**Acceptance Criteria:**
- Given a duel row and its rounds, when `DuelRules` and `DuelView` are used, then no SQL write runs and the results match the matrix.
- Given the migration, when the schema is regenerated from migrations, then `db/schema.rb` holds exactly the three new tables and nothing else changed.

## Implementation Notes

- Margin read as the winning strength minus the losing strength floored at 0 (`winning - max(losing, 0)`): it only differs from a plain difference when the loser has no value (strength -1), so a card beating a missing value wins by its own strength.
- `played_rounds` (and so `scores`, `margins`, `result`) recompute each round's outcome from the frozen cards; the round row's `winner` and `decided_on_value` are written by the test helper from the same `DuelRules.outcome`, not read back.
- A finished duel's view keeps `round` 10 and that round's caller, and its `hand` is the two cards left unplayed.
- The view test checks every value below the view is plain data, that no integer outside the two decks names a card of the other hand, that no array equals a draw order, and that the hand follows deck order.
- Not run here (per plan): the five test files. The pure objects were exercised in a throwaway script outside the repo with the same expectations as the rules test and the view walk; all matched.

## Plan Change Log

## Review Triage Log

### 2026-11-16 — Review pass
- verdicts: 7 findings — high 0, medium 1, low 3, false 3, maybe-false 0
- findings:
  - `[medium]` `[patch]` `test/domains/game/duel_view_test.rb` `assert_equal rules.finished? || locked ? 2 : 3, …` raises `Lint/RequireParentheses` (a ternary whose condition is an `||` as the first argument of an unparenthesised call), which fails the Ruby style step of CI — parenthesised the call and the condition.
  - `[low]` `[reject]` `DuelRules.by_value` compares a rating tie on the whole percent only, not then the review count — real only for two editions of different seasons with the same one-decimal percentile and the same whole rating (within a season equal percentiles mean equal rating and review count); the fix adds a stat-specific branch, and the spec's "exact value" can as well be read as the stored whole percent. Left for the author (noted in the result).
  - `[low]` `[patch]` `DuelRules.strength` read any direction other than `:high` as `:low`, so a string direction (as rows store it) would silently flip the winner and margin — `strength` now maps `{ high:, low: }.fetch(direction)`, so a wrong direction raises; `outcome` and `by_value` go through it first.
  - `[false]` `[reject]` `DuelView` and `DuelCard` carry card-season and card ids — the view is a server-side object that later screens render through `Catalog::CardViews`; nothing in this change renders or broadcasts it, and the rule bans ids in URLs, HTML, JSON, DOM ids and stream names, none of which this change writes.
  - `[false]` `[reject]` the deletion dialog lists past duels as kept while the spec says duel history is deleted with the account — the seat rows do stay for the opponent with the deleted player unnamed (the anonymised player now, a nulled seat once removed players are handled), which is what "Kept, without your Steam id or your name" says, as for past trades; the player's own history goes with the account either way.
  - `[low]` `[patch]` `test/domains/game/duel_snapshot_test.rb` named its deck in French ("Deux saisons") against the English-only repo text rule — renamed "Two seasons".
  - `[false]` `[reject]` descriptive comments in the new tests and test support — every test file and support module of the repository, epic 42's included under the same `AGENTS.md`, opens with such a description; no app code comment was added.

## Design Notes

**`game_duels`**: `token` string unique; `state` default `challenged` (challenged cancelled refused lapsed active finished); `challenger_cards`, `opponent_cards` jsonb; `challenger_draw_order`, `opponent_draw_order` `bigint, array: true` (card-season ids); `first_caller`; `move_number` int default 0; `move_deadline_at`; `challenger_score`, `opponent_score` smallint default 0; `challenger_margin`, `opponent_margin` decimal(5,1) default 0; `result` (challenger opponent draw); `capsule` (granted automatic_move already_won_today: the finishing move's duel-capsule case, written by a later story); `started_at`, `ended_at`; timestamps. Checks: the value lists; `(state = 'active' OR state = 'finished') = (started_at, first_caller, both cards, both draw orders all NOT NULL)`; `(state = 'challenged' OR state = 'active') = (ended_at IS NULL)`; `(state = 'finished') = (result IS NOT NULL)`; `capsule IS NULL OR state = 'finished'`; scores 0–10 summing ≤ 10; margins ≥ 0; `move_number >= 0`. Index `move_deadline_at` where challenged or active (the deadline sweep).
**`game_duel_seats`**: `duel` FK; `role` (challenger opponent), unique with `duel_id`; `player` FK to `accounts_players`, nullable, indexed; `deck_token` string nullable; `stream_key` uuid not null default `gen_random_uuid()` unique; `present_until`; `status` (invited seated left); timestamps. Checks: lists; `role = 'opponent' OR status <> 'invited'`; `player_id IS NOT NULL OR status = 'left'`. Partial unique indexes on `player_id` where `status = 'seated'` and where `status = 'invited'`.
**`game_duel_rounds`** — the row is written by the call; the answer fills it (that is the locked call): `duel` FK; `number` smallint 1–10, unique with `duel_id`; `caller` role; `caller_card_season_id` not null, `answer_card_season_id` nullable (FKs to `catalog_card_seasons`, no index); `stat` (five), `direction` (high low); `caller_value`, `answer_value` jsonb (as the snapshot holds them); `caller_automatic`, `answer_automatic` bool default false; `winner` role nullable (nil = no point); `decided_on_value` bool default false; `called_at` not null, `answered_at`; timestamps. Checks: lists; `(answered_at IS NULL) = (answer_card_season_id IS NULL)`; `answered_at IS NOT NULL OR winner IS NULL`.

**Snapshot entry** (string keys, JSON values): `{"card_season_id", "card_id", "number", "rarity" (1–5), "stats" => {"popularity" => {"value", "percentile" (Float), "median_distance"}, …}}`; release as `Date#iso8601`, discovery as UTC `iso8601(6)`. `DuelCard < Data.define(:card_season_id, :card_id, :number, :rarity, :stats)`, `DuelCard::Stat = Data.define(:value, :percentile, :median_distance)`; `from_snapshot(hash)` parses back to Date/Time and BigDecimal percentiles (`BigDecimal(x.to_s)`); `to_snapshot`; `stat(name)`. `DuelSnapshot` orders by `catalog_seasons.number`, `catalog_card_seasons.number` and fetches each profile (a deck card without one raises).

**`DuelRules.new(duel, rounds)`** (rounds sorted by number). Class level: `other(role)`, `caller(round, first_caller)`, `strength(card, stat, direction)` (percentile for high, 100 − percentile for low, `-1` without value), `outcome(caller_card, answer_card, stat, direction)` → `Outcome(winner: :caller|:answerer|nil, decided_on_value:, margin:)` (margin = winning strength − losing strength floored at 0; exact values compared only on equal strengths, reversed for discovery and for `:low`). Instance: `round` (revealed count + 1, at most 10), `finished?`, `caller`, `answerer`, `pending` (the round without `answered_at`), `revealed`, `deck(role)`, `card(role, id)`, `played(role)` (ids of every round incl. a locked call), `hand(role)` (in deck order, never draw order), `stats_left(role)` (revealed only), `played_rounds` → `Played(number, caller, caller_card, answer_card, stat, direction, winner (role|nil), decided_on_value, margin, caller_automatic, answer_automatic)`, `scores`/`margins` (`{ challenger:, opponent: }`, BigDecimal margins), `result`, `automatic_call` → `Call(card, stat, direction)`, `automatic_answer` → card. "Lower card number" is the earlier place in the fixed order (season, then number); a 50 percentile calls high.

**`DuelView < Data.define(:token, :state, :move_number, :round, :caller, :mine, :theirs, :hand, :current_call, :rounds, :result)`**, `Side = Data.define(:role, :deck, :played, :score, :margin, :stats_left)`. `for(duel, seat)` raises `ArgumentError` unless `seat.duel_id == duel.id`; unstarted → empty sides (stats_left all five), `round`/`caller`/`current_call`/`result` nil, `hand`/`rounds` empty. `current_call` is `DuelRules::Call` with the caller's card, and stat and direction only for the caller's own seat.

## Verification

**Commands:**
- `RAILS_ENV=test DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_build_43_1 SCHEMA=tmp/migrated_schema.rb bin/rails db:drop db:create db:migrate && cp tmp/migrated_schema.rb db/schema.rb`, then `RAILS_ENV=test DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_build_43_1 bin/rails db:drop` -- expected: `/usr/bin/git diff db/schema.rb` shows only the three tables and the version.
- `ruby -c` on each new Ruby file -- expected: Syntax OK.
- Test suites: run by the coordinator after integration (`test/models/game/duel_test.rb`, `test/domains/game/duel_rules_test.rb`, `test/domains/game/duel_view_test.rb`, `test/domains/game/duel_snapshot_test.rb`, `test/controllers/accounts_controller_test.rb`).

**Manual checks (if no CLI):**
- `grep -rnE "AD-[0-9]|R[0-9]+\b|story [0-9]|epic [0-9]|DESIGN.md|EXPERIENCE.md"` over the new files finds nothing.

## Auto Run Result

**Summary:** The three duel tables exist with every column the later duel stories name (the snapshot, draw orders, first caller, move number and deadline, scores, margins, result, the capsule case, times; per seat the role, player, deck token, stream key, presence lease and status; per round the call, both cards and values, winner, exact-value decision and automatic flags), with their checks, the one-seated and one-invited partial unique indexes and a partial index for the deadline sweep. `Game::DuelSnapshot` freezes a deck into `Game::DuelCard`s in season-then-number order from `Game::DuelProfiles`; `Game::DuelRules` holds the call order, hands, stats left, round outcome, scores, margins, result and both automatic moves without touching the database; `Game::DuelView.for(duel, seat)` gives one seat plain data only.

**Files changed:**
- `db/migrate/20261116100000_create_game_duels.rb` -- creates `game_duels`, `game_duel_seats`, `game_duel_rounds`.
- `db/schema.rb` -- regenerated from the migrations (three tables, their foreign keys, version).
- `app/domains/game/app/models/game/duel.rb`, `duel_seat.rb`, `duel_round.rb` -- the rows; `Duel#started?`, `#cards(role)`, `#draw_order(role)`.
- `app/domains/game/app/models/game/duel_card.rb` -- the frozen card and its snapshot form.
- `app/domains/game/app/queries/game/duel_snapshot.rb` -- a deck's frozen cards.
- `app/domains/game/app/models/game/duel_rules.rb` -- the rules.
- `app/domains/game/app/models/game/duel_view.rb` -- what one seat sees.
- `config/locales/en.yml`, `config/locales/fr.yml` -- the deletion dialog names past duels among what is kept.
- `test/controllers/accounts_controller_test.rb` -- `game_duel_seats` in `KEPT`.
- `test/support/duels.rb`, `test/domains/game/duel_rules_test.rb`, `duel_view_test.rb`, `duel_snapshot_test.rb`, `test/models/game/duel_test.rb` -- the tests.

**Review findings:** 3 patched (1 medium: a RuboCop `Lint/RequireParentheses` offence in the view test; 2 low: `strength` now refuses a direction other than `:high`/`:low`, and the snapshot test's French deck name). 0 deferred. 4 rejected: the rating tie ignoring the review count (low; rare across seasons, a stat-specific branch, the spec's "exact value" readable as the stored whole percent — the author may want it), ids in the view (false; server-side object, nothing rendered), "kept" past duels in the deletion dialog (false; rows stay for the opponent, unnamed), test comments (false; the repository's test convention). The patches were applied in the main session rather than through the implementing subagent, because its re-engagement message asks it to run tests and this run's coordinator forbids running any suite.

**Follow-up review recommended:** false (first pass; patched: high 0, medium 1, low 2).

**Verification:** schema regenerated from the migrations on a throwaway Postgres 18 database (`gameble_build_43_1`, dropped after), its diff only the three tables, their foreign keys and the version; `ruby -c` passes on every changed Ruby file; the planning-id grep finds nothing; the YAML files load. The implementing subagent exercised the pure objects in a throwaway script outside the repository with the rules test's expectations and the view walk; all matched. Test suites: run by the coordinator after integration — `test/models/game/duel_test.rb`, `test/domains/game/duel_rules_test.rb`, `test/domains/game/duel_view_test.rb`, `test/domains/game/duel_snapshot_test.rb`, `test/controllers/accounts_controller_test.rb`.

**Residual risks:** nothing ran under Rails here, so the database checks, the real jsonb round trip, `assert_no_queries` on an unsaved duel and the `caller` column on `Game::DuelRound` (an attribute reader shadowing `Kernel#caller` on that model) are proven only once the coordinator runs the suites. The `capsule` column and its three values anticipate the duel-capsule story; a different set of cases there would need a migration.
