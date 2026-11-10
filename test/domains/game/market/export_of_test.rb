require "test_helper"
require_relative "../../../support/holdings"
require_relative "../../../support/market"
require_relative "../../../support/market_listings"
require_relative "../../../support/market_auctions"
require_relative "../../../support/market_bidding"

class Game::Market::ExportOfTest < ActiveSupport::TestCase
  include Holdings
  include MarketAuctions
  include MarketBidding
  include MarketListings
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
end
