class AllowRepostGameFeedEntries < ActiveRecord::Migration[8.1]
  def change
    change_column_null :game_feed_entries, :pack_id, true
    change_column_null :game_feed_entries, :position, true
    add_check_constraint :game_feed_entries, "(kind IN ('pull', 'discovery')) = (pack_id IS NOT NULL AND position IS NOT NULL)",
      name: "game_feed_entries_pack_check", validate: false
  end
end
