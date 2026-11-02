class IndexGameFeedEntriesOnToken < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :game_feed_entries, :token, unique: true, algorithm: :concurrently
  end
end
