require "test_helper"

class Game::PublishWeeklyVerdictJobTest < ActiveSupport::TestCase
  MONDAY = Time.utc(2026, 11, 2, 0, 5)

  def player(number, **attributes) = Accounts::Player.create!(steam_id: (76561197960800000 + number).to_s, **attributes)

  def luck(player, z_score)
    Game::Fortune.insert_all!([ { player_id: player.id, week_start: MONDAY.to_date - 7, regular_packs: 1, actual_points: (z_score * 100).round,
      expected_points: 0, variance: 10_000, created_at: MONDAY, updated_at: MONDAY } ])
  end

  def verdicts = Game::FeedEntry.where(kind: "verdict")

  test "Monday's run names last week's first public player, once however often it runs" do
    winner = player(1)
    luck(player(2, visibility: :friends_only), 5.0)
    luck(winner, 2.0)

    travel_to(MONDAY) { 2.times { Game::PublishWeeklyVerdictJob.perform_now } }

    assert_equal [ winner.id ], verdicts.pluck(:player_id)
    assert_equal Time.utc(2026, 11, 2), verdicts.sole.occurred_at
    assert verdicts.sole.notable
  end

  test "no public ranked player, no entry" do
    luck(player(1, visibility: :private), 3.0)

    travel_to(MONDAY) { Game::PublishWeeklyVerdictJob.perform_now }

    assert_empty verdicts
  end

  test "the next week has its own entry" do
    luck(player(1), 2.0)
    Game::FeedEntry.record_verdict(player_id: accounts_players(:player).id, week_start: MONDAY.to_date - 7, now: MONDAY)

    travel_to(MONDAY) { Game::PublishWeeklyVerdictJob.perform_now }

    assert_equal 2, verdicts.count
  end
end
