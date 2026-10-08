class ValidateGameFeedEntriesPackCheck < ActiveRecord::Migration[8.1]
  def change
    validate_check_constraint :game_feed_entries, name: "game_feed_entries_pack_check"
  end
end
