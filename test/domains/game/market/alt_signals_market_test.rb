require "test_helper"
require_relative "../../../support/alt_signal_seeds"
require_relative "../../../support/market"
require_relative "../../../support/market_listings"

class Game::Market::AltSignalsMarketTest < ActiveSupport::TestCase
  include AltSignalSeeds
  include MarketListings
  include MarketSettings

  setup do
    @alice = accounts_players(:player)
    @bob = accounts_players(:moderator)
    @carol = accounts_players(:administrator)
    @card = catalog_card_seasons(:common_card_one)
    open_market!(first_opened_at: 90.days.ago)
    Game::Pack.update_all(opened_at: nil)
    @now = Time.current
  end

  def detected(signal) = Game::Market::AltSignals.call(now: @now).select { it.signal == signal }

  def outside!(price, seller: @alice, buyer: @bob, ago: 2.days) = sale!(seller, buyer, @card, price, sold_at: ago.ago, average_after_sale: 10_000)

  def tie_through_minimum_price_sales!
    3.times { |ago| sale!(@alice, @bob, @card, 1_300, sold_at: (ago + 1).days.ago) }
  end

  test "two sales under half and over twice the average, between the same accounts, are outside the market price" do
    priced_history!(@card, average: 10_000)
    outside!(4_999)
    outside!(20_001, ago: 1.day)

    found = detected("sales_outside_price")

    assert_equal [ [ @alice.id, @bob.id ] ], found.map { [ it.account_id, it.other_account_id ] }
    assert_equal({ "sales" => 2, "below" => 1, "above" => 1 }, found.first.facts)
  end

  test "exactly half or twice the average, a single outside sale and sales to different buyers are not a signal" do
    priced_history!(@card, average: 10_000)
    outside!(5_000)
    outside!(20_000, ago: 1.day)
    outside!(4_000, buyer: @carol, ago: 3.days)

    assert_empty detected("sales_outside_price")
  end

  test "an edition with fewer earlier sales than the few-sales threshold has no market price" do
    priced_history!(@card, average: 10_000, sales: Game::Market::EditionPrice::MINIMUM_SALES - 1)
    outside!(1_000)
    outside!(30_000, ago: 1.day)

    assert_empty detected("sales_outside_price")
  end

  test "a sale older than 30 days is left out" do
    priced_history!(@card, average: 10_000)
    outside!(4_000)
    outside!(4_000, ago: 31.days)

    assert_empty detected("sales_outside_price")
  end

  test "a sale with no leader is left out" do
    priced_history!(@card, average: 10_000)
    outside!(4_000)
    outside!(4_000, ago: 1.day).update_columns(leader_id: nil, leader_maximum: nil)

    assert_empty detected("sales_outside_price")
  end

  test "3 sales at the minimum price between the same two accounts are a signal, 2 or one above the minimum are not" do
    3.times { |ago| sale!(@alice, @bob, @card, 1_300, sold_at: (ago + 1).days.ago) }
    2.times { |ago| sale!(@bob, @carol, @card, 1_300, sold_at: (ago + 1).days.ago) }
    2.times { |ago| sale!(@carol, @alice, @card, 1_300, sold_at: (ago + 1).days.ago) }
    sale!(@carol, @alice, @card, 1_301)

    found = detected("minimum_price_sales")

    assert_equal [ [ @alice.id, @bob.id, { "sales" => 3 } ] ], found.map { [ it.account_id, it.other_account_id, it.facts ] }
  end

  test "the minimum price is the one of the listing's rarity and of the version it was created under" do
    earlier = open_market!(minimum_price_common: 1_400)
    3.times { |ago| sale!(@alice, @bob, @card, 1_400, sold_at: (ago + 1).days.ago, settings: earlier) }
    open_market!(minimum_price_common: 1_500)
    3.times { |ago| sale!(@carol, @bob, catalog_card_seasons(:uncommon_card_one), 1_400, sold_at: (ago + 1).days.ago, settings: earlier) }

    assert_equal [ @alice.id ], detected("minimum_price_sales").map(&:account_id)
  end

  test "a bid on a listing of a seller tied by a pair signal is a signal, naming the seller" do
    tie_through_minimum_price_sales!
    listing = listing!(seller: @alice, card_season: @card)
    bid!(@bob, listing)
    bid!(@bob, listing, outcome: "raise")

    found = detected("bids_on_tied_seller")

    assert_equal [ [ @bob.id, @alice.id, { "listings" => 1, "bids" => 1 } ] ], found.map { [ it.account_id, it.other_account_id, it.facts ] }
  end

  test "a bid with no tie, or by a third account, is not a signal" do
    tie_through_minimum_price_sales!
    listing = listing!(seller: @alice, card_season: @card)
    bid!(@carol, listing)
    other = listing!(seller: @carol, card_season: @card)
    bid!(@bob, other)

    assert_empty detected("bids_on_tied_seller")
  end

  test "an account signal or another bid never makes a tie" do
    [ @alice, @bob ].each { |player| (1..3).each { |day| open_capsules!(player, 130, on: @now.utc.to_date - day) } }
    listing = listing!(seller: @alice, card_season: @card)
    bid!(@bob, listing)

    assert_equal 2, Game::Market::AltSignals.call(now: @now).count { it.signal == "near_maximum_opening" }
    assert_empty detected("bids_on_tied_seller")
  end

  test "a bid older than 30 days is left out" do
    tie_through_minimum_price_sales!
    bid!(@bob, listing!(seller: @alice, card_season: @card), created_at: 31.days.ago)

    assert_empty detected("bids_on_tied_seller")
  end

  test "an account that deleted itself is never a signal, as account or as the other account" do
    tie_through_minimum_price_sales!
    @bob.update_columns(deleted_at: Time.current)

    assert_empty Game::Market::AltSignals.call(now: @now)
  end

  test "a one-way trade pair ties its accounts too" do
    10.times { one_way_trade!(@alice, @bob, closed_at: @now - 1.day) }
    bid!(@alice, listing!(seller: @bob, card_season: @card))

    assert_equal [ [ @alice.id, @bob.id ] ], detected("bids_on_tied_seller").map { [ it.account_id, it.other_account_id ] }
  end

  test "the refresh stores the new signals and writes nothing else" do
    tie_through_minimum_price_sales!
    bid!(@bob, listing!(seller: @alice, card_season: @card))
    watched = -> { [ Game::Market::Listing.pluck(:id, :status, :final_price), Game::Market::Bid.pluck(:id, :outcome), Game::Market::LedgerEntry.count ] }

    assert_no_changes watched do
      Game::Market::RefreshAltSignals.new.call(now: @now).value!
    end

    assert_equal %w[bids_on_tied_seller minimum_price_sales], Game::Market::AltSignal.order(:signal).pluck(:signal)
  end
end
