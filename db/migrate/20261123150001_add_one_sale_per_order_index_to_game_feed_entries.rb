class AddOneSalePerOrderIndexToGameFeedEntries < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :game_feed_entries, :order_id, unique: true, where: "kind = 'sale'",
      name: "index_game_feed_entries_one_sale_per_order", algorithm: :concurrently
  end
end
