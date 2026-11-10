require "test_helper"
require_relative "../../../support/holdings"
require_relative "../../../support/market"
require_relative "../../../support/market_listings"
require_relative "../../../support/market_auctions"
require_relative "../../../support/market_bidding"

class Game::Market::BidderListingsTest < ActiveSupport::TestCase
  include Holdings
  include MarketAuctions
  include MarketBidding
  include MarketListings
  include MarketSettings

  setup do
    @seller = accounts_players(:player)
    @bidder = accounts_players(:moderator)
    @rival = accounts_players(:administrator)
    @cards = %i[common_card_one uncommon_card_one rare_card_one].map { catalog_card_seasons(it) }
    @settings = open_market!(first_opened_at: 1.day.ago)
    [ @bidder, @rival ].each { fund!(it, 200_000) }
  end

  def groups = Game::Market::BidderListings.call(player: @bidder, locale: :en)

  def record(listing, player: @bidder, maximum: 30_000, outcome: "lost")
    Game::Market::Bid.create!(listing:, player:, maximum:, price_after: listing.starting_price, outcome:)
  end

  def row_of(listing) = (groups.in_progress + groups.recent).find { it.token == listing.token }

  test "an auction the player leads reads EN TÊTE with the price, their maximum and the raise" do
    listing = listing!(seller: @seller, card_season: @cards[0], starting_price: 20_000)
    assert bid(@bidder, 30_000, listing).success?

    row = groups.in_progress.sole
    assert_equal [ listing.token, :leading, 20_000, 30_000, true ], [ row.token, row.status, row.price, row.maximum, row.can_raise ]
    assert_nil row.ended_at
  end

  test "a bid that never led reads DÉPASSÉ with the typed maximum" do
    listing = listing!(seller: @seller, card_season: @cards[0], starting_price: 20_000)
    assert bid(@rival, 50_000, listing).success?
    assert bid(@bidder, 30_000, listing).success?

    row = groups.in_progress.sole
    assert_equal [ :outbid, 30_000 ], [ row.status, row.maximum ]
  end

  test "the own maximum is the largest of the player's rows after a raise, never the leader's" do
    listing = listing!(seller: @seller, card_season: @cards[0], starting_price: 20_000)
    assert bid(@bidder, 30_000, listing).success?
    assert bid(@bidder, 45_000, listing).success?
    assert bid(@rival, 40_000, listing).success?

    row = groups.in_progress.sole
    assert_equal 45_000, row.maximum
    assert_not_includes Game::Market::BidderListings::Row.members, :leader_maximum
  end

  test "another player's maximum is never the one read" do
    listing = listing!(seller: @seller, card_season: @cards[0], starting_price: 20_000)
    assert bid(@bidder, 25_000, listing).success?
    assert bid(@rival, 90_000, listing).success?

    assert_equal 25_000, groups.in_progress.sole.maximum
  end

  test "every ended status maps to its word" do
    sold_won = listing!(seller: @seller, card_season: @cards[0], status: "sold", ends_at: 2.days.ago)
    sold_won.update_columns(sold_at: 2.days.ago, final_price: 22_000, leader_id: @bidder.id, leader_maximum: 30_000)
    sold_lost = listing!(seller: @seller, card_season: @cards[1], status: "sold", ends_at: 3.days.ago)
    sold_lost.update_columns(sold_at: 3.days.ago, final_price: 24_000, leader_id: @rival.id, leader_maximum: 30_000)
    unsold = listing!(seller: @seller, card_season: @cards[2], status: "unsold", ends_at: 1.day.ago)
    withdrawn = listing!(seller: @seller, card_season: catalog_card_seasons(:portal_one), status: "withdrawn", ends_at: 4.days.ago)
    [ sold_won, sold_lost, unsold, withdrawn ].each { record(it) }

    statuses = groups.recent.to_h { [ it.token, it.status ] }
    assert_equal :won, statuses.fetch(sold_won.token)
    assert_equal :lost, statuses.fetch(sold_lost.token)
    assert_equal :lost, statuses.fetch(unsold.token)
    assert_equal :withdrawn, statuses.fetch(withdrawn.token)
    assert_equal 22_000, groups.recent.find { it.token == sold_won.token }.price
    assert_empty groups.in_progress
  end

  test "ended auctions are newest end first, dated by the sale else the end" do
    older = listing!(seller: @seller, card_season: @cards[0], status: "unsold", ends_at: 3.days.ago)
    newer = listing!(seller: @seller, card_season: @cards[1], status: "sold", ends_at: 3.days.ago)
    newer.update_columns(sold_at: 1.day.ago, final_price: 20_000, leader_id: @rival.id, leader_maximum: 25_000)
    [ older, newer ].each { record(it) }

    assert_equal [ newer.token, older.token ], groups.recent.map(&:token)
    assert_in_delta newer.sold_at, groups.recent.first.ended_at, 1
  end

  test "an auction ended inside seven days is listed and one ended eight days ago is not" do
    inside = listing!(seller: @seller, card_season: @cards[0], status: "unsold", ends_at: 6.days.ago + 1.hour)
    outside = listing!(seller: @seller, card_season: @cards[1], status: "unsold", ends_at: 8.days.ago)
    [ inside, outside ].each { record(it) }

    assert_equal [ inside.token ], groups.recent.map(&:token)
  end

  test "open auctions are ordered by their end and a due one has no raise" do
    later = listing!(seller: @seller, card_season: @cards[0], hours: 48)
    sooner = listing!(seller: @seller, card_season: @cards[1], hours: 3)
    due = listing!(seller: @seller, card_season: @cards[2], ends_at: 1.minute.ago)
    [ later, sooner, due ].each { record(it, outcome: "beaten") }

    assert_equal [ due.token, sooner.token, later.token ], groups.in_progress.map(&:token)
    assert_equal [ false, true, true ], groups.in_progress.map(&:can_raise)
  end

  test "voided bids and cancelled listings are left out" do
    voided = listing!(seller: @seller, card_season: @cards[0])
    record(voided, outcome: "voided")
    cancelled = listing!(seller: @seller, card_season: @cards[1], status: "cancelled")
    record(cancelled)

    assert_empty groups.in_progress
    assert_empty groups.recent
  end

  test "a player who never bid has no rows, and another player's auctions are not theirs" do
    listing = listing!(seller: @seller, card_season: @cards[0])
    record(listing, player: @rival)

    assert_empty groups.in_progress
    assert_empty groups.recent
  end

  test "each auction appears once however many bids the player placed" do
    listing = listing!(seller: @seller, card_season: @cards[0], starting_price: 20_000)
    assert bid(@bidder, 30_000, listing).success?
    assert bid(@bidder, 40_000, listing).success?

    assert_equal 1, groups.in_progress.size
    assert_nil row_of(listing)&.ended_at
  end
end
