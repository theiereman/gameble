---
title: 'Only a reachable friend can be challenged, from Duels or the friend''s row and profile'
type: 'feature'
ticket: '3'
created: '2026-11-16'
status: 'built'
baseline_revision: '933281009805ca526b2f7b6a788ea8d6fc61bfe4'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/AGENTS.md'
  - '{project-root}/docs/design-system.md'
  - '{project-root}/_bmad-output/initiative-gameble/epic-live-friend-duels/story-two-friends-play-a-whole-duel-to-its-result-on-a-plain-duel-plan.md'
warnings: []
deferred:
  - summary: >-
      DÉFIER and DÉFIER EN DUEL open Duels at the challenge form anchor even when the form is not rendered (seated, waiting, received challenge, no complete deck).
    evidence: |-
      The form is rendered only for an idle player with a complete deck and a challengeable friend; the buttons do not read that state.
    location: >-
      app/views/duels/_online.html.erb
    severity: medium
---

<intent-contract>

## Intent

**Problem:** A challenge can be sent to any friend, online or not, and the only way in is a plain form on Duels: the friend's row, friend profile and public profile have no way to start a duel, and nothing says who can answer now.

**Approach:** A lease `reachable_until` on the Accounts player row, set 45 s ahead by `Accounts::NoteReachable` when `PlayerStreamChannel` is subscribed and every 30 s while it is (no event, nothing cleared on unsubscribe); `Game::ReachableFriends` is the one read feeding `ChallengeFriend` (new refusal `friend_unavailable`), an "EN LIGNE" section on Duels and a "DÉFIER EN DUEL" button after ÉCHANGE on the friend's row, friend profile and public profile; each button opens the Duels challenge form on that friend.

## Boundaries & Constraints

**Always:**
- Obey `AGENTS.md`: writes only in operations; GETs never write; tokens never ids (the friend in a link is the player token); a Pundit policy per action; every string in `en.yml` and `fr.yml` (French typography: U+202F before `: ; ? !` and inside « », plurals need `zero`); no planning ids; English repo text; Ruby/TS files under 400 lines; no `style` attribute; ERB must also parse with plain Ruby ERB (no `<% case %>`/`<% when %>` with text between, never shorthand hash args before `%>`, write `friend: friend`).
- Migration is expand-only (`add_column`, nullable datetime, no index); regenerate `db/schema.rb` as the task directs, never hand-edit it.
- `Game::ReachableFriends` is the only reader of `reachable_until`; "online" words, the friends page online count and `FriendsPresence` keep reading `last_seen_at`.
- Reachable means: friend in good standing, friendship, `reachable_until` in the future, neither the player's nor the friend's profile private (the player's own private profile gives no rows). Each row says whether the friend is seated or invited elsewhere.

**Never:**
- No new Solid Queue worker, process or queue (connection budget), no new job, no event for the lease, no clearing on unsubscribe, no timer UI, no bell, sheet or dialog (later entries), no change to `DuelStream`.
- Do not run tests, rubocop, packwerk, zeitwerk, i18n-tasks, vitest or `bin/ci`: suites are run by the coordinator after integration. Allowed: `ruby -c`, YAML loads, `script/check_planning_references`, `script/check_file_sizes`, `npm run format:check`, `npm run lint:css`, `npx tsc --noEmit`, ERB compile checks.
- Git only as `/usr/bin/git`; never touch `develop`/`main`; never stage `package-lock.json` or `config/*.key`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Subscribe | a signed-in player subscribes to their own stream | `reachable_until` = now + 45 s, no event published, `updated_at` untouched | rejected subscription writes nothing |
| Renew | 30 s timer fires while subscribed | `reachable_until` = now + 45 s again | — |
| Unsubscribe | player leaves | nothing written | — |
| Reachable friends | friend with future lease, both open | row for the friend, `in_duel` false | — |
| Reachable, in a duel | friend seated or invited | row with `in_duel` true | — |
| Left out | lapsed or null lease / private friend / own profile private / not a friend / removed player | no row | — |
| Challenge | friend reachable and free | as before | — |
| Challenge, unreachable | lapsed or null lease | nothing written | `friend_unavailable` |
| Duels screen | reachable friends | "EN LIGNE · n", one row per friend with DÉFIER (`Défier <name>`), an in-duel one with "Duel en cours" and no button | — |
| Duels, none online | friends but none reachable | "Aucun ami en ligne pour l'instant." | — |
| Duels, no friend | no friend at all | "Ajoutez des amis pour les défier." and AJOUTER DES AMIS (link to friends page) | — |
| Duels, own profile private | own visibility private | "Vos duels sont fermés tant que votre profil est privé." in place of the friends, no DÉFIER | — |
| Friend row / profiles | reachable friend, neither private | DÉFIER EN DUEL (`Défier <name> en duel`) after ÉCHANGE; in a duel: "Duel en cours" text instead | — |
| Friend row, private friend | friend's profile private (viewer open) | "Duels fermés tant que ce profil est privé." in place of the button | — |
| Opens the form | DÉFIER / DÉFIER EN DUEL clicked | Duels with the challenge form and that friend preselected (`?friend=<player token>`) | unknown token: form as usual |

</intent-contract>

## Code Map

- `db/migrate/20261116100000_create_game_duels.rb` -- latest migration; add `db/migrate/20261116110000_add_reachable_until_to_accounts_players.rb` (`add_column :accounts_players, :reachable_until, :datetime`, `ActiveRecord::Migration[8.1]`).
- `app/domains/accounts/app/operations/accounts/note_last_seen.rb` -- precedent: a housekeeping write with no event (`update_all`, `in_good_standing`); `test/domains/accounts/note_last_seen_test.rb` -- test precedent (one statement, no event, `updated_at` untouched).
- `app/channels/player_stream_channel.rb`, `test/channels/player_stream_channel_test.rb` -- add the lease on subscribe and `periodically :note_reachable, every: 30.seconds`; a rejected subscription must not write.
- `app/domains/game/app/queries/game/friends_of.rb`, `friends_presence.rb`, `models/game/visibility.rb` (`open_to_friends?`), `models/game/duel_seat.rb` (statuses seated/invited) -- reuse for `Game::ReachableFriends` (module with `call(player, now: Time.current)` returning `Row = Data.define(:player, :in_duel)` ordered by persona name, `[]` for nil player or own private).
- `app/domains/game/app/operations/game/challenge_friend.rb`, `duel_steps.rb` -- add `step reachable(player, friend)` right after `friends_to_duel` (Failure(:friend_unavailable) unless `ReachableFriends.call(player)` has the friend); `config/locales/{en,fr}.yml` `errors.game.friend_unavailable` by hand ("This friend is not online right now." / "Cet ami n'est pas en ligne pour l'instant.").
- `test/support/live_duels.rb` (`befriend`: also give both players `reachable_until` a day ahead with `update_columns`, so every existing duel test and the duel system test keep working), `test/domains/game/duel_challenge_operations_test.rb`.
- `app/models/duel_lobby.rb`, `app/controllers/duels_controller.rb` (`show`; pass `params[:friend]`), `app/views/duels/show.html.erb`, `_lobby.html.erb` -- the form's friend radios become the reachable friends not in a duel, the one named by `friend` preselected; add the EN LIGNE panel (new partial `duels/_online.html.erb`) between the lobby and `duels/decks`; the existing lines `no_deck`, closed, `no_friends` stay as they are.
- `app/views/friends/_friend_row.html.erb`, `app/views/friend_profiles/show.html.erb`, `app/views/public_profiles/_action.html.erb` (the `:friends` branch) -- add the new partial `duels/_challenge_button.html.erb` (locals `friend:`) after the trade control; `app/helpers/duels_helper.rb` -- `duel_reachable(friend)` returning the viewer's `ReachableFriends` row for that friend (memoised per request in `@reachable_friends`, indexed by player id), nil when none.
- `app/helpers/trades_helper.rb` (`trades_closed_line`), `app/views/friends/_friend_row.html.erb` -- precedent for the "closed" line markup; `app/frontend/styles/duel.css`, friends styles -- tokens only, stay under the CSS size limit.
- `config/locales/en.yml`, `fr.yml` -- `duels.online.{heading,none,no_friends,add_friends}` (heading `"Online · %{count}"` / `"En ligne · %{count}"`, a plain string with no plural hash), `duels.challenge.{button,label,button_in_duel,label_in_duel,in_duel}` ("Challenge" / "Défier", "Challenge %{name}" / "Défier %{name}", "Challenge to a duel" / "Défier en duel", "Challenge %{name} to a duel" / "Défier %{name} en duel", "In a duel" / "Duel en cours"); reuse `errors.game.friend_duels_closed` for the private-friend line (via `Game::ChallengeFriend.failure_message`) and `own_duels_closed` for the Duels line.
- `test/controllers/duels_controller_test.rb`, the friends page controller test, `test/system/live_updates_test.rb` -- rendering tests and two-session precedent.

## Tasks & Acceptance

**Execution:**
- [ ] `db/migrate/20261116110000_add_reachable_until_to_accounts_players.rb` -- the column; then regenerate `db/schema.rb` on `gameble_build_43_3` as the task directs and drop that database.
- [ ] `app/domains/accounts/app/operations/accounts/note_reachable.rb` -- `call(player_id:, at: Time.current)`: one `update_all(reachable_until: at + LEASE)` on `Player.in_good_standing.where(id:)`, `LEASE = 45.seconds`, no event, returns `Success(written)`.
- [ ] `app/channels/player_stream_channel.rb` -- note on subscribe (confirmed own stream only), `periodically` renew; `unsubscribed` untouched.
- [ ] `app/domains/game/app/queries/game/reachable_friends.rb` -- the query; friends via `FriendsOf`, filter on `reachable_until`, one `DuelSeat` lookup for busy ids.
- [ ] `app/domains/game/app/operations/game/duel_steps.rb`, `challenge_friend.rb`, locales -- the refusal.
- [ ] `app/models/duel_lobby.rb`, `app/controllers/duels_controller.rb`, `app/views/duels/*`, `app/helpers/duels_helper.rb` -- Duels sections and preselection.
- [ ] `app/views/friends/_friend_row.html.erb`, `friend_profiles/show.html.erb`, `public_profiles/_action.html.erb`, `app/views/duels/_challenge_button.html.erb` -- DÉFIER EN DUEL, "Duel en cours", the private-friend line.
- [ ] `app/frontend/styles/duel.css` (+ friends styles if needed) -- minimal layout from tokens.
- [ ] `config/locales/en.yml`, `fr.yml` -- copy above.
- [ ] Tests: `test/domains/accounts/note_reachable_test.rb` (lease 45 s, one statement, no event, `updated_at` untouched, removed player untouched); `test/channels/player_stream_channel_test.rb` (lease set on subscribe, none on a rejected one, `PlayerStreamChannel.periodic_timers` holds a 30 s timer whose method renews the lease after time travel, unsubscribe writes nothing); `test/domains/game/reachable_friends_test.rb` (every Matrix row); `test/domains/game/duel_challenge_operations_test.rb` (unreachable friend refused with `friend_unavailable`, nothing written); controller tests for the Duels sections (EN LIGNE count and names, `Duel en cours`, none online, no friend, own private, preselection) and the friends page / friend profile / public profile buttons (reachable, in a duel, private friend, lapsed); `test/system/duel_reachability_test.rb` (two sessions: Hugo's page open, he is on Léa's Duels under EN LIGNE and on her friends page with DÉFIER EN DUEL; after time travel past the lease and a reload both lose him; retrying matchers; restore anything global).

**Acceptance Criteria:**
- Given Léa and Hugo friends and Hugo's page open, when Léa opens Duels and her friends page, then Hugo shows under EN LIGNE with DÉFIER and on his row with DÉFIER EN DUEL; when his lease has lapsed and she reloads, he is on neither and `ChallengeFriend` refuses him with `friend_unavailable`.
- Given a reachable friend, when Léa follows DÉFIER or DÉFIER EN DUEL, then Duels opens its challenge form with that friend selected.
- Given a subscribed player, when 30 s pass, then the lease is renewed to 45 s ahead; when they leave, nothing is written.

## Implementation Notes

- `duels.lobby.no_friends` moved to `duels.online.no_friends`: the lobby cannot tell "no friend" from "none online", so the EN LIGNE panel owns the line.
- The Duels screen hides the EN LIGNE panel while the player's own profile is private; the lobby's closed line stands in its place.
- Written but not run (suites run by the coordinator after integration): only `ruby -c`, YAML loads, `script/check_planning_references`, `script/check_file_sizes`, `npm run lint:css`, `npm run format:check` were run.

## Plan Change Log

## Review Triage Log

### 2026-11-16 — Review pass
- verdicts: 6 findings — high 0, medium 2, low 3, false 1, maybe-false 0
- findings:
  - `[low]` `[patch]` a private own profile printed the closed line twice and an "En ligne · 0" heading — the EN LIGNE panel is not rendered while the profile is private; the controller test asserts one line and no heading.
  - `[medium]` `[defer]` DÉFIER links point to `#duel-challenge` even when the form is absent (seated, waiting, received challenge, no complete deck) — the later challenge sheet entry owns the disabled states and their reasons.
  - `[medium]` `[patch]` the system test's `travel` could meet Hugo's live 30 s renewal timer — Hugo's page now goes to `about:blank` before the clock moves.
  - `[low]` `[reject]` a private friend shows the trades and duels closed lines side by side — the requirement words the duels line for a private friend; the trades line is pre-existing.
  - `[low]` `[patch]` a rejected subscription could still write the lease through a started timer — `note_reachable` returns when `subscription_rejected?`.
  - `[false]` `[reject]` `no_friends` key move contradicts the Code Map — the lobby cannot distinguish no friend from none online, and the removed line would show twice; recorded in Implementation Notes.

## Design Notes

The lease is a housekeeping write like `last_seen_at`: no event, one `UPDATE`. `ReachableFriends` rows keep busy friends so Duels can print "Duel en cours" while `ChallengeFriend` still answers `friend_busy` for them (reachable is checked first, busy second). A friend link is `duels_path(friend: friend.token, anchor: "duel-challenge")`; the lobby preselects the radio whose token matches, ignoring unknown tokens.

## Verification

**Commands:**
- `ruby -c` on each new or changed Ruby file -- expected: Syntax OK.
- YAML loads of `config/locales/en.yml` and `fr.yml` -- expected: no error.
- `script/check_planning_references`, `script/check_file_sizes`, `npm run format:check`, `npm run lint:css`, `npx tsc --noEmit` -- expected: exit 0.
- Test suites: run by the coordinator after integration.

## Auto Run Result

**Summary:** `reachable_until` lease on the Accounts player row, written by `Accounts::NoteReachable` on `PlayerStreamChannel` subscribe and every 30 s; `Game::ReachableFriends` feeds `ChallengeFriend` (`friend_unavailable`), an EN LIGNE panel and a preselecting challenge form on Duels, and DÉFIER EN DUEL on the friend's row, friend profile and public profile.

**Files changed:** migration and `db/schema.rb`; `Accounts::NoteReachable`; `PlayerStreamChannel`; `Game::ReachableFriends`; `ChallengeFriend` and `DuelSteps`; `DuelLobby`, `DuelsController`, `DuelsHelper`; duels views (`_online`, `_challenge_button`, `_lobby`, `show`), friends and public profile views; `duel.css`, `friends.css`; locales; tests (note, channel, query, operation, controller, system).

**Review findings:** 3 patched (1 medium, 2 low), 1 deferred (medium), 2 rejected (see the triage log).

**Follow-up review recommended:** false.

**Verification:** `ruby -c`, YAML loads, `script/check_planning_references`, `script/check_file_sizes`, `npm run lint:css`, `npm run format:check` pass. Suites run by the coordinator.

**Residual risks:** nothing ran under Rails; the channel test calls the periodic timer through `instance_exec` and the system test relies on a shared test-process clock.
