require "test_helper"
require_relative "../../support/game_packs"
require_relative "../../support/live_duels"

# Calling and answering a duel's rounds: each move by the right seat, at the move number shown, with a card of its hand;
# the call locks a round, the answer settles it as the rules decide, and the tenth answer finishes the duel. A refused
# move writes nothing.
class Game::DuelRoundOperationsTest < ActiveSupport::TestCase
  include GamePacks
  include LiveDuels

  setup do
    @lea = accounts_players(:player)
    @hugo = accounts_players(:moderator)
    befriend(@lea, @hugo)
    complete_deck(@lea, "Lea")
    complete_deck(@hugo, "Hugo")
    @duel = start_duel(@lea, @hugo)
  end

  def current = Game::Duel.find(@duel.id)

  def call(player, card:, stat:, direction: "high", move_number: current.move_number)
    Game::CallRound.new.call(player:, token: @duel.token, move_number:, card:, stat:, direction:)
  end

  def answer(player, card:, move_number: current.move_number)
    Game::AnswerRound.new.call(player:, token: @duel.token, move_number:, card:)
  end

  def hand_position(rules, role) = position_of(rules, role, rules.hand(role).first)

  def outside_position(rules, role) = rules.deck(role).index { !rules.hand(role).include?(it) } + 1

  def events(type) = Rails.configuration.event_store.read.of_type([ type ]).to_a

  def written
    [ Game::Duel.find(@duel.id).attributes, Game::DuelRound.where(duel_id: @duel.id).order(:id).map(&:attributes),
      Game::DuelSeat.where(duel_id: @duel.id).order(:id).map(&:attributes), Rails.configuration.event_store.read.count ]
  end

  def assert_refused(code, &operation)
    before = written
    assert_equal code, operation.call.failure
    assert_equal before, written
  end

  test "a call locks the round with the caller's card, its value on the stat, and writes one event" do
    rules = rules_of(current)
    caller = seat_player(current, rules.caller)
    card = rules.hand(rules.caller).first

    call(caller, card: position_of(rules, rules.caller, card), stat: "rating", direction: "low").value!

    round = current.rounds.sole
    assert_equal [ 1, rules.caller.to_s, card.card_season_id, "rating", "low" ],
      [ round.number, round.caller, round.caller_card_season_id, round.stat, round.direction ]
    assert_equal [ card.to_snapshot.dig("stats", "rating", "value") ], [ round.caller_value ]
    assert round.called_at
    assert_nil round.answered_at
    assert_equal 2, current.move_number
    assert_equal [ { duel_id: @duel.id, number: 1 } ], game_events(caller, Game::DuelRoundCalled).map(&:data)
  end

  test "an answer settles the round as the rules decide, and the duel's scores and margins with it" do
    call_round(@duel)
    rules = rules_of(current)
    answerer = seat_player(current, rules.answerer)
    card = rules.hand(rules.answerer).last
    pending = rules.pending
    outcome = Game::DuelRules.outcome(rules.card(rules.caller, pending.caller_card_season_id), card, pending.stat.to_sym,
      pending.direction.to_sym)

    answer(answerer, card: position_of(rules, rules.answerer, card)).value!

    duel = current
    round = duel.rounds.sole
    assert_equal card.card_season_id, round.answer_card_season_id
    assert_equal [ card.to_snapshot.dig("stats", round.stat, "value") ], [ round.answer_value ]
    assert round.answered_at
    assert_equal [ { caller: rules.caller, answerer: rules.answerer }[outcome.winner]&.to_s, outcome.decided_on_value ],
      [ round.winner, round.decided_on_value ]
    settled = rules_of(duel)
    assert_equal settled.scores, { challenger: duel.challenger_score, opponent: duel.opponent_score }
    assert_equal settled.margins, { challenger: duel.challenger_margin, opponent: duel.opponent_margin }
    assert_equal [ 3, "active" ], [ duel.move_number, duel.state ]
    assert_equal [ { duel_id: @duel.id, number: 1 } ], game_events(answerer, Game::DuelRoundAnswered).map(&:data)
  end

  test "the tenth answer finishes the duel with the rules' result, and its event replaces the round's" do
    10.times { play_round(@duel) }

    duel = current
    rules = rules_of(duel)
    assert rules.finished?
    assert_equal [ "finished", rules.result.to_s, 21 ], [ duel.state, duel.result, duel.move_number ]
    assert duel.ended_at
    assert_equal rules.scores, { challenger: duel.challenger_score, opponent: duel.opponent_score }
    assert_equal rules.margins, { challenger: duel.challenger_margin, opponent: duel.opponent_margin }
    assert_equal rules.played_rounds.map { it.winner&.to_s }, duel.rounds.map(&:winner)
    assert_equal rules.played_rounds.map(&:decided_on_value), duel.rounds.map(&:decided_on_value)
    assert_equal %w[left left], Game::DuelSeat.where(duel_id: duel.id).pluck(:status)
    assert_equal 10, events(Game::DuelRoundCalled).size
    assert_equal (1..9).to_a, events(Game::DuelRoundAnswered).map { it.data[:number] }.sort
    assert_equal [ { duel_id: duel.id, challenger_id: @lea.id, opponent_id: @hugo.id } ], events(Game::DuelFinished).map(&:data)
  end

  test "a move out of turn, at a stale move number or once the duel is over is refused and writes nothing" do
    rules = rules_of(current)
    caller = seat_player(current, rules.caller)
    answerer = seat_player(current, rules.answerer)

    assert_refused(:not_your_move) { call(answerer, card: hand_position(rules, rules.answerer), stat: "rating") }
    assert_refused(:not_your_move) { answer(answerer, card: hand_position(rules, rules.answerer)) }
    assert_refused(:not_your_move) { call(caller, card: hand_position(rules, rules.caller), stat: "rating", move_number: 0) }

    call(caller, card: hand_position(rules, rules.caller), stat: "rating").value!
    locked = rules_of(current)
    assert_refused(:not_your_move) { call(caller, card: hand_position(locked, locked.caller), stat: "release") }
    assert_refused(:not_your_move) { answer(caller, card: hand_position(locked, locked.caller)) }
    assert_refused(:not_your_move) { answer(answerer, card: hand_position(locked, locked.answerer), move_number: 1) }

    answer_round(current)
    9.times { play_round(@duel) }
    assert_refused(:not_your_move) { call(caller, card: 1, stat: "rating") }
  end

  test "a card outside the hand or the deck is refused" do
    rules = rules_of(current)
    caller = seat_player(current, rules.caller)

    [ outside_position(rules, rules.caller), 0, 13, -1 ].each do |card|
      assert_refused(:card_not_in_hand) { call(caller, card:, stat: "rating") }
    end

    call_round(@duel)
    locked = rules_of(current)
    answerer = seat_player(current, locked.answerer)
    assert_refused(:card_not_in_hand) { answer(answerer, card: outside_position(locked, locked.answerer)) }
  end

  test "a stat the caller called in a revealed round is refused" do
    rules = rules_of(current)
    caller = seat_player(current, rules.caller)
    call(caller, card: hand_position(rules, rules.caller), stat: "discovery").value!
    answer_round(current)
    play_round(@duel)

    third = rules_of(current)
    assert_equal rules.caller, third.caller
    assert_refused(:stat_already_called) { call(caller, card: hand_position(third, third.caller), stat: "discovery") }
  end

  test "an unreadable move is refused, and a player holding no seat finds no duel" do
    rules = rules_of(current)
    caller = seat_player(current, rules.caller)
    position = hand_position(rules, rules.caller)

    assert_refused(:invalid_move) { call(caller, card: position, stat: "luck") }
    assert_refused(:invalid_move) { call(caller, card: position, stat: "rating", direction: "sideways") }
    assert_refused(:invalid_move) { call(caller, card: "first", stat: "rating") }
    assert_refused(:invalid_move) { call(caller, card: position, stat: "rating", move_number: nil) }
    assert_refused(:invalid_move) { answer(caller, card: { "1" => "2" }) }
    assert_refused(:duel_not_found) { call(accounts_players(:administrator), card: position, stat: "rating") }
    assert_refused(:duel_not_found) { Game::CallRound.new.call(player: caller, token: 7, move_number: 1, card: position, stat: "rating", direction: "high") }
  end
end
