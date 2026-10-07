---
title: "Friends' presence"
type: 'feature'
ticket: '3'
created: '2026-10-07'
status: 'built'
baseline_revision: '2c2731fe2777c67e1a33931d1666fbe14d8db58a'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: ['oversized']
deferred:
  - summary: >-
      Story 5.5's trade actions (accept, counter) are not recorded as a player's activity.
    evidence: |-
      Their events are built in a parallel lane and absent here; Game::Handlers::PlayerActivity::EVENTS lists only the events that exist (pack, daily, propose, cancel, decline, invitations).
    location: >-
      packs/game/app/handlers/game/handlers/player_activity.rb:15
    severity: low
---

<intent-contract>

## Intent

**Problem:** A player cannot tell which friends are around: accounts have no last-seen time, nothing records a player's latest game action, the friend rows show only a name and menu 04 has no "n en ligne" count (CAP-21, R5).

**Approach:** Per AD-24: `last_seen_at` on `accounts_players`, written by a job a request enqueues at most about once a minute (throttled in the session and again in the write), never by the GET itself; a `Game` handler records the latest game action and its time on the actor's `game_player_states` row; one `Game` query reads both at render and gives each friend a presence (doing an activity, online, or last seen), shown on the friend rows and counted on menu 04.

**Decisions (autonomous run, author away):** windows (tuned in play, AD-24, one place each): online = seen within 5 minutes, activity shown within 3 minutes of it, last-seen write throttle 1 minute; a recent activity counts as online even before the job ran; last seen is the later of `last_seen_at` and the activity time; never seen shows "Hors ligne"; activities are keys stored on the row and worded at render: pack opened "Ouvre un booster", daily booster "Récupère son booster du jour", trade proposed / cancelled / declined "Négocie un échange", invitation sent / accepted "Se fait des amis"; the time ago is compact ("Il y a 12 min", "Il y a 3 h", "Il y a 2 j"); menu 04 shows "n en ligne" for a player (0 included), nothing for a visitor; the PLUS row reads nothing; the events of story 5.5 (accept, counter) are not subscribed here; the coding is done in this session (subagents unavailable).

## Boundaries & Constraints

**Always:** a GET writes no row (AD-11): the request only enqueues; the last-seen write is a housekeeping operation in `Accounts` publishing no event (AD-10); the activity handler runs in the publishing transaction, writes only the actor's own state row with one upsert, publishes nothing and never fails the operation for a missing row; presence is read at render, nothing is broadcast (AD-13, AD-24); banned friends stay hidden (FriendsOf).

**Never:** Action Cable presence, a per-friend fan-out, a write per request, avatars, card counts or PROPOSER UN ÉCHANGE on the row, the friend profile, story 5.5's events.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Friend just acted | friend opened a pack 1 min ago | row: blue dot "Ouvre un booster"; counted online | n/a |
| Friend browsing | last_seen 2 min ago, no recent activity | lime "En ligne"; counted | n/a |
| Friend idle | last_seen 3 h ago | muted "Il y a 3 h"; not counted | n/a |
| Never seen | no last_seen, no activity | muted "Hors ligne" | n/a |
| Signed-in GET | any page, session mark absent or > 1 min | job enqueued, no row written by the GET | n/a |
| Repeat GET within a minute | session mark fresh | no job enqueued | n/a |
| Job runs twice in a minute | last_seen 20 s old | no update | n/a |
| Unknown activity key | key no longer worded | shown as "En ligne" | default |

</intent-contract>

## Code Map

- `db/migrate/20261007140000_add_presence.rb` + `db/schema.rb` -- `accounts_players.last_seen_at` (datetime), `game_player_states.last_activity` (string), `last_activity_at` (datetime).
- `packs/accounts/app/operations/accounts/note_last_seen.rb` (new) -- `call(player_id:, at:)`: one `update_all` where `last_seen_at IS NULL OR < at - THROTTLE`, `at` capped to now; no event; `THROTTLE = 1.minute`. Pattern: `update_settings.rb`.
- `packs/accounts/app/jobs/accounts/note_last_seen_job.rb` (new) -- `ActiveJob::Base`, queue `default`, calls the operation (style of `packs/game/app/jobs/game/backfill_friend_codes_job.rb`).
- `app/controllers/application_controller.rb` -- `before_action :note_presence` after `set_sentry_user`: for a signed-in player, if `session[:seen_at]` (epoch) is absent or older than THROTTLE and the player's `last_seen_at` too, enqueue the job with the request time and set the session mark. Enqueuing is not a write (AD-11; `test/controllers/read_only_requests_test.rb`).
- `packs/game/app/handlers/game/handlers/player_activity.rb` (new) -- `EVENTS = { Game::PackOpened => [:opening_pack, :player_id], ... }`; upsert like `Game::MarkCollectionSeen` (unique_by player_id, record_timestamps false). Subscribe in `config/initializers/event_store.rb` to `EVENTS.keys`. Actor: TradeCancelled = proposer_id, TradeDeclined = recipient_id (see `close_trade.rb` PARTY), InvitationSent sender_id, InvitationAccepted recipient_id.
- `packs/game/app/models/game/player_state.rb` -- doc: written also by the handler.
- `packs/game/app/queries/game/friends_presence.rb` (new) -- `call(player, now: Time.current)` → rows `(player, state, activity, seen_at)` in FriendsOf order; state `:active | :online | :offline`; `online?`; windows as constants; `online_count(player)`. Reuse `Game::FriendsOf`.
- `app/controllers/friends_controller.rb`, `app/views/friends/show.html.erb` -- rows from FriendsPresence with a presence dot and text.
- `app/helpers/presence_helper.rb` (new) -- `presence_text(row)` (compact time ago).
- `app/controllers/pages_controller.rb`, `app/views/pages/home.html.erb`, `_menu.html.erb`, `_menu_friends.html.erb` -- `@friends_online` into menu 04's `menu-item__meta`.
- `config/locales/{fr,en}.yml` -- `friends.show.presence.*`, `pages.home.menu.friends_online`.
- `app/frontend/styles/friends.css` -- presence dot (lime / accent / muted).

## Tasks & Acceptance

**Execution:**
- [ ] `db/migrate/20261007140000_add_presence.rb`, `db/schema.rb` -- add the three columns -- AD-24 storage
- [ ] `packs/accounts/app/operations/accounts/note_last_seen.rb`, `packs/accounts/app/jobs/accounts/note_last_seen_job.rb`, `app/controllers/application_controller.rb` -- throttled last-seen write and its enqueue -- last seen never written by a GET
- [ ] `packs/game/app/handlers/game/handlers/player_activity.rb`, `config/initializers/event_store.rb`, `packs/game/app/models/game/player_state.rb` -- record the latest activity -- AD-10 handler
- [ ] `packs/game/app/queries/game/friends_presence.rb` -- presence per friend and the online count -- one place for the windows
- [ ] `app/controllers/friends_controller.rb`, `app/views/friends/show.html.erb`, `app/helpers/presence_helper.rb`, `app/frontend/styles/friends.css`, `app/controllers/pages_controller.rb`, `app/views/pages/{home,_menu,_menu_friends}.html.erb`, `config/locales/{fr,en}.yml` -- show presence and "n en ligne"
- [ ] `test/packs/accounts/note_last_seen_test.rb`, `test/packs/game/player_activity_test.rb`, `test/packs/game/friends_presence_test.rb`, `test/controllers/presence_test.rb`, `test/controllers/friends_controller_test.rb` -- the matrix above, the hook (enqueued once, not again within a minute, GET writes nothing), friend rows and the menu count

**Acceptance Criteria:**
- Given a friend who opened a pack a minute ago, when the player opens AMIS, then the friend's row shows "Ouvre un booster" and menu 04 counts them in "n en ligne".
- Given a friend last seen 3 hours ago, when the player opens AMIS, then the row shows "Il y a 3 h" and the menu does not count them.
- Given any signed-in GET, when it is served, then no row is written during the request and at most one last-seen job is enqueued per minute and session.

## Implementation Notes

- Subagents unavailable, done in-session (implementation and the quick review lens).
- The session throttle is needed beyond the write's own: without it every signed-in request enqueued a job (the test adapter never runs it, so `last_seen_at` stayed empty), which broke the back-office import tests' `assert_no_enqueued_jobs`; those now ignore `Accounts::NoteLastSeenJob` only (`assert_no_import_jobs`).
- `online_count` is one SQL count (friendships subquery, players LEFT JOIN states) so the hub's query budget grows by one (14 to 15) whatever the number of friends; it relies on ACTIVITY_WINDOW being shorter than ONLINE_WINDOW, and the presence test checks it against the rows in every scenario.
- The friend rows gained `.friends__name` and `.friends__presence`; the 5.2 invitations test now targets the name.
- Migration `20261007145300_add_presence.rb`; `db/schema.rb` version moved to it.

## Plan Change Log

## Review Triage Log

### 2026-10-07 — Review pass
- verdicts: 3 findings — high 0, medium 0, low 2, false 1, maybe-false 0
- findings:
  - `[low]` `[reject]` the activity handler calls `PlayerState.upsert` itself where the other handlers call a model method (WeeklyContribution.record_opening) — AD-10 names "the player's latest activity" as a handler write and PlayerState's doc lists the handler as a writer; no caller diverges, and moving it adds a method for no behaviour change.
  - `[low]` `[defer]` story 5.5's own actions (accepting, countering a trade) are not activities yet — their events do not exist on this branch; whoever merges 5.5 adds them to `PlayerActivity::EVENTS`, minding AD-10's lock order (the actor's state row last).
  - `[false]` a friend whose profile is private still shows presence — AD-13's visibility question covers surfaces naming a player beside their cards; the friend row shows no card, and presence is shown only to friends.

## Verification

**Commands:**
- `bin/rails test` (PARALLEL_WORKERS=2, lane test db) -- expected: green
- `bin/rails test test/system/hub_test.rb` (PARALLEL_WORKERS=1) -- expected: green
- `bin/rubocop` on changed Ruby files, `bin/packwerk check`, `bundle exec i18n-tasks health` -- expected: clean

## Auto Run Result

- **Summary:** friends' presence (CAP-21, AD-24). `accounts_players.last_seen_at`, written by `Accounts::NoteLastSeenJob` / `Accounts::NoteLastSeen` (one throttled UPDATE, no event), enqueued by `ApplicationController#note_presence` at most once a minute per session and never written by the request; `Game::Handlers::PlayerActivity` records the actor's latest action on `game_player_states` (`last_activity`, `last_activity_at`) for pack openings, the daily booster, trade propose / cancel / decline and invitations sent / accepted; `Game::FriendsPresence` gives each friend active / online / offline with the windows in one place (online 5 min, activity 3 min), and an online count in one query; the friend rows show a dot and "Ouvre un booster" / "En ligne" / "Il y a 3 h" / "Hors ligne", menu 04 shows "n en ligne".
- **Files:**
  - `db/migrate/20261007145300_add_presence.rb`, `db/schema.rb` -- the three columns.
  - `packs/accounts/app/operations/accounts/note_last_seen.rb`, `packs/accounts/app/jobs/accounts/note_last_seen_job.rb` -- throttled last-seen write and its job.
  - `app/controllers/application_controller.rb` -- `note_presence` enqueues, session-throttled.
  - `packs/game/app/handlers/game/handlers/player_activity.rb`, `config/initializers/event_store.rb`, `packs/game/app/models/game/player_state.rb` -- the activity handler and its subscription.
  - `packs/game/app/queries/game/friends_presence.rb` -- presence rows and the online count.
  - `app/controllers/friends_controller.rb`, `app/views/friends/show.html.erb`, `app/helpers/presence_helper.rb`, `app/frontend/styles/friends.css` -- presence on the friend rows.
  - `app/controllers/pages_controller.rb`, `app/views/pages/home.html.erb`, `_menu.html.erb`, `_menu_friends.html.erb` -- "n en ligne" on menu 04.
  - `config/locales/fr.yml`, `config/locales/en.yml` -- presence and menu copy.
  - tests: `test/packs/accounts/note_last_seen_test.rb`, `test/packs/game/player_activity_test.rb`, `test/packs/game/friends_presence_test.rb`, `test/controllers/presence_test.rb`, `test/helpers/presence_helper_test.rb`, and updates to `friends_controller_test.rb`, `invitations_controller_test.rb`, `pages_controller_test.rb` (query budget 15, the no-season meta), `back_office/import_runs_controller_test.rb` (no import job, the last-seen job allowed).
- **Review:** quick lens, in-session; 0 patches, 1 deferred (5.5's events), 2 rejected (handler writes through upsert: allowed by AD-10; private friends' presence: no card shown, AD-13 does not apply).
- **Follow-up review recommended:** false (no patched entries).
- **Verification:** `bin/rails test` 1453 runs, 0 failures; `bin/rails test test/system/hub_test.rb` 10 runs, 0 failures; `bin/rubocop` on the changed Ruby files clean; `bundle exec packwerk check` clean; `i18n-tasks missing` and `unused` clean; `npm run typecheck` and `npx vitest run` (132 tests) pass.
- **Residual risks:** the windows and the activity wording are first guesses, tuned in play (AD-24); the English copy is unreviewed; the last-seen time is only as fresh as the job queue.
