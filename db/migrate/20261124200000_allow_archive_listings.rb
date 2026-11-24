class AllowArchiveListings < ActiveRecord::Migration[8.1]
  def change
    change_column_null :game_market_listings, :seller_id, true
  end
end
