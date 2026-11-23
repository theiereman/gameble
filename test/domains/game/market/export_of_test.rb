require "test_helper"
require_relative "../../../support/holdings"
require_relative "../../../support/market"
require_relative "../../../support/market_listings"
require_relative "../../../support/market_auctions"
require_relative "../../../support/market_bidding"
require_relative "../../../support/market_orders"

class Game::Market::ExportOfTest < ActiveSupport::TestCase
  include Holdings
  include MarketAuctions
  include MarketBidding
  include MarketListings
  include MarketOrders
  include MarketSettings

  setup do
    @seller = accounts_players(:player)
    @bidder = accounts_players(:moderator)
    @card = catalog_card_seasons(:common_card_one)
    open_market!(first_opened_at: 1.day.ago)
    hold(@seller, @card.id, 1, reserved: 1)
    @listing = listing!(seller: @seller, card_season: @card, starting_price: 20_000, ends_at: 1.day.from_now)
    fund!(@bidder, 100_000)
    assert bid(@bidder, 30_000).success?
  end

  test "a bidder's rows are their wallet, ledger entries and bids, the listing named by token" do
    result = Game::Market::ExportOf.call(@bidder)

    assert_equal [ 70_000, 30_000 ], [ result.wallet.available, result.wallet.committed ]
    assert_equal %w[mint hold], result.entries.map(&:kind)
    assert_equal [ nil, @listing.token ], result.entries.map(&:listing_token)
    assert_equal [ [ @listing.token, 30_000, "leading" ] ], result.bids.map { [ it.listing_token, it.maximum, it.outcome ] }
    assert_empty result.listings
    assert_empty result.card_season_ids
  end

  test "a seller's rows are their listings, with the card to look up and no leader field" do
    result = Game::Market::ExportOf.call(@seller)

    assert_equal [ @listing.token ], result.listings.map(&:token)
    assert_equal [ @card.id ], result.card_season_ids
    assert_empty result.bids
    assert_empty Game::Market::ExportOf::ListingRow.members & %i[leader_id leader_maximum winner_id]
  end

  test "a buyer's orders, a seller's sales to orders, Archive purchases and bought slots, the cards to look up, no buyer on a sale" do
    rare = catalog_card_seasons(:rare_card_one)
    open = order!(@bidder, rare, 900)
    served = order!(@bidder, @card, 300)
    served.update_columns(status: "served", seller_id: @seller.id, served_card_season_id: @card.id, served_at: Time.current, average_after_sale: 300)
    Game::Market::ArchiveWithdrawal.create!(player_id: @seller.id, card_season_id: rare.id, settings_id: Game::Market::CurrentSettings.call.id,
      purchase_token: SecureRandom.base58(24), price: 100)
    Game::CapacitySlot.create!(player_id: @seller.id, kind: "goal", bought: 2)

    buyer = Game::Market::ExportOf.call(@bidder)
    seller = Game::Market::ExportOf.call(@seller)

    assert_equal [ [ open.token, "blue-depths", "open", nil ], [ served.token, "tin-soldier", "served", @card.id ] ],
      buyer.orders.map { [ it.token, it.card_slug, it.status, it.served_card_season_id ] }
    assert_equal [ nil, @listing.token, nil, nil ], buyer.entries.map(&:listing_token)
    assert_equal [ nil, nil, open.token, served.token ], buyer.entries.map(&:order_token)
    assert_equal [ @card.id ], buyer.card_season_ids
    assert_equal [ [ @card.id, 300 ] ], seller.sales_to_orders.map { [ it.card_season_id, it.price ] }
    assert_empty Game::Market::ExportOf::SaleToOrderRow.members & %i[token player_id buyer_id order_token]
    assert_equal [ [ rare.id, 100 ] ], seller.archive_purchases.map { [ it.card_season_id, it.price ] }
    assert_equal [ [ "goal", 2 ] ], seller.bought_slots.map { [ it.kind, it.bought ] }
    assert_equal [ @card.id, rare.id ], seller.card_season_ids
    assert_empty seller.orders
  end
end
