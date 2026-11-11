require "test_helper"
require_relative "../../../support/singleton_stub"
require_relative "../../../support/holdings"
require_relative "../../../support/market"
require_relative "../../../support/market_listings"
require_relative "../../../support/market_auctions"
require_relative "../../../support/market_bidding"

class Game::Market::PlaceBidTest < ActiveSupport::TestCase
  include SingletonStub

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
    @settings = open_market!(increment_basis_points: 500, soft_close_seconds: 180)
    hold(@seller, @card.id, 1, reserved: 1)
    @listing = listing!(seller: @seller, card_season: @card, starting_price: 20_000, ends_at: 1.day.from_now)
    [ @first, @second ].each { fund!(it, 100_000) }
  end

  def reloaded = @listing.reload

  test "the worked example prices each bid and releases the first leader with the third" do
    destroyed = Game::Market::ReconcileWallets.call.destroyed

    assert bid(@first, 30_000).success?
    assert_equal [ @first.id, 30_000, 20_000 ], reloaded.attributes.values_at("leader_id", "leader_maximum", "current_price")

    count = entries_of.count
    assert bid(@second, 25_000).success?
    assert_equal [ @first.id, 30_000, 26_300 ], reloaded.attributes.values_at("leader_id", "leader_maximum", "current_price")
    assert_equal count, entries_of.count

    assert bid(@second, 40_000).success?
    assert_equal [ @second.id, 40_000, 31_500 ], reloaded.attributes.values_at("leader_id", "leader_maximum", "current_price")
    assert_equal [ 100_000, 0 ], figures(@first)
    assert_equal [ 60_000, 40_000 ], figures(@second)
    assert_equal destroyed, Game::Market::ReconcileWallets.call.destroyed
    assert Game::Market::ReconcileWallets.call.balanced?
  end

  test "the winner of the worked example pays the price and recovers the rest" do
    bid(@first, 30_000)
    bid(@second, 25_000)
    bid(@second, 40_000)
    @listing.update!(ends_at: 1.minute.ago)

    Game::Market::CloseAuction.new.call(player: @seller, listing_id: @listing.id)

    assert_equal [ 68_500, 0 ], figures(@second)
    assert_equal [ 100_000, 0 ], figures(@first)
  end

  test "a first bid leads at the starting price and holds its maximum" do
    answer = bid(@first, 30_000).value!

    assert_equal [ :new_leader, 20_000, 30_000, 21_000 ], [ answer.branch, answer.price, answer.maximum, answer.minimum ]
    assert_equal [ 70_000, 30_000 ], figures(@first)
    assert_equal %w[hold], entries_of.where(player_id: @first.id).pluck(:kind)
    assert_equal [ [ @first.id, 30_000, 20_000, "leading" ] ], Game::Market::Bid.pluck(:player_id, :maximum, :price_after, :outcome)
  end

  test "a bid beaten at once writes no entry and keeps the leader" do
    bid(@first, 30_000)

    answer = bid(@second, 25_000).value!

    assert_equal [ :beaten, 26_300, nil, false ], [ answer.branch, answer.price, answer.maximum, answer.equal_maximum ]
    assert_equal [ 100_000, 0 ], figures(@second)
    assert_empty entries_of.where(player_id: @second.id)
    assert_equal [ "beaten" ], outcomes(@second)
    assert_equal 26_300, Game::Market::Bid.where(player_id: @second.id).pick(:price_after)
  end

  test "a new leader releases the previous one and turns their rows outbid" do
    bid(@first, 30_000)
    bid(@second, 25_000)

    answer = bid(@second, 40_000).value!

    assert_equal [ :new_leader, 31_500 ], [ answer.branch, answer.price ]
    assert_equal [ 100_000, 0 ], figures(@first)
    assert_equal [ "outbid" ], outcomes(@first)
    assert_equal %w[beaten leading], outcomes(@second)
    assert_equal %w[release], entries_of.where(player_id: @first.id, kind: "release").pluck(:kind)
  end

  test "equal maximums keep the leader and set the price to the maximum" do
    bid(@first, 30_000)

    answer = bid(@second, 30_000).value!

    assert answer.equal_maximum
    assert_equal [ :beaten, 30_000 ], [ answer.branch, answer.price ]
    assert_equal [ @first.id, 30_000 ], reloaded.attributes.values_at("leader_id", "current_price")
  end

  test "the leader's raise holds only the difference and moves neither price nor end" do
    bid(@first, 30_000)
    ends_at = reloaded.ends_at

    answer = bid(@first, 35_000).value!

    assert_equal [ :raise, 20_000, 35_000 ], [ answer.branch, answer.price, answer.maximum ]
    assert_equal [ 65_000, 35_000 ], figures(@first)
    assert_equal [ 20_000, ends_at ], [ reloaded.current_price, reloaded.ends_at ]
    assert_equal [ 5_000 ], entries_of.where(player_id: @first.id, kind: "hold").order(:id).pluck(:committed_delta).last(1)
    assert_equal %w[leading raise], outcomes(@first)
  end

  test "a leader's bid that is not above their maximum is refused" do
    bid(@first, 30_000)

    nothing_changes do
      assert_equal :below_minimum, bid(@first, 30_000).failure
      assert_equal :below_minimum, bid(@first, 29_000).failure
    end
  end

  test "a bid in the last minutes extends the end by the soft close" do
    @listing.update!(ends_at: 2.minutes.from_now)

    freeze_time do
      bid(@first, 30_000)

      assert_equal 180.seconds.from_now, reloaded.ends_at
      assert_equal reloaded.ends_at, Game::Market::Bid.last.extended_until
    end
  end

  test "a beaten bid in the last minutes extends the end too" do
    bid(@first, 30_000)
    @listing.update!(ends_at: 2.minutes.from_now)

    freeze_time do
      bid(@second, 25_000)

      assert_equal 180.seconds.from_now, reloaded.ends_at
    end
  end

  test "a bid outside the window does not extend" do
    @listing.update!(ends_at: 10.minutes.from_now)
    ends_at = reloaded.ends_at

    bid(@first, 30_000)

    assert_equal ends_at, reloaded.ends_at
    assert_nil Game::Market::Bid.last.extended_until
  end

  test "a bid with exactly the window left does not extend" do
    freeze_time do
      @listing.update!(ends_at: 180.seconds.from_now)

      bid(@first, 30_000)

      assert_equal 180.seconds.from_now, reloaded.ends_at
      assert_nil Game::Market::Bid.last.extended_until
    end
  end

  test "a leader's raise in the window does not extend" do
    bid(@first, 30_000)
    @listing.update!(ends_at: 1.minute.from_now)
    ends_at = reloaded.ends_at

    bid(@first, 35_000)

    assert_equal ends_at, reloaded.ends_at
    assert_nil Game::Market::Bid.last.extended_until
  end

  test "the window of the listing's own version applies, not the current one" do
    open_market!(soft_close_seconds: 3_600)
    @listing.update!(ends_at: 10.minutes.from_now)
    ends_at = reloaded.ends_at

    bid(@first, 30_000)

    assert_equal ends_at, reloaded.ends_at
  end

  test "a bid publishes one event naming the outbid player on a new leader" do
    bid(@first, 30_000)

    bid(@second, 40_000)

    data = events(Game::Market::BidPlaced).last.data
    assert_equal 2, events(Game::Market::BidPlaced).size
    assert_equal [ @second.id, "new_leader", @first.id, 30_000 ], data.values_at(:bidder_id, :branch, :outbid_player_id, :outbid_released)
    assert_equal [ @first.id, "new_leader", nil, 0 ], events(Game::Market::BidPlaced).first.data.values_at(:bidder_id, :branch, :outbid_player_id, :outbid_released)
  end

  test "a beaten bid and a raise name nobody" do
    bid(@first, 30_000)
    bid(@second, 25_000)
    bid(@first, 35_000)

    assert_equal [ "beaten", "raise" ], events(Game::Market::BidPlaced).last(2).map { it.data[:branch] }
    assert(events(Game::Market::BidPlaced).last(2).all? { it.data[:outbid_player_id].nil? && it.data[:outbid_released].zero? })
  end

  test "a removed leader counts as no leader and is released in the same post" do
    bid(@first, 30_000)
    @first.update_columns(banned_at: Time.current)

    answer = bid(@second, 25_000).value!

    assert_equal [ :new_leader, 20_000, @second.id ], [ answer.branch, answer.price, reloaded.leader_id ]
    assert_equal [ 100_000, 0 ], figures(@first)
    assert_equal [ "outbid" ], outcomes(@first)
    assert_empty Game::Market::Bid.where(outcome: "voided")
  end

  test "a bid below the starting price or the next increment is refused" do
    nothing_changes do
      assert_equal :below_minimum, bid(@first, 19_999).failure
    end
    bid(@first, 30_000)
    nothing_changes do
      assert_equal :below_minimum, bid(@second, 20_999).failure
    end
  end

  test "a maximum above what is available is refused, a raise too" do
    nothing_changes do
      assert_equal :more_than_available, bid(@first, 100_001).failure
    end
    bid(@first, 90_000)
    nothing_changes do
      assert_equal :more_than_available, bid(@first, 100_001).failure
    end
  end

  test "two bids of one player never commit more than is available" do
    assert bid(@first, 70_000).success?

    nothing_changes do
      assert_equal :more_than_available, bid(@first, 170_001).failure
    end
    assert_equal [ 30_000, 70_000 ], figures(@first)
  end

  test "the seller cannot bid on their own listing" do
    fund!(@seller, 50_000)

    nothing_changes { assert_equal :own_listing, bid(@seller, 30_000).failure }
  end

  test "an ended listing refuses a bid" do
    @listing.update!(ends_at: 1.second.ago)
    nothing_changes { assert_equal :auction_ended, bid(@first, 30_000).failure }
    @listing.update!(ends_at: 1.day.from_now, status: "sold", sold_at: Time.current, final_price: 20_000)
    nothing_changes { assert_equal :auction_ended, bid(@first, 30_000).failure }
  end

  test "a removed seller refuses a bid" do
    @seller.update_columns(deleted_at: Time.current, steam_id: nil)

    nothing_changes { assert_equal :listing_withdrawn, bid(@first, 30_000).failure }
  end

  test "a closed market refuses a bid" do
    close_market!

    nothing_changes { assert_equal :market_closed, bid(@first, 30_000).failure }
  end

  test "a bad amount is invalid" do
    [ "abc", 0, -5, "", "1.5", 9_223_372_036_854_775_808, nil ].each do |maximum|
      nothing_changes { assert_equal :invalid_price, bid(@first, maximum).failure }
    end
  end

  test "a whole number given as text is accepted" do
    assert bid(@first, " 30000 ").success?
  end

  test "an unknown listing is not found" do
    assert_equal :listing_not_found, Game::Market::PlaceBid.new.call(player: @first, listing_id: 0, maximum: 30_000).failure
  end

  test "a banned or deleted bidder is refused" do
    @first.update_columns(banned_at: Time.current)

    nothing_changes { assert_equal :player_required, bid(@first, 30_000).failure }
  end

  test "a bidder removed while waiting on the bank lock is refused" do
    stale = Accounts::Player.find(@first.id)
    stub_singleton(Game::TradeLocks, :players, ->(*) { Accounts::Player.where(id: @first.id).update_all(banned_at: Time.current) }) do
      nothing_changes { assert_equal :player_required, bid(stale, 30_000).failure }
    end
  end

  test "a deadlock answers market busy" do
    stub_singleton(Game::TradeLocks, :players, ->(*) { raise ActiveRecord::Deadlocked }) do
      nothing_changes { assert_equal :market_busy, bid(@first, 30_000).failure }
    end
  end
end
