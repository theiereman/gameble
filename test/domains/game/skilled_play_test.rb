require "test_helper"
require_relative "../../support/duels"

# The practice bot's play, read from its own seat's view alone: it beats the automatic move most of the time, and
# what the other seat hides (its hand, its draw order, the stat of a locked call) never changes its move.
class Game::SkilledPlayTest < ActiveSupport::TestCase
  include Duels

  SEED = 20_261_120

  def rules(duel) = Game::DuelRules.new(duel, duel.rounds.to_a)

  def skilled(duel) = Game::SkilledPlay.new(Game::DuelView.for(duel, duel.seats.find { it.role == "opponent" }))

  def seated(duel)
    Game::DuelRules::ROLES.each { duel.seats.build(role: it.to_s, status: "seated") }
    duel
  end

  def random_deck(first_id, random)
    Array.new(12) do |index|
      duel_card(first_id + index, number: index + 1, **Game::DuelStat::STATS.index_with { random.rand(0..100) })
    end
  end

  def play_out(duel)
    Game::DuelRules::ROUNDS.times do
      bot_calls = rules(duel).caller == :opponent
      call = bot_calls ? skilled(duel).call_move : rules(duel).automatic_call
      lock_call(duel, call.card.card_season_id, call.stat, call.direction)
      answer = bot_calls ? rules(duel).automatic_answer : skilled(duel).answer_card
      answer_call(duel, answer.card_season_id)
    end
    rules(duel).result
  end

  test "the bot beats the automatic move in at least three duels out of five" do
    random = Random.new(SEED)
    duels = Array.new(300) do |index|
      seated(active_duel(challenger: random_deck(1001, random), opponent: random_deck(2001, random),
        first_caller: index.even? ? "challenger" : "opponent"))
    end

    results = assert_no_queries { duels.map { play_out(it) } }

    assert_operator results.count(:opponent), :>=, 180
  end

  test "the bot's call ignores the other seat's draw order" do
    shown = seated(active_duel(first_caller: "opponent"))
    other = seated(active_duel(first_caller: "opponent"))
    other.challenger_draw_order = shown.challenger_draw_order.reverse

    assert_not_equal ids(rules(shown).hand(:challenger)), ids(rules(other).hand(:challenger))
    assert_equal skilled(shown).call_move, skilled(other).call_move
  end

  test "the bot's answer ignores the other seat's draw order and the stat it locked" do
    shown = seated(active_duel)
    other = seated(active_duel)
    other.challenger_draw_order = [ 1012, *(1001..1011) ]
    lock_call(shown, 1012, :popularity, :high)
    lock_call(other, 1012, :rating, :low)

    assert_not_equal ids(rules(shown).hand(:challenger)), ids(rules(other).hand(:challenger))
    assert_equal skilled(shown).answer_card, skilled(other).answer_card
  end
end
