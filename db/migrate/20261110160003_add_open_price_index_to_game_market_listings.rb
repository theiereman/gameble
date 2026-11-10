class AddOpenPriceIndexToGameMarketListings < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :game_market_listings, %i[current_price id], where: "status = 'open'", algorithm: :concurrently,
      name: "index_game_market_listings_open_current_price"
  end
end
