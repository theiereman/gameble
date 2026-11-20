require "test_helper"
require_relative "../../support/duels"

# A player's wins, losses and draws, and their last ten results, read from finished duels and the player's own seat.
class Game::DuelRecordTest < ActiveSupport::TestCase
  include Duels

  setup do
    @lea = accounts_players(:player)
    @hugo = accounts_players(:moderator)
    @third = accounts_players(:administrator)
  end

  def finished_duel(challenger: @lea, opponent: @hugo, result: "challenger", scores: [ 6, 4 ], ended_at: Time.current,
    rules_version: Game::DuelRules::VERSION)
    duel = active_duel
    duel.assign_attributes(state: "finished", result:, ended_at:, challenger_score: scores.first, opponent_score: scores.last,
      rules_version:)
    duel.save!
    { "challenger" => challenger, "opponent" => opponent }.each do |role, player|
      Game::DuelSeat.create!(duel:, role:, player_id: player&.id, status: "left")
    end
    duel
  end

  def detail(result) = result.to_h.values_at(:outcome, :score, :other_score, :opponent_id)

  test "wins, losses and draws are counted from the player's own seat, in one query" do
    finished_duel(result: "challenger")
    finished_duel(result: "opponent", scores: [ 4, 6 ])
    finished_duel(challenger: @hugo, opponent: @lea, result: "opponent", scores: [ 4, 6 ])
    finished_duel(challenger: @hugo, opponent: @lea, result: "challenger")
    finished_duel(challenger: @hugo, opponent: @lea, result: "challenger")
    finished_duel(result: "draw", scores: [ 5, 5 ])

    record = nil
    assert_queries_count(1) { record = Game::DuelRecord.call(@lea) }

    assert_equal Game::DuelRecord::Record.new(wins: 2, losses: 3, draws: 1), record
    assert_equal Game::DuelRecord::Record.new(wins: 3, losses: 2, draws: 1), Game::DuelRecord.call(@hugo)
  end

  test "a duel that did not finish counts for nobody, and a third player has no record" do
    finished_duel
    unfinished = active_duel
    unfinished.save!
    Game::DuelSeat.create!(duel: unfinished, role: "challenger", player_id: @lea.id, status: "seated")

    assert_equal Game::DuelRecord::Record.new(wins: 1, losses: 0, draws: 0), Game::DuelRecord.call(@lea)
    assert_equal Game::DuelRecord::NONE, Game::DuelRecord.call(@third)
    assert_queries_count(0) { assert_equal Game::DuelRecord::NONE, Game::DuelRecord.call(nil) }
  end

  test "a duel played under older rules counts in neither the record nor the last results" do
    current = finished_duel
    finished_duel(result: "opponent", scores: [ 4, 6 ], rules_version: Game::DuelRules::VERSION - 1)

    assert_equal Game::DuelRecord::Record.new(wins: 1, losses: 0, draws: 0), Game::DuelRecord.call(@lea)
    assert_equal Game::DuelRecord::Record.new(wins: 0, losses: 1, draws: 0), Game::DuelRecord.call(@hugo)
    assert_equal [ current.token ], Game::RecentDuels.call(@lea).map(&:token)
  end

  test "the last ten results, the newest first, each with the player's own score and the opponent" do
    12.times { |index| finished_duel(scores: [ 6, index % 5 ], ended_at: (20 - index).hours.ago) }
    lost = finished_duel(challenger: @hugo, opponent: @lea, result: "challenger", scores: [ 7, 3 ], ended_at: 1.minute.ago)
    drawn = finished_duel(result: "draw", scores: [ 5, 5 ], ended_at: 30.seconds.ago)

    results = Game::RecentDuels.call(@lea)

    assert_equal 10, results.size
    assert_equal [ drawn.token, lost.token ], results.first(2).map(&:token)
    assert_equal [ :draw, 5, 5, @hugo.id ], detail(results.first)
    assert_equal [ :loss, 3, 7, @hugo.id ], detail(results.second)
    assert_equal [ :win, 6, 1, @hugo.id ], detail(results.third)
    assert_equal 10, results.map(&:token).uniq.size
  end

  test "a result whose opponent left reads no opponent, and a player with no duel reads none" do
    finished_duel(opponent: nil)

    assert_nil Game::RecentDuels.call(@lea).first.opponent_id
    assert_empty Game::RecentDuels.call(@third)
    assert_empty Game::RecentDuels.call(nil)
  end
end
