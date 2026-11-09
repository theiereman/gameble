class AddOneVerdictPerWeekIndexToGameFeedEntries < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :game_feed_entries, :occurred_at, unique: true, where: "kind = 'verdict'",
      name: "index_game_feed_entries_one_verdict_per_week", algorithm: :concurrently
  end
end
