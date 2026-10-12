class IndexGameFeedEntriesOnTradeId < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :game_feed_entries, :trade_id, unique: true, where: "trade_id IS NOT NULL", algorithm: :concurrently
  end
end
