require "test_helper"
require_relative "../../../support/market"
require_relative "../../../support/market_auctions"
require_relative "../../../support/market_orders"

class Game::Market::OrderConversionContractTest < ActiveSupport::TestCase
  include MarketSettings
  include MarketAuctions
  include MarketOrders

  setup do
    Game::Market::Settings.delete_all
    open_market!
    @owner = buyer!
    fund!(@owner, 1_000)
    @order = order!(@owner, catalog_card_seasons(:rare_card_one), 900)
  end

  test "an order takes the statuses bid and beaten and no other" do
    %w[bid beaten].each do |status|
      @order.update_columns(status:)

      assert_equal status, @order.reload.status
    end
    assert_raises(ActiveRecord::StatementInvalid) { @order.update_columns(status: "converted") }
  end

  test "a notice takes the kinds order_leads and order_beaten and no other" do
    %w[order_leads order_beaten].each do |kind|
      owner = buyer!
      Game::Market::Notice.record(player_id: owner.id, kind:, order_id: @order.id)

      assert_equal [ kind ], Game::Market::Notice.where(player_id: owner.id).pluck(:kind)
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      Game::Market::Notice.insert!({ player_id: @owner.id, kind: "order_converted", order_id: @order.id, noticed_at: Time.current })
    end
  end

  test "an order has one end notice whichever kind it is" do
    Game::Market::Notice.create!(player: @owner, order: @order, kind: "order_leads", noticed_at: Time.current)

    %w[order_beaten order_served order_expired order_leads].each do |kind|
      assert_raises(ActiveRecord::RecordNotUnique) do
        Game::Market::Notice.create!(player: @owner, order: @order, kind:, noticed_at: Time.current)
      end
    end
  end

  test "a notice about the listing of a cheaper order stays beside the end notice" do
    Game::Market::Notice.create!(player: @owner, order: @order, kind: "listed_above_order", noticed_at: Time.current)

    assert_nothing_raised { Game::Market::Notice.create!(player: @owner, order: @order, kind: "order_beaten", noticed_at: Time.current) }
  end

  test "Archive withdrawals are indexed by player and time" do
    indexes = ActiveRecord::Base.connection.indexes(:game_market_archive_withdrawals)

    assert_includes indexes.map(&:columns), %w[player_id created_at]
  end

  test "the converted orders of a listing carry the same keys in both events" do
    row = { order_id: 1, owner_id: 2, listing_id: 3, price: 400, status: "bid", ignored: true }

    listed = Game::Market::CardListed.with(listing_id: 3, seller_id: 4, card_season_id: 5, converted: [ row ])
    applied = Game::Market::WantedChoicesApplied.with(seller_id: 4, sales: [], listing_ids: [ 3 ], entrusted: [], converted: [ row ])

    expected = [ { order_id: 1, owner_id: 2, listing_id: 3, price: 400, status: "bid" } ]
    assert_equal expected, listed.data.fetch(:converted)
    assert_equal expected, applied.data.fetch(:converted)
    assert_empty Game::Market::CardListed.with(listing_id: 3, seller_id: 4, card_season_id: 5).data.fetch(:converted)
    assert_raises(KeyError) { Game::Market::CardListed.with(listing_id: 3, seller_id: 4, card_season_id: 5, converted: [ row.except(:price) ]) }
  end
end
