class AddSoldCardSeasonIndexToGameMarketListings < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :game_market_listings, %i[card_season_id sold_at], where: "status = 'sold'", algorithm: :concurrently, name: "index_game_market_listings_sold_card_season"
  end
end
