class AddSellerStatusIndexToGameMarketListings < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :game_market_listings, %i[seller_id status], algorithm: :concurrently
  end
end
