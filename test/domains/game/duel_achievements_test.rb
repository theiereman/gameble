require "test_helper"
require_relative "../../support/game_packs"
require_relative "../../support/duels"

# The ten duel achievements read finished duels, their seats and rounds: what counts, what a round played by the game
# does not, and the job that follows a finished duel for both seats.
class Game::DuelAchievementsTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include GamePacks
  include Duels

  COMMON = 1
  LEGENDARY = 5

  setup do
    @lea = accounts_players(:player)
    @hugo = accounts_players(:moderator)
    @challenger_card, @opponent_card = Catalog::CardSeason.order(:id).limit(2).pluck(:id)
  end

  def progress(metric, player = @lea) = Game::AchievementProgress.call(player, [ metric ]).fetch(metric)

  def deck_with(card_season_id, rarity) = [ duel_card(card_season_id).with(rarity:) ]

  # A finished duel between the two with the seats' scores, and the rounds given as hashes of the columns that differ.
  def finished_duel(challenger: @lea, opponent: @hugo, result: "challenger", scores: [ 6, 4 ], challenger_rarity: COMMON,
    opponent_rarity: COMMON, rounds: [])
    duel = active_duel(challenger: deck_with(@challenger_card, challenger_rarity), opponent: deck_with(@opponent_card, opponent_rarity))
    duel.assign_attributes(state: "finished", result:, ended_at: Time.current, challenger_score: scores.first, opponent_score: scores.last)
    duel.save!
    { "challenger" => challenger, "opponent" => opponent }.each do |role, player|
      Game::DuelSeat.create!(duel:, role:, player_id: player.id, status: "left")
    end
    rounds.each.with_index(1) { |columns, number| round(duel, number, **columns) }
    duel
  end

  def round(duel, number, winner: "challenger", caller: "challenger", stat: "rating", caller_automatic: false, answer_automatic: false)
    Game::DuelRound.create!(duel:, number:, caller:, caller_card_season_id: caller == "challenger" ? @challenger_card : @opponent_card,
      answer_card_season_id: caller == "challenger" ? @opponent_card : @challenger_card, stat:, direction: "high", winner:, caller_automatic:,
      answer_automatic:, called_at: Time.current, answered_at: Time.current)
  end

  test "the catalogue lists the ten duel achievements with their thresholds, and the metrics they read" do
    expected = [
      [ :first_dispute_settled_amicably, :duels_finished, 1 ], [ :competitive_advantage_observed, :duels_won, 1 ],
      [ :dominant_position, :duels_won, 10 ], [ :abuse_of_dominant_position, :duels_won, 50 ], [ :de_facto_monopoly, :duels_won, 100 ],
      [ :valuation_error, :common_beats_legendary_rounds, 1 ], [ :merger_by_absorption, :shutout_duels, 1 ],
      [ :settled_at_the_margin, :margin_wins, 1 ], [ :client_base_diversification, :distinct_duel_opponents, 5 ],
      [ :certified_versatility, :distinct_stats_won, 5 ]
    ]

    assert_equal expected, Game::Achievements::CATALOGUE.last(10).map { [ it.key, it.metric, it.threshold ] }
    assert expected.all? { Game::AchievementProgress::METRICS.include?(it[1]) }
  end

  test "a finished duel counts for both seats, a duel still on does not" do
    finished_duel(result: "draw", scores: [ 5, 5 ])
    active = active_duel
    active.save!
    Game::DuelSeat.create!(duel: active, role: "challenger", player_id: @lea.id, status: "seated")

    assert_equal [ 1, 1 ], [ progress(:duels_finished), progress(:duels_finished, @hugo) ]
  end

  test "a win counts for the winner's seat only, a draw and a loss for neither" do
    finished_duel(result: "challenger")
    finished_duel(result: "opponent", scores: [ 4, 6 ])
    finished_duel(result: "draw", scores: [ 5, 5 ])

    assert_equal [ 1, 1 ], [ progress(:duels_won), progress(:duels_won, @hugo) ]
    assert_equal 3, progress(:duels_finished)
  end

  test "the win achievements reach their thresholds at 1, 10, 50 and 100 wins" do
    wins = Game::Achievements::CATALOGUE.select { it.metric == :duels_won }
    stands = ->(count) { wins.select { |achievement| achievement.met?({ duels_won: count }) }.map(&:threshold) }

    assert_equal [], stands.call(0)
    assert_equal [ 1, 10, 50, 100 ], stands.call(100)
    assert_equal [ 1, 10 ], stands.call(49)
  end

  test "a round won with a Common card against a Legendary card counts, read from the snapshot's rarities" do
    finished_duel(challenger_rarity: COMMON, opponent_rarity: LEGENDARY, rounds: [ { winner: "challenger" } ])
    finished_duel(challenger_rarity: COMMON, opponent_rarity: COMMON, rounds: [ { winner: "challenger" } ])
    finished_duel(challenger_rarity: LEGENDARY, opponent_rarity: COMMON, rounds: [ { winner: "challenger" } ])
    finished_duel(challenger_rarity: COMMON, opponent_rarity: LEGENDARY, rounds: [ { winner: "opponent" } ])

    assert_equal 1, progress(:common_beats_legendary_rounds)
  end

  test "a Common answer that beats a Legendary call counts for the answerer" do
    finished_duel(challenger_rarity: LEGENDARY, opponent_rarity: COMMON, result: "opponent", rounds: [ { winner: "opponent" } ])

    assert_equal [ 0, 1 ], [ progress(:common_beats_legendary_rounds), progress(:common_beats_legendary_rounds, @hugo) ]
  end

  test "a round won by the winner's own automatic move counts for neither Valuation Error nor Certified Versatility" do
    finished_duel(opponent_rarity: LEGENDARY, rounds: [ { winner: "challenger", caller_automatic: true } ])
    finished_duel(opponent_rarity: LEGENDARY, rounds: [ { winner: "opponent", caller: "opponent", stat: "release", answer_automatic: true } ])

    assert_equal [ 0, 0 ], [ progress(:common_beats_legendary_rounds), progress(:distinct_stats_won) ]
  end

  test "an automatic move of the loser leaves the round the winner's" do
    finished_duel(opponent_rarity: LEGENDARY, rounds: [ { winner: "challenger", answer_automatic: true } ])

    assert_equal [ 1, 1 ], [ progress(:common_beats_legendary_rounds), progress(:distinct_stats_won) ]
  end

  test "a duel won 10 to 0 counts, a 10 to 0 loss and a 9 to 1 win do not" do
    finished_duel(scores: [ 9, 1 ])
    finished_duel(result: "opponent", scores: [ 0, 10 ])

    assert_equal [ 0, 1 ], [ progress(:shutout_duels), progress(:shutout_duels, @hugo) ]

    finished_duel(scores: [ 10, 0 ])

    assert_equal 1, progress(:shutout_duels)
  end

  test "a win whose score was tied counts as won on the margin, a plain win and a tied draw do not" do
    finished_duel(scores: [ 6, 4 ])
    finished_duel(result: "draw", scores: [ 5, 5 ])
    finished_duel(result: "opponent", scores: [ 5, 5 ])

    assert_equal [ 0, 1 ], [ progress(:margin_wins), progress(:margin_wins, @hugo) ]
  end

  test "five distinct friends count once each, however many duels they played" do
    friends = Array.new(5) { Accounts::Player.create!(steam_id: "7656119796043#{(9000 + it)}") }
    friends.each { finished_duel(opponent: it, result: "draw", scores: [ 5, 5 ]) }
    finished_duel(opponent: friends.first)

    assert_equal [ 5, 1 ], [ progress(:distinct_duel_opponents), progress(:distinct_duel_opponents, friends.first) ]
  end

  test "opponents who deleted their account count as one opponent together" do
    friends = Array.new(3) { Accounts::Player.create!(steam_id: "7656119796044#{(9000 + it)}") }
    friends.each { finished_duel(opponent: it, result: "draw", scores: [ 5, 5 ]) }
    assert_equal 3, progress(:distinct_duel_opponents)

    Game::DuelSeat.where(player_id: friends.first(2).map(&:id)).update_all(player_id: nil)

    assert_equal 2, progress(:distinct_duel_opponents)
  end

  test "the rounds won with each of the five stats count once per stat, in any duel" do
    stats = Game::DuelStat::STATS.map(&:to_s)
    finished_duel(rounds: stats.first(3).map { { stat: it } })
    finished_duel(rounds: [ { stat: stats.first }, { stat: stats[3] }, { stat: stats[4], winner: "opponent" } ])

    assert_equal [ 4, 1 ], [ progress(:distinct_stats_won), progress(:distinct_stats_won, @hugo) ]
    finished_duel(rounds: [ { stat: stats[4] } ])

    assert_equal 5, progress(:distinct_stats_won)
  end

  test "an automatic duel still counts once it ends, a 10 to 0 win included" do
    finished_duel(scores: [ 10, 0 ], rounds: Array.new(10) { { caller_automatic: true, answer_automatic: true } })

    assert_equal [ 1, 1, 1, 0 ], %i[duels_finished duels_won shutout_duels distinct_stats_won].map { progress(it) }
  end

  test "a round nobody won counts for no seat" do
    finished_duel(result: "draw", scores: [ 0, 0 ], rounds: [ { winner: nil } ])

    assert_equal [ 0, 0, 0 ], %i[distinct_stats_won duels_won margin_wins].map { progress(it) }
  end

  test "a finished duel runs the job for both seats, which grants neither a duel achievement" do
    duel = finished_duel
    event = Game::DuelFinished.new(data: { duel_id: duel.id, challenger_id: @lea.id, opponent_id: @hugo.id })

    assert_enqueued_jobs 2, only: Game::GrantAchievementsJob do
      Game::Handlers::Achievements.call(event)
    end
    perform_enqueued_jobs only: Game::GrantAchievementsJob

    assert_empty unlocked(@lea)
    assert_empty unlocked(@hugo)
  end

  test "the Duelliste back stays the one of Abuse of Dominant Position, which 50 wins no longer grant" do
    assert_equal [ :achievement, "abuse_of_dominant_position" ], Game::CardBacks.find("duelliste").unlock.to_h.values_at(:kind, :target)

    50.times { finished_duel }
    Game::GrantAchievementsJob.grant(@lea)

    assert_empty unlocked(@lea)
    assert_empty Game::CardBackUnlock.where(player_id: @lea.id, back: "duelliste")
  end

  def unlocked(player) = Game::AchievementUnlock.where(player_id: player.id).order(:id).pluck(:achievement)
end
