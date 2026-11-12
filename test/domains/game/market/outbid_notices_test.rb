require "test_helper"
require_relative "../../../support/holdings"
require_relative "../../../support/market"
require_relative "../../../support/market_listings"
require_relative "../../../support/market_auctions"
require_relative "../../../support/market_bidding"

class Game::Market::OutbidNoticesTest < ActiveSupport::TestCase
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

  def notices(player) = Game::Market::Notice.where(player_id: player.id, listing_id: @listing.id).to_a

  test "taking the lead writes the outbid player one notice naming the bidder and the released maximum" do
    bid(@first, 30_000)
    bid(@second, 40_000)

    notice = notices(@first).sole
    assert_equal [ "outbid", @second.id, 30_000 ], [ notice.kind, notice.other_player_id, notice.amount ]
    assert_empty notices(@second)
  end

  test "being outbid twice on one listing keeps one row, naming the latest bidder with the latest time" do
    bid(@first, 30_000)
    bid(@second, 40_000)
    first_time = notices(@first).sole.noticed_at
    bid(@first, 50_000)
    bid(@second, 55_000)

    assert_equal 1, Game::Market::Notice.where(player_id: @first.id).count
    notice = notices(@first).sole
    assert_equal [ @second.id, 50_000 ], [ notice.other_player_id, notice.amount ]
    assert_operator notice.noticed_at, :>, first_time
  end

  test "a first bid, a raise and a bid beaten at once write no notice" do
    bid(@first, 30_000)
    bid(@first, 35_000)
    bid(@second, 25_000)

    assert_equal 0, Game::Market::Notice.count
  end

  test "a refused bid writes no notice" do
    bid(@first, 30_000)
    bid(@second, 10)

    assert_equal 0, Game::Market::Notice.count
  end

  test "the table refuses an unknown kind and a second row for one player and listing" do
    assert_raises(ActiveRecord::StatementInvalid) do
      ActiveRecord::Base.transaction(requires_new: true) { Game::Market::Notice.record(player_id: @first.id, listing_id: @listing.id, kind: "mystery") }
    end
    Game::Market::Notice.record(player_id: @first.id, listing_id: @listing.id, kind: "outbid", amount: 1)
    assert_raises(ActiveRecord::RecordNotUnique) do
      ActiveRecord::Base.transaction(requires_new: true) { Game::Market::Notice.insert!({ player_id: @first.id, listing_id: @listing.id, kind: "won", noticed_at: Time.current }) }
    end
  end
end
