---
title: 'A challenge is sent from the Défier un ami sheet and answered from a dialog'
type: 'feature'
ticket: '4'
created: '2026-11-16'
status: 'built'
baseline_revision: '36b2bf677515b784b40912ff14fd80faf7b84c91'
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
  - '{project-root}/_bmad-output/initiative-gameble/epic-live-friend-duels/story-only-a-reachable-friend-can-be-challenged-from-duels-or-the-plan.md'
  - '{project-root}/_bmad-output/initiative-gameble/epic-live-friend-duels/story-two-friends-play-a-whole-duel-to-its-result-on-a-plain-duel-plan.md'
warnings: ['oversized']
deferred:
  - summary: >-
      A challenger who navigated away from Duels while waiting gets neither the outcome line nor the landing when the friend answers.
    evidence: |-
      The outcome and the landing marker are streamed into #duel-sheet-outcome, which exists only on the Duels page.
    location: >-
      app/views/duels/_sheet.html.erb
    severity: medium
  - summary: >-
      After a declined or lapsed outcome the sheet offers no way to challenge again until a reload.
    evidence: |-
      The waiting block is hidden and the choose form was not rendered in that sheet.
    location: >-
      app/frontend/controllers/duel_sheet_controller.ts
    severity: low
  - summary: >-
      The no-deck outcome is inferred from the friend's decks at render time, not at refusal time.
    evidence: |-
      DuelUpdate reads the invited player's current decks when it renders a refused outcome.
    location: >-
      app/models/duel_update.rb
    severity: low
---

<intent-contract>

## Intent

**Problem:** Challenging is a plain inline form on Duels, a challenge received is an inline block of that screen only, a challenge can be neither cancelled nor refused, and the DÉFIER links point at a form that is often not rendered.

**Approach:** "Défier un ami" becomes a `BottomSheetComponent` on Duels (deck radios, friend radios, DÉFIER, then a waiting state with ANNULER and an outcome line), opened by the screen's one primary button and by every DÉFIER / DÉFIER EN DUEL. A challenge received becomes a dialog in the layout, pushed on the private stream, with ACCEPTER and REFUSER. Two operations, `Game::CancelChallenge` and `Game::RefuseChallenge`, end a challenge like `LapseChallenge`; each end is pushed to both private streams.

## Boundaries & Constraints

**Always:**
- Obey `AGENTS.md`: writes only in operations (`call` returns a plain value, uses `step`/`Failure(:code)`, never wraps its result in `Success(...)`); one event per operation inside its transaction; handlers never publish; broadcasts through a job; GETs never write; tokens never ids; a Pundit policy per action; every string in `en.yml` and `fr.yml` (French typography: U+202F before `: ; ? !` and inside « », plurals need `zero`; dynamic `errors.game.<code>` keys by hand); no planning ids; English repo text; Ruby/TS files under 400 lines; no `style` attribute; ERB must also parse with plain Ruby ERB (no `<% case %>`/`<% when %>` with text between, never shorthand hash args before `%>`); no endless `def x = a if cond`; `assert_select` selectors never hold a literal `?`.
- Reuse, do not duplicate: `BottomSheetComponent`, `ButtonComponent` (`opens:`, `describedby:`, `aria_label:`), `duels/_clock` and `duel_clock_controller` (deadline from `move_deadline_at`), `Game::ReachableFriends`, `Game::HeldSeats`, `DeckList`, `DuelLobby`, `ToastComponent` (the `#toasts` region is `role=status` polite: the closing status lines are toasts appended on the stream), `gameble:opening-revealing` (`app/frontend/lib/events.ts`), the existing refusal codes (`friend_unavailable`, `friend_busy`, `duel_in_progress`, `deck_not_ready`, `not_your_move`, `duel_not_found`).
- The sheet is one root Stimulus controller (`duel_sheet_controller.ts`) over a pure state module `app/frontend/lib/duel_sheet.ts` (with a vitest test); it clones server-rendered `<template>`s, never builds markup; screens talk to chrome only through `gameble:*` events declared in `events.ts`.
- The duels table already allows states `cancelled` and `refused` (check constraint): no migration.
- Existing duel tests keep passing: update those that drove the removed inline form (`#duel-challenge`) and the inline received block, and remove the locale keys that become unused (`i18n-tasks` flags them), in both locales.

**Never:**
- No new Solid Queue worker/process/queue (connection budget); no new job (extend `PlayerStreamJob`); no timer on the server beyond the existing `DuelDeadlineJob`.
- No migration, no change to the duel rules, the clock, `present_until` (owned by a later entry) or `AcceptChallenge`'s lapse window.
- Do not run tests, rubocop, packwerk, zeitwerk, i18n-tasks, vitest or `bin/ci`: suites are run by the coordinator after integration. Allowed: `ruby -c`, YAML loads, ERB compile checks, `script/check_planning_references`, `script/check_file_sizes`, `npm run format:check` (`npm run format` fixes), `npm run lint:css`, `npx tsc --noEmit`.
- Git only as `/usr/bin/git`; never touch `develop`/`main`; never stage `package-lock.json` or `config/*.key`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Cancel | challenger, duel `challenged` | state `cancelled`, `ended_at`, `move_number` +1, both seats `left`, one `DuelChallengeCancelled` | — |
| Cancel, wrong player | the invited friend or an outsider | nothing written | `not_your_move` / `duel_not_found` |
| Cancel after answer | duel active, lapsed, refused | nothing written | `not_your_move` |
| Refuse | invited friend, duel `challenged` | state `refused`, same writes, one `DuelChallengeRefused` | — |
| Refuse, wrong player / after answer | challenger, outsider, active duel | nothing written | `not_your_move` / `duel_not_found` |
| Streams | any end (lapsed, refused, cancelled, accepted) | notices for both players reach `PlayerStreamJob` | — |
| Last used deck | latest seat of the player with a `deck_token` | that deck preselected if still complete, else the first complete deck | none: first complete deck |
| Sheet, choosing | complete deck, reachable free friends | deck radios, friend radios, DÉFIER enabled | — |
| Sheet, no complete deck | only drafts or none | DÉFIER `aria-disabled`, focusable, reason under it: "Il vous faut un deck complet de 12 cartes pour défier." (new key); a draft radio `aria-disabled` with "<n> / 12" and "Un brouillon ne peut pas jouer : il lui faut 12 cartes." (`errors.game.deck_not_ready`) | — |
| Sheet, duel in progress | player seated or invited | DÉFIER disabled, reason `errors.game.duel_in_progress` | — |
| Sheet, friend in a duel | reachable row `in_duel` | radio `aria-disabled`, its accessible name carries "<name>, duel en cours", only the avatar dimmed | — |
| Sheet, friend gone | DÉFIER refused with `friend_unavailable` or `friend_busy` | redirect to Duels; sheet open on that friend, greyed, "<name> n'est plus disponible." inline | other refusals keep the alert flash |
| Sheet, waiting | challenger's duel `challenged` | "En attente de la réponse de <name>… <s> s" counting down from `move_deadline_at`, ANNULER (POST to cancel, back to Duels) | — |
| Sheet, answered | `accepted` on the private stream | the challenger lands on the duel | — |
| Sheet, declined / lapsed | `refused` / `lapsed` on the stream | outcome line "<name> a décliné." / "<name> n'a pas répondu.", waiting block hidden, focus on the line; friend without a complete deck: "<name> n'a pas de deck complet." instead of declined | — |
| Dialog, received | a challenge sent to a reachable player, any signed-in page | modal dialog titled "<name> vous défie en duel.", "Votre deck" radios (last used preselected, drafts `aria-disabled`), ACCEPTER, REFUSER, the clock (alert colour from 10 s); no bell line | — |
| Dialog, no complete deck | invited player without one | REFUSER only, with the draft reason | — |
| Dialog, capsule opening | `gameble:opening-revealing` `revealing: true` | the dialog waits, shows once the opening ends | — |
| Dialog closes | cancelled, lapsed on the stream | the dialog closes, a toast says "<name> a annulé son défi." / "Le défi de <name> a expiré.", focus returns to where it was; own refusal: notice "Défi refusé." | — |
| Open from a link | DÉFIER / DÉFIER EN DUEL / DÉFIER UN AMI | on Duels the sheet opens (friend preselected, focus on the first choice); from another page the link goes to `duels_path(friend: <player token>)` and the sheet renders open | unknown token: sheet as usual |

</intent-contract>

## Code Map

- `app/domains/game/app/operations/game/{lapse_challenge,accept_challenge,challenge_friend,duel_steps}.rb` -- model new operations on `LapseChallenge`; move `lapse` in `DuelSteps` onto a shared `end_challenge(state, event, ...)` step used by lapse, cancel and refuse (state must be `challenged`, else `Failure(:not_your_move)`; use `lock_duel`, `role_of`, `leave`, `next_move`, `duel_published`).
- `app/domains/game/app/events/game/duel_challenge_lapsed.rb` -- add `duel_challenge_cancelled.rb`, `duel_challenge_refused.rb`; `config/initializers/event_store.rb` -- subscribe where `DuelChallengeLapsed` is (grep it); `app/models/duel_stream.rb` (`EVENTS`) and `app/models/player_stream.rb` (`DUEL_EVENTS`, `notices`) -- add both events; a duel notice becomes `{ player_id:, topic: "duels", duel_id:, kind:, role: }` (kind `sent|accepted|lapsed|refused|cancelled`) so the job can tell each side what to render.
- `app/jobs/player_stream_job.rb`, `app/views/player_streams/_update.turbo_stream.erb` -- extend with a duel part built by a small class under `app/models` (e.g. `DuelUpdate`): for the invited side update `#duel-received` with the current received dialog (empty when none) and append the closing toast (cancelled, lapsed); for the challenger side update `#duel-sheet-outcome` with the outcome line (refused, lapsed) or the landing marker (accepted: an element whose controller `Turbo.visit`s `duel_path`). Per locale like the existing broadcast.
- `app/domains/game/app/queries/game/last_used_deck.rb` (new) -- token of the player's latest `DuelSeat` with a `deck_token`; `game/held_seats.rb`, `game/reachable_friends.rb` -- reuse.
- `app/models/duel_lobby.rb`, `app/models/deck_list.rb`, new `app/models/duel_sheet.rb` -- view model: deck choices (complete first, drafts with reasons), friend choices (reachable rows plus the refused friend greyed), preselections, the disabled reason, the waiting seat.
- `app/controllers/duel_moves_controller.rb`, `app/policies/duel_policy.rb`, `config/routes.rb` (near `duel_acceptance`) -- `cancel` (POST `duels/:token/cancellation`) and `refuse` (POST `duels/:token/refusal`, `redirect_back_or_to duels_path`, notice "Défi refusé." / "Challenge refused."), policies `cancel?`/`refuse?` = `seated?`, add them to the `throttle_player` list; `challenge` redirects to `duels_path(friend: token)`, and on `friend_unavailable`/`friend_busy` also sets a flash naming that friend so the sheet shows the inline line; `app/controllers/duels_controller.rb` builds the sheet.
- `app/views/duels/{show,_lobby,_online,_challenge_button,_deck_choice}.html.erb` -- `show` renders the sheet; the lobby drops the inline form and the received block and keeps the primary DÉFIER UN AMI (`ButtonComponent` `opens: "duel-sheet"`), the in-progress row with REPRENDRE and the waiting line; `_online` rows open the sheet on that row's friend (a wrapper `data-duel-sheet-friend="<player token>"` read by the controller); `_challenge_button` (friends row, friend profile, public profile) keeps its link `duels_path(friend: token)` with the anchor removed. New `duels/_sheet.html.erb` (+ `_sheet_choose`, `_sheet_waiting`, shared `_deck_radios`), new `shell/_duel_received.html.erb` rendered in `app/views/layouts/application.html.erb` for a signed-in player outside the back office (`<div id="duel-received">` slot with the dialog inside when a challenge is held; compute the deck list only when one is).
- `app/frontend/controllers/{duel_sheet,duel_received}_controller.ts` (new), `app/frontend/lib/duel_sheet.ts` (+ `.test.ts`), `app/frontend/lib/events.ts` -- sheet: picks the friend of a clicked opener, blocks selecting an `aria-disabled` radio and submitting a disabled DÉFIER, reveals the outcome and hides the waiting block when an outcome node is connected (target callback), focuses (first choice on open, waiting block after DÉFIER, outcome line), keeps the server's `open` attribute out of morphs (`turbo:before-morph-attribute`: cancel the `open` attribute change on `#duel-sheet`); dialog: `showModal` on connect once no opening is revealing (listen to `gameble:opening-revealing`), keeps the focused element before showing and refocuses it when the dialog node disappears, countdown via the existing clock; `app/frontend/controllers/bottom_sheet_controller.ts`, `dialog_opener_controller.ts`, `live_refresh_controller.ts` (holds refresh while a dialog is open) -- read, do not change unless needed.
- `app/frontend/styles/duel.css` (+ the stylesheet the sheet needs; stay under the 500-line CSS limit, tokens only, `docs/design-system.md`) -- radio rows at `touch-min`, dimmed thumbnail/avatar only, reason text muted, clock `--alert`.
- `config/locales/{en,fr}.yml` -- new `duels.sheet.*`, `duels.received.*` keys; reuse `duels.challenge.*`, `duels.online.*`, `duels.lobby.waiting_html`; remove keys left unused (`duels.lobby.{accept,challenge,friend,heading,received_html}` if unused after the change).
- Tests to update or extend: `test/support/live_duels.rb`, `test/controllers/duels_controller_test.rb`, `test/domains/game/duel_challenge_operations_test.rb`, the test covering `PlayerStream` notices and `PlayerStreamJob`, `test/system/duel_play_test.rb`, `test/system/duel_reachability_test.rb` (they drove the removed form / anchor), the duel policy test.

## Tasks & Acceptance

**Execution:**
- [ ] `Game::CancelChallenge`, `Game::RefuseChallenge`, the two events, `DuelSteps#end_challenge`, subscriptions -- operations, events, streams.
- [ ] `Game::LastUsedDeck`, `DuelSheet`, `DuelLobby` -- reads.
- [ ] `PlayerStream` notices, `PlayerStreamJob`, `_update.turbo_stream.erb`, the new duel-update class -- both private streams told of every end; dialog pushed; toasts.
- [ ] Controller actions, routes, policy, throttle, flash -- cancel, refuse, inline refusal.
- [ ] Views: sheet (choose, waiting, outcome, `<template>`s), dialog partial in the layout, lobby, online rows, challenge button.
- [ ] TypeScript: sheet and dialog controllers, state module, events, vitest test.
- [ ] CSS and locales (en and fr, U+202F, plural `zero`, dynamic error keys if a new refusal is added).
- [ ] Tests: operation tests for cancel and refuse (every Matrix row, both streams told, wrong player, after acceptance, `.with(server_time: nil)` when comparing `DuelView`s); `LastUsedDeck`; `DuelSheet` model; component/controller tests for the disabled states' accessible names (DÉFIER `aria-disabled` + `aria-describedby` reason, draft and in-duel radios `aria-disabled` with the reason in their name), last used deck preselected, dialog without a deck offers REFUSER only; job test for the pushed dialog, toasts and outcome lines; policy test; vitest for `lib/duel_sheet.ts`; `test/system/duel_challenge_test.rb` with two sessions: Léa challenges Hugo from the sheet and cancels; challenges again and Hugo refuses from the dialog (Léa's sheet reads "Hugo declined."); challenges again and Hugo accepts and both land on the duel; a player with only a draft sees DÉFIER disabled with its reason (retrying matchers, restore anything global).

**Acceptance Criteria:**
- Given Léa and reachable Hugo with complete decks, when she opens DÉFIER UN AMI, picks a deck and Hugo and presses DÉFIER, then the sheet waits with a countdown and ANNULER, Hugo's page shows the dialog (never a bell line), and ANNULER ends the challenge and closes his dialog with "Léa a annulé son défi.".
- Given a challenge received, when Hugo refuses, then Léa's open sheet says "Hugo a décliné."; when he accepts, then both land on the duel.
- Given a draft-only player, when she opens the sheet, then DÉFIER is disabled with its reason and no friend can be challenged.

## Implementation Notes

## Plan Change Log

## Review Triage Log

### 2026-11-16 — Review pass
- verdicts: 9 findings — high 0, medium 3, low 3, false 1, maybe-false 0
- findings:
  - `[medium]` `[patch]` an unknown friend token or a non-friend flash token opened the sheet — `DuelSheet#open?` now needs a matching or gone row; the controller test asserts it stays closed.
  - `[medium]` `[patch]` Escape closed the received dialog while the challenge stayed pending — the `cancel` event is prevented in `duel_received_controller.ts`.
  - `[medium]` `[patch]` a cached page restores the dialog open but not modal — `showWhenFree` closes and reopens it as modal.
  - `[low]` `[defer]` the no-deck outcome is read at render time — deferred, noted in the list.
  - `[false]` `[reject]` `friend_name(nil)` could raise — `friend_name` uses `player&.persona_name` and falls back to the nameless label.
  - `[medium]` `[defer]` an away challenger gets no outcome or landing — the sheet node exists only on Duels; deferred.
  - `[low]` `[defer]` no way to challenge again after an outcome without a reload — deferred.
  - `[low]` `[reject]` the system test lost the REPRENDRE assertion — the lobby row is covered by the controller test; not worth a flaky extra step.
  - `[low]` `[reject]` no controller-level tests for the Stimulus controllers — the state module is unit-tested and the system test drives the flow; adding a harness is more than a correction.

## Design Notes

Why outcomes travel on the stream: a dialog open holds `live-refresh`, so the sheet cannot rely on a morph; the job renders each side's fragment per locale (`#duel-received`, `#duel-sheet-outcome`) and the controllers react to the connected nodes. The sheet's `open` attribute is server-set only on a full visit (`params[:friend]`, a refusal flash) and kept out of morphs so a refresh never reopens it non-modally.

## Verification

**Commands:**
- `ruby -c` on each new or changed Ruby file; YAML loads of both locale files -- expected: no error.
- `script/check_planning_references`, `script/check_file_sizes`, `npm run format:check`, `npm run lint:css`, `npx tsc --noEmit` -- expected: exit 0.
- Test suites: run by the coordinator after integration.

## Auto Run Result

**Summary:** the Défier un ami sheet, the received-challenge dialog in the layout, `Game::CancelChallenge` and `Game::RefuseChallenge`, and the pushes to both private streams.

**Review findings:** 3 patched (medium), 3 deferred, 3 rejected (see the triage log).

**Follow-up review recommended:** false.

**Verification:** `ruby -c`, YAML loads, `script/check_planning_references`, `script/check_file_sizes`, `npm run format:check`, `npm run lint:css`, `npx tsc --noEmit`. Suites run by the coordinator.

**Residual risks:** nothing ran under Rails or a browser; the dialog does not detect a reveal already running when it connects.
