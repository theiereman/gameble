require "test_helper"
require_relative "../../../support/market"

class Game::Market::OrderTest < ActiveSupport::TestCase
  include MarketSettings

  setup do
    @player = accounts_players(:player)
    @card = catalog_cards(:common_card)
    @settings = open_market!
    @now = Time.current
  end

  def order!(player: @player, card: @card, settings: @settings, price: 100, expires_at: @now + 7.days, **)
    Game::Market::Order.create!(player:, card_id: card.id, settings:, price:, expires_at:, **)
  end

  def refused(error, &) = assert_raises(error) { ActiveRecord::Base.transaction(requires_new: true, &) }

  test "an order gets a token and starts open" do
    order = order!

    assert_equal 24, order.token.length
    assert_equal "open", order.reload.status
  end

  test "a second open order of one player for one card is refused, and passes once the first is cancelled" do
    first = order!

    refused(ActiveRecord::RecordNotUnique) { order! }
    first.update_columns(status: "cancelled")
    assert_nothing_raised { order! }
    assert_nothing_raised { order!(player: accounts_players(:moderator)) }
  end

  test "an order past its end but not yet expired still blocks a new one on its game, though it is no longer open" do
    due = order!(expires_at: @now - 1.minute)

    assert_not_includes Game::Market::Order.open_at(@now), due
    refused(ActiveRecord::RecordNotUnique) { order! }
  end

  test "the table refuses an unknown status and a price that is not positive" do
    refused(ActiveRecord::StatementInvalid) { order!(status: "lost") }
    refused(ActiveRecord::StatementInvalid) { order!(price: 0) }
  end

  test "the served columns are set together, and exactly when the order is served" do
    served = { seller_id: accounts_players(:moderator).id, served_card_season_id: catalog_card_seasons(:common_card_one).id, served_at: @now,
      average_after_sale: 90 }

    refused(ActiveRecord::StatementInvalid) { order!(status: "served") }
    refused(ActiveRecord::StatementInvalid) { order!(**served) }
    refused(ActiveRecord::StatementInvalid) { order!(status: "served", **served.except(:average_after_sale)) }
    assert_nothing_raised { order!(status: "served", **served) }
  end

  test "an order is open at a moment only while open and before it expires" do
    live = order!
    order!(card: catalog_cards(:rare_card), expires_at: @now)
    order!(card: catalog_cards(:uncommon_card), expires_at: @now - 1.minute)
    order!(card: catalog_cards(:portal), status: "cancelled")

    assert_equal [ live ], Game::Market::Order.open_at(@now).to_a
  end

  test "an order reaches the rarities whose minimum price, in the version it was placed under, is at most its price" do
    order = order!(price: 78)
    stricter = open_market!(minimum_price_rare: 200)
    later = order!(card: catalog_cards(:rare_card), settings: stricter, price: 78)

    assert_equal [ order ], Game::Market::Order.reaching(:rare).to_a
    assert_equal [ order, later ].sort, Game::Market::Order.reaching("uncommon").to_a.sort
    assert_empty Game::Market::Order.reaching(:epic)
  end

  test "an unknown rarity is refused" do
    assert_raises(ArgumentError) { Game::Market::Order.reaching("mythic") }
    assert_raises(ArgumentError) { Game::Market::Order.reaching("common; DROP TABLE game_market_orders") }
  end
end
