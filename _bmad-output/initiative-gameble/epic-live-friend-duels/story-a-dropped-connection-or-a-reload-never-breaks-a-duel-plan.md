---
title: 'A dropped connection or a reload never breaks a duel'
type: 'feature'
ticket: '7'
created: '2026-11-17'
status: 'built'
baseline_revision: '940317c64aa1a7d9c787a2f3e62497f71f7d07f9'
route: 'full'
route_source: 'auto'
review: 'thorough'
review_source: 'pinned'
lenses_ran: ['blind-hunter', 'edge-case-hunter', 'verification-gap', 'intent-alignment']
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/AGENTS.md'
  - '{project-root}/docs/design-system.md'
warnings: ['oversized']
deferred:
  - summary: >-
      The native apps are not changed: a native tab or top-bar destination does not yet count as a disconnection through any native code, and the native DUELS tab badge is not wired.
    evidence: |-
      no Swift or Kotlin toolchain on the build machine; `mobile/` untouched. On the web the lease lapses 20 s after the page leaves.
    severity: medium
  - summary: >-
      After the move's timer has run out the button keeps reading the sending label until a board arrives; the own banner and the subscribe push are the only signs.
    evidence: |-
      `app/frontend/controllers/duel_controller.ts` (`resend` stops silently once `retryOpen` is false).
    severity: low
  - summary: >-
      A cable that never connects while the browser is online shows no own-connection banner, and no lease is written either.
    evidence: |-
      `app/frontend/lib/duel_link.ts` (`linkChecked` needs a cable seen connected once).
    severity: low
  - summary: >-
      Every board push now also renders the connection slot, and the sweep re-pushes an unchanged slot every 10 s while a seat is away; the client drops identical ones.
    evidence: |-
      `app/jobs/duel_stream_job.rb`, `app/jobs/duel_absence_job.rb`; load unmeasured, see the live duel load unknown of the epic.
    severity: low
  - summary: >-
      The bell's resume line also shows while the player is on that duel's page, and `deadlineAt` (the retry bound read from the clock) has no controller test.
    evidence: |-
      `Game::BellItems.duel_seats` does not know the current page; `duel_controller.test.ts` has no `.duel-clock` fixture.
    severity: low
---

<intent-contract>

## Intent

**Problem:** Nothing writes a seat's lease, so the reconnection deadline never shortens; a friend who drops is invisible to the other seat; a seat that reconnects is not refreshed; a move lost to the network stays disabled; a player who left an active duel has no way back from the hub, the bell or the tab bar.

**Approach:** The seat stream's channel leases presence (20 s ahead on subscribe and every 10 s, no event) and pushes the current view on every subscribe; the view says whether the other seat is absent and a connection slot outside the board shows both players' connection states; the move button retries a failed request while its timer runs; Duels, the bell, the DUELS tab and menu 04 lead back to a duel in progress, and the bell shows a duel finished in the last 7 days.

## Boundaries & Constraints

**Always:** Obey `AGENTS.md` (operations write, one event per operation, no ids in markup, tokens, every string in `en.yml` and `fr.yml` with French plural `zero`, no `style` attribute, files under 400 lines, no planning ids). The presence write is a housekeeping write with no event; unsubscribing changes nothing. A seat is absent once its lease has lapsed; a seat that never held a lease is not absent. A repeated move is refused by its `move_number` and never played twice. The board's drop rule for an older view stays; presence travels in its own slot so a same-number push never wipes a choice in progress.

**Never:** No migration; no change to `DuelRules` or the clock's rules; no native app code (no Swift or Kotlin toolchain here). Never push; never run the whole system suite.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Lease | seat stream subscribed, then every 10 s | `present_until` = now + 20 s, no event | a seat not `seated` is left alone |
| Return | subscribe after the lease lapsed or after a cable drop | both seats get the current board (older number dropped by the client) and their connection slot | -- |
| Other absent | other seat lease lapsed, duel active | "Connexion de Hugo perdue… s s" counting to lease + 60 s on this seat's page | the sweep re-pushes the slot every 10 s |
| Own cable lost | stream source loses `connected`, or `offline` | "Connexion perdue… s s" counting 60 s; hidden on return | -- |
| Move while offline | ANNONCER or RÉPONDRE, request fails | button reads ENVOI…, same form resent every 2 s while its timer runs | a resend of a delivered move is refused by `move_number`, redirect without an alert |
| Left a duel | active duel, player elsewhere | Duels row REPRENDRE; bell "Votre duel contre X attend votre retour." + Reprendre; badge 1 on DUELS tab and menu 04 | -- |
| Finished duel | finished within 7 days | bell "Duel contre X terminé : victoire, 6 à 4." + Voir | older than 7 days: no line |

</intent-contract>

## Code Map

- `app/domains/game/app/operations/game/note_duel_presence.rb` (new) -- the lease write; `app/channels/duel_seat_channel.rb` -- calls it on subscribe and every 10 s, enqueues `DuelStreamJob` on subscribe or a lapsed lease.
- `app/domains/game/app/models/game/duel_view.rb`, `app/models/duel_screen.rb` -- `away_until` of the other seat; `app/views/duels/_connection.html.erb`, `play.html.erb`, `app/jobs/duel_stream_job.rb` (`boards:` flag), `app/jobs/duel_absence_job.rb` + `app/domains/game/app/queries/game/duels_with_absent_seat.rb`, `config/recurring.yml`.
- `app/frontend/lib/duel_link.ts`, `controllers/duel_link_controller.ts`, `controllers/duel_controller.ts`, `lib/duel_form.ts` -- own connection, ENVOI… and retry (settles the deferred "move button stays disabled" line); `duel_moves_controller.rb` -- silent refusal of a resent move.
- `app/domains/game/app/queries/game/duel_in_progress.rb` (new), `bell_items.rb`, `bell_helper.rb`, `shell/_tab_bar.html.erb`, `pages/_menu_duels.html.erb`, `player_stream.rb`, `player_stream_job.rb`, `player_streams/_update.turbo_stream.erb`, `duels/_lobby.html.erb`.

## Tasks & Acceptance

**Execution:**
- [x] Presence lease, channel, view, slot, absence job, locales, unit tests
- [x] Client: own connection, ENVOI… and retry, vitest
- [x] Bell lines, badge, REPRENDRE name, tests
- [x] One system test, two sessions (Hugo offline in round 3, returns, leaves for the hub, REPRENDRE)

**Acceptance Criteria:**
- Given an active duel with both seats subscribed, when Hugo's lease lapses and the sweep runs, then Léa's page reads "Connexion de Hugo perdue…" with a countdown, and when Hugo subscribes again both resume at the same round.
- Given Hugo offline when he presses ANNONCER, then the button reads ENVOI…, and once online the move lands once.
- Given Hugo left the duel, then Duels shows REPRENDRE, the bell shows its line and the DUELS tab a badge of 1.

## Implementation Notes

- Implemented directly in the main session (the plan was formed from a full read of the duel code), reviewed by four independent lenses.
- Presence travels in its own slot (`#duel-connection`, pushed by `DuelStreamJob`, a `boards:` flag, and by `DuelAbsenceJob` every 10 s) so a same-number push never wipes a choice; the client drops an identical slot.
- The channel pushes the current boards on every subscribe, which is the reconnection and reload refresh; the client's strictly-newer rule drops what it already shows.
- The retry resends the same form every 2 s (`resent=1`); the controller turns a `:not_your_move` refusal of a resent move into a silent redirect. A server error response also counts as a failed send. Settles the deferred line of entry 43.5.
- `DuelFinished` joins the player stream's duel events so the DUELS badge and the bell refresh when a duel ends.
- System tests: the lapsed lease is forced in the database and the sweep run by hand; the offline state is emulated with the browser's network conditions plus a server-side cable disconnect; a move that cannot get through is emulated by blocking the move URLs.

## Plan Change Log

## Review Triage Log

### 2026-11-17 - Review pass
- verdicts: 31 findings - high 0, medium 3, low 18, false 6, maybe-false 4
- findings:
  - `[medium]` `[patch]` a resend after an HTTP error response (not a network error) stalled with the button disabled - a `turbo:submit-end` handler counts a 5xx as a failed send and `resend` re-arms its own timer; vitest covers it.
  - `[medium]` `[patch]` the bell's duel lines were verified only by a system test - helper tests for both kinds in both locales, and unconditional win, loss and draw outcomes for each seat.
  - `[low]` `[patch]` the resend refusal was tested for calls only - a controller test for answers.
  - `[low]` `[patch]` the system test accepted a French heading in an English page - the heading is matched in English only.
  - `[medium]` `[defer]` native apps not changed - deferred, no toolchain.
  - `[low]` `[defer]` button keeps the sending label after the timer ran out; own banner never shown for a cable never connected; connection slot rendered on every board push and swept every 10 s while unchanged; resume line on the duel's own page; `deadlineAt` without a controller test.
  - `[false]` `[reject]` presence written for finished duels - a finished duel's seats are `left` and the operation skips them (`NoteDuelPresence` test).
  - `[low]` `[reject]` the absence rule is repeated in five places - the minute is the clock's `ABSENCE`, shared by the view, the query and the clock; the client's 60 s is the same spec figure.
  - `[low]` `[reject]` the two countdowns differ by the lease - the own banner counts from the drop, the friend's from the lapse, as the ticket words each.
  - `[low]` `[reject]` `textContent` on the button drops markup - the move buttons carry plain text only.
  - `[low]` `[reject]` French "de Alice" elision, plural branch never reached, `secondsUntil` imported from the booster clock, a literal space before the unit, own spoken text without consequence - copy and plural keys are the ticket's wording and the repo's pattern; the clock helper is already shared by `duel_clock.ts`.
  - `[low]` `[reject]` a silenced resend of a real not-your-turn refusal - only a retry carries the flag and the redirect shows the current board.
  - `[maybe-false]` `[reject]` a stale banner after a sweep races a return push - the next 10 s sweep or any push re-renders from current state.
  - `[low]` `[reject]` banner at 0 s while saying moves play automatically - the board plays them within seconds and pushes; reading 0 s is the truthful state.
  - `[low]` `[reject]` the intent-alignment divergences (one system test split into four, forced lease, URL-blocked move) - the same flows are covered, the real 20 s and 10 s timers are covered by the channel test.
  - `[low]` `[reject]` remaining style findings (plan file unfinished, brittle waits, redundant reload test) - plan finalized here; waits are retrying matchers.


## Verification

**Commands:**
- `bin/rails test` on the touched unit, channel, job, query and helper tests; `bin/rails test test/system/duel_connection_test.rb test/system/duel_play_test.rb test/system/duel_deadline_test.rb` -- expected: pass.
- `npm run test:js`, `npx tsc --noEmit`, `npm run format:check`, `npm run lint:css`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bundle exec rubocop`, `bundle exec i18n-tasks health`, `script/check_planning_references`, `script/check_file_sizes` -- expected: exit 0.

## Auto Run Result

**Summary:** A seat stream's lease is written on subscribe and every 10 s; the other seat sees the lost connection with its countdown; reconnection and reload push the current boards; a move that cannot get through reads the sending label and is resent while its timer runs; Duels, the bell, the DUELS tab and menu 04 lead back to a duel in progress, and the bell shows a duel finished in the last 7 days.

**Files changed:** presence operation, absence query and job, channel, view and screen, connection slot, stream job; client link controller and retry; bell items and helper, tab and menu badges, player stream; copy; tests and one system file.

**Review findings:** 4 patched, 5 deferred (see the triage log), the rest rejected with reasons. Follow-up review recommended: false.

**Verification:** 4204 Ruby unit and integration runs, `npm run test:js` (1483), tsc, prettier, stylelint, rubocop, zeitwerk, packwerk, i18n-tasks missing, planning-id and file-size checks pass. System tests: duel_connection (4, five green runs), duel_play, duel_challenge, duel_deadline, duels, bell, duel_reachability, hub, market_badges, live_updates, native_app. Not verified: the native apps, a real flaky network, a real 20 s lease expiry in a browser.
