class AddListingToGameMarketOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :game_market_orders, :listing_id, :bigint
    add_foreign_key :game_market_orders, :game_market_listings, column: :listing_id, validate: false
  end
end
