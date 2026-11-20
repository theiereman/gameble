class AddOpenExpiresAtIndexToGameMarketOrders < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :game_market_orders, :expires_at, where: "status = 'open'", algorithm: :concurrently, name: "index_game_market_orders_open_expires_at"
  end
end
