require "test_helper"
require_relative "../../../support/market"

class Game::Market::ArchiveCapsTest < ActiveSupport::TestCase
  include MarketSettings

  setup do
    @player = accounts_players(:player)
    @now = Time.utc(2026, 11, 25, 12)
    @settings = open_market!
  end

  def withdraw!(at, player: @player)
    Game::Market::ArchiveWithdrawal.create!(player_id: player.id, card_season_id: catalog_card_seasons(:common_card_one).id,
      purchase_token: SecureRandom.base58(24), price: 100, settings_id: @settings.id, created_at: at)
  end

  def standings(player: @player) = Game::Market::ArchiveCaps.call(player:, now: @now)

  test "a visitor has no standing" do
    assert_equal({}, standings(player: nil))
  end

  test "every listed rarity shares the week's standing, five purchases from Monday" do
    assert_equal %i[common uncommon rare], standings.keys
    assert_equal [ 5, 5, Time.utc(2026, 11, 30) ], standings[:rare].to_h.values
    assert_not standings[:rare].reached?
  end

  test "this week's purchases of this player count, last week's and another player's do not" do
    4.times { withdraw!(@now - 1.day) }
    withdraw!(Time.utc(2026, 11, 22, 23, 59))
    withdraw!(@now, player: accounts_players(:moderator))
    assert_equal 1, standings[:common].left

    withdraw!(@now)
    assert standings[:uncommon].reached?
  end
end
