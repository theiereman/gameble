require "test_helper"
require_relative "../../../support/market"
require_relative "../../../support/market_listings"

# An event stored before an opening converted orders carries no converted key; every reader of it reads none.
class Game::Market::ConvertedOrdersTest < ActiveSupport::TestCase
  include MarketListings
  include MarketSettings

  setup do
    @seller = accounts_players(:player)
    open_market!
    @listing = listing!(seller: @seller, card_season: catalog_card_seasons(:common_card_one))
    @listed = Game::Market::CardListed.new(data: { listing_id: @listing.id, seller_id: @seller.id, card_season_id: @listing.card_season_id })
    @applied = Game::Market::WantedChoicesApplied.new(data: { seller_id: @seller.id, sales: [], listing_ids: [ @listing.id ], entrusted: [] })
  end

  test "the reader gives no rows and no owners" do
    [ @listed, @applied ].each do |event|
      assert_empty Game::Market::ConvertedOrders.rows(event.data)
      assert_empty Game::Market::ConvertedOrders.owner_ids(event.data)
    end
  end

  test "the reader gives the converted rows and their owners when the event carries them" do
    row = { order_id: 7, owner_id: 9, listing_id: @listing.id, price: 400, status: "bid" }
    event = Game::Market::CardListed.with(listing_id: @listing.id, seller_id: @seller.id, card_season_id: @listing.card_season_id, converted: [ row ])

    assert_equal [ row ], Game::Market::ConvertedOrders.rows(event.data)
    assert_equal [ 9 ], Game::Market::ConvertedOrders.owner_ids(event.data)
  end

  test "every handler replays such an event" do
    assert_nothing_raised do
      [ @listed, @applied ].each do |event|
        Game::Market::Handlers::OrderNotices.call(event)
        Game::Market::Handlers::WantedNotices.call(event)
        Game::Market::Handlers::WantedRefresh.call(event)
      end
    end
  end

  test "the stream and the push readers read no converted order" do
    assert_equal [ { player_id: @seller.id, balance: true } ], PlayerStream.notices(@listed)
    assert_equal [ { player_id: @seller.id, balance: true } ], PlayerStream.notices(@applied)
    assert_empty MarketPushNotice.notices(@listed)
    assert_empty MarketPushNotice.notices(@applied)
  end
end
