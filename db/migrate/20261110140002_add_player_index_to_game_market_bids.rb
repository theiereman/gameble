class AddPlayerIndexToGameMarketBids < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :game_market_bids, %i[player_id listing_id], algorithm: :concurrently, name: "index_game_market_bids_on_player_and_listing"
  end
end
