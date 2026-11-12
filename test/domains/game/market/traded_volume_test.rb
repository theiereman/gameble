require "test_helper"
require_relative "../../../support/market"
require_relative "../../../support/market_listings"

class Game::Market::TradedVolumeTest < ActiveSupport::TestCase
  include MarketListings
  include MarketSettings

  NOW = Time.utc(2026, 11, 12, 15)

  setup do
    open_market!(first_opened_at: 30.days.ago)
    @seller = accounts_players(:player)
  end

  def sold!(price, at)
    listing!(seller: @seller, card_season: catalog_card_seasons(:common_card_one), status: "sold").update_columns(sold_at: at, final_price: price)
  end

  test "it sums the sold auctions of each UTC day, today included, over fourteen days" do
    sold!(1_000, NOW - 14.days)
    sold!(2_000, NOW - 13.days)
    sold!(500, NOW - 1.day)
    sold!(700, NOW - 1.day)
    sold!(300, NOW - 1.hour)
    listing!(seller: @seller, card_season: catalog_card_seasons(:rare_card_one))

    volume = Game::Market::TradedVolume.call(now: NOW)

    assert_equal 14, volume.days.size
    assert_equal [ Date.new(2026, 10, 30), Date.new(2026, 11, 12) ], [ volume.days.first, volume.days.last ]
    assert_equal [ 2_000, *[ 0 ] * 11, 1_200, 300 ], volume.amounts
    assert_equal 1_500, volume.week
    assert_equal 2_000, volume.week_before
    assert_equal(-25, volume.change_percent)
    assert volume.traded?
  end

  test "there is no change without a week before, and nothing traded reads as such" do
    sold!(900, NOW - 2.days)

    assert_nil Game::Market::TradedVolume.call(now: NOW).change_percent
    assert_not Game::Market::TradedVolume.call(now: NOW + 20.days).traded?
  end
end
