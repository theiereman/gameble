require "test_helper"
require_relative "../../support/live_duels"

# The bell's duel lines: a duel in progress waits on its player's return, a duel finished in the last 7 days is a result.
class Game::BellDuelLinesTest < ActiveSupport::TestCase
  include LiveDuels

  setup do
    @lea = accounts_players(:player)
    @hugo = accounts_players(:moderator)
    @hugo.update!(persona_name: "Hugo")
    befriend(@lea, @hugo)
    complete_deck(@lea, "Lea")
    complete_deck(@hugo, "Hugo")
    @duel = start_duel(@lea, @hugo)
  end

  def duels(player, now: Time.current) = Game::BellItems.call(player, now:).duels

  def finish(duel) = 10.times.reduce(duel) { |played, _| play_round(played) }

  test "a duel in progress is one resume line for each player, naming the other" do
    [ [ @lea, @hugo ], [ @hugo, @lea ] ].each do |player, other|
      line = duels(player).sole

      assert_equal [ @duel.token, :resume, other.id ], [ line.token, line.kind, line.opponent.id ]
    end
  end

  test "a challenge not yet accepted is no line" do
    other = accounts_players(:administrator)
    befriend(@lea, other)
    Game::DuelSeat.where(duel_id: @duel.id).update_all(status: "left")
    Game::Duel.where(id: @duel.id).update_all(state: "lapsed", ended_at: Time.current, started_at: nil, first_caller: nil, challenger_cards: nil,
      opponent_cards: nil, challenger_draw_order: nil, opponent_draw_order: nil)

    assert_empty duels(@lea)
  end

  test "a duel finished within 7 days is a result line from each player's side, and none after" do
    finished = finish(@duel)
    now = Time.current

    mine = duels(@lea, now:).sole
    theirs = duels(@hugo, now:).sole

    assert_equal [ :finished, finished.token ], [ mine.kind, mine.token ]
    assert_equal [ finished.challenger_score, finished.opponent_score ], [ mine.score, mine.other_score ]
    assert_equal [ finished.opponent_score, finished.challenger_score ], [ theirs.score, theirs.other_score ]
    assert_equal [ @hugo.id, @lea.id ], [ mine.opponent.id, theirs.opponent.id ]
    assert_empty duels(@lea, now: finished.ended_at + 8.days)
    assert_equal 1, duels(@lea, now: finished.ended_at + 6.days).size
  end

  test "each seat reads the result from its own side: win, loss and draw" do
    finished = finish(@duel)

    { "challenger" => [ :win, :loss ], "opponent" => [ :loss, :win ], "draw" => [ :draw, :draw ] }.each do |result, (mine, theirs)|
      Game::Duel.where(id: finished.id).update_all(result:)

      assert_equal [ mine, theirs ], [ duels(@lea).sole.outcome, duels(@hugo).sole.outcome ], result
    end
  end

  test "an opponent who left the game is named by no one" do
    finished = finish(@duel)
    Game::DuelSeat.where(duel_id: finished.id, role: "opponent").update_all(player_id: nil)

    assert_nil duels(@lea).sole.opponent
  end
end
