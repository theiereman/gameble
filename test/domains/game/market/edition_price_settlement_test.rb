require "test_helper"
require_relative "../../../support/holdings"
require_relative "../../../support/market"
require_relative "../../../support/market_listings"
require_relative "../../../support/market_auctions"
require_relative "../../../support/market_sales"

class Game::Market::EditionPriceSettlementTest < ActiveSupport::TestCase
  include Holdings
  include MarketAuctions
  include MarketListings
  include MarketSales
  include MarketSettings

  setup do
    @seller = accounts_players(:player)
    @winner = accounts_players(:moderator)
    @card = catalog_card_seasons(:common_card_one)
    @settings = open_market!(average_sale_count: 5, average_window_days: 90)
    fund!(@winner, 200_000)
  end

  def due_listing(card = @card, price: 20_000)
    hold(@seller, card.id, 1, reserved: 1)
    listing = listing!(seller: @seller, card_season: card, starting_price: price, ends_at: 1.minute.ago)
    lead!(listing, @winner, price, price:)
    listing
  end

  def close(listing) = Game::Market::CloseAuction.new.call(player: @seller, listing_id: listing.id)

  def row(card = @card) = Game::Market::EditionPrice.find_by(card_season_id: card.id)

  test "a settlement writes the row and the listing's average" do
    listing = due_listing(price: 10_000)

    assert close(listing).success?

    assert_equal [ 10_000, 1 ], row.attributes.values_at("average", "sales_used")
    assert_not_nil row.refreshed_at
    assert_equal 10_000, listing.reload.average_after_sale
  end

  test "the sale counts in its own window with the earlier sales" do
    sold!(@card, 30_000, sold_at: 2.days.ago)
    sold!(@card, 20_000, sold_at: 3.days.ago)
    listing = due_listing(price: 10_000)

    close(listing)

    assert_equal [ 20_000, 3 ], row.attributes.values_at("average", "sales_used")
    assert_equal 20_000, listing.reload.average_after_sale
  end

  test "two settlements in turn leave the row on the formula and each listing its own average" do
    first = due_listing(price: 10_000)
    close(first)
    second = due_listing(price: 20_000)
    close(second)

    assert_equal [ 15_000, 2 ], row.attributes.values_at("average", "sales_used")
    assert_equal [ 10_000, 15_000 ], [ first.reload.average_after_sale, second.reload.average_after_sale ]
    assert_equal 1, Game::Market::EditionPrice.where(card_season_id: @card.id).count
  end

  test "two editions are independent" do
    other = catalog_card_seasons(:rare_card_one)
    close(due_listing(price: 10_000))
    close(due_listing(other, price: 50_000))

    assert_equal 10_000, row.average
    assert_equal 50_000, row(other).average
  end

  test "an unsold close writes no row and no average" do
    hold(@seller, @card.id, 1, reserved: 1)
    listing = listing!(seller: @seller, card_season: @card, ends_at: 1.minute.ago)

    assert_no_difference -> { Game::Market::EditionPrice.count } do
      close(listing)
    end
    assert_nil listing.reload.average_after_sale
  end

  test "a withdrawn close writes no row and no average" do
    hold(@seller, @card.id, 1, reserved: 1)
    listing = listing!(seller: @seller, card_season: @card, ends_at: 1.minute.ago)
    lead!(listing, @winner, 20_000, price: 1_300)
    @seller.update!(deleted_at: Time.current)

    assert_no_difference -> { Game::Market::EditionPrice.count } do
      assert close(listing).success?
    end
    assert_equal [ "withdrawn", nil ], [ listing.reload.status, listing.average_after_sale ]
  end

  test "a second close changes nothing" do
    listing = due_listing(price: 10_000)
    close(listing)

    assert_no_changes -> { [ row.attributes, listing.reload.average_after_sale ] } do
      assert_equal :listing_not_closable, close(listing).failure
    end
  end

  test "a deadlock stores nothing" do
    listing = due_listing(price: 10_000)

    Game::Market::EditionPrice.stub(:lock_row, ->(*) { raise ActiveRecord::Deadlocked }) do
      assert_equal :market_busy, close(listing).failure
    end

    assert_nil row
    assert_equal [ "open", nil ], [ listing.reload.status, listing.average_after_sale ]
  end

  test "the edition row is locked after the holdings and before the wallets" do
    listing = due_listing(price: 10_000)
    statements = []
    watcher = ->(*, payload) { statements << payload[:sql] if payload[:sql].include?("FOR UPDATE") }

    ActiveSupport::Notifications.subscribed(watcher, "sql.active_record") { close(listing) }

    locked = statements.map do |sql|
      case sql
      when /"game_holdings"/ then :holdings
      when /"game_market_edition_prices"/ then :edition
      when /"game_market_wallets"/ then :wallets
      end
    end.compact
    assert_equal %i[holdings edition wallets], locked.uniq
  end
end
