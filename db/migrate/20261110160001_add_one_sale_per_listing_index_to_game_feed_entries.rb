class AddOneSalePerListingIndexToGameFeedEntries < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :game_feed_entries, :listing_id, unique: true, where: "kind = 'sale'",
      name: "index_game_feed_entries_one_sale_per_listing", algorithm: :concurrently
  end
end
