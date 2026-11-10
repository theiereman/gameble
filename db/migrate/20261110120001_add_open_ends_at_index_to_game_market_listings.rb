class AddOpenEndsAtIndexToGameMarketListings < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :game_market_listings, :ends_at, where: "status = 'open'", algorithm: :concurrently, name: "index_game_market_listings_open_ends_at"
  end
end
