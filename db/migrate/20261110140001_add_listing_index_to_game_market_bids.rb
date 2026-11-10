class AddListingIndexToGameMarketBids < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :game_market_bids, %i[listing_id id], algorithm: :concurrently, name: "index_game_market_bids_on_listing_and_id"
  end
end
