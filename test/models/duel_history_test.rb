require "test_helper"
require_relative "../support/duels"

class DuelHistoryTest < ActiveSupport::TestCase
  include Duels

  setup do
    @lea = accounts_players(:player)
    @hugo = accounts_players(:moderator)
  end

  def finish_duel(opponent, rules_version: Game::DuelRules::VERSION)
    duel = active_duel
    duel.update!(state: "finished", result: "challenger", ended_at: Time.current, challenger_score: 6, opponent_score: 4,
      rules_version:)
    { "challenger" => @lea, "opponent" => opponent }.each do |role, player|
      Game::DuelSeat.create!(duel:, role:, player_id: player&.id, status: "left")
    end
    duel
  end

  def player_queries
    count = 0
    counter = ->(*, payload) { count += 1 if payload[:sql].include?("FROM \"accounts_players\"") }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield }
    count
  end

  test "each row names its opponent, all read with one query" do
    3.times { finish_duel(@hugo) }
    finish_duel(nil)
    history = DuelHistory.new(@lea)

    rows = nil
    assert_equal 1, player_queries { rows = history.rows }
    assert_equal [ nil, @hugo, @hugo, @hugo ], rows.map(&:opponent).sort_by { it&.id.to_i }
  end

  test "the record and the rows leave out duels played under older rules" do
    current = finish_duel(@hugo)
    finish_duel(@hugo, rules_version: Game::DuelRules::VERSION - 1)
    history = DuelHistory.new(@lea)

    assert_equal Game::DuelRecord::Record.new(wins: 1, losses: 0, draws: 0), history.record
    assert_equal [ current.token ], history.rows.map(&:token)
  end
end
