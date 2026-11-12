require "test_helper"
require_relative "../../../support/holdings"
require_relative "../../../support/market"
require_relative "../../../support/market_listings"
require_relative "../../../support/market_auctions"
require_relative "../../../support/market_bidding"

class Game::Market::OutcomeNoticesTest < ActiveSupport::TestCase
  include Holdings
  include MarketAuctions
  include MarketBidding
  include MarketListings
  include MarketSettings

  setup do
    @seller = accounts_players(:player)
    @first = accounts_players(:moderator)
    @second = accounts_players(:administrator)
    @card = catalog_card_seasons(:common_card_one)
    open_market!(increment_basis_points: 500, soft_close_seconds: 180)
    hold(@seller, @card.id, 1, reserved: 1)
    @listing = listing!(seller: @seller, card_season: @card, starting_price: 20_000, ends_at: 1.day.from_now)
    [ @first, @second ].each { fund!(it, 100_000) }
  end

  def notice(player) = Game::Market::Notice.find_by(player_id: player.id, listing_id: @listing.id)

  def close = Game::Market::CloseAuction.new.call(player: @seller, listing_id: @listing.id)

  test "a close with a winner writes the winner's won line with the price and the seller's sold line with what they receive" do
    bid(@first, 30_000)
    bid(@second, 25_000)
    @listing.update_columns(ends_at: 1.minute.ago)

    assert close.success?

    assert_equal [ "won", 26_300 ], notice(@first).attributes.values_at("kind", "amount")
    assert_equal [ "sold", 23_670 ], notice(@seller).attributes.values_at("kind", "amount")
    assert_nil notice(@second)
  end

  test "a close with no bid writes the seller's unsold line and nothing else" do
    @listing.update_columns(ends_at: 1.minute.ago)

    assert close.success?

    assert_equal [ "unsold", nil ], notice(@seller).attributes.values_at("kind", "amount")
    assert_equal 1, Game::Market::Notice.count
  end

  test "a bidder who lost at the close keeps the line they had and gets no outcome line" do
    bid(@first, 30_000)
    bid(@second, 40_000)
    @listing.update_columns(ends_at: 1.minute.ago)
    close

    assert_equal "outbid", notice(@first).kind
    assert_equal "won", notice(@second).kind
  end
end
