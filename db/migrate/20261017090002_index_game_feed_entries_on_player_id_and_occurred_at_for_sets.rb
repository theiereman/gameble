class IndexGameFeedEntriesOnPlayerIdAndOccurredAtForSets < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :game_feed_entries, %i[player_id occurred_at], unique: true, where: "kind = 'set'",
      name: "index_game_feed_entries_one_set_per_operation", algorithm: :concurrently
  end
end
