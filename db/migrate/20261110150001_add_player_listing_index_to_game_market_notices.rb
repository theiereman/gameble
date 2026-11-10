class AddPlayerListingIndexToGameMarketNotices < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :game_market_notices, %i[player_id listing_id], unique: true, algorithm: :concurrently, name: "index_game_market_notices_on_player_and_listing"
  end
end
