require "test_helper"
require_relative "../../support/game_sets"

class Game::PioneerBoardTest < ActiveSupport::TestCase
  include GameSets

  NOW = Time.utc(2026, 11, 18, 12)
  MONDAY = Time.utc(2026, 11, 16)

  def player(number, **attributes) = Accounts::Player.create!(steam_id: (76561197960500000 + number).to_s, **attributes)

  def discover(player, card_season_ids, at: NOW)
    Game::FirstDiscovery.insert_all!(Array(card_season_ids).map do |card_season_id|
      { card_season_id:, player_id: player.id, discovered_at: at, created_at: at, updated_at: at }
    end)
  end

  def standings(period)
    Game::PioneerBoard.rows(Game::PioneerBoard.ranked(period, now: NOW).to_a).map { [ it.player, it.rank, it.count ] }
  end

  test "players rank by discoveries, ties share a rank and the one who reached the count first comes first" do
    _season, cards = published_cards(7)
    first, later, earlier = player(1), player(2), player(3)
    discover(first, cards[0, 3])
    discover(later, cards[3], at: NOW - 1.hour)
    discover(later, cards[4], at: NOW - 10.minutes)
    discover(earlier, cards[5, 2], at: NOW - 2.hours)

    assert_equal [ [ first, 1, 3 ], [ earlier, 2, 2 ], [ later, 2, 2 ] ], standings(:week)
  end

  test "banned and deleted players are neither ranked nor counted" do
    _season, cards = published_cards(3)
    active = player(1)
    discover(active, cards[0])
    discover(player(2, deleted_at: NOW), cards[1, 2])

    assert_equal [ [ active, 1, 1 ] ], standings(:total)
  end

  test "the week starts on Monday at midnight UTC" do
    _season, cards = published_cards(2)
    pioneer = player(1)
    discover(pioneer, cards[0], at: MONDAY - 1.second)
    discover(pioneer, cards[1], at: MONDAY)

    assert_equal [ [ pioneer, 1, 1 ] ], standings(:week)
    assert_equal [ [ pioneer, 1, 2 ] ], standings(:total)
  end

  test "the season counts only the published season's editions, the total every edition" do
    _old, old_cards = published_cards(2)
    _current, current_cards = published_cards(1)
    pioneer = player(1)
    discover(pioneer, old_cards)
    discover(pioneer, current_cards)

    assert_equal [ [ pioneer, 1, 1 ] ], standings(:season)
    assert_equal [ [ pioneer, 1, 3 ] ], standings(:total)

    Catalog::Season.update_all(status: "draft")
    assert_empty standings(:season)
  end

  test "the viewer's place gives their rank, count and page; nobody, a banned viewer or one without a discovery has none" do
    _season, cards = published_cards(101)
    50.times { |index| discover(player(index + 1), cards[index * 2, 2]) }
    viewer = player(99)
    discover(viewer, cards[100])

    assert_equal Game::PioneerBoard::Place.new(rank: 51, count: 1, page: 2), Game::PioneerBoard.place(viewer, :week, now: NOW)
    assert_nil Game::PioneerBoard.place(nil, :week, now: NOW)
    assert_nil Game::PioneerBoard.place(player(100), :week, now: NOW)
    viewer.update!(banned_at: NOW)
    assert_nil Game::PioneerBoard.place(viewer, :week, now: NOW)
  end

  test "the board holds the top three and the viewer's place" do
    _season, cards = published_cards(4)
    players = Array.new(4) { player(it) }
    players.each_with_index { |each, index| discover(each, cards[index], at: NOW - index.minutes) }

    board = Game::PioneerBoard.board(:week, viewer: players.first, now: NOW)

    assert_equal players.reverse.first(3), board.rows.map(&:player)
    assert_equal Game::PioneerBoard::Place.new(rank: 1, count: 1, page: 1), board.place
    assert_equal [ 1, 1, 1 ], board.rows.map(&:rank)
  end

  test "the week stays the week, the second period follows the scope" do
    assert_equal :week, Game::PioneerBoard.period_for(:week, :current)
    assert_equal :season, Game::PioneerBoard.period_for(:season, :current)
    assert_equal :total, Game::PioneerBoard.period_for(:season, :all)
  end
end
