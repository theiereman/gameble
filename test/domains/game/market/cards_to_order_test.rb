require "test_helper"
require_relative "../../../support/game_sets"
require_relative "../../../support/holdings"
require_relative "../../../support/market"
require_relative "../../../support/market_auctions"
require_relative "../../../support/market_orders"

class Game::Market::CardsToOrderTest < ActiveSupport::TestCase
  include GameSets
  include Holdings
  include MarketAuctions
  include MarketOrders
  include MarketSettings

  setup do
    @player = accounts_players(:player)
    @seasons = %i[rare_card_one common_card_one uncommon_card_one portal_one].map { catalog_card_seasons(it) }
    insert_set(@seasons.map(&:id), { complete: 4 })
    Game::AddGoal.new.call(player: @player, kind: "theme", key: "roguelike").value!
    open_market!
    fund!(@player, 10_000)
  end

  def cards(player = @player) = Game::Market::CardsToOrder.call(player, Game::GoalNeeds.call(@player), locale: :en)

  def titles = cards.values.sole.map(&:title)

  test "the missing cards of each goal in set order, as card views by slug" do
    hold(@player, @seasons.last.id)

    assert_equal [ Game::Goal.sole.id ], cards.keys
    assert_equal [ "Blue Depths", "Tin Soldier", "Green Hills" ], titles
    assert_equal %w[blue-depths tin-soldier green-hills], cards.values.sole.map(&:id)
  end

  test "a card the player has an open order on is skipped; a served or cancelled order skips nothing" do
    order!(@player, @seasons.first, 100)
    order!(@player, @seasons.second, 100)
      .update_columns(status: "served", seller_id: buyer!.id, served_card_season_id: @seasons.second.id, served_at: Time.current, average_after_sale: 100)
    order!(@player, @seasons.third, 100).update_columns(status: "cancelled")
    order!(buyer!.tap { fund!(it, 1_000) }, @seasons.last, 100)

    assert_equal [ "Tin Soldier", "Green Hills", "Portal" ], titles
  end

  test "nothing while the market is suspended or was never opened, nor for a visitor" do
    assert_equal({}, cards(nil))

    close_market!
    assert_equal({}, cards)

    forget_market!
    assert_equal({}, cards)
  end
end
