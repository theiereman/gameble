require "test_helper"
require_relative "../../../support/market"
require_relative "../../../support/market_listings"
require_relative "../../../support/market_auctions"

class Game::Market::DeletionNoteTest < ActiveSupport::TestCase
  include MarketAuctions
  include MarketListings
  include MarketSettings

  setup do
    @player = accounts_players(:player)
    @other = accounts_players(:moderator)
    open_market!
  end

  def note = Game::Market::DeletionNote.call(player: @player)

  test "a player with no market activity has no note" do
    assert_nil note
  end

  test "a player with a balance has a note carrying the available and the committed PiCoins" do
    fund!(@player, 5_000)
    listing = listing!(seller: @other, card_season: catalog_card_seasons(:common_card_one), ends_at: 1.day.from_now)
    lead!(listing, @player, 2_000)

    assert_equal 5_000, note.balance
  end

  test "a player with an open listing and no balance has a note" do
    listing!(seller: @player, card_season: catalog_card_seasons(:common_card_one), ends_at: 1.day.from_now)

    assert_equal 0, note.balance
  end

  test "a closed listing alone gives no note" do
    listing!(seller: @player, card_season: catalog_card_seasons(:common_card_one), status: "cancelled")

    assert_nil note
  end
end
