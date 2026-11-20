class AddOpenBestPriceIndexToGameMarketOrders < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    # A card's best open order is read in this exact order, so every column serves the scan.
    safety_assured do
      add_index :game_market_orders, %i[card_id price created_at id], order: { price: :desc }, where: "status = 'open'", algorithm: :concurrently,
        name: "index_game_market_orders_open_best_price"
    end
  end
end
