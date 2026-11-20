class AddOneOpenOrderPerCardIndexToGameMarketOrders < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :game_market_orders, %i[player_id card_id], unique: true, where: "status = 'open'", algorithm: :concurrently,
      name: "index_game_market_orders_one_open_per_card"
  end
end
