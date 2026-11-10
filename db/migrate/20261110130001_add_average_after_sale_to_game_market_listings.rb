class AddAverageAfterSaleToGameMarketListings < ActiveRecord::Migration[8.1]
  def change
    add_column :game_market_listings, :average_after_sale, :bigint
  end
end
