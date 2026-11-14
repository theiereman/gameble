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

  def board(period = :week, sort: :luck)
    fortunes = Game::FortuneBoard.ranked(period, now: NOW, sort:).to_a
    Game::FortuneBoard.rows(fortunes, ranked_count: fortunes.size, now: NOW)
  end

  test "players rank by the unrounded Z-score, a tie going to the earlier account, and the board shows each index" do
    close, closer, tied, last = Array.new(4) { player(it) }
    luck(close, 3.0)
    luck(closer, 3.1)
    luck(tied, 3.0)
    luck(last, -2.0)

    rows = board
    summary = Game::FortuneBoard.summary(now: NOW)

    assert_equal [ closer, close, tied, last ], rows.map(&:player)
    assert_equal [ 1, 2, 3, 4 ], rows.map(&:rank)
    assert_equal [ [ true, 25 ], [ true, 50 ], [ false, 50 ], [ false, 25 ] ], rows.map { [ it.top_half?, it.share_of_half ] }
    assert_equal [ 457, 453, 453, -381 ], rows.map(&:index)
    assert_equal [ 4, 4, 1, 4 ], [ summary.ranked_count, summary.active_count, summary.privileged_count, summary.packs_opened ]
    assert_equal [ true, false, false, false ], rows.map(&:privileged)
  end

  test "sorted by capsules opened, each player keeps their luck rank" do
    steady, busy = player(1), player(2)
    luck(steady, 2.0)
    luck(busy, 1.0)
    Game::Fortune.where(player_id: busy.id).update_all(regular_packs: 9)

    assert_equal [ [ busy, 2, 9 ], [ steady, 1, 1 ] ], board(sort: :capsules).map { [ it.player, it.rank, it.packs_opened ] }
  end

  test "each row counts the cards pulled per rarity in the board's period, duplicates included" do
    puller = player(1)
    luck(puller, 1.0)
    Game::Fortune.where(player_id: puller.id, week_start: Game::WeeklyGoal.week_start(NOW)).update_all(common_cards: 7, rare_cards: 2)
    Game::Fortune.where(player_id: puller.id, week_start: nil).update_all(common_cards: 30, rare_cards: 5, legendary_cards: 1)

    assert_equal({ 1 => 7, 2 => 0, 3 => 2, 4 => 0, 5 => 0 }, board.sole.rarities)
    assert_equal({ 1 => 30, 2 => 0, 3 => 5, 4 => 0, 5 => 1 }, board(:all_time).sole.rarities)
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

  test "the week's board ranks only this week's players; the total board ranks everyone, marking only this week's Privileged" do
    veteran, newcomer = player(1), player(2)
    luck(veteran, 4.0, week: false)
    luck(newcomer, 1.0)

    assert_equal [ newcomer ], board.map(&:player)
    assert_equal 1, Game::FortuneBoard.summary(now: NOW).ranked_count
    assert_equal [ veteran, newcomer ], board(:all_time).map(&:player)
    assert_equal [ false, true ], board(:all_time).map(&:privileged)
    assert_equal [ 2, 1, 1 ], Game::FortuneBoard.summary(:all_time, now: NOW).deconstruct.first(3)
  end

  test "the board knows no last week" do
    assert_raises(ArgumentError) { Game::FortuneBoard.ranked(:last_week, now: NOW) }
  end

  test "banned and deleted players leave the ranking and the count of active players" do
    kept, banned, deleted = player(1), player(2), player(3)
    [ kept, banned, deleted ].each_with_index { |each, index| luck(each, index.to_f) }
    banned.update!(banned_at: NOW)
    deleted.update!(deleted_at: NOW, steam_id: nil)

    assert_equal [ kept ], board.map(&:player)
    assert_equal 1, Game::FortuneBoard.summary(now: NOW).ranked_count
  end

  test "a private player leaves the board, the counts and the Privileged, and keeps an index without a rank" do
    kept, hidden = player(1), player(2)
    luck(kept, 1.0)
    luck(hidden, 3.0)
    hidden.update!(visibility: :private)

    summary = Game::FortuneBoard.summary(now: NOW)
    standing = Game::FortuneStanding.call(hidden, period: :week, now: NOW)

    assert_equal [ kept ], board.map(&:player)
    assert_equal [ 1, 1 ], [ summary.ranked_count, summary.packs_opened ]
    assert_equal Set[kept.id], Game::Privileged.ids(now: NOW)
    assert_equal [ nil, 0, false ], [ standing.rank, standing.ranked_count, standing.privileged ]
    assert_operator standing.index, :>, 0
    assert_not_predicate standing, :shareable?
    assert_equal 1, Game::FortuneStanding.call(kept, period: :week, now: NOW).rank
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
