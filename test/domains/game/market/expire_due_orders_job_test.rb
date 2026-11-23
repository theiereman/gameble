require "test_helper"
require_relative "../../../support/singleton_stub"
require_relative "../../../support/market"
require_relative "../../../support/market_auctions"
require_relative "../../../support/market_bidding"
require_relative "../../../support/market_orders"

class Game::Market::ExpireDueOrdersJobTest < ActiveSupport::TestCase
  include SingletonStub
  include MarketAuctions
  include MarketBidding
  include MarketOrders
  include MarketSettings

  setup do
    @buyer = accounts_players(:player)
    open_market!
    fund!(@buyer, 10_000)
    @cards = [ catalog_card_seasons(:common_card_one), catalog_card_seasons(:portal_one), catalog_card_seasons(:rare_card_one) ]
  end

  def due!(card, expires_at: 1.minute.ago) = order!(@buyer, card, 300, expires_at:)

  test "a due order expires once and its price returns to the buyer" do
    order = due!(@cards.first)

    Game::Market::ExpireDueOrdersJob.perform_now

    assert_equal "expired", order.reload.status
    assert_equal [ 10_000, 0 ], figures(@buyer)
    assert_equal 1, Game::Market::LedgerEntry.where(order_id: order.id, kind: "release").count
  end

  test "a second run changes nothing and reports nothing" do
    due!(@cards.first)
    Game::Market::ExpireDueOrdersJob.perform_now

    assert_no_difference([ -> { Game::Market::LedgerEntry.count }, -> { Rails.configuration.event_store.read.count } ]) do
      assert_no_error_reported { Game::Market::ExpireDueOrdersJob.perform_now }
    end
  end

  test "an undue and an ended order are left alone" do
    undue = due!(@cards.first, expires_at: 1.hour.from_now)
    cancelled = due!(@cards.second).tap { it.update_columns(status: "cancelled") }

    assert_no_difference(-> { Game::Market::LedgerEntry.count }) { Game::Market::ExpireDueOrdersJob.perform_now }

    assert_equal %w[open cancelled], [ undue.reload.status, cancelled.reload.status ]
  end

  test "an order that raises does not stop the others and is reported with its id" do
    first, second, third = @cards.map { due!(it) }
    real = Game::Market::ExpireOrder.new
    failing = ->(**arguments) { arguments[:order_id] == second.id ? raise("boom") : real.call(**arguments) }

    report = assert_error_reported(RuntimeError) do
      stub_singleton(Game::Market::ExpireOrder, :new, -> { failing }) { Game::Market::ExpireDueOrdersJob.perform_now }
    end

    assert_equal second.id, report.context[:order_id]
    assert_equal %w[expired open expired], [ first, second, third ].map { it.reload.status }
  end

  test "due orders expire while the market is closed" do
    order = due!(@cards.first)
    close_market!(first_opened_at: 1.day.ago)

    Game::Market::ExpireDueOrdersJob.perform_now

    assert_equal "expired", order.reload.status
  end
end
