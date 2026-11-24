require "test_helper"
require_relative "../../../support/market"
require_relative "../../../support/archive_at_reference"

class Game::Market::ArchiveWeekTest < ActiveSupport::TestCase
  include ArchiveAtReference
  include MarketSettings

  test "the week counts the editions listed, those sold out and the copies sold since Monday, with the coefficient and the prices" do
    settings = open_market!(archive_price_common: 60, archive_price_rare: 300)
    common = catalog_card_seasons(:common_card_one)
    rare = catalog_card_seasons(:rare_card_one)
    Game::Market::ArchiveStock.create!(card_season_id: common.id, quantity: 2)
    withdraw = ->(at) { Game::Market::ArchiveWithdrawal.create!(player_id: accounts_players(:player).id, card_season_id: rare.id,
      purchase_token: SecureRandom.base58(24), price: 300, settings_id: settings.id, created_at: at) }
    withdraw.(Time.current)
    withdraw.(Time.current.utc.beginning_of_week - 1.minute)

    week = Game::Market::ArchiveWeek.call(settings)

    assert_equal [ 2, 1, 1, 1.0 ], [ week.listed, week.sold_out, week.copies_sold, week.coefficient ]
    assert_equal({ common: 60, uncommon: 100, rare: 300 }, week.prices)
  end
end
