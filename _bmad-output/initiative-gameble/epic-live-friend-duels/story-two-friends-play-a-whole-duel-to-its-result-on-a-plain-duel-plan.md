---
title: 'Two friends play a whole duel to its result on a plain duel screen'
type: 'feature'
ticket: '2'
created: '2026-11-16'
status: 'built'
baseline_revision: 'f33c0fd43a0cc4fd12570480d2314b95f54cbb95'
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
  - '{project-root}/_bmad-output/initiative-gameble/epic-live-friend-duels/story-the-duel-s-rules-and-what-each-seat-may-see-as-pure-objects-plan.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The duel tables, `Game::DuelRules` and `Game::DuelView` exist, but nothing writes a duel or shows one: two friends cannot yet challenge, accept and play ten rounds.

**Approach:** A tracer through every layer, with no timer: four `Game` operations (`ChallengeFriend`, `AcceptChallenge`, `CallRound`, `AnswerRound`) behind rate-limited POSTs; challenge events reach both players' private streams (`PlayerStream`, a `duels-updated` signal that live-refreshes Duels); every duel change pushes, after commit, from a job on a new `duels` queue, each seat's own `DuelView` rendering to that seat's own stream; Duels gains a plain challenge form and the received challenge; a plain duel screen by token, one root Stimulus controller `duel` whose state module `app/frontend/lib/duel.ts` drops a pushed view not newer than the one shown.

## Boundaries & Constraints

**Always:**
- Obey `AGENTS.md`: writes only in operations (one event per transaction, inside it); jobs after commit, broadcasts only from a job; GETs never write; a Pundit policy per action; no database id in URLs, HTML, JSON, DOM ids or stream names (duel token, deck token, player token, seat `stream_key`; a card in a form is its 1-based position in the seat's own deck in the duel's fixed order); every string in `en.yml` and `fr.yml`, each new `errors.game.<code>` by hand; no planning ids; English repo text; Ruby/TS files under 400 lines (tests exempt); no `style` attribute; never name a model in a test class body.
- Lock order inside each duel move: bank locks of the seats' players in good standing in ascending id (`Game::TradeLocks.players`), then the duel row (`Duel.lock.find`), then its seats (`order(:id).lock`), then reads of decks, deck cards and holdings. `ChallengeFriend` locks both players' banks before reading any seat.
- Each move checks the state, `move_number` (an integer the form sends, compared to the locked row) and whose move it is, raises `move_number` by 1, publishes one event; a refusal writes nothing (rows and events rolled back), except `AcceptChallenge`'s lapse (I/O matrix).
- Every page and push renders through `Game::DuelView.for(duel, seat)` only; the client computes nothing of the rules.
- Forms rendered in `duels/_board` pass `authenticity_token: false` (the partial is also rendered by the job, which has no session; Turbo sends `X-CSRF-Token` from the layout's meta tag).

**Never:**
- No timer, deadline job, `move_deadline_at`, lapse by time, `CancelChallenge`, `RefuseChallenge`, `PlayAutomaticMove`, presence lease, `reachable_until`/`ReachableFriends`, bell line, badge, sheet, dialog, desktop layout or designed duel screen (later entries). No migration (the 43.1 tables hold every column).
- Do not run tests, rubocop, packwerk, zeitwerk, i18n-tasks, vitest or `bin/ci`: the suites are run by the coordinator after integration. Static checks without a database are allowed (`ruby -c`, `script/check_planning_references`, `script/check_file_sizes`, `npm run format:check`, `npm run lint:css`, `npx tsc --noEmit`).
- Run git only as `/usr/bin/git`; do not touch `develop` or `main`; never stage `package-lock.json` or `config/*.key`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Challenge | friends, both open to friends, challenger not seated, friend neither seated nor invited, complete owned deck | duel `challenged`, `move_number` 0; seat challenger `seated` with `deck_token`; seat opponent `invited`; `DuelChallengeSent` | — |
| Challenge refused | friend nil, self, not a friend or removed / own profile private / friend's private / challenger seated anywhere / friend seated or invited / deck unknown, another's, under 12 cards or a card no longer held | nothing written | `not_a_friend` / `own_duels_closed` / `friend_duels_closed` / `duel_in_progress` / `friend_busy` / `deck_not_ready` |
| Accept | the invited friend, matching `move_number`, a complete owned deck | `active`, `started_at`; both decks frozen by `DuelSnapshot` (fixed order); each draw order a `SecureRandom` permutation of its deck's ids; `first_caller` drawn with `SecureRandom`; opponent seat `seated` with its `deck_token`; `move_number` 1; `DuelChallengeAccepted` | — |
| Snapshot frozen | a deck card removed or the deck deleted after the accept | the duel's cards and every view unchanged | — |
| Accept, a deck not ready | challenger's or chosen deck no longer complete or owned | duel `lapsed`, `ended_at`, `move_number` + 1, both seats `left`, `DuelChallengeLapsed` committed | then `Failure(:deck_not_ready)` |
| Accept refused | challenger accepts / stale `move_number` / not `challenged` / acceptor seated elsewhere / friendship gone or either profile private | nothing written | `not_your_move` / `not_your_move` / `not_your_move` / `duel_in_progress` / `not_a_friend`, `own_duels_closed`, `friend_duels_closed` |
| Call | the round's caller, no locked call, card in hand, stat in its `stats_left` | round row (`number` = `rules.round`, caller role, card, stat, direction, `caller_value` from the snapshot, `called_at`); `move_number` + 1; `DuelRoundCalled` | — |
| Answer | the answerer, a locked call, card in hand | round completed (answer card and value, `answered_at`, `winner` role or nil and `decided_on_value` from `DuelRules.outcome`); duel scores and margins from `DuelRules`; `move_number` + 1; `DuelRoundAnswered` | — |
| Round 10 answered | the last answer | also `finished`, `result`, `ended_at`, both seats `left`; `DuelFinished` in place of `DuelRoundAnswered` | — |
| Move refused | out of turn, a call already locked, stale `move_number`, duel not `active` / position not in hand or outside 1–12 / stat called in a revealed round / stat, direction, card or move number unreadable / player holds no seat | nothing written | `not_your_move` / `card_not_in_hand` / `stat_already_called` / `invalid_move` / `duel_not_found` |
| Push | any committed duel event | one `DuelStreamJob` (`duels` queue) per transaction; each seat with a player gets, per locale, its own board on `["duel-seat", stream_key, locale]` | — |
| Seat channel | a signed seat stream name | streamed only to that seat's player | rejected otherwise |
| Duel page | a viewer holding no seat / a visitor | 403 / sign-in redirect | — |

</intent-contract>

## Code Map

- `app/domains/game/app/models/game/duel.rb`, `duel_seat.rb`, `duel_round.rb`, `duel_rules.rb`, `duel_view.rb`, `duel_card.rb`, `queries/game/duel_snapshot.rb` -- 43.1 objects; read their plan's Design Notes. `DuelRules.new(duel, rounds)` sorts the same row objects: read `caller`/`answerer` before updating the pending row, then build a new `DuelRules` for scores, margins, `finished?`, `result`. `rules.deck(role)[position - 1]` is the card at a position; `DuelCard` compares by value.
- `app/domains/game/app/operations/game/operation.rb` -- `Game::Operation` (`call` must take `player:`), `require_player`, `stream_name`; `lib/application_operation.rb` -- `failure_message`; `step Failure(:code)` after a committed `transaction` returns that failure.
- `app/domains/game/app/operations/game/trade_steps.rb` (`friends`), `propose_trade.rb` -- precedent for friendship/`open_to_friends?` checks and an operation's shape; `models/game/trade_locks.rb` -- `TradeLocks.players(*ids)`; `models/game/visibility.rb`; `queries/game/friendship_between.rb`, `friends_of.rb`; `operations/game/deck_steps.rb` -- deck lookup by player and token.
- `app/domains/game/app/events/game/trade_proposed.rb` -- event class shape; `config/initializers/event_store.rb` -- subscriptions (add `DuelStream`; `PlayerStream` already subscribed to `PlayerStream::EVENTS`).
- `app/models/player_stream.rb` + `app/jobs/player_stream_job.rb` -- notices `{ player_id:, topic: }`; a topic `duels` becomes the `duels-updated` signal with no other change to the job.
- `app/models/listing_stream.rb`, `app/jobs/listing_stream_job.rb`, `lib/after_commit_batch.rb` -- precedent for `DuelStream` and its job; `app/channels/player_stream_channel.rb` + `test/channels/player_stream_channel_test.rb` -- precedent for `DuelSeatChannel` and its test.
- `config/queue.yml` -- add a `duels` worker; `test/config/queue_config_test.rb`.
- `app/controllers/duels_controller.rb`, `app/policies/duel_policy.rb`, `app/views/duels/show.html.erb`, `_decks.html.erb`, `app/models/deck_list.rb` (`rows`, `Row#complete?`), `app/controllers/trades_controller.rb` (`throttle_player`, refusals as flash `alert`), `app/controllers/concerns/trade_proposals.rb` (`Accounts::PlayerByToken`).
- `app/components/player_name_component.rb` (`linked: false`; the one component naming a player), `app/helpers/duel_profile_helper.rb` (`duel_stat_value` takes a `Game::DuelProfiles::Stat`), `config/locales/en.yml` `duel_stats.names/directions/no_value` (reuse).
- `app/frontend/lib/stream_actions.ts` (+ `.test.ts`), `lib/events.ts`, `controllers/live_refresh_controller.ts`, `controllers/goal_control_controller.ts` (`turbo:before-stream-render` listener), `app/frontend/styles/duels.css`, `entrypoints/application.css`.
- Tests to follow: `test/domains/game/deck_operations_test.rb`, `test/support/decks.rb` (`ranked_cards(player, 12, titles:)`), `test/support/duels.rb`, `test/support/game_packs.rb` (`game_events`), `test/controllers/duels_controller_test.rb`, `test/jobs/player_stream_job_test.rb`, `test/models/player_stream_test.rb`, `test/models/listing_stream_test.rb`, `test/system/live_updates_test.rb` (two sessions, `perform_enqueued_jobs`), `test/policies/duel_policy_test.rb`.

## Tasks & Acceptance

**Execution:**
- [x] `app/domains/game/app/events/game/duel_challenge_sent.rb`, `duel_challenge_accepted.rb`, `duel_challenge_lapsed.rb`, `duel_round_called.rb`, `duel_round_answered.rb`, `duel_finished.rb` -- the six events (Design Notes).
- [x] `app/domains/game/app/operations/game/duel_steps.rb`, `challenge_friend.rb`, `accept_challenge.rb`, `call_round.rb`, `answer_round.rb` -- the operations per the matrix and Design Notes.
- [x] `app/domains/game/app/models/game/duel.rb` -- `seat_of(player)` from loaded seats.
- [x] `app/domains/game/app/queries/game/duel_by_token.rb`, `duels_by_id.rb`, `held_seats.rb`, `duel_seat_holder.rb` -- reads for the web layer (Design Notes).
- [x] `app/models/player_stream.rb` -- `DUEL_EVENTS` (sent, accepted, lapsed) tell both players, topic `duels`.
- [x] `app/models/duel_stream.rb`, `app/jobs/duel_stream_job.rb`, `config/initializers/event_store.rb`, `config/queue.yml` -- the seat pushes on the `duels` queue.
- [x] `app/channels/duel_seat_channel.rb` -- `Turbo::StreamsChannel` subclass accepting a verified name only for the seat's player.
- [x] `app/policies/duel_policy.rb`, `app/controllers/duels_controller.rb` (`play`), `app/controllers/duel_moves_controller.rb`, `config/routes.rb` -- routes and actions (Design Notes).
- [x] `app/models/duel_lobby.rb`, `app/models/duel_screen.rb`, `app/helpers/duels_helper.rb` -- presenters and formatting for the views.
- [x] `app/views/duels/show.html.erb`, `_lobby.html.erb`, `play.html.erb`, `_board.html.erb` (+ small partials as needed) -- Duels' challenge block and the duel screen.
- [x] `app/frontend/lib/duel.ts`, `app/frontend/controllers/duel_controller.ts`, `app/frontend/lib/stream_actions.ts`, `app/frontend/lib/events.ts` -- the root controller and its state module; `duels-updated` signal.
- [x] `app/frontend/styles/duel.css`, `app/frontend/entrypoints/application.css` -- plain layout from tokens only.
- [x] `config/locales/en.yml`, `config/locales/fr.yml` -- copy (Design Notes), French with `zero` forms for any plural.
- [x] `test/support/live_duels.rb` -- DB builders: `befriend(a, b)`, `complete_deck(player, prefix)` (`ranked_cards(player, 12, titles: "#{prefix} card A".."L")`, a deck named `"#{prefix} deck"` with 12 `DeckCard`s), `start_duel(challenger, opponent)` (challenge + accept through the operations), `play_round(duel)` (automatic call and answer through `CallRound`/`AnswerRound` with positions from `DuelRules`).
- [x] `test/domains/game/duel_challenge_operations_test.rb`, `test/domains/game/duel_round_operations_test.rb` -- every matrix row of the operations, each refusal writing nothing (rows + events), the frozen snapshot, `DuelFinished` once in place of round 10's `DuelRoundAnswered` (9 answered events), stored scores/margins/result equal to `DuelRules`.
- [x] `test/channels/duel_seat_channel_test.rb`, `test/jobs/duel_stream_job_test.rb`, `test/models/duel_stream_test.rb`, `test/models/player_stream_test.rb`, `test/policies/duel_policy_test.rb`, `test/controllers/duels_controller_test.rb`, `test/controllers/duel_moves_controller_test.rb`, `test/config/queue_config_test.rb` -- channel refusing another player and a visitor; each seat's push holds only its own hand (hand titles in `#duel-hand`, the caller's direction words absent from the answerer's push), one push per seat and locale and none elsewhere, `queue_name == "duels"`; job enqueued once after commit; duel notices; policy per action; duel page 403 for a non-seat viewer and its board for a seat; POSTs redirect with the refusal as `alert`; the `duels` worker.
- [x] `test/system/duel_play_test.rb` -- the two-session test (Acceptance Criteria).
- [x] `app/frontend/lib/duel.test.ts`, `app/frontend/lib/stream_actions.test.ts` -- the drop rule; the new signal.

**Acceptance Criteria:**
- Given Léa and Hugo friends with a complete deck each, when Léa challenges Hugo from Duels, Hugo (his Duels page live-refreshed) accepts with his deck, Léa's Duels page live-refreshes and she resumes, and both play the ten rounds in turn (caller per `DuelRules.caller`, each move's board reaching the other session by push after `perform_enqueued_jobs(only: [ PlayerStreamJob, DuelStreamJob ])`, `#duel-board[data-move-number]` reaching `2n` after round n's call and `2n + 1` after its answer), then both pages show the same final result and score from their own side, and at every step neither `#duel-hand` holds a card of the other seat's hand and the answerer's page never shows the locked call's direction.
- Given a seat's page showing move n, when a push of move m ≤ n arrives, then the board is not replaced.

## Implementation Notes

- Copy keys beyond the plan: `duels.lobby.friend` (the friend fieldset's legend), `duels.lobby.in_progress_html` (the seated-and-active line above RESUME) and `duels.board.ended` (the board of a lapsed challenge). The received challenge without a complete deck reuses the `deck_not_ready` refusal text.
- `complete_deck` sets each holding's `reserved` to 1, as adding cards through the editor would, so `DeleteDeck` can release them in the frozen-snapshot test.
- The system test checks the drop rule live: after each call the mover's board carries a `data-kept` mark that the push of the same move must not remove.
- Written but not run (the suites run after integration): only `ruby -c`, ERB compilation, `tsc`, prettier, stylelint, `check_planning_references` and `check_file_sizes` were run.

## Plan Change Log

## Review Triage Log

### 2026-11-16 — Review pass
- verdicts: 4 findings — high 0, medium 2, low 2, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` the duel controller advanced its move number only when the board connected, after Turbo's repaint wait, so two out-of-order pushes both newer than the screen could render newest-then-oldest — `streamed` now records the move number at the moment it accepts a view.
  - `[medium]` `[patch]` `ChallengeFriend` refused a challenger only when seated, so a player holding a received challenge could challenge another friend and strand the first duel behind `duel_in_progress` — a challenger now counts as idle only with no seated or invited seat (`idle`); the challenge test covers an invited challenger.
  - `[low]` `[patch]` `DuelScreen` read `Game::DuelSteps::DIRECTIONS`, a private operation mixin — the directions moved to `Game::DuelStat::DIRECTIONS`, read by the steps and the screen.
  - `[low]` `[reject]` an unreadable `deck` param on accept lapses the challenge — the matrix's lapse row says a deck no longer complete or owned lapses it, and an unknown token cannot be told apart; a form always sends one of the player's own tokens.

## Design Notes

**Events** (`< RubyEventStore::Event`, identifiers only, published on `stream_name(player.id)` of the acting player): `DuelChallengeSent`, `DuelChallengeAccepted`, `DuelChallengeLapsed`, `DuelFinished` carry `{ duel_id:, challenger_id:, opponent_id: }`; `DuelRoundCalled`, `DuelRoundAnswered` carry `{ duel_id:, number: }`.

**`Game::DuelSteps`** (private helpers, included in the four operations): find the duel by token among the player's seats (`Failure(:duel_not_found)`); parse move number and position as integers (`Failure(:invalid_move)`), stat in `DuelStat::STATS`, direction `high`/`low` (`Failure(:invalid_move)`); lock as the Always rule says, returning `[duel, seats_by_role]`; `friends_to_duel(player, other)` (as `TradeSteps#friends`, codes `not_a_friend`, `own_duels_closed`, `friend_duels_closed`); `ready_deck(player_id, token)` (the player's deck, 12 `DeckCard`s, each with a holding of quantity > 0, else `Failure(:deck_not_ready)`); `seated?(player_id)`/`busy?` through `DuelSeat` statuses; `leave(seats)`.

```ruby
transaction do # ChallengeFriend, after require_player and a persisted friend other than the player (else :not_a_friend)
  TradeLocks.players(player.id, friend.id)
  step friends_to_duel(player, friend)
  step not_seated(player)           # :duel_in_progress
  step free(friend)                 # seated or invited -> :friend_busy
  step ready_deck(player.id, deck_token)
  duel = Duel.create!
  # seats: challenger seated with deck_token; opponent invited; publish DuelChallengeSent; return duel
end
```

`AcceptChallenge` returns the duel; on a deck not ready its transaction marks the lapse and returns a flag, then `step Failure(:deck_not_ready)` outside it. Draws: `cards.map(&:card_season_id).shuffle(random: SecureRandom)`, `DuelRules::ROLES.sample(random: SecureRandom)`.

**Queries:** `DuelByToken.call(token)` → `Duel.includes(:seats)` or nil (String only); `DuelsById.call(ids)` → duels with seats and rounds; `HeldSeats.call(player)` → `Data(seated:, invited:)`, each a seat with its duel and the duel's seats, or nil; `DuelSeatHolder.call(stream_key)` → the seat's `player_id` or nil.

**Streams:** `DuelStream.streamables(stream_key, locale = I18n.locale) = [ "duel-seat", stream_key, locale.to_s ]`, `EVENTS` = accepted, called, answered, finished; `call(event)` adds `event.data[:duel_id]` to an `AfterCommitBatch` that enqueues `DuelStreamJob.perform_later(duel_ids.uniq)`. The job (`queue_as :duels`), for each seat with a player and each locale, `I18n.with_locale` and `Turbo::StreamsChannel.broadcast_replace_to(*DuelStream.streamables(seat.stream_key, locale), target: "duel-board", partial: "duels/board", locals: { screen: DuelScreen.new(duel, seat, locale:) })`. `DuelSeatChannel#subscribed` streams the verified name only when it equals `DuelStream.streamables(key, locale).join(":")` for a locale in `I18n.available_locales` and `DuelSeatHolder.call(key) == current_player.id`. `config/queue.yml`: `- queues: [ duels ]`, `threads: 3`, `processes: 1`, `polling_interval: 0.1`.

**Routes** (under the locale scope, after the deck routes, token constraint `/[1-9A-HJ-NP-Za-km-z]{24}/`): `post "duels/challenges" => "duel_moves#challenge", as: :duel_challenges`; `get "duels/:token" => "duels#play", as: :duel`; `post "duels/:token/acceptance" => "duel_moves#accept", as: :duel_acceptance`; `post "duels/:token/calls" => "duel_moves#announce", as: :duel_calls`; `post "duels/:token/answers" => "duel_moves#answer", as: :duel_answers`. `DuelPolicy`: `show?`, `challenge?` = player; `play?`, `accept?`, `announce?`, `answer?` = the record is a `Game::Duel` one of whose seats has the player. Actions authorize `Game::DuelByToken.call(params[:token]) || :duel` with `policy_class: DuelPolicy`. `DuelMovesController`: `throttle_player to: 60` on its four actions (alert `duels.throttled`, path `duels_path`); challenge (`friend` = player token, `deck` = deck token) and accept redirect to Duels with a refusal's message as `alert`, a successful accept to the duel; `announce` (`card` position, `call` = `"<stat>-<direction>"`, `move_number`) and `answer` (`card`, `move_number`) redirect to the duel, a refusal as `alert`.

**Duels screen** (`DuelLobby`, `duels/_lobby` above MY DECKS, the section gaining `live-refresh` on `duels-updated`): a received challenge (`<name> challenges you to a duel.`, the complete decks as radios, hidden `move_number`, ACCEPT; no complete deck → the deck reason); then a seated challenge (`Waiting for <name>'s answer…`), a seated active duel (`Duel in progress against <name>.` and a RESUME link to it), or the form (complete decks and friends open to friends as radios, CHALLENGE); own profile private, no complete deck, no friend each replace the form with their line.

**Duel screen** (`play.html.erb`: `turbo_exempts_page_from_cache`, phone back to Duels, `turbo_stream_from(*DuelStream.streamables(@screen.stream_key), channel: DuelSeatChannel)`, root `section.duel.page.page--regular[data-controller=duel]` with a hidden h1, then `duels/_board`): `div#duel-board[data-duel-target=board][data-move-number]` holding the opponent's name (`PlayerNameComponent`, `linked: false`; anonymous when the seat has no player), round `n / 10`, score from the player's side and `margin ±n`, the turn line, their deck `#duel-their-deck` (12 titles, played ones marked Played) with their calls left, the locked call's card with its five raw values (Hidden call for the answerer, the call's direction words for the caller), your deck `#duel-my-deck`, `#duel-hand` (radios inside `form#duel-call` with a 10-option call group named by `duel_stats.directions`, a stat not in `stats_left` disabled with Already called; or radios inside `form#duel-answer`; else a list), the played rounds as an ordered list each one reveal sentence (automatic marks when set); finished: the result line, `Decided on margin: <n> percentile points` when equal scores did not draw, and the ten rounds. An unstarted duel shows waiting or ended.

**Client:** `lib/duel.ts` exports `startDuel(moveNumber)`, `acceptsView(state, moveNumber)` (strictly newer), `viewShown(state, moveNumber)`, `moveNumberFrom(text)` (non-negative integer or null). `duel_controller.ts` keeps the state, updates it in `boardTargetConnected`, and on `turbo:before-stream-render` whose stream targets the board reads the template's first element `data-move-number` and calls `event.preventDefault()` unless accepted.

**Copy** (en / fr): errors.game `friend_busy` "This friend is already in a duel or has a challenge waiting." / "Cet ami est déjà en duel ou a déjà un défi en attente."; `deck_not_ready` "A draft cannot play: it needs 12 cards." / "Un brouillon ne peut pas jouer : il lui faut 12 cartes."; `not_your_move` "This move is no longer yours to play." / "Ce coup ne vous revient plus."; `stat_already_called` "You have already called this stat." / "Vous avez déjà annoncé cette caractéristique."; `card_not_in_hand` "This card is not in your hand." / "Cette carte n'est pas dans votre main."; `duel_in_progress` "You already have a duel in progress." / "Vous avez déjà un duel en cours."; `own_duels_closed` "Your duels are closed while your profile is private." / "Vos duels sont fermés tant que votre profil est privé."; `friend_duels_closed` "Duels closed while this profile is private." / "Duels fermés tant que ce profil est privé."; `duel_not_found` "That duel could not be found." / "Ce duel est introuvable."; `invalid_move` "That move could not be read. Reload the page." / "Ce coup n'a pas pu être lu. Rechargez la page.". Screen copy from the copy deck: Challenge a friend / Défier un ami, Challenge / Défier, Accept / Accepter, Resume / Reprendre, `%{name} challenges you to a duel.` / `%{name} vous défie en duel.`, `Waiting for %{name}'s answer…` / `En attente de la réponse de %{name}…`, You need a complete 12-card deck to challenge. / Il vous faut un deck complet de 12 cartes pour défier., Add friends to challenge them. / Ajoutez des amis pour les défier., Round / Manche `%{number} / 10`, margin / écart, Your call / À vous d'annoncer, Your answer / À vous de répondre, `%{name} is calling…` / `%{name} annonce…`, `%{name} is answering…` / `%{name} répond…`, Call / Annoncer, Answer with this card / Répondre avec cette carte, Hidden call / Annonce cachée, Their deck / Son deck, Your deck / Votre deck, Played / Joué, Your hand / Votre main, Stat / Caractéristique, Already called / Déjà annoncée, `Calls left: %{stats}` / `Annonces restantes : %{stats}`, reveal `Round %{number} won: %{card}, %{value}, against %{other_card}, %{other_value}, %{direction}. %{score} to %{other_score}.` / `Manche %{number} gagnée : …, contre …, … %{score} à %{other_score}.` (lost / perdue, drawn / nulle), decided on the exact value / départagée à la valeur exacte, Move played automatically / Coup joué automatiquement, `Win against %{name} · %{score} – %{other_score}` / `Victoire contre …` (Loss against / Défaite contre, Draw with / Égalité avec), `Decided on margin: %{margin} percentile points` / `Départagé à l'écart : %{margin} points de centile`. Keys holding a name rendered by the component end in `_html`.

## Verification

**Commands:**
- `ruby -c` on each new or changed Ruby file -- expected: Syntax OK.
- `ruby -ryaml -e 'YAML.load_file("config/locales/en.yml"); YAML.load_file("config/locales/fr.yml"); YAML.load_file("config/queue.yml")'` -- expected: no error.
- `script/check_planning_references` and `script/check_file_sizes` -- expected: exit 0.
- `npx tsc --noEmit`, `npm run format:check`, `npm run lint:css` -- expected: exit 0.
- Test suites: run by the coordinator after integration.

**Manual checks (if no CLI):**
- No `id`, `card_season_id` or draw order reaches a template, a form value, a DOM id or a stream name.

## Auto Run Result

**Summary:** Two friends can challenge, accept and play ten rounds to a result. Four operations (`ChallengeFriend`, `AcceptChallenge`, `CallRound`, `AnswerRound`) lock the seated players' banks, the duel row, then its seats, check state, `move_number` and turn, and publish one event each; round 10's answer publishes `DuelFinished` instead of `DuelRoundAnswered`. Challenge events reach both private streams as a `duels-updated` signal; every duel event enqueues after commit one `DuelStreamJob` on the new `duels` queue that renders each seat's own `DuelView` board to that seat's own stream (`["duel-seat", stream_key, locale]`), carried by `DuelSeatChannel`. Duels gains a challenge form and the received challenge; the duel screen is at `/:locale/duels/:token` under a seat-only policy, with `duel` root controller and `lib/duel.ts` dropping a board not newer than the one shown.

**Files changed:** events, operations and queries under `app/domains/game`; `DuelStream`, `DuelStreamJob`, `DuelSeatChannel`, `DuelMovesController`, `DuelLobby`, `DuelScreen`, `DuelsHelper`, duel views, `duel.css`, `duel.ts`, `duel_controller.ts`, locales, routes, queue config, and the tests listed in the plan.

**Review findings:** 3 patched (2 medium, 1 low), 0 deferred, 1 rejected (see the triage log).

**Follow-up review recommended:** false (first pass; patched: high 0, medium 2, low 1 — the two mediums were a client ordering race and a stranded challenge, both fixed at the cause).

**Verification:** `ruby -c` on changed Ruby files, YAML loads, `script/check_planning_references`, `script/check_file_sizes`, `npx tsc --noEmit`, `npm run format:check`, `npm run lint:css` pass. Test suites: suites run by the coordinator after integration.

**Residual risks:** nothing ran under Rails. The two-session system test relies on jobs enqueued by the server thread landing in the class-level test adapter. A challenged player cannot yet cancel or refuse (later entries), so a challenge stays open until accepted.
