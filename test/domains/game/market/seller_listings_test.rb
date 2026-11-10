require "test_helper"
require_relative "../../../support/holdings"
require_relative "../../../support/market"
require_relative "../../../support/market_listings"
require_relative "../../../support/market_auctions"

class Game::Market::SellerListingsTest < ActiveSupport::TestCase
  include Holdings
  include MarketAuctions
  include MarketListings
  include MarketSettings

  setup do
    @seller = accounts_players(:player)
    @other = accounts_players(:moderator)
    @common = catalog_card_seasons(:common_card_one)
    @rare = catalog_card_seasons(:rare_card_one)
    @settings = open_market!(first_opened_at: 1.day.ago)
  end

  def rows = Game::Market::SellerListings.call(player: @seller, locale: :en)

  def tokens(group) = group.map(&:token)

  test "open listings are in progress, the soonest end first" do
    later = listing!(seller: @seller, card_season: @common, hours: 48)
    sooner = listing!(seller: @seller, card_season: @rare, hours: 2)

    assert_equal [ sooner.token, later.token ], tokens(rows.in_progress)
    assert_empty rows.ended
  end

  test "ended listings are newest first and dated by their end" do
    sold = listing!(seller: @seller, card_season: @common, status: "sold", ends_at: 3.days.ago)
    sold.update_columns(sold_at: 2.days.ago, final_price: 1_500)
    unsold = listing!(seller: @seller, card_season: @rare, status: "unsold", ends_at: 1.day.ago)

    assert_equal [ unsold.token, sold.token ], tokens(rows.ended)
    assert_in_delta sold.sold_at, rows.ended.last.ended_at, 1
    assert_equal 1_500, rows.ended.last.current_price
    assert_in_delta unsold.ends_at, rows.ended.first.ended_at, 1
  end

  test "a listing cancelled before its end is in ended, dated by its cancel" do
    cancelled = listing!(seller: @seller, card_season: @common, status: "cancelled", ends_at: 5.days.from_now)

    row = rows.ended.sole
    assert_equal cancelled.token, row.token
    assert_in_delta cancelled.updated_at, row.ended_at, 1
    assert_empty rows.in_progress
  end

  test "the window keeps the last 30 days by the end of each outcome" do
    old = listing!(seller: @seller, card_season: @common, status: "unsold", ends_at: 31.days.ago)
    old_cancel = listing!(seller: @seller, card_season: @rare, status: "cancelled", ends_at: 2.days.from_now)
    old_cancel.update_columns(updated_at: 31.days.ago)
    kept = listing!(seller: @seller, card_season: @rare, status: "unsold", ends_at: 29.days.ago)

    assert_equal [ kept.token ], tokens(rows.ended)
    assert_not_includes tokens(rows.ended), old.token
  end

  test "ended rows stop at one hundred" do
    now = Time.current
    Game::Market::Listing.insert_all!(Array.new(101) do |index|
      { token: "token#{index.to_s.rjust(19, "0")}", seller_id: @seller.id, card_season_id: @common.id, settings_id: @settings.id, starting_price: 1_300,
        current_price: 1_300, duration_hours: 24, ends_at: now - index.minutes - 1.hour, status: "unsold", created_at: now, updated_at: now }
    end)

    assert_equal 100, rows.ended.size
  end

  test "a sold row carries what the seller received, from their own ledger rows only" do
    sold = listing!(seller: @seller, card_season: @common, status: "sold", ends_at: 1.day.ago)
    sold.update_columns(sold_at: 1.day.ago, final_price: 31_500, leader_id: @other.id, leader_maximum: 40_000)
    fund!(@seller, 1_000)
    fund!(@other, 1_000)
    [ [ @seller, :sale, 31_500 ], [ @seller, :commission, -3_150 ], [ @other, :sale, 999 ] ].each do |player, kind, amount|
      Game::Market::Ledger.post(Game::Market::Ledger::Entry.new(player_id: player.id, kind:, available_delta: amount, listing_id: sold.id, settings_id: @settings.id))
    end

    assert_equal 28_350, rows.ended.sole.received
  end

  test "only the seller's own listings are read" do
    listing!(seller: @other, card_season: @rare)

    assert_empty rows.in_progress
    assert_empty rows.ended
  end

  test "an open listing can be cancelled only without a leader and before its end" do
    free = listing!(seller: @seller, card_season: @common, hours: 5)
    led = listing!(seller: @seller, card_season: @rare, hours: 6)
    fund!(@other, 50_000)
    lead!(led, @other, 30_000)
    due = listing!(seller: @seller, card_season: catalog_card_seasons(:uncommon_card_one), ends_at: 1.minute.ago)

    by_token = rows.in_progress.index_by(&:token)
    assert by_token.fetch(free.token).can_cancel
    assert_not by_token.fetch(led.token).can_cancel
    assert_not by_token.fetch(due.token).can_cancel
  end

  test "an unsold row offers a relist while it is the latest of its edition and a free copy exists" do
    hold(@seller, @common.id, 1)
    unsold = listing!(seller: @seller, card_season: @common, status: "unsold", ends_at: 1.day.ago, starting_price: 2_000, buy_now_price: 9_000)

    offer = rows.ended.sole.relist
    assert_equal [ "#{@common.card.slug}:#{@common.season.number}", 2_000, 9_000 ], [ offer.ref, offer.start, offer.buy_now ]
    assert_equal unsold.token, rows.ended.sole.token
  end

  test "no relist offer without a free copy" do
    hold(@seller, @common.id, 1, reserved: 1)
    listing!(seller: @seller, card_season: @common, status: "unsold", ends_at: 1.day.ago)

    assert_nil rows.ended.sole.relist
  end

  test "no relist offer on an older listing of the edition" do
    hold(@seller, @common.id, 1)
    older = listing!(seller: @seller, card_season: @common, status: "unsold", ends_at: 3.days.ago)
    newer = listing!(seller: @seller, card_season: @common, status: "unsold", ends_at: 1.day.ago)

    by_token = rows.ended.index_by(&:token)
    assert_nil by_token.fetch(older.token).relist
    assert by_token.fetch(newer.token).relist
  end

  test "no relist offer on a sold, cancelled or withdrawn row" do
    hold(@seller, @common.id, 1)
    %w[sold cancelled withdrawn].each_with_index do |status, index|
      listing = listing!(seller: @seller, card_season: [ @common, @rare, catalog_card_seasons(:uncommon_card_one) ][index], status:, ends_at: 1.day.ago)
      listing.update_columns(sold_at: 1.day.ago, final_price: 1_300) if status == "sold"
    end

    assert(rows.ended.all? { it.relist.nil? })
  end

  test "a row carries no leader, bidder or maximum" do
    assert_equal %i[token card status current_price ends_at ended_at received can_cancel relist], Game::Market::SellerListings::Row.members
  end
end
