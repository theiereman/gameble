require "test_helper"
require_relative "../../../support/holdings"
require_relative "../../../support/market"
require_relative "../../../support/market_listings"
require_relative "../../../support/market_auctions"

class Game::Market::AnnonceEventsTest < ActiveSupport::TestCase
  include Holdings
  include MarketAuctions
  include MarketListings
  include MarketSettings

  setup do
    @seller = accounts_players(:player)
    @reader = accounts_players(:moderator)
    @rival = accounts_players(:administrator)
    @card = catalog_card_seasons(:common_card_one)
    open_market!
    hold(@seller, @card.id, 1, reserved: 1)
    @listing = listing!(seller: @seller, card_season: @card, starting_price: 20_000, ends_at: 1.day.from_now)
    fund!(@rival, 50_000)
    lead!(@listing, @rival, 40_000, price: 31_500)
    Game::Market::Notice.record(player_id: @reader.id, listing_id: @listing.id, kind: "outbid", other_player_id: @rival.id, amount: 30_000)
  end

  def events(viewer) = Game::Market::AnnonceEvents.call(token: @listing.token, viewer:)

  test "an outbid viewer who is not leading gets the notice's other player and amount" do
    outbid = events(@reader).outbid

    assert_equal [ @rival, 30_000 ], [ outbid.other, outbid.amount ]
  end

  test "a visitor, another player and the leader get none" do
    assert_nil events(nil).outbid
    assert_nil events(@seller).outbid
    assert_nil events(@rival).outbid
  end

  test "a viewer who leads again gets none" do
    @listing.update_columns(leader_id: @reader.id)

    assert_nil events(@reader).outbid
  end

  test "a listing that is no longer open gets none" do
    @listing.update_columns(status: "sold")

    assert_nil events(@reader).outbid
  end
end
