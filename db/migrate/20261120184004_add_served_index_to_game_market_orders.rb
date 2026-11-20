class AddServedIndexToGameMarketOrders < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :game_market_orders, %i[served_card_season_id served_at], where: "status = 'served'", algorithm: :concurrently,
      name: "index_game_market_orders_served"
  end
end
