require "test_helper"

class Game::FortuneBoardTest < ActiveSupport::TestCase
  NOW = Time.utc(2026, 10, 28, 12)

  def player(number) = Accounts::Player.create!(steam_id: (76561197960400000 + number).to_s)

  def luck(player, z_score, week: true, all_time: true)
    weeks = [ (Game::WeeklyGoal.week_start(NOW) if week), (:all_time if all_time) ].compact
    Game::Fortune.insert_all!(weeks.map do |week_start|
      { player_id: player.id, week_start: (week_start unless week_start == :all_time), regular_packs: 1,
        actual_points: (z_score * 100).round, expected_points: 0, variance: 10_000, created_at: NOW, updated_at: NOW }
    end)
  end

  test "players rank by the unrounded Z-score, a tie going to the earlier account, and the board shows each index" do
    close, closer, tied, last = Array.new(4) { player(it) }
    luck(close, 3.0)
    luck(closer, 3.1)
    luck(tied, 3.0)
    luck(last, -2.0)

    board = Game::FortuneBoard.call(nil, period: :week, now: NOW)

    assert_equal [ closer, close, tied, last ], board.rows.map(&:player)
    assert_equal [ 1, 2, 3, 4 ], board.rows.map(&:rank)
    assert_equal [ 457, 453, 453, -381 ], board.rows.map(&:index)
    assert_equal [ 4, 4, 1 ], [ board.ranked_count, board.active_count, board.privileged_count ]
    assert_equal [ true, false, false, false ], board.rows.map(&:privileged)
  end

  test "the Privileged are the top tenth of this week's active players, rounded up, and change as the week's ranking does" do
    players = Array.new(11) { player(it) }
    players.each_with_index { |each, index| luck(each, index.to_f) }

    assert_equal players.last(2).to_set, Game::Privileged.ids(now: NOW).map { Accounts::Player.find(it) }.to_set
    assert Game::Privileged.call(players.last, now: NOW)
    assert_not Game::Privileged.call(players.first, now: NOW)

    Game::Fortune.where(player_id: players.first.id).update_all(actual_points: 1_500)
    assert Game::Privileged.call(players.first, now: NOW)
    assert_not Game::Privileged.call(players[-2], now: NOW)
  end

  test "the all-time board ranks everyone who ever opened a pack, and marks only this week's Privileged" do
    veteran, newcomer = player(1), player(2)
    luck(veteran, 4.0, week: false)
    luck(newcomer, 1.0)

    all_time = Game::FortuneBoard.call(nil, period: :all_time, now: NOW)
    week = Game::FortuneBoard.call(nil, period: :week, now: NOW)

    assert_equal [ veteran, newcomer ], all_time.rows.map(&:player)
    assert_equal [ false, true ], all_time.rows.map(&:privileged)
    assert_equal [ newcomer ], week.rows.map(&:player)
  end

  test "banned and deleted players leave the ranking and the count of active players" do
    kept, banned, deleted = player(1), player(2), player(3)
    [ kept, banned, deleted ].each_with_index { |each, index| luck(each, index.to_f) }
    banned.update!(banned_at: NOW)
    deleted.update!(deleted_at: NOW, steam_id: nil)

    board = Game::FortuneBoard.call(nil, period: :week, now: NOW)

    assert_equal [ kept ], board.rows.map(&:player)
    assert_equal 1, board.active_count
  end

  test "a viewer below the shown rows gets their own row and rank" do
    players = Array.new(3) { player(it) }
    players.each_with_index { |each, index| luck(each, index.to_f) }

    board = Game::FortuneBoard.call(players.first, period: :week, now: NOW, shown: 2)

    assert_equal players.last(2).reverse, board.rows.map(&:player)
    assert_equal [ players.first, 3 ], [ board.own.player, board.own.rank ]
    assert_nil Game::FortuneBoard.call(players.last, period: :week, now: NOW, shown: 2).own
  end

  test "a player's standing: index, label, rank among the period's players, Privileged, and the figures" do
    lucky, other = player(1), player(2)
    luck(lucky, 3.52)
    luck(other, 0.0)

    standing = Game::FortuneStanding.call(lucky, period: :week, now: NOW)

    assert_equal [ 471, :indecently_lucky, 1, 2, true ], [ standing.index, standing.label, standing.rank, standing.ranked_count, standing.privileged ]
    assert_equal 1, standing.packs_opened
    assert_predicate standing, :opened?
    assert_equal 352, standing.actual_points
  end

  test "a player who opened nothing in the period has an empty standing, without a rank" do
    standing = Game::FortuneStanding.call(player(1), period: :week, now: NOW)

    assert_not standing.opened?
    assert_nil standing.rank
    assert_not standing.privileged
    assert_not Game::FortuneStanding.call(nil, period: :all_time, now: NOW).opened?
  end
end
