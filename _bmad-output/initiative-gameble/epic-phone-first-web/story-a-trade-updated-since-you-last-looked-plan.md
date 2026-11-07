---
title: 'A trade updated since you last looked'
type: 'feature'
ticket: '11'
created: '2026-11-03'
status: done
baseline_revision: 'b53ec114d603e9d216b8863a5f52844620e1f774'
route: 'full'
route_source: 'auto'
review: 'thorough'
review_source: 'pinned'
lenses_ran: [blind-hunter, edge-case-hunter, verification-gap, intent-alignment]
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: ['oversized']
deferred:
  - summary: >-
      The player data export does not list the trade-seen markers.
    evidence: |-
      `Game::ExportOf` exports feed reactions and the daily claims, and the deletion dialog now names `game_trade_views`; the marker rows carry only a timestamp per trade, so the export was left unchanged. The author may want them in the export for completeness.
    location: >-
      app/domains/game/app/queries/game/export_of.rb
    severity: low
---

<intent-contract>

## Intent

**Problem:** A player who proposed a trade learns that the friend accepted or declined it only by opening the trades screen; the bell lists trades waiting on the player but says nothing about a trade the friend answered.

**Approach:** A server-side last-seen marker per player and trade (a `game_trade_views` row) is written by a POST that the trade board fires when it renders a trade the friend answered and the player has not seen since. `Game::TradeUpdates` lists those unseen answers; `Game::BellItems` carries them and the bell shows one line each ("Alice accepted your trade." / "Alice declined your trade.") linking straight to the trade. Once the marker is written the line is gone on every device.

## Boundaries & Constraints

**Always:** the marker is written only by `Game::MarkTradeSeen`, reached by `POST /:locale/trades/:token/seen` (`TradeSeensController#create`, `TradeSeenPolicy#create?` = player, rate limited, 204 on success, 404 when the trade is not the player's); the operation publishes one `Game::TradeSeen` event inside its transaction, and `PlayerStream` turns it into a `trades` notice for that player so the bell of every device of the player reloads; a GET (the trade page, the bell frame) reads `Game::TradeUpdates` and writes nothing; the marker is `seen_at` and a line is unseen while no marker has `seen_at >= closed_at`; the update lines cover trades the player proposed that the friend accepted or declined within `Game::TradeUpdates::WINDOW` (7 days), capped at five, excluding a friend who is banned or gone; a trade countered back to the player stays a "waiting" line (story 10); keys and markup carry tokens, never ids (`trade-update:<token>:<closed_at iso8601(6)>`); `game_trade_views` has foreign keys to the player and (on delete cascade) the trade and a unique index on `(player_id, trade_id)`; `Game::ReleasePlayer` deletes the player's views; migration is expand-only (a new table; the unique index is created with the table, no existing table touched); every string in `en.yml` and `fr.yml`; file size limits.

**Decisions (agent, recorded in pending-approvals):** the marker is a table row, not a column on `game_trades` (it is per player, and both players of a trade have one) and not the browser's storage (it must follow the player across devices); it is written by a POST fired from the board when it renders an unseen answer (the page's own GET stays read-only), not by a job, because the write must happen when the player really opens the trade; opening the trade by any path (the bell line, the list, the trades index that shows the first trade) writes it; a trade the friend answered shows for 7 days at most; only accept and decline count as "updated" (a counter-offer is already a waiting line, a cancelled or expired trade is not an answer).

**Never:** a write on a GET; a controller or job writing the model directly; database ids in URLs, HTML, DOM or stream names; changing the waiting-trade lines, their client-side seen set or keys of story 10; React or markup built in script; `style` attributes; editing `app/frontend/images/pixel/` by hand; adding tests to `test/system/shell_test.rb` or `test/integration/shell_test.rb`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Answered | player proposed, friend accepted (or declined) 1 hour ago, no marker | bell line "<friend> accepted (declined) your trade." to `/en/trades/<token>`, counted in the bell | none |
| Opened | player opens `/en/trades/<token>` | the board posts `/en/trades/<token>/seen`; marker written; line gone from the bell and from the player's other devices | POST refused or fails: the line stays until the next open |
| GET writes nothing | GET of the trade page and of the bell frame | no `game_trade_views` row and no event written | none |
| Seen already | marker `seen_at >= closed_at` | no line; the board renders no seen beacon | none |
| Not the answered side | the player is the recipient who answered, or the trade is open, cancelled, expired | no line | none |
| Old | answered 8 days ago | no line | none |
| Excluded friend | friend banned or deleted | no line | none |
| Cap | six unseen answers | the five most recent | none |
| Not the player's trade | POST seen for another pair's trade or an unknown token | 404, nothing written | `trade_not_found` |
| Visitor | POST without a player | refused by the policy | none |
| Repeat | POST twice | marker keeps the later `seen_at`; both succeed | none |
| Release | player is released (account deletion) | their views are deleted | none |

</intent-contract>

## Code Map

- `app/domains/game/app/queries/game/bell_items.rb` -- `Result` gains `updates` (`UpdateLine = Data.define(:token, :player, :outcome, :closed_at)`), loaded with the same one `Accounts::Player.where(id:)` query as senders. Pattern to copy for the new query: `trades_waiting.rb` (`relation`), `trades_of.rb` (`Trade` access, `state_of`).
- New `app/domains/game/app/queries/game/trade_updates.rb` -- `relation(player, now:)` (proposer, `status` in accepted/declined, `closed_at >= now - WINDOW`, proposer-partner `Accounts::Player.in_good_standing`, `NOT EXISTS` a `game_trade_views` row with `seen_at >= closed_at`), `call(player, now:)` (newest first, `PER_KIND`) and `unseen?(player, token, now:)`.
- New `app/domains/game/app/models/game/trade_view.rb` (`self.table_name = "game_trade_views"`; model pattern `feed_reaction.rb`), migration `db/migrate/20261103184200_create_game_trade_views.rb` (pattern `20261102150300_create_game_feed_reactions.rb`), `db/schema.rb` regenerated from migrations as AGENTS.md says.
- New `app/domains/game/app/operations/game/mark_trade_seen.rb` (`Game::Operation`, `call(player:, trade_token:)`; patterns `react_to_feed_entry.rb` for the upsert + publish, `trade_steps.rb` `find_trade` shows party check); new event `app/domains/game/app/events/game/trade_seen.rb` (pattern `trade_declined.rb`); `app/models/player_stream.rb` gets `SEEN_EVENTS = [ Game::TradeSeen ]`, added to `EVENTS` and a `notices` branch giving `[ trades_notice(data[:player_id]) ]`; `config/initializers/event_store.rb` already subscribes `PlayerStream::EVENTS`.
- `app/domains/game/app/operations/game/release_player.rb` -- delete the player's `TradeView` rows beside `FeedReaction`.
- Controller/policy/route: new `app/controllers/trade_seens_controller.rb` (pattern `app/controllers/collection_seen_controller.rb`: rate limit, `authorize`, `head :no_content`), `app/policies/trade_seen_policy.rb`, `config/routes.rb` -- `post "trades/:token/seen" => "trade_seens#create", as: :trade_seen` with the token constraint, beside `resources :trades`. Do not add it to `TradesController` (policy per action, file size).
- Beacon: `app/views/trades/_board.html.erb` renders `trades/seen_beacon` (new partial: `<div hidden data-controller="trade-seen" data-trade-seen-url-value=...>`, pattern `app/views/library/_seen.html.erb`) when `!trade.open? && Game::TradeUpdates.unseen?(current_player, trade.token)` (put the condition in `app/helpers/trades_helper.rb`, check its size). New `app/frontend/controllers/trade_seen_controller.ts` (pattern `collection_seen_controller.ts`: one POST on connect, skipped in a Turbo preview, CSRF header, failure ignored); check how controllers are registered.
- Bell: `app/helpers/bell_helper.rb` `bell_lines` (after the waiting trades) with `bell_trade_update_line` (key `trade-update:<token>:<closed_at.utc.iso8601(6)>`, path `trade_path(token:)`, action `see`; not lasting); `config/locales/en.yml` and `fr.yml` `shell.bell.trade_accepted` / `trade_declined` (en keys alphabetical; French "%{name} a accepté votre échange." / "%{name} a refusé votre échange."). The client needs no change: it hides a line once its path is opened and reloads the frame on `gameble:trades-updated`.
- `app/domains/game/app/queries/game/counterparts.rb`, `drop_friends_and_trades.rb` -- read only, to confirm nothing else needs the views.
- Tests to extend or copy: `test/domains/game/bell_items_test.rb`, `test/controllers/bells_controller_test.rb`, `test/controllers/collection_seen_controller_test.rb`, `test/controllers/trades_controller_test.rb`, `test/controllers/read_only_requests_test.rb`, `test/domains/game/trade_accept_counter_expire_test.rb` (sign-in and trade setup helpers: `test/support/game_trades.rb`), `test/jobs/player_stream_job_test.rb`, `test/policies/bell_policy_test.rb`, `test/system/bell_test.rb`, `test/system/trades_test.rb`, a player stream notices test (grep `PlayerStream.notices`).

## Tasks & Acceptance

**Execution:**
- [ ] `db/migrate/20261103184200_create_game_trade_views.rb`, `app/domains/game/app/models/game/trade_view.rb`, `db/schema.rb` -- the marker table
- [ ] `app/domains/game/app/queries/game/trade_updates.rb` + `test/domains/game/trade_updates_test.rb` -- the unseen answers; every matrix row from Answered to Cap
- [ ] `app/domains/game/app/operations/game/mark_trade_seen.rb`, `events/game/trade_seen.rb`, `app/models/player_stream.rb`, `release_player.rb` + `test/domains/game/mark_trade_seen_test.rb` -- the write, the event, the notice, the release; Repeat, Not the player's trade, Release
- [ ] `config/routes.rb`, `trade_seens_controller.rb`, `trade_seen_policy.rb` + `test/controllers/trade_seens_controller_test.rb`, `test/policies/trade_seen_policy_test.rb` -- the POST, 204/404, visitor refused, no `id` in the response
- [ ] `app/views/trades/_board.html.erb`, `_seen_beacon.html.erb`, `trades_helper.rb`, `trade_seen_controller.ts` (+ vitest if it has pure logic) + controller tests in `trades_controller_test.rb` -- the beacon shows only for an unseen answer; GET of the trade writes nothing (a row count and event count before and after)
- [ ] `bell_items.rb`, `bell_helper.rb`, locales + `test/domains/game/bell_items_test.rb`, `test/controllers/bells_controller_test.rb` -- the line
- [ ] `test/system/bell_test.rb` (or `test/system/trade_updates_test.rb`) -- one flow: the friend declines, the bell counts the line, the player opens the trade through it, the line is gone, reload and a second sign-in of the same player still show no line
- [ ] `_bmad-output/initiative-gameble/pending-approvals.md` -- the decisions above, under entry 11

**Acceptance Criteria:**
- Given a trade the player proposed that the friend declined, when any page loads, then the bell shows the line and counts it.
- Given that line, when the player follows it, then the trade page loads, the marker is written through a POST, and the bell no longer shows the line, also on a fresh browser session of the same player.
- Given a plain GET of the trade page or the bell, when it runs, then no `game_trade_views` row is written (the controller tests count rows).
- Given `bundle exec packwerk check`, `bin/rails zeitwerk:check` and the strong_migrations checks, then they pass.

## Implementation Notes

Environment for the implementer: this is a git worktree; never touch `/home/teyermann/projets/gameble` outside it. Use `export DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w33_11 CHROME_BIN=/usr/bin/chromium PARALLEL_WORKERS=4` (1 for system tests); the database exists with the current schema. Write logs only under `/tmp/claude-1000/-home-teyermann-projets-gameble/0353116f-3ad0-428d-8fae-d1f0bd030123/scratchpad/story11-marker/`. Do not commit; do not touch `package-lock.json`. After the migration regenerate the schema as AGENTS.md says (`RAILS_ENV=test SCHEMA=tmp/migrated_schema.rb bin/rails db:drop db:create db:migrate db:schema:dump`, then copy and diff). If a git command is refused through the rtk hook, use `/usr/bin/git`. AGENTS.md at the repo root is binding.

## Plan Change Log

## Review Triage Log

### 2026-11-03 — Review pass
- verdicts: 20 findings — high 0, medium 0, low 17, false 3, maybe-false 0
- findings:
  - blind-hunter
    - `[low]` `[reject]` no index on `game_trade_views.trade_id` for the cascade — trades are never deleted, so the cascade never runs; the unique `(player_id, trade_id)` index serves the query.
    - `[low]` `[reject]` no index for the update query — `index_game_trades_on_proposer_id_and_status` already narrows it to the player's answered trades.
    - `[low]` `[defer]` the data export omits the markers — recorded in `deferred`; a timestamp per trade, the deletion text names the table.
    - `[low]` `[reject]` a `TradeSeen` event on every repeat POST — the beacon renders only while the answer is unseen, so a repeat needs two tabs; a skip would add a branch to a rare path.
    - `[low]` `[reject]` the beacon marks a trade seen in a background tab — opening the trade by any path is the recorded decision; a visibility gate adds states for no observed harm.
    - `[low]` `[reject]` the controller ignores non-2xx answers and has no vitest — the next render of the board posts again; the controller holds no pure logic to test, and the system test covers it end to end.
    - `[low]` `[reject]` the cap of five hides a sixth answer — the same recorded cap as the other lines; a sixth shows once the first are opened.
    - `[low]` `[reject]` untested branches (422, nil `closed_at`, 7-day boundary, later ban) — each is a one-line guard of the query or controller already exercised by neighbours.
    - `[low]` `[reject]` `TradeView` has no associations or validations — it is written only by the operation, as `FeedReaction`.
    - `[false]` `[reject]` the token regex is repeated inline — every neighbouring trade route repeats the same constraint.
  - edge-case-hunter
    - `[false]` `[reject]` an answer watched live never marks seen — the live refresh re-fetches the page as the player, so the morphed board renders the beacon and Stimulus connects it.
    - `[low]` `[reject]` a failed POST is not retried — same as the blind hunter's row.
    - `[low]` `[reject]` a marker can be written for an open trade — harmless, the player is a party, and it only hides a later answer if `seen_at >= closed_at`, which cannot be (the close is later).
    - `[low]` `[reject]` repeat POSTs publish — same as above.
    - `[low]` `[reject]` a banned player's POST answers 422 — a banned session is signed out by the application before the action.
    - `[low]` `[reject]` waiting trades and answers can reach ten lines — the cap is per kind, as written.
    - `[false]` `[reject]` a re-closed trade makes the line return — a closed trade never reopens, `closed_at` is final.
  - verification-gap
    - no findings.
  - intent-alignment
    - `[low]` `[reject]` the system test reaches the trade only through the bell line — the beacon fires on any board render and the controller tests cover the render; the choice of a POST fired by the page is queued in pending-approvals.
    - `[low]` `[reject]` a client without JavaScript leaves the line — the marker needs a POST; the recorded decision.
    - `[low]` `[reject]` the narrow meaning of "updated" (accept and decline only) — recorded decision, a counter is already a waiting line.

## Verification

**Commands:**
- `bin/rails test test/domains/game test/controllers test/policies test/jobs test/integration test/helpers test/models` (the files this change touches, at least: trade_updates, mark_trade_seen, bell_items, trade_seens_controller, trades_controller, bells_controller, read_only_requests, player_stream, bell_policy, trade_seen_policy, drop_friends_and_trades, release_player) -- expected: pass
- `bin/rails test test/system/bell_test.rb test/system/trades_test.rb -n /seen|bell|update/` -- expected: pass
- `npm run test:js && npm run format:check && npm run lint:css` -- expected: pass
- `script/check_file_sizes && script/check_planning_references && bundle exec packwerk check && bin/rails zeitwerk:check && bundle exec i18n-tasks missing` -- expected: pass
- `bin/ci` -- expected: pass

## Auto Run Result

**Summary:** the bell now tells a player who proposed a trade that the friend accepted or declined it, until the player opens the trade. The marker is a `game_trade_views` row (player, trade, `seen_at`); a line is unseen while no marker has `seen_at >= closed_at`. The trade board renders a hidden beacon only for an unseen answer; its Stimulus controller POSTs `/:locale/trades/:token/seen`, which `Game::MarkTradeSeen` turns into the marker plus one `TradeSeen` event. `PlayerStream` makes that event reload the player's bell on every device. The GET of the trade and the bell frame write nothing (tests count rows and events).

**Files**
- New: migration `20261103184200_create_game_trade_views`, `Game::TradeView`, `Game::TradeUpdates`, `Game::MarkTradeSeen`, `Game::TradeSeen`, `TradeSeensController`, `TradeSeenPolicy`, `trades/_seen_beacon`, `trade_seen_controller.ts`, and tests (query, operation, controller, policy, system).
- Changed: `bell_items.rb`, `bell_helper.rb`, `trades_helper.rb`, `_board.html.erb`, `player_stream.rb`, `release_player.rb`, routes, `en.yml`/`fr.yml` (bell lines and the deletion texts), `db/schema.rb`, `pending-approvals.md`, and the bell, trades, accounts and player stream tests.

**Review:** one thorough pass with four lenses: 20 findings, high 0, medium 0, low 17, false 3. Patches applied: none. Deferred: 1 (the data export, also in `deferred-work.md`). Every rejected finding carries its reason in the triage log.

**Follow-up review recommended: false.** No patch was applied.

**Verification:** `bin/ci` with `PARALLEL_WORKERS=4`, `npm run test:js`, `zeitwerk:check`, packwerk, format, CSS lint, planning references and file sizes (outcomes in the final report).

**Residual risks**
- The marker is written when the board renders in a browser that runs scripts; a failed POST leaves the line until the next render.
- Repeated POSTs publish one event each (rare: the beacon renders only while unseen).
- The table plus page-fired POST, the 7-day window and the accept/decline-only meaning are queued for the author in `pending-approvals.md`.

## Code Review

### 2026-11-04 — 0 decision-needed, 0 patch, 4 defer, 2 rejected

- [x] [Review][Defer] The trade seen marker is missing from the player data export while the deletion text lists it — deferred: add it to the export or say so on the privacy page
- [x] [Review][Defer] A reconnecting trade-seen controller posts again and each post publishes an event; a failed post is ignored — deferred: low until noticed, publish only when the marker changes
- [x] [Review][Defer] An answer older than seven days leaves the bell unseen, against the commit title — deferred: the window is the plan's decision, confirm with the author
- [x] [Review][Defer] The trade_id foreign key has no index of its own — deferred: add with the next migration touching the table

**Rejected**
- Unfriended or banned friend in the line, clock skew, open trade marker: low, unreachable or harmless.
- Plan hygiene, session paths in the plan, unreachable 422 branch: low or edits the plan.
