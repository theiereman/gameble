# The feed's type filters (story 6.2) read one kind's entries newest first,
# notable or fillers: this index serves that read in order. Built
# concurrently so the table stays writable (strong_migrations).
class IndexGameFeedEntriesOnKind < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :game_feed_entries, [ :kind, :notable, :occurred_at ], algorithm: :concurrently
  end
end
