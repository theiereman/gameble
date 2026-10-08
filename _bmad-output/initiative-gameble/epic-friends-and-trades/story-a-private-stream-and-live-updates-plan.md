---
title: 'A private stream and live updates'
type: 'feature'
ticket: '9'
created: '2026-10-07'
status: 'built'
baseline_revision: '9456caaec83deb65db340e76f3ac5648f565aba2'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: true
context: []
warnings: ['oversized']
deferred:
  - summary: >-
      A ban set from the console reaches the banned player's friends and trade partners only at their next render.
    evidence: |-
      PlayerStream learns of a cut-off from Accounts::PlayerBanned, which no code publishes yet (the ban action comes with moderation); a console ban followed by game:drop_friends_and_trades closes the trades through Game::DropFriendsAndTrades, which publishes nothing. Deletions are live (Accounts::PlayerDeleted). Once the ban action publishes PlayerBanned, its partners are told with no further change.
    location: >-
      app/models/player_stream.rb
    severity: low
---

<intent-contract>

## Intent

**Problem:** Trades and invitations reach the other player only when they reload: the waiting badge (5.6) is read at render, an invitation received or accepted shows on the next visit, and nothing tells the sender that a friend accepted (R6, AD-13).

**Approach:** Each player gets an opaque stream key in `Accounts`, rotated on ban and deletion; the cable connection identifies the player from the session and refuses a banned or deleted one; a private channel subscribes a player to their own stream only. A web-layer subscriber to the trade and invitation events gathers notices per transaction and, after commit, enqueues one job that sends each player concerned one Turbo Stream message per locale: the badge of menu 03 and the ÉCHANGES tab, the NOUVEL AMI toast, and a typed `gameble:*` signal on which the trades and Friends screens refresh themselves with a morph.

**Decisions (autonomous run, author away):** the key is `accounts_players.stream_key`, a uuid made by the database (`gen_random_uuid()`, so fixtures and raw inserts get one), unique, never in a URL; it changes in the same write that sets `banned_at` or `deleted_at` (a model rule, since bans are set from the console until epic 7's BanPlayer); the stream is per locale (`<key>:<locale>`) because it carries rendered copy and the locale lives in the URL; a visitor's connection is accepted with no player (public streams come later) but cannot subscribe to a private stream; a subscription is refused unless the signed name is the current player's own, so a rotated key's page gets nothing; notices: every trade event (proposed, countered, accepted, declined, cancelled, expired) to both parties ("trades": badge + list/board refresh), invitation sent and accepted to both ("friends": Friends screen refresh), and NOUVEL AMI to the sender of an accepted invitation (the accepter already gets the flash toast); a banned or deleted player receives nothing and a banned or deleted friend is never named; "batched" means one job per committed transaction carrying all its notices, and one message per player and locale; no toast for an incoming proposal (no copy for it; the badge says it); the counter form page does not refresh itself (the player is editing); a refresh waits while a form is being submitted or a field of the page holds unsent text.

## Boundaries & Constraints

**Always:** broadcasts only from a job, enqueued after commit (AD-13, `enqueue_after_transaction_commit`); no database id in a stream name, DOM id or message (AD-15); copy from the locale files, rendered by the server (AD-18); DOM events declared in `app/frontend/lib/events.ts` (AD-16); real time through Turbo Streams only, no Solid Cable call (AD-12); a GET still writes nothing (AD-11).

**Never:** presence over the cable (AD-24), a per-friend fan-out, the feed or gauge streams, the trade board island or its `trade-badge` event from the island (5.7/5.8), the deletion/ban handler of trades and friendships (5.11), a BanPlayer operation (epic 7), changes to the Game operations.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Proposal | Léa proposes to Hugo, Hugo on the hub | Hugo's menu 03 badge and tab badge go to the new count, accessible names too, no reload | n/a |
| Counter | Hugo counters, Léa on the trades screen | Léa's list and board morph to the new state, her badge rises | n/a |
| Invitation sent | Léa sends to Hugo, Hugo on Amis | the invitation row appears with ACCEPTER / IGNORER | n/a |
| Invitation accepted | Hugo accepts Léa's | Léa sees the NOUVEL AMI toast naming Hugo; her Amis list refreshes | n/a |
| Rolled back | operation fails or its transaction rolls back | no job, no broadcast | n/a |
| Inside a transaction | event published, not yet committed | nothing enqueued or broadcast until commit | n/a |
| Banned player connects | session of a banned (or deleted) player | connection rejected | `reject_unauthorized_connection` |
| Foreign or old stream | another player's name, a name of a rotated key, a visitor | subscription rejected | `reject` |
| Ban / deletion | `banned_at` or `deleted_at` set | `stream_key` changes in the same write | n/a |
| Typing on Amis | a code typed, not sent, when a signal arrives | no refresh until the field is sent or cleared | n/a |

</intent-contract>

## Code Map

- `db/migrate/` (after `20261007183102`), `db/schema.rb` -- three migrations as 5.6's trade token: add nullable uuid column + default `gen_random_uuid()` + backfill + unvalidated NOT NULL check; validate and NOT NULL; unique index concurrently.
- `packs/accounts/app/models/accounts/player.rb` -- `before_save` rotating `stream_key` when `banned_at`/`deleted_at` becomes set. `packs/accounts/app/operations/accounts/delete_player.rb` -- unchanged (its `update!` sets `deleted_at`); doc line.
- New `app/channels/application_cable/{connection,channel}.rb` -- `identified_by :current_player`, from `request.session[:player_id]` via `Accounts::PlayerById`.
- New `app/channels/player_stream_channel.rb` -- `< Turbo::StreamsChannel`, own names only.
- New `app/models/player_stream.rb` -- streamables/name per locale, event → notices, the per-transaction batch (`ApplicationRecord.current_transaction` `after_commit`/`after_rollback`); subscribed in `config/initializers/event_store.rb`.
- New `app/jobs/player_stream_job.rb` -- per player: `Game::TradesWaiting`, new friends' names, `Turbo::StreamsChannel.broadcast_stream_to` per locale with `app/views/player_streams/_update.turbo_stream.erb`.
- Badges: extract `pages/_menu_trades_badge.html.erb` (from `pages/_menu_trades.html.erb`) and `shell/_tab_trades_badge.html.erb` (from `shell/_tab_bar.html.erb`), each inside a `display: contents` slot with ids `menu-trades-badge` / `tab-trades-badge`; style in `shell.css`.
- Layout `app/views/layouts/application.html.erb` + `ShellHelper#player_stream_tag` -- `turbo_stream_from` for a signed-in player outside the back-office.
- Toast: `ToastComponent` appended to `#toasts` (`toast_controller.ts` already times toasts that arrive later); copy `invitations.new_friend.*`; name fallback `friends.show.nameless`.
- Client: `app/frontend/lib/turbo.ts` (the `window.Turbo` type, moved out of `countdown_controller.ts`), `lib/stream_actions.ts` (+ test) registering the `gameble-event` stream action, `lib/events.ts` (`gameble:trades-changed`, `gameble:friends-changed`), new `controllers/live_refresh_controller.ts` (`Turbo.session.refresh(document.baseURI, { method: "morph", scroll: "preserve" })`, held during a submission or while a field differs from its default); `app/frontend/entrypoints/application.ts`.
- Views using it: `app/views/trades/_screen.html.erb` (not when `editing`), `app/views/friends/show.html.erb`.

## Tasks & Acceptance

**Execution:**
- [ ] migrations, `db/schema.rb`, `player.rb` -- stream key and its rotation
- [ ] `app/channels/*` -- connection and private channel
- [ ] `app/models/player_stream.rb`, `config/initializers/event_store.rb`, `app/jobs/player_stream_job.rb`, `app/views/player_streams/_update.turbo_stream.erb` -- notices, batch, job
- [ ] badge partials, `_menu_trades`, `_tab_bar`, `shell.css`, layout, `shell_helper.rb` -- targets and subscription
- [ ] `lib/turbo.ts`, `lib/stream_actions.ts`, `lib/events.ts`, `live_refresh_controller.ts`, `countdown_controller.ts`, `application.ts`, trades and friends views -- client
- [ ] tests: `test/channels/application_cable/connection_test.rb`, `test/channels/player_stream_channel_test.rb`, `test/models/player_stream_test.rb` (notices, batch after commit, rollback), `test/jobs/player_stream_job_test.rb`, `test/packs/accounts/stream_key_test.rb`, `test/integration/player_stream_tag_test.rb`, `app/frontend/lib/stream_actions.test.ts`, `test/system/live_updates_test.rb`

**Acceptance Criteria:**
- Given two players signed in, when one proposes or counters a trade, then the other's badge (menu 03 and tab) and open trades screen change without a reload.
- Given a player on Amis, when a friend sends them an invitation, then the row appears without a reload; when they accept one, the sender sees NOUVEL AMI.
- Given a banned player's session, when the browser opens the cable, then the connection is refused.
- Given an operation's transaction, then nothing is enqueued or broadcast before it commits, and nothing at all when it rolls back.

## Implementation Notes

- Subagents unavailable, done in-session (implementation and the quick review lens).
- The stream key is a uuid with a database default (`gen_random_uuid()`), so fixtures and raw inserts get one and Rails reads it back on create; three migrations (add + default + backfill + unvalidated check, validate + NOT NULL, concurrent unique index). The rotation is a `before_save` on `Accounts::Player` when `banned_at` or `deleted_at` becomes set: no ban operation exists yet, so this is the one place that covers the console, `Accounts::DeletePlayer` and a later ban action.
- `PlayerStream` (app/models) is the event-store handler; it buffers notices per transaction (`ApplicationRecord.current_transaction` uuid, thread-local) and enqueues one `PlayerStreamJob` from `after_commit`, dropping the buffer on rollback. The job renders `player_streams/_update.turbo_stream.erb` with `ApplicationController.render` once per locale.
- Badges moved into `pages/_menu_trades_badge` and `shell/_tab_trades_badge`, inside `display: contents` slots `#menu-trades-badge` / `#tab-trades-badge`; the tab slot is always present for a player (the badge inside hides at zero).
- Client: a `gameble-event` custom Turbo Stream action raises `gameble:trades-changed` / `gameble:friends-changed`; `live_refresh_controller.ts` calls `Turbo.session.refresh(baseURI, { method: "morph", scroll: "preserve" })`, held during a Turbo submission, while a field differs from its default, or while a dialog is open (a morph would drop its `open`). `window.Turbo`'s type moved to `lib/turbo.ts`.
- Merge of develop (story 5.11, `Game::DropFriendsAndTrades`, and `AGENTS.md`): `Game::DropFriendsAndTrades` publishes nothing, so `PlayerStream` also listens to `Accounts::PlayerDeleted` and `Accounts::PlayerBanned`, subscribed before the Game handlers, and finds the partners with a new query `Game::Counterparts` (open-trade partners, friends, pending-invitation counterparts) while they still exist; they get "trades"/"friends" notices, so their badge, trades screen and Friends screen update after the commit. The job reads no invitation or friendship rows, and a friend deleted or banned before it runs is not named (tested). A ban set from the console publishes no event (until the ban action exists), so its partners learn at their next render. Planning ids and most comments removed from the new code, per AGENTS.md; `db/schema.rb` regenerated from the migrations on an empty database.

## Plan Change Log

## Review Triage Log

### 2026-10-07 — Review pass
- verdicts: 5 findings — high 0, medium 2, low 3, false 0, maybe-false 0 (quick lens run in-session, subagents unavailable; diff read against develop 80054de after merging it)
- findings:
  - `[medium]` `[patch]` In development the jobs run in their own process (`bin/jobs`) and `config/cable.yml` used the in-process `async` adapter, so no broadcast ever reached a browser locally — development now uses Action Cable's `postgresql` adapter (LISTEN/NOTIFY on the primary database); checked with a runner broadcast.
  - `[medium]` `[patch]` Turbo drops a `session.refresh` asked for while a visit is still current (the visit is forgotten just after `turbo:load`), so a second update landing during the first refresh was lost; seen once as a failing system test (the new friend missing after the toast) — `live_refresh_controller.ts` now holds the refresh while `Turbo.navigator.currentVisit` is set and retries after `turbo:load`; the live updates system test then passed three runs in a row.
  - `[low]` `[defer]` A console ban tells no partner live (no `Accounts::PlayerBanned` is published yet) — recorded in `deferred`; the ban action will publish the event.
  - `[low]` `[reject]` The acting player's own tab refreshes once more when its own update comes back on the stream — one extra GET right after the action's redirect; leaving the actor out would also leave out their other tabs.
  - `[low]` `[reject]` If enqueuing the job raises inside `after_commit`, the operation's caller sees the error although the transaction committed — the same holds for every job enqueued after commit in this app (`enqueue_after_transaction_commit`), and the queue sits on the same database server.

## Verification

**Commands:**
- `bin/rails test` (non-system, PARALLEL_WORKERS=2, lane DB) -- green
- `bin/rails test test/system/live_updates_test.rb test/system/trades_test.rb test/system/friends_test.rb test/system/shell_test.rb test/system/hub_test.rb` (PARALLEL_WORKERS=1) -- green
- `bin/rubocop` (changed Ruby), `bundle exec packwerk check`, `bundle exec i18n-tasks missing`, `npm run typecheck`, `npx vitest run` -- clean

## Auto Run Result

- **Summary:** each player has an opaque stream key (`accounts_players.stream_key`, uuid, rotated in the write that bans or deletes) and one private Turbo Stream per locale. The cable connection identifies the player from the session and refuses a banned or deleted one; `PlayerStreamChannel` subscribes a player to their own streams only. `PlayerStream`, subscribed to the trade and invitation events (and to account deletion and ban, before Game drops the ties), gathers notices per transaction and enqueues one `PlayerStreamJob` after the commit; the job sends each player concerned one message per locale: the waiting badge of menu 03 and of the tab, the NOUVEL AMI toast to an accepted invitation's sender, and a `gameble-event` stream action raising `gameble:trades-updated` / `gameble:friends-updated`, on which the trades screen (not the counter form) and the Friends screen morph themselves, waiting for submissions, visits, unsent text and open dialogs.
- **Files:**
  - `db/migrate/20261007193000..193002_*`, `db/schema.rb` -- the stream key (regenerated from the migrations).
  - `packs/accounts/app/models/accounts/player.rb`, `packs/accounts/app/operations/accounts/delete_player.rb` -- the rotation.
  - `app/channels/application_cable/connection.rb`, `app/channels/player_stream_channel.rb` -- connection and private channel.
  - `app/models/player_stream.rb`, `packs/game/app/queries/game/counterparts.rb`, `config/initializers/event_store.rb` -- notices, the per-transaction batch, the cut-off partners.
  - `app/jobs/player_stream_job.rb`, `app/views/player_streams/_update.turbo_stream.erb` -- the broadcast.
  - `app/views/pages/_menu_trades{,_badge}.html.erb`, `app/views/shell/_tab_bar.html.erb`, `app/views/shell/_tab_trades_badge.html.erb`, `app/frontend/styles/shell.css`, `app/views/layouts/application.html.erb`, `app/helpers/shell_helper.rb` -- badge slots and the subscription.
  - `app/frontend/lib/{turbo,stream_actions,events}.ts`, `app/frontend/controllers/live_refresh_controller.ts`, `countdown_controller.ts`, `entrypoints/application.ts`, `app/views/trades/_screen.html.erb`, `app/views/friends/show.html.erb` -- client.
  - `config/cable.yml` -- development on the `postgresql` adapter.
  - Tests: `test/channels/*`, `test/models/player_stream_test.rb`, `test/jobs/player_stream_job_test.rb`, `test/packs/accounts/stream_key_test.rb`, `test/integration/player_stream_tag_test.rb`, `test/system/live_updates_test.rb`, `app/frontend/lib/stream_actions.test.ts`.
- **Review:** 2 patches (medium), 1 deferred (low), 2 rejected (low; reasons in the triage log).
- **Follow-up review recommended:** true — two medium entries were patched; the unverified risk is the refresh retry after a visit (`live_refresh_controller.ts`), whose race the system test only met once in five runs.
- **Verification:** `bin/rails test` (non-system, PARALLEL_WORKERS=2, lane DB): 1667 runs, 0 failures; `bin/rails test test/system/{live_updates,trades,friends,shell,hub,countdown}_test.rb` (PARALLEL_WORKERS=1): 44 runs, 0 failures, the live updates file three more times green; `bin/rubocop` on changed Ruby, `bundle exec packwerk check`, `i18n-tasks missing` and `unused`, `bin/rails zeitwerk:check`, `npm run typecheck`, `npx vitest run` (152): clean. Matrix rows each covered: proposal/counter/invitation/acceptance (system and job tests), rollback and inside-transaction (model test), banned connection (connection test), foreign/old stream (channel test), rotation (stream key test), typing (system test).
- **Residual risks:** the stream is per locale, so a message is rendered twice; production relies on Solid Cable's database being migrated (it is configured already); the console-ban gap above.

