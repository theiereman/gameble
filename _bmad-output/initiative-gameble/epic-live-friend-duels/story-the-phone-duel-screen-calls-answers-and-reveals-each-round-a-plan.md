---
title: 'The phone duel screen calls, answers and reveals each round as designed'
type: 'feature'
ticket: '5'
created: '2026-11-17'
status: 'built'
baseline_revision: '1ec34832767fb89d1dca5f31dc16acd995657aba'
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
warnings: ['oversized']
deferred: ['no retry after a network failure of a move (43.7)', 'Joué label may clip on 12 thumbnails (hitl)', 'rematch availability read at render']
---

<intent-contract>

## Intent

**Problem:** The duel screen of entry 2 is a plain stack of text: no thumbnails, no card faces, no radio groups for card, stat and direction, no reveal, no designed result, no rematch, no tab-bar-free layout.

**Approach:** Rebuild the duel board (`duels/_board`, `DuelScreen`, `duel.ts`, `duel_controller.ts`) as boards 4 to 7 and DESIGN.md's Duel, Duel header, Duel reveal and Duel result at phone width, with no tab bar and no back, keeping entry 6's timer by the name of whoever must act. The server renders every state from `Game::DuelView` only; the client holds choices, the reveal, the 400 ms guard and Esc in one state module.

## Boundaries & Constraints

**Always:**
- Obey `AGENTS.md`; the contract of entry 2's plan still holds (every page and push renders through `DuelScreen` over `Game::DuelView.for(duel, seat)` only, no database id or draw order in markup, token-based names, `authenticity_token: false` on forms in `duels/_board` since the job renders it, no `style` attribute, files under 400 lines (CSS 500), no planning ids in code, English repo text, French only in `fr.yml`, every string in `en.yml` and `fr.yml`, French plurals with `zero`).
- The board still carries `data-move-number` and the client still drops a view not newer than the one shown. Secrecy is unchanged: the answerer's board never holds the locked call's stat or direction, no board holds the other seat's hand.
- Server-rendered markup only: the client toggles `hidden`/`disabled`/`aria-*` and moves focus; it never builds markup. A rich screen has one root controller (`duel`) holding its state module `app/frontend/lib/duel.ts`; children talk to it by `dispatch` and it drives them through outlets.
- Accessibility floor (EXPERIENCE.md, Accessibility Floor, Duels): the hand, the five stats and the two directions are each a radio group (one tab stop, arrows inside) named "Votre main", "Caractéristique", "Sens" (`fieldset` + `legend`); a stat already called stays in its group with `aria-disabled="true"`, its name ending "déjà annoncée"; a card's name holds its game, each stat's its percentile in words ("Sortie, plus ancienne que 97 % des cartes") then the raw value, each direction its words. "ANNONCER" and "RÉPONDRE AVEC CETTE CARTE" are ordinary buttons after the groups, `aria-disabled` until their choices are complete (never `disabled`). The deck rows are lists whose played items say "joué". Slashes, dashes, signs and units read as words through visually hidden text, the visual twin `aria-hidden`: "MANCHE 2 / 10" as "Manche 2 sur 10", "6 – 4" as "6 à 4", "<s> s" as "<s> secondes", a margin "+3" as "plus 3" and "−2" as "moins 2".
- Colours from tokens only (`--color-capsule-duel`, `--color-lime`, `--color-alert`, `--color-text-max`, `--color-dim`, `--color-muted`), spacing from `--space-*`; new styles in a new `app/frontend/styles/duel-board.css` imported after `duel.css` in `entrypoints/application.css` (keep each CSS file under 500 lines; delete from `duel.css` whatever the new board replaces).
- Motion: a face-up card is a 200 ms flip, a drawn card slides into the hand in about 200 ms; under reduced motion (`html[data-motion="reduced"]`, and `@media (prefers-reduced-motion: reduce)` unless `html[data-motion="full"]`, as `booster.css` does) a plain swap, no animation.

**Never:**
- No connection banners, "ENVOI…" retry, presence lease, bell line or badge (entry 7); no desktop layout (entry 9; the markup must simply still work wide); no capsule line, record or history (epic 44; leave only an empty `div#duel-capsule-line` between the result's margin line and its rounds as the place 44.1 fills); no change to the operations, `DuelView`, `DuelRules`, the clock or the jobs; no migration.
- Never hand-edit `app/frontend/images/pixel/`. Never stage `package-lock.json` or `config/*.key`. Run git only as `/usr/bin/git`. Never run the whole system suite.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Calling | caller's turn | hand of three as a radio group; choosing a card shows that card's five stats (a called one `aria-disabled`, "Déjà annoncée"); choosing a stat shows its two directions in words; ANNONCER `aria-disabled` until card, stat and direction are chosen; every choice changeable; POST sends `card`, `stat`, `direction`, `move_number` | a refusal redirects with its message as today |
| Answering | answerer's turn | the friend's card face up with its five values, "Annonce cachée" on a `capsule-duel` outline, never its stat or direction; hand radio group; RÉPONDRE AVEC CETTE CARTE `aria-disabled` until a card is chosen | as today |
| Waiting | not my turn | round heading names whose move it is ("Hugo répond…" / "Hugo annonce…"), no spinner, the table shows the caller's card and the empty answerer's slot, the hand is a plain list | — |
| Press guard | ANNONCER or RÉPONDRE pressed | nothing fires on press (pointer or Enter); on release it fires only if 400 ms have passed since the button became active (choices complete, or the board shown with them complete); a release inside the window does nothing and keeps the choices | — |
| Esc | duel screen, no dialog open | clears the latest choice (direction, then stat, then card); with none left does nothing; never navigates | — |
| Reveal | a round answered within the last 10 s when the board renders | both cards side by side (200 ms flip, caller's then answer's), the stat and direction in words, both values in words and raw, the outcome word (Gagnée, Perdue, Nulle, départagée à la valeur exacte), "Coup joué automatiquement" under the card it concerns, SUIVANTE; focus on the outcome heading whose text holds the whole round; after 3 s from first shown, or at once on SUIVANTE, the live board shows and focus goes to the hand when the viewer must call or answer, else the round heading, on a finished duel the result heading | an older view is dropped; a later board of the same round does not restart the 3 s; a dismissed round never shows again |
| Friend's call lands | pushed board for my answer turn | a polite status line says "<name> a annoncé. Sa carte : <card>." | — |
| Drawn card | a pushed board whose hand holds a card not in the previous hand | that card slides in (plain with reduced motion) | — |
| Result | finished duel | heading (focus target) reads first: "Victoire contre Hugo, 6 à 4[, départagée à l'écart de 12 points de centile]" (visual "Victoire contre Hugo · 6 – 4"); "Départagé à l'écart : 12 points de centile" when equal scores did not draw; `div#duel-capsule-line`; the ten rounds as an ordered list of one sentence each ("Manche 3, Léa annonce la plus ancienne : Quake, 1996, contre Half-Life, 1998. Gagnée." plus the automatic and exact-value marks); REJOUER | — |
| Rematch | finished, opponent reachable and free | REJOUER (primary, accessible name "Rejouer contre Hugo") posts the challenge to the same friend with the player's own deck token; success lands on Duels with the sheet open and waiting on Hugo | refusal as `ChallengeFriend` today |
| Rematch unavailable | opponent not reachable, no longer a friend or anonymous / in a duel | REJOUER `aria-disabled`, reason under it, `aria-describedby`: "<name> n'est plus en ligne." / "Duel en cours" | — |
| Screen chrome | any duel state | no tab bar, no back button, no phone back link; the top bar keeps the screen name | — |

</intent-contract>

## Code Map

- `app/views/duels/_board.html.erb`, `_hand.html.erb`, `_hand_cards.html.erb`, `_side.html.erb`, `play.html.erb`, `_clock.html.erb` -- the plain board to rebuild (keep `#duel-board[data-duel-target=board][data-move-number]`, `#duel-their-deck li` x12, `#duel-my-deck li` x12, `#duel-hand`, `form#duel-call`, `form#duel-answer`, `#duel-current-call`, `.duel-clock` and its data values: other tests read them). Split the board into small partials; each under 400 lines.
- `app/models/duel_screen.rb` -- presenter over `Game::DuelView` (`titles` through `Catalog::CardViews.call(ids, locale:)` which returns `CardView` with `title`, `image_url`, `rarity`, `year`, `publisher`, `genre`, `number`, `season_number`; `reveals`, `calls`, `turn`, `outcome`, `decided_on_margin?`, `position(card)`). Extend it: card views, the last revealed round with both cards, the reveal window (from the last row of `@duel.rounds` by `answered_at` against `view.server_time`), the viewer's name (the seat's player through `Accounts::PlayerById`), per-card stat rows for the hand, the rematch state (`Game::ReachableFriends.call(player)` rows: `player`, `in_duel`), the status sentence of a friend's call.
- `app/helpers/duels_helper.rb`, `app/helpers/duel_profile_helper.rb` (`duel_stat_words(stat, rarity:)`, `duel_stat_value(stat)` take a `Game::DuelProfiles::Stat`; `duels_helper#duel_card_value` already builds one; percentile may be nil: use `duel_stats.no_value`), `friends_helper#friend_name`, `PlayerNameComponent` (`linked: false`, `duel_player_name`).
- `app/components/card_component.rb` (`size: :s | :m`, `tilt: false`, takes a `CardView`; spans only so it nests in a `label`), `button_component.rb` (`aria_disabled:`, `describedby:`, `aria_label:`, `type: :submit`; `variant: :link` is for "see all" only), `app/models/deck_list.rb` + `app/frontend/styles/duels.css` `.deck-row__covers/__cover/__art` (pattern for small cover thumbnails, aspect 460/215, `object-fit: cover`).
- `app/controllers/duel_moves_controller.rb` (`announce` splits `params[:call]`; change it to read `params[:stat]` and `params[:direction]`; `challenge` redirects to `duels_path(friend: token)` which opens the sheet waiting), `duels_controller.rb` (`play`), `app/views/duels/_sheet*.html.erb`, `app/models/duel_sheet.rb`, `duel_lobby.rb` -- the sheet REJOUER lands on.
- `app/views/layouts/application.html.erb` (tab bar is rendered `unless back_office_page? || content_for?(:public_page) || hotwire_native_app?`; add `content_for?(:no_tab_bar)`), `app/views/shell/_top_bar.html.erb` (`top-bar__bridge` and `top-bar__previous` links of a named screen; skip both when `content_for?(:no_back)`), `shell-header-phone.css` (`body:has(.tab-bar) .main` pads only when the bar exists).
- `app/frontend/lib/duel.ts` + `duel.test.ts` (keep `startDuel`, `acceptsView`, `viewShown`, `moveNumberFrom` and their tests), `controllers/duel_controller.ts` (root; listens to `turbo:before-stream-render` for target `duel-board`), `controllers/duel_clock_controller.ts` + `lib/duel_clock.ts` (add an optional `spoken` target updated with the seconds in words each tick; the visual `[data-duel-clock-target=text]` becomes `aria-hidden`; keep its existing text and values), `lib/events.ts`, `lib/booster_clock.ts`.
- `app/frontend/styles/duel.css` (337 lines; remove rules of the old plain board that the new CSS replaces), `entrypoints/application.css` (imports at 116-120).
- `config/locales/en.yml` / `fr.yml` -- `duels.board.*`, `duels.clock.*`, `duel_stats.*` (directions `duel_stats.directions.<stat>.high|low`, names, `words`, `values`), `duels.sheet`; keys are kept alphabetically (run `bundle exec i18n-tasks normalize` if available, and `i18n-tasks health`/`unused` as CI does).
- Tests to update or follow: `test/controllers/duels_controller_test.rb` (~l.320-360), `test/jobs/duel_stream_job_test.rb` (reads `#duel-hand label, #duel-hand li`, `#duel-current-call h2` "Hidden call" / "Annonce cachée", `form#duel-call`, `input[name=card]`, `input[name=call]` values, `.duel-clock`), `test/controllers/duel_moves_controller_test.rb` (the `call` param), `test/system/duel_play_test.rb`, `duel_challenge_test.rb`, `duel_deadline_test.rb` (read `#duel-board`, `.duel-clock`), `test/support/live_duels.rb` (`complete_deck`, `start_duel`, `call_round`, `answer_round`, `play_round`), `test/application_system_test_case.rb` (`resize_to`), `test/system/booster_test.rb` (`PHONE = [ 390, 844 ]` and restoring the size).

## Tasks & Acceptance

**Execution:**
- [ ] `app/models/duel_screen.rb` (+ a `DuelScreen` test) -- the presenter additions above; keep it under 400 lines (extract a small object for the hand's stat rows or the reveal if needed).
- [ ] `app/helpers/duels_helper.rb` -- helpers for the spoken forms (round, score, margin sign, seconds), the stat row label (name, words, raw value), the reveal sentence (reuse `duels.board.reveal.*`), the result summary and the one-sentence round list item.
- [ ] `app/views/duels/_board.html.erb` and new partials (`_header`, `_deck`, `_table`, `_call_form`, `_answer_form`, `_reveal`, `_result`, `_rounds`, `_rematch`) -- the board as the Design Notes lay it out; delete `_side.html.erb`, `_hand*.html.erb` if replaced.
- [ ] `app/views/duels/play.html.erb`, `app/views/layouts/application.html.erb`, `app/views/shell/_top_bar.html.erb` -- no tab bar, no back, a persistent visually hidden polite status line outside `#duel-board`.
- [ ] `app/controllers/duel_moves_controller.rb` -- `announce` reads `stat` and `direction`.
- [ ] `app/frontend/lib/duel.ts` (+ `duel.test.ts`) -- the state module: choices and their clearing order, a blocked (`aria-disabled`) choice refused, the readiness of each form, the press guard, the reveal (shown once per round, 3 s, SUIVANTE, not restarted by a later board), the drawn-card diff, the move-number drop rule already there.
- [ ] `app/frontend/controllers/duel_controller.ts` (+ a child `duel_press_controller.ts` for the guarded button if the root passes ~250 lines) -- radio change handling (reveal the chosen card's stat set and the chosen stat's direction set by toggling `hidden` and `disabled` so only the active set submits), syncing DOM radios from state after a refused choice, Esc, press/release, reveal timer and focus rules, status line, drawn-card mark, `data-armed` on the button once the guard elapsed (system tests wait on it instead of sleeping).
- [ ] `app/frontend/controllers/duel_clock_controller.ts`, `app/frontend/lib/duel_clock.ts`, `app/views/duels/_clock.html.erb` -- the spoken seconds.
- [ ] `app/frontend/styles/duel-board.css`, `duel.css`, `entrypoints/application.css` -- phone styling per DESIGN.md Duel, header, reveal, result (timer in `--font-count-large`, `--color-alert` from 10 s, score in `--font-count-large-phone`/`--font-count-large`, `--space-touch-min` rows if the token exists in `tokens.css`, else `--space-button-height`), the flip, slide and outcome fade with reduced-motion fallbacks.
- [ ] `config/locales/en.yml`, `config/locales/fr.yml` -- copy of the Copy deck, Duel and Duel result and record (see Design Notes).
- [ ] `test/controllers/duels_controller_test.rb`, `test/jobs/duel_stream_job_test.rb`, `test/controllers/duel_moves_controller_test.rb` -- follow the new markup: radio groups named Your hand / Stat / Direction (`fieldset legend`), a called stat `aria-disabled` with "Already called" in its name, the answerer's board without the stat or direction in any form, the result's spoken summary (both locales), REJOUER enabled/disabled with its reasons, no tab bar and no back link on the page, `announce` with `stat` and `direction`.
- [ ] `test/system/duel_play_test.rb` -- rewritten as the one phone-width (390 x 844, size restored in `ensure`) two-session test, see Acceptance Criteria; delete what the rewrite makes redundant (the ten-round click-through is replaced by rounds 2 to 10 played through `play_round`).

**Acceptance Criteria:**
- Given Léa and Hugo friends with a complete deck each, Léa's best card titled "Quake", on phone-width pages, when Léa chooses Quake, then the stat Release and "La plus ancienne" (Oldest) and presses ANNONCER once its guard has elapsed, then Hugo (after the push) sees Quake face up with "Annonce cachée" and no direction, chooses a card and RÉPONDRE, then both pages show the reveal whose focused outcome heading holds "Manche 1 gagnée|perdue|nulle : …" from their own side, then after SUIVANTE (or 3 s) the live board returns with the score updated; and in the call that follows by the same caller (round 3) the stat Release shows "Déjà annoncée" and aria-disabled.
- Given the ten rounds played to the result through the operations, when both pages show the result, then the heading reads the spoken summary first, the ten rounds are an ordered list of ten sentences, and REJOUER on Léa's page opens Duels with the sheet showing "En attente de la réponse de Hugo…".
- Given a rematch to a friend who is offline or in a duel, then REJOUER is `aria-disabled` with its reason.
- Given a guarded button, a press without release, a release inside 400 ms and a keyboard Enter keydown fire nothing; a release after 400 ms (and Enter's keyup) fires.
- Given Esc on the duel screen with a direction, a stat and a card chosen, three presses clear direction, stat, card in that order and the page stays.

## Implementation Notes

- Built by a subagent from this plan; the screen is split into small partials (`_header`, `_deck`, `_table`, `_face`, `_hand_group`, `_call_form`, `_answer_form`, `_reveal`, `_result`, `_rounds`, `_rematch`); the client keeps its state in `lib/duel.ts` and `lib/duel_form.ts`, styles in `duel-board.css` and `duel-reveal.css`.
- The form sends `card`, `stat`, `direction`; `data-armed` on the button marks the guard elapsed so system tests wait on it.
- Duel screens set `no_tab_bar` and `no_back` (layout, top bar, `ShellHelper`); one line added to `docs/design-system.md`.
- The reveal is rendered only when the last answer is the latest move (`move_number == 2n + 1`) and within 10 s; the client alone times its 3 s.
- hitl follow-ups (real phone, not done): touch guard, flip and slide feel, 12 thumbnails at 320 CSS px, screen-reader pass, comparison with boards 4 to 7 of the mockups (not opened: the canvas is not readable as a page).

## Plan Change Log

## Review Triage Log

### 2026-11-17 — Review pass
- verdicts: 9 findings — high 0, medium 2, low 5, false 0, maybe-false 2
- findings:
  - `[medium]` `[patch]` a dismissed reveal came back after the player's own move (reload resets the client state while the server still rendered the 10 s window) — the reveal now renders only when its answer is the latest move; `DuelScreenTest` covers it.
  - `[medium]` `[patch]` a finished duel with an anonymous opponent gave no REJOUER — it now renders `aria-disabled` with its reason.
  - `[low]` `[patch]` comments describing internal design in `duel.ts`, `duel_form.ts`, `duel_controller.ts`, `duel_screen.rb` — removed.
  - `[low]` `[patch]` `revealDue` unused outside its test — deleted with its test.
  - `[low]` `[patch]` a re-indented line in `duel_stream_job_test.rb` — realigned.
  - `[low]` `[defer]` the button stays disabled after a network failure of a move — entry 43.7 owns retry; logged in `deferred-work.md`.
  - `[maybe-false]` `[defer]` "Joué" may clip on a 26 px thumbnail — needs a real phone; logged.
  - `[maybe-false]` `[reject]` the system test's coupling to the 3 s window — it asserts the reveal with retrying matchers right after the board arrives and ran green on 8 runs; the 3 s is the contract.
  - `[low]` `[reject]` the rematch reason when the viewer is not open to friends — a viewer with a finished duel still has the friend list; the stated reason stays truthful about the opponent.

## Design Notes

**Layout of the board (top to bottom, one column at phone width):** `header.duel-header` (friend's name `.duel-board__opponent` in label muted; `h2#duel-round-heading[tabindex=-1]` holding "MANCHE n / 10" kicker visual + its spoken twin, then " · " and the turn text "À vous d'annoncer" / "À vous de répondre" / "<name> annonce…" / "<name> répond…"; the score `.duel-board__figure` in count-large with its spoken twin, "écart ±n" label muted under it; the clock `duels/_clock` by the mover's name); `section#duel-their-deck` ("SON DECK" kicker, an `ol` of 12 `li` thumbnails in one row of 12 (grid 12 columns, aspect 460/215, image `alt=""`, `aria-hidden` on the image; each `li` holds the game title visually hidden and, if played, `.duel-deck__played` "Joué" over the thumbnail with the thumbnail at `opacity: .35`), then `p.duel-side__calls` "Annonces restantes : <stats>" using `theirs.stats_left`); `section#duel-table` (caller's card slot and answerer's slot, `CardComponent` size `:m` face up; an empty slot is a dashed `--color-dim` frame; under the answerer's face-up card the five values in a `dl` and, in the answerer's view, `.duel-table__hidden` "Annonce cachée" on a 2px `--color-capsule-duel` outline; in the caller's view, after the call, the call's words); `section#duel-my-deck` ("VOTRE DECK", same list, no calls line); `#duel-hand` at the foot: the hand fieldset ("Votre main", each card a `label` with a radio `name=card value=<position>` and a `CardComponent :s` plus a visually hidden name), then, in the call form, the stat fieldset ("Caractéristique") then the direction fieldset ("Sens"), then the full-width primary button. While not my turn `#duel-hand` is a plain list of the three cards. A mover's pushed or loaded board keeps `#duel-current-call` as the table section for the locked call (its `h2` says the call's words to the caller, "Annonce cachée" to the answerer; the existing job test reads it, update the test if you rename it).

**Stat and direction sets (server-rendered, one per card and per stat):** inside `form#duel-call`, for every hand card render a `div[data-duel-card=<position>][hidden]` holding the five stat radios `name=stat value=<stat>` (disabled while hidden), each label "<stat name>" + the percentile in words + the raw value; a stat missing from `mine.stats_left` has `aria-disabled="true"` and the visible note "Déjà annoncée" in its label text. For every stat render `div[data-duel-stat=<stat>][hidden]` holding two radios `name=direction value=high|low` labelled by `duels_helper#duel_direction(stat, direction)`. The client un-hides and enables only the active set (the chosen card's stats, the chosen stat's directions) and disables the others so only chosen radios submit. A change that lands on an `aria-disabled` radio is refused by the state module and the DOM re-synced from state (arrow keys select natively).

**Reveal (server):** `DuelScreen#reveal` is present when at least one round is revealed and the last `answered_at` is within `REVEAL_WINDOW = 10` seconds before `view.server_time` (a reload or a late push still shows it; the client alone owns the 3 s). The board then renders `div#duel-reveal[data-duel-target=reveal][data-round=<n>]` visible and `div#duel-live[data-duel-target=live]` `hidden`; with no reveal only `#duel-live`. `#duel-reveal` holds `h2#duel-reveal-heading[tabindex=-1]` with the full sentence of `duels.board.reveal.*` (existing keys: "Manche 3 gagnée : Quake, 1996, contre Half-Life, 1998, la plus ancienne. 2 à 1."), the two cards side by side with, under each, the value in words (`duel_stat_words`) and raw (`duel_stat_value`), the outcome word under the pair (new keys: Won / Lost / Draw, plus "decided on the exact value"), `.duel-reveal__automatic` under the card whose move the game played, and the SUIVANTE button (`type=button`, `data-action`). The state module remembers the highest dismissed round; on a board with a reveal whose round is above it, the reveal shows (root controller hides `#duel-live`) until `endsAt = firstShown + 3000` or SUIVANTE; a later board of the same round keeps the existing `endsAt`. Focus: reveal shown -> `#duel-reveal-heading`; reveal dismissed or none -> finished: `#duel-result-heading`; my call or answer: the first radio of the hand group (checked one if any); else `#duel-round-heading`. Never steal focus on a dropped view.

**Press guard:** `GUARD_MS = 400`. `becameActive(state, now)` runs when the form's choices become complete, and on a board shown with them complete; `released(state, now)` returns whether to fire. The root controller never lets a press fire: on `keydown` Enter it `preventDefault()`s and handles `keyup` Enter as the release; for the pointer it uses the native click (a click is the release) and ignores `pointerdown`. Blocked (`aria-disabled`) buttons never fire. When it fires it calls `form.requestSubmit()`.

**Copy** (add, French first-class; keep existing keys): Your hand / Votre main, Stat / Caractéristique, Direction / Sens (`duels.board.direction`), Next / Suivante (`duels.board.next`), Won / Gagnée, Lost / Perdue, Draw / Nulle (outcome words, `duels.board.outcome.*`), spoken forms (`round_spoken` "Round %{number} of 10" / "Manche %{number} sur 10", `score_spoken` "%{score} to %{other_score}" / "%{score} à %{other_score}", margin spoken "plus %{points}" / "minus %{points}" / "%{points}" and French "plus" / "moins", `duels.clock.spoken` "%{seconds} seconds" / "%{seconds} secondes"), the friend's call status "%{name} has called. Their card: %{card}." / "%{name} a annoncé. Sa carte : %{card}.", the result's spoken summary ("Win against Hugo, 6 to 4[, decided on the margin of 12 percentile points]" / "Victoire contre Hugo, 6 à 4[, départagée à l'écart de 12 points de centile]"; Défaite contre, Égalité avec), the round sentence ("Round 3, Léa calls Oldest: Quake, 1996, against Half-Life, 1998. Won." / "Manche 3, Léa annonce la plus ancienne : Quake, 1996, contre Half-Life, 1998. Gagnée."; the direction word lower-cased in French), "Rematch" / "Rejouer", accessible name "Rematch %{name}" / "Rejouer contre %{name}", "%{name} is no longer online." / "%{name} n'est plus en ligne.", "Duel in progress" / "Duel en cours" (the key already used for a friend in a duel in `duels.challenge.in_duel` reads "In a duel": add a new key for the exact copy). Keep `duels.board.hidden_call`, `margin`, `played`, `their_deck`, `my_deck`, `calls_left`, `already_called`, `call`, `answer`, `automatic`, `decided_on_margin` as they are; the visual "MANCHE" text is the existing `round` string with `text-transform` or its uppercase.

**Remove:** the old per-seat `call` radio group of ten and the old reveal `ol` of the board (the result keeps one list of ten sentences; during play the reveal shows only the last round).

## Verification

**Commands:**
- `export DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_w43_5 RAILS_ENV=test CHROME_BIN=/usr/bin/chromium`; `bin/rails test test/controllers/duels_controller_test.rb test/controllers/duel_moves_controller_test.rb test/jobs/duel_stream_job_test.rb test/models test/policies test/channels` -- expected: pass.
- `bin/rails test test/system/duel_play_test.rb test/system/duel_challenge_test.rb test/system/duel_deadline_test.rb` -- expected: pass (only these system files).
- `npm run test:js`, `npx tsc --noEmit`, `npm run format:check`, `npm run lint:css` -- expected: exit 0.
- `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bundle exec rubocop` on touched Ruby, `bundle exec i18n-tasks health` (as CI runs it), `script/check_planning_references`, `script/check_file_sizes` -- expected: exit 0.

**Manual checks (hitl follow-ups, not blocking):**
- On a real phone: the 400 ms guard on touch, the flip and the drawn card slide, the 12-thumbnail rows at 320 CSS px, focus order with a screen reader (VoiceOver / TalkBack), against boards 4 to 7 of the mockups.

## Auto Run Result

**Summary:** The phone duel screen shows the header, both decks as rows of 12 thumbnails, the table, the hand as radio groups (Votre main, Caractéristique, Sens), the guarded ANNONCER and RÉPONDRE, Esc clearing the latest choice, the 3 s reveal with SUIVANTE and a focused outcome heading, the result with its spoken summary and ten sentences, and REJOUER through the Défier un ami sheet; no tab bar and no back.

**Verification:** duel unit, controller, helper, model and job tests, the three duel system files (6 runs), `npm run test:js` (1476), tsc, prettier, stylelint, rubocop, zeitwerk, packwerk, `i18n-tasks missing`, `check_planning_references`, `check_file_sizes` pass. Not verified: a real phone, a screen reader, the mockup boards.

**Review findings:** 5 patched, 2 deferred, 2 rejected. Follow-up review recommended: false.
