require "test_helper"
require_relative "../../../support/market"

class Game::Market::ArchiveCapsTest < ActiveSupport::TestCase
  include MarketSettings

  setup do
    @player = accounts_players(:player)
    @now = Time.zone.local(2026, 11, 24, 12)
    @settings = open_market!(archive_cap_rare: 1, archive_cap_window_days_rare: 1, archive_cap_epic: 2, archive_cap_window_days_epic: 7)
  end

  def withdraw!(card, at, player: @player)
    Game::Market::ArchiveWithdrawal.create!(player_id: player.id, card_season_id: catalog_card_seasons(card).id, purchase_token: SecureRandom.base58(24),
      price: 100, settings_id: @settings.id, created_at: at)
  end

  def standings(player: @player) = Game::Market::ArchiveCaps.call(player:, settings: @settings, now: @now)

  test "a visitor has no standing" do
    assert_equal({}, standings(player: nil))
  end

  test "a capped rarity with no purchase has all its cap left and no next date" do
    assert_equal %i[rare epic legendary], standings.keys
    assert_equal [ 2, 7, 2, nil ], standings[:epic].to_h.values
    assert_not standings[:epic].reached?
  end

  test "a purchase inside the window lowers what is left, the cap reached gives the date it frees up" do
    withdraw!(:portal_one, @now - 2.days)
    assert_equal 1, standings[:epic].left

    withdraw!(:portal_one, @now - 1.day)
    standing = standings[:epic]

    assert standing.reached?
    assert_equal @now - 2.days + 7.days, standing.next_at
  end

  test "more purchases than the cap give the time the count falls below it" do
    @settings = open_market!(archive_cap_epic: 1, archive_cap_window_days_epic: 7)
    withdraw!(:portal_one, @now - 3.days)
    withdraw!(:portal_one, @now - 1.day)

    assert_equal @now - 1.day + 7.days, standings[:epic].next_at
  end

  test "a purchase exactly a window old no longer counts" do
    withdraw!(:rare_card_one, @now - 1.day)

    assert_equal 1, standings[:rare].left
  end

  test "rarities and players are counted apart" do
    withdraw!(:rare_card_one, @now - 1.hour)
    withdraw!(:portal_one, @now - 1.hour, player: accounts_players(:moderator))

    assert standings[:rare].reached?
    assert_equal 2, standings[:epic].left
    assert_equal 1, standings(player: accounts_players(:moderator))[:rare].left
  end

  test "a common purchase counts toward no cap" do
    withdraw!(:common_card_one, @now - 1.hour)

    assert_equal [ 1, 2, 1 ], standings.values.map(&:left)
  end
end
