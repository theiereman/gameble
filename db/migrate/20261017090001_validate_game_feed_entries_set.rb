class ValidateGameFeedEntriesSet < ActiveRecord::Migration[8.1]
  def change
    validate_check_constraint :game_feed_entries, name: "game_feed_entries_kind_check"
    validate_check_constraint :game_feed_entries, name: "game_feed_entries_set_check"
    validate_check_constraint :game_feed_entries, name: "game_feed_entries_tier_check"
  end
end
