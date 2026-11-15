class AddMovesToGameFeedEntries < ActiveRecord::Migration[8.1]
  def change
    add_column :game_feed_entries, :moves, :jsonb
  end
end
