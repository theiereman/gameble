require "test_helper"
require_relative "../../../support/market"
require_relative "../../../support/market_auctions"
require_relative "../../../support/market_orders"

class Game::Market::EligibleOrdersTest < ActiveSupport::TestCase
  include MarketAuctions
  include MarketOrders
  include MarketSettings

  setup do
    @seller = accounts_players(:player)
    @rare = catalog_card_seasons(:rare_card_one)
    @common = catalog_card_seasons(:common_card_one)
    @settings = open_market!
    @now = Time.current
  end

  def funded_buyer(player = buyer!) = player.tap { fund!(it, 100_000) }

  def eligible(card = @rare) = Game::Market::EligibleOrders.call(card.id, except: @seller.id, now: @now).to_a

  test "the best price comes first, then the oldest, then the lowest id" do
    at = 1.day.ago
    cheap = order!(funded_buyer, @rare, 500, created_at: 2.days.ago)
    newer = order!(funded_buyer, @rare, 900, created_at: @now)
    older = order!(funded_buyer, @rare, 900, created_at: at)
    tied = order!(funded_buyer, @rare, 900, created_at: at)

    assert_equal [ older, tied, newer, cheap ], eligible
    assert_equal older, Game::Market::BestEligibleOrder.call(@rare.id, except: @seller.id, now: @now)
  end

  test "the seller's own order, a removed owner's, one under the rarity's minimum, another game's and a closed one are skipped" do
    fund!(@seller, 1_000)
    order!(@seller, @rare, 900)
    order!(funded_buyer(accounts_players(:banned)), @rare, 900)
    order!(funded_buyer.tap { it.update_columns(deleted_at: 1.hour.ago) }, @rare, 900)
    order!(funded_buyer, @rare, @settings.minimum_price(:rare) - 1)
    order!(funded_buyer, @common, 900)
    order!(funded_buyer, @rare, 900, expires_at: @now)
    order!(funded_buyer, @rare, 900).update!(status: "cancelled")

    assert_empty eligible
  end

  test "the minimum is the one of the order's own version" do
    order = order!(funded_buyer, @rare, 100, settings: open_market!(minimum_price_rare: 100))
    open_market!(minimum_price_rare: 200)

    assert_equal [ order ], eligible
  end

  test "an edition without a rarity has no eligible order" do
    order!(funded_buyer, @rare, 900)
    @rare.update_columns(rarity: nil)

    assert_empty eligible
    assert_empty Game::Market::EligibleOrders.best([ @rare.id ], except: @seller.id, now: @now)
  end

  test "the grid reads each edition's best order and leaves out the editions no order reaches" do
    buyer = funded_buyer
    best = order!(buyer, @rare, 900)
    order!(funded_buyer, @rare, 800)
    common = order!(buyer, @common, 20)
    legendary = catalog_card_seasons(:legendary_card_one)
    order!(funded_buyer, legendary, 900)

    assert_equal({ @rare.id => best, @common.id => common },
      Game::Market::EligibleOrders.best([ @rare.id, @common.id, legendary.id ], except: @seller.id, now: @now))
  end

  test "the draw gives each edition in turn its count of best orders no earlier edition took" do
    best = order!(funded_buyer, @rare, 900)
    second = order!(funded_buyer, @rare, 800)
    third = order!(funded_buyer, @rare, 700)
    common = order!(funded_buyer, @common, 20)

    drawn = Game::Market::EligibleOrders.draw([ [ @rare.id, 1 ], [ @common.id, 0 ], [ @rare.id, 3 ], [ @common.id, 1 ] ], except: @seller.id, now: @now)

    assert_equal [ [ best ], [], [ second, third ], [ common ] ], drawn
  end

  test "the draw gives an edition without a rarity no order" do
    order!(funded_buyer, @rare, 900)
    @rare.update_columns(rarity: nil)

    assert_equal [ [] ], Game::Market::EligibleOrders.draw([ [ @rare.id, 1 ] ], except: @seller.id, now: @now)
  end
end
